classdef ChannelTimeData
    %CHANNELTIMEDATA Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        channels
        time
        data
    end
    
    methods
        function obj = ChannelTimeData(ch, time, data)
            %CHANNELTIMEDATA Construct an instance of this class
            %   Detailed explanation goes here
            l= logging.Logger.getLogger;
            if nargin==3
                if isstring(ch)||iscellstr(ch)||isinteger(ch)
                    obj.channels=ch;
                else
                    l.error('Provide string or scalar.')
                end
                if isa(time,'neuro.time.TimeIntervalCombined')||isa(time,'neuro.time.TimeInterval')
                    obj.time = time;
                else
                    l.error('Provide neuro.time.TimeIntervalCombined object.')
                end
                if isequal(size(data),[numel(ch.getActiveChannels) time.getNumberOfPoints])
                    obj.data=data;
                else
                    l.error('Data size is not compatible with channel and time info.')
                end
            end
        end
        
%         function obj = get(obj,channels,time)
%             %METHOD1 Summary of this method goes here
%             %   Detailed explanation goes here
%             if ~exist('channels','var')|| isempty(channels)
%                 channels=obj.Channels.getActiveChannels;
%             end
%             if ~exist('time','var')|| isempty(time)
%                 time=[obj.Time.getStartTime obj.Time.getEndTime];
%             end
%         end
        function obj = getLowpassFiltered(obj,freq)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            dat=ft_preproc_lowpassfilter(table2array(obj.data)', ...
                obj.time.getSampleRate,freq);
            obj.data=array2table(dat',VariableNames= ...
                obj.data.Properties.VariableNames);
        end
        function obj = getMedianFiltered(obj,winSeconds)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            obj.data=smoothdata(obj.data,"movmedian", ...
                winSeconds*obj.time.getSampleRate);
        end
    end
end

