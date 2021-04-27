function [spikes] = Hiro_to_bz(spike_data, session_name, stable_filter)
% spikes = Hiro_to_bz(spikes_mat_file, session_name, stable_filter)
%   This one-off function converts Hiro Miyawaki's data 
% (Miyawaki et al., 2016) in .mat format to the output format of 
% bz_GetSpikes, or at least enough to msec time-scale functions by
% K.Diba or D.English & S.McKenzie. Also spits out quality (1,2,3 = best,
% better, ok, poor pyramidal neurons, 8 = interneuron, 9 = MUA. 
% 4 and 9 are filtered out by default.
%
%   INPUTS
%   spike_data: spikes data loaded from .m file from Hiro Miyawaki data
%   session_name: e.g. 'RoySleep0' or 'KevinMaze1'. Note that wake
%       v sleep can be un-ambiguously determined from this ('Rest =
%       pre-maze during dark cycle, 'Sleep' = post-maze sleep during light
%       cycle, 'Maze' = 3 hr end of rest + 3 hour on linear track + 3 hour
%       beginning of sleep).
%   stable_filter (optional): true (default) = keep only neurons that are
%   stable across ALL epochs. Accepts either single boolean or array
%   boolean matching # epochs in data.
%
%  OUTPUTS - see bz_GetSpikes. Includes spike.times, .UID, .sessionName,
%  .shankID, and .cluID. Spike times in MILLISECONDS.

if nargin < 3
    stable_filter = true;
end

time_to_msec=1/(1000); 

spikes.sessionName = session_name;

% Make life easy on the user - accept full data structure or
% session-specific sub-structure
try 
    cat(1, spike_data.quality);
catch ME
    
    % load session specific structure
    if strcmp(ME.identifier, 'MATLAB:nonExistentField')
        spike_data = spike_data.(session_name);
    end
end


% Filter out unstable neurons
stable_bool = true(1,length(spike_data));
if any(stable_filter)
    stability_all = cat(1, spike_data.isStable);
    stable_bool = all(stability_all == stable_filter,2);
end

% Filter out MUA and poor quality interneurons
UIDall = 1:length(spike_data);
quality_all = cat(1, spike_data.quality);
good_bool = ismember(quality_all, [1 2 3 8]) & stable_bool; % filter out poor pyr. cells (4) and MUA (9).
spikes.UID = UIDall(good_bool);
spikes_file_filt = spike_data(good_bool);
nneurons = length(spikes_file_filt);

% spike times
[stimes_sec{1:nneurons}] = deal(spikes_file_filt.time);
spikes.times = cellfun(@(a) a'*time_to_msec, stimes_sec, ...
    'UniformOutput', false); % make row array

% spinindices
UIDs_cell = arrayfun(@(a) ones(size(spikes.times{a}))*spikes.UID(a), ...
    1:nneurons, 'UniformOutput', false);
times_unsorted = cat(1, spikes.times{:});
[times_sorted, isort] = sort(times_unsorted); % sort
UIDs_unsorted = cat(1, UIDs_cell{:});
spikes.spindices = [times_sorted, UIDs_unsorted(isort)];

% shankID and cluID
shank_clu = cat(1, spikes_file_filt.id);
spikes.shankID = shank_clu(:,1)'; 
spikes.cluID = shank_clu(:,2)';

% Now do the same as spindices but for cluster and shank ID
shankIDs_cell = arrayfun(@(a) ones(size(spikes.times{a}))*spikes.shankID(a), ...
    1:nneurons, 'UniformOutput', false);
cluIDs_cell = arrayfun(@(a) ones(size(spikes.times{a}))*spikes.cluID(a), ...
    1:nneurons, 'UniformOutput', false);
sIDs_unsorted = cat(1, shankIDs_cell{:});
cIDs_unsorted = cat(1, cluIDs_cell{:});
spikes.shcluindices = [sIDs_unsorted(isort), cIDs_unsorted(isort)];

% quality
spikes.quality = cat(1, spikes_file_filt.quality)';

% stability
spikes.stability = cat(1, spikes_file_filt.stability)';

end

