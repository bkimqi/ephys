function [pairs_plot_all, pp_pairs] = pre_v_postCCG(spike_data_fullpath, ...
    session_name, varargin)
% pre_v_postCCG(spike_data_path, session_name)
%   Screen for ms connectivity in ANY of the PRE-rest (3hr) , MAZE (3hr) or
%   POST-sleep (3hr) sessions and plot CCGs with stats for visual
%   inspection. Useful for initial screening of millisecond-connectivity
%   across all cell pairs and plotting of ALL pairs. See ____ for plotting
%   final pairs only.
%
%   IMPORTANT NOTE: this code uses the CCG function from 
%   www.github.com/buzsakilab/buzcode.git repository. You MUST have
%   the buzcode/analysis/spikes/correlation folder on your path!
% 

ip = inputParser;
ip.addRequired('spike_data_fullpath', @isfile);
ip.addRequired('session_name', @ischar);
ip.addParameter('alpha', 0.05, @(a) a > 0 && a < 0.25);
ip.addParameter('jscale', 5, @(a) a > 0 && a < 10);
ip.addParameter('debug', false, @islogical);
ip.addParameter('conn_type', 'ExcPairs', @(a) ismember(a, ...
    {'ExcPairs', 'InhPairs', 'GapPairs'}));
ip.addParameter('wintype', 'gauss', @(a) ismember(a, ...
    {'gauss', 'rect', 'triang'})); % convolution window type
ip.addParameter('plot_conv', true, @islogical);
ip.addParameter('plot_jitter', false, @islogical); 
ip.addParameter('save_plots', true, @islogical); % save all the plots you make 
ip.addParameter('jitter_debug', false, @islogical); % used for debugging jitter code only
ip.addParameter('save_jitter', false, @islogical); % save jitter results for fast recall!
ip.addParameter('njitter', 100, @(a) a > 0 && round(a) == a);
ip.addParameter('screen_type', 'one_prong', @(a) ismember(a, ...
    {'one_prong', 'two_prong'})); % one_prong = @jscale and alpha specified, two_prong = @alpha specified + EITHER 5ms or 1ms convolution window.
ip.addParameter('combine_epochs', false, @islogical)
ip.addParameter('pair_type_plot', 'all', @(a) ismember(a, ...
    {'all', 'pyr-pyr', 'int-int', 'pyr-int'}));
ip.addParameter('pairs_list', [], @(a) isnumeric(a) && size(a,2) == 2);
ip.addParameter('for_grant', false, @islogical);  % simplify plots for grant prelim data plots!
ip.parse(spike_data_fullpath, session_name, varargin{:});

alpha = ip.Results.alpha;
jscale = ip.Results.jscale;
debug = ip.Results.debug;
wintype = ip.Results.wintype;
conn_type = ip.Results.conn_type;
plot_conv = ip.Results.plot_conv;
plot_jitter = ip.Results.plot_jitter;
save_plots = ip.Results.save_plots;
jitter_debug = ip.Results.jitter_debug;
njitter = ip.Results.njitter;
save_jitter = ip.Results.save_jitter;
screen_type = ip.Results.screen_type;
combine_epochs = ip.Results.combine_epochs;
pair_type_plot = ip.Results.pair_type_plot;
pairs_list = ip.Results.pairs_list;
for_grant = ip.Results.for_grant;

nplot = 4; % # pairs to plot per figure

% Make sure you look at convolution plots prior to running jitter.
if plot_jitter; plot_conv = false; end
%% Step 0: load spike and behavioral data, parse into pre, track, and post session

[data_dir, name, ~] = fileparts(spike_data_fullpath);
if ~debug
load(spike_data_fullpath, 'spikes')
if contains(name, 'wake')
    load(fullfile(data_dir, 'wake-behavior.mat'), 'behavior');
    load(fullfile(data_dir, 'wake-basics.mat'),'basics');
elseif contains(name, 'sleep') % this can be used later for parsing NREM v REM v other periods...
    load(fullfile(data_dir, 'sleep-behavior.mat'), 'behavior');
    load(fullfile(data_dir, 'sleep-basics.mat'), 'basics');
end
SampleRate = basics.(session_name).SampleRate;

% Make data nicely formatted to work with buzcode
bz_spikes = Hiro_to_bz(spikes.(session_name), session_name);

% Pull out PRE, MAZE, and POST time limits
nepochs_plot = 3; % used to keep plots nice!
if contains(name, 'wake')
    if ~combine_epochs
        nepochs = 3;
        save_name_append = '';
        epoch_names = {'Pre', 'Maze', 'Post'};
        time_list = behavior.(session_name).time/1000; % convert time list to milliseconds
    
    elseif combine_epochs
        nepochs = 1;
        epoch_names = {'Pre-Maze-Post Combined'};
        time_list = [behavior.(session_name).time(1)/1000, ...
            behavior.(session_name).time(end)/1000];
        save_name_append = '_combined';
    end
elseif contains(name, 'sleep')
    nepochs = 3;
    
    % Name epochs nicely (up to 5 maximum!)
%     prefixes = {'First', 'Second', 'Third', 'Fourth', 'Fifth'};
%     epoch_names = cellfun(@(a) ['Sleep ' a ' ' num2str(1) '/' num2str(nepochs)], ...
%         prefixes(1:nepochs), 'UniformOutput', false);
    epoch_names = arrayfun(@(a) ['Sleep Block ' num2str(a)], 1:nepochs, ...
        'UniformOutput', false);
    epoch_times = (0:nepochs)*diff(behavior.(session_name).time/1000)/nepochs + ...
        behavior.(session_name).time(1)/1000;
    save_name_append = ['_' num2str(nepochs) 'epochs'];
    time_list = nan(nepochs,2);
    for j = 1:nepochs
        time_list(j,:) = [epoch_times(j), epoch_times(j+1)];
    end
end

nneurons = length(spikes.(session_name));
for j = 1:nepochs
    epoch_bool = bz_spikes.spindices(:,1) >= time_list(j,1) ...
        & bz_spikes.spindices(:,1) <= time_list(j,2); % ID spike times in each epoch
    parse_spikes(j).spindices = bz_spikes.spindices(epoch_bool,:); % parse spikes by epoch into this variable
end
% Figure out if pyramidal or inhibitory
cell_type = repmat('p', 1, length(bz_spikes.quality));
cell_type(bz_spikes.quality == 8) = 'i';

%% Step 1: Screen for ms connectivity by running EranConv_group on each session 
alpha_orig = alpha; jscale_orig = jscale;
if strcmp(screen_type, 'one_prong')
    jscale_use = jscale;
elseif strcmp(screen_type, 'two_prong')
    jscale_use = [1 5];
end
for js = 1:length(jscale_use)
    try
        if ~exist('pairs','var')  % the logic in the if/else statement is terrible.
            load(fullfile(data_dir,[session_name '_jscale' num2str(jscale_use(js)) '_alpha' ...
                num2str(round(alpha*100)) '_pairs' save_name_append]), ...
                'pairs', 'jscale', 'alpha')
        elseif strcmp(screen_type,'two_prong') && js >= 2
            if pairs(1).jscale == 1
                pairs_comb(1).pairs = pairs;
                load(fullfile(data_dir,[session_name '_jscale' num2str(jscale_use(js)) '_alpha' ...
                    num2str(round(alpha*100)) '_pairs' save_name_append]),...
                    'pairs', 'jscale', 'alpha')
                pairs_comb(2).pairs = pairs; % concatenate!
                
            else
                error('Error in pre_v_postCCG')
            end
            
        end
        if alpha_orig ~= alpha || jscale_use(js) ~= jscale
            disp('input jscale and/or alpha values differ from inputs. Re-running Eran Conv')
            error('Re-run EranConv analysis with specified jscale and alpha')
        end
    catch
        for j = 1:nepochs
            % This next line of code seems silly, but I'm leaving it in
            % You can replace bz_spike.UID with any cell numbers to only plot
            % through those. Might be handy in the future!
            cell_inds = arrayfun(@(a) find(bz_spikes.UID == a), bz_spikes.UID);
            disp(['Running EranConv_group for ' session_name ' ' epoch_names{j} ' epoch'])
            [ExcPairs, InhPairs, GapPairs, RZero] = ...
                EranConv_group(parse_spikes(j).spindices(:,1)/1000, parse_spikes(j).spindices(:,2), ...
                bz_spikes.UID(cell_inds), SampleRate, jscale_use(js), alpha, bz_spikes.shankID(cell_inds), ...
                wintype);
            pairs(j).ExcPairs = ExcPairs;
            pairs(j).InhPairs = InhPairs;
            pairs(j).GapPairs = GapPairs;
            pairs(j).RZero = RZero;
            pairs(j).jscale = jscale_use(js);
        end
        save(fullfile(data_dir,[session_name '_jscale' num2str(jscale_use(js)) '_alpha' ...
            num2str(round(alpha*100)) '_pairs' save_name_append]), ...
            'pairs', 'jscale', 'alpha')
    end
end

% Now concatenate all cell pairs that pass EITHER timescale criteria if
% using two-pronged screening approach
if strcmp(screen_type, 'two_prong')
    
    % concatenate pairs 
    for k = 1:nepochs
        pairs(k).(conn_type) = cat(1, pairs_comb(1).pairs(k).(conn_type),...
            pairs_comb(2).pairs(k).(conn_type));
        
        % Identify unique pairs
        pair_row_inds = arrayfun(@(a,b) find(all(pairs(k).(conn_type)(:,1:2) == [a b],2)), ...
            pairs(k).(conn_type)(:,1), pairs(k).(conn_type)(:,2), ...
            'UniformOutput', false); % this identifies all row indices that match a given cell-pair
        
        unique_pairs = unique(cellfun(@(a) a(1), pair_row_inds)); % keep only the first of a redundant pair
        
        % Keep only unique pairs
        pairs(k).(conn_type) = pairs(k).(conn_type)(unique_pairs,:);
    end
    
end
elseif debug  % use this to cut down on time while debugging...
    if isempty(getenv('computername'))
        load('/data/Working/Other Peoples Data/HiroData/wake_new/pre_v_postCCG_debug_data.mat',...
            'bz_spikes', 'parse_spikes', 'pairs', 'SampleRate', 'wintype');
    elseif strcmp(getenv('computername'),'NATLAPTOP')
       load('C:\Users\Nat\Documents\UM\Working\HiroData\wake_new\pre_v_postCCG_debug_data.mat',...
           'bz_spikes', 'parse_spikes', 'pairs', 'SampleRate', 'wintype');
    end
end
    
%% Step 2a: Identify pairs that passed the screening test above in Step 1
for ref_epoch = 1:nepochs
    if ~isempty(pairs(ref_epoch).(conn_type))
        % Get boolean for pairs on different shanks only
        cell1_shank = arrayfun(@(a) bz_spikes.shankID(a == bz_spikes.UID), ...
            pairs(ref_epoch).(conn_type)(:,1));
        cell2_shank = arrayfun(@(a) bz_spikes.shankID(a == bz_spikes.UID), ...
            pairs(ref_epoch).(conn_type)(:,2));
        diff_shank_bool = cell1_shank ~= cell2_shank;
        pairs_diff_shank = pairs(ref_epoch).(conn_type)(diff_shank_bool,:);
        
        % Aggregate all pairs based on epoch in which they obtained ms
        % connectivity.
        if ~exist('pairs_plot_all','var') % set up pairs to plot with nans in non-significant epochs
            pairs_plot_all = cat(2, pairs_diff_shank(:,1:2), ...
                nan(size(pairs_diff_shank,1),ref_epoch-1), pairs_diff_shank(:,3));
        elseif exist('pairs_plot_all','var')
            % First ID cell pairs with ms_connectivity in multiple epochs
            temp = arrayfun(@(a,b) find(all(pairs_plot_all(:,1:2) == [a b],2)), ...
                pairs_diff_shank(:,1), pairs_diff_shank(:,2), 'UniformOutput', false);
            redundant_pairs = cat(2, cat(1,temp{:}), find(~cellfun(@isempty, temp)));
            unique_pairs = find(cellfun(@isempty, temp));
            
            % Now add in pvalues for current epoch
            pairs_plot_all = [pairs_plot_all nan(size(pairs_plot_all,1),1)];  %#ok<AGROW>
            if ~isempty(redundant_pairs)
                pairs_plot_all(redundant_pairs(:,1), ref_epoch + 2) = ...
                    pairs_diff_shank(redundant_pairs(:,2),3);
            end
            
            % Now add in new cell-pairs that gain ms connectivity in that epoch
            if ~isempty(unique_pairs)
                pairs_plot_all = cat(1, pairs_plot_all, ...
                    cat(2, pairs_diff_shank(unique_pairs,1:2), nan(length(unique_pairs),...
                    ref_epoch - 1), pairs_diff_shank(unique_pairs,3)));
            end
            
            
        end
    elseif isempty(pairs(ref_epoch).(conn_type)) && ref_epoch == 3  && ...
            size(pairs_plot_all, 2) < nplot % edge-case
        ncol_append = nplot - size(pairs_plot_all,2);
        pairs_plot_all = cat(2, pairs_plot_all, nan(size(pairs_plot_all,1), ncol_append));
    end
end

% Pull out only specific pairs if specified!
if ~isempty(pairs_list)
    pairs_keep_bool = false(size(pairs_plot_all, 1), 1);
    for j = 1:size(pairs_list,1)
        pairs_keep_bool = pairs_keep_bool | ...
            (pairs_plot_all(:,1) == pairs_list(j,1) & ...
            pairs_plot_all(:,2) == pairs_list(j,2));
    end
    pairs_plot_all = pairs_plot_all(pairs_keep_bool, :);
end


% Get all pyr-pyr pairs!
c1type = arrayfun(@(a) cell_type(a == bz_spikes.UID), pairs_plot_all(:,1));
c2type = arrayfun(@(a) cell_type(a == bz_spikes.UID), pairs_plot_all(:,2));
pp_pairs = pairs_plot_all(c1type == 'p' & c2type == 'p',:);

pages_look = [];
for j = 1:size(pp_pairs,1) 
    pages_look = [pages_look ...
        ceil(find(pairs_plot_all(:,1) == pp_pairs(j,1) & ...
        pairs_plot_all(:,2) == pp_pairs(j,2))/nplot)]; 
end

% append on pages where you should lookup pyr-pyr pairs
pp_pairs = [pp_pairs, pages_look'];  

%% Step 2b: keep only pairs of cell types you want
% 2021_04_05: 'all' pairs and 'pyr-pyr' pairs only valid now

switch pair_type_plot
    case 'all'
        pair_type_append = '';
    case 'pyr-pyr'
        pairs_plot_all = pp_pairs(:,1:end-1);
        pair_type_append = '_pponly';
end

%% Step 2c: set up figures and subplots
if plot_conv || plot_jitter
    try close 100; end; try close 102; end
    hcomb = cat(2, figure(100), figure(102));
    
    % Monitor specific plot settings.
    screensize = get(0,'screensize');
    % set plotting up for 4k vs HD monitors
    if screensize(3) >= 3840 && screensize(4) >= 2160
        res_type = '4k';
        pos = [70 230 2660 1860]; a_offset = [0 850 100 900]'; b_offset = [0 0 -100 -100]';
    else
        res_type = 'HD';
        pos = [35 115 1160 630]; a_offset = [0 50 700 800]'; b_offset = [0 -50 0 -50]';
    end
    arrayfun(@(a) set(a, 'Position', pos), hcomb(:));
end

%% Step 3: Now plot everything
if save_jitter; jitter_data = struct(); end
if plot_jitter || plot_conv
    if jitter_debug  % grab only a couple cell pairs to plot when debugging.
        keyboard
        input_pairs = input('Enter 2xn array of cells pairs to plot, otherwise type ''all'' to plot all pairs: ');
        if ~strcmp(input_pairs, 'all')
            temp = arrayfun(@(a,b) find(all(pairs_plot_all(:,1:2) == [a b],2)), ...
                input_pairs(:,1), input_pairs(:,2), 'UniformOutput', false);
            pair_inds_use = cat(1,temp{:});
            pairs_plot_all = pairs_plot_all(pair_inds_use, :);
        end
    end
    
    % Set up variables for plotting
    npairs_all = size(pairs_plot_all,1);
    nfigs = ceil(npairs_all/nplot);
    nrows = nplot;
    coarse_fine_text = {'coarse', 'fine'};
    nepochs = length(epoch_names);
    hw2 = waitbar(0, ['running CCG\_jitter for ' session_name ' ' conn_type]);
    set(hw2,'Position', [1420 250 220 34]);
    for nfig = 1:nfigs
        if nfig < nfigs % update pairs to plot
            rows_to_plot = (nplot*(nfig-1)+1):nplot*nfig;
        elseif nfig == nfigs
            rows_to_plot = (nplot*(nfig-1)+1):npairs_all;
            nplot = length(rows_to_plot);
        end
        pairs_plot = pairs_plot_all(rows_to_plot,:);
        if nfig > 1  % set up new figures
            try close 100; end; try close 102; end
            hcomb = cat(2, figure(100), figure(102)); arrayfun(@(a) set(a, 'Position', pos), hcomb(:));
        end
        
        for coarse_fine = 1:2
            if coarse_fine == 1 % coarse
                duration = 0.02; binSize = 0.0005; jscale_plot = 5;
            elseif coarse_fine == 2 % fine
                duration = 0.007; binSize = 1/SampleRate; jscale_plot = 1;
            end
            
            % If plotting jitter only do at the time-scale specified to
            % save time.
            if plot_jitter && jscale_plot ~= jscale
                continue
            end
            fig_use = figure(hcomb(1, coarse_fine));
            for epoch_plot = 1:nepochs
                
                for k = 1:nplot
                    
                    cell1 = pairs_plot(k,1);
                    cell2 = pairs_plot(k,2);
                    cell1_type = cell_type(bz_spikes.UID == cell1);
                    cell2_type = cell_type(bz_spikes.UID == cell2);
                    pval = pairs_plot(k,epoch_plot+2);
                    res1 = parse_spikes(epoch_plot).spindices(...
                        parse_spikes(epoch_plot).spindices(:,2) == cell1,1)/1000;
                    res2 = parse_spikes(epoch_plot).spindices(...
                        parse_spikes(epoch_plot).spindices(:,2) == cell2,1)/1000;
                    if epoch_plot == 2 && k == 1; top_row = conn_type; else; top_row = ''; end
                    if plot_conv
                        [pvals, pred, qvals, ccgR, tR] = CCGconv(res1, res2, SampleRate, ...
                            binSize, duration, 'jscale', jscale_plot, 'alpha', 0.01, ...
                            'plot_output', get(fig_use, 'Number'), ...
                            'ha', subplot(nrows, 3, epoch_plot + (k-1)*nepochs_plot),...
                            'wintype', wintype);
                        if ~isnan(pval)
                            title({top_row; [epoch_names{epoch_plot} ' ' num2str(cell1) cell1_type ...
                                ' v ' num2str(cell2) cell2_type ': ' ...
                                'p_{' num2str(pairs(epoch_plot).jscale) 'ms}= ' num2str(pval, '%0.2g')]});
                        elseif isnan(pval)
                            title({top_row; [epoch_names{epoch_plot} ' ' num2str(cell1) cell1_type ... 
                                ' v ' num2str(cell2) cell2_type]});
                        end
                    elseif plot_jitter
                        [GSPExc,GSPInh,pvalE,pvalI,ccgR,tR,LSPExc,LSPInh,JBSIE,JBSII] = ...
                            CCG_jitter(res1, res2, SampleRate, binSize, duration, 'jscale', jscale, ...
                            'plot_output', get(fig_use, 'Number'), 'subfig', epoch_plot + (k-1)*nepochs_plot, ...
                            'subplot_size', [nrows, 3], 'njitter', njitter, 'alpha', alpha,...
                            'for_grant', for_grant);
                        if save_jitter
                           jitter_data =  save_jitter_vars(jitter_data, [cell1, cell2], ...
                               rows_to_plot(k), epoch_plot, GSPExc, GSPInh,...
                               pvalE,pvalI,ccgR,tR,LSPExc,LSPInh,JBSIE,JBSII);
                        end
                        if strcmp(conn_type, 'InhPairs')
                            JBSI = max(JBSII); jb_type = 'JBSII_{max}= ';
                        else
                            JBSI = max(JBSIE); jb_type = 'JBSIE_{max}= ';
                        end
                        title({top_row; [epoch_names{epoch_plot} ' ' num2str(cell1) cell1_type...
                            ' v ' num2str(cell2) cell2_type ': ' ...
                            jb_type num2str(JBSI)]});
                        ylims = get(gca,'ylim');
                        
                        if ~for_grant
                            if any(GSPExc)
                                hold on;
                                plot(tR(GSPExc == 1)*1000, 0.95*ylims(2), 'r^');
                            end
                            if any(GSPInh)
                                hold on;
                                plot(tR(GSPInh == 1)*1000, 0.95*ylims(2),'bv');
                            end
                        end
                            
                        
                    end
                    
                    % plot only cell #s for grant.
                    if for_grant
                        if epoch_plot == 1
                            title({top_row; [epoch_names{epoch_plot} ': ' ...
                                num2str(cell1) cell1_type...
                                ' v ' num2str(cell2) cell2_type]});
                        else
                            title({top_row; epoch_names{epoch_plot}});
                        end
                    end
                    
                    % Turn off xlabels for all but bottom row for
                    % readability on HD monitors
                    if k < nplot
                        cur_ax = subplot(nrows, 3, epoch_plot + (k-1)*nepochs);
                        xlabel(cur_ax,'');
                        if strcmp(res_type,'HD')
                            set(cur_ax,'XTick',[],'XTickLabel','');
                        end
                    end
                    waitbar(rows_to_plot(k)/npairs_all, hw2);
                end
            end
            if save_plots  % save all plots!
                if plot_conv; type = 'conv'; elseif plot_jitter; type = 'jitter'; end
                arrayfun(@(a) make_figure_pretty(a,  'linewidth', 1, 'fontsize', 14), ...
                    hcomb)
                printNK([session_name '_all_' conn_type '_jscale' num2str(jscale) '_' ...
                    coarse_fine_text{coarse_fine} '_CCGs_' type save_name_append pair_type_append],...
                    data_dir, 'hfig', fig_use, 'append', true);
            end
        end
        
    end
    
    % If no pairs identified, save that info in a pdf so you don't keep on
    % looking for that data later!
    if save_plots && isempty(pairs_plot_all)
        for coarse_fine = 1:2
            fig_use = figure(hcomb(1, coarse_fine));
            subplot(1,1,1);
            text(0.1, 0.5, ['No ' conn_type ' found']);
            axis off
            printNK([session_name '_all_' conn_type '_jscale' num2str(jscale) '_' ...
                coarse_fine_text{coarse_fine} '_CCGs' save_name_append pair_type_append],...
                data_dir, 'hfig', fig_use, 'append', true);
        end
    end
    try close(hw2); end
end

%%
if plot_jitter && save_jitter
    if strcmp('screen_type', 'one_prong')
        scale_name = ['_jscale' num2str(jscale)];
    else
        scale_name = ['_twoprong_jscale' num2str(jscale)];
    end
    jitter_filename = fullfile(data_dir, [session_name '_' conn_type scale_name...
        '_alpha' num2str(round(alpha*100)) save_name_append '_jitterdata.mat']);
    save(jitter_filename,'jitter_data', 'njitter','epoch_names')
end

try close 100; end; try close 102; end
end

%% Send all variables calculated from jitter into data structure.
function [jit_var_out] = save_jitter_vars(jit_var_in, cell_pair, row, epoch, varargin)
    var_names = {'GSPExc','GSPInh','pvalE','pvalI','ccgR','tR','LSPExc',...
        'LSPInh','JBSIE','JBSII'};
%     if isfield(jit_var_in, 'JBSII')
%         npairs = size(jit_var_in,1);
%     else
%         npairs = 0;
%     end
    jit_var_out = jit_var_in;
    jit_var_out(row, epoch).cell_pair = cell_pair;
    for var_num = 1:length(var_names)
        jit_var_out(row, epoch).(var_names{var_num}) = varargin{var_num};
    end
end

