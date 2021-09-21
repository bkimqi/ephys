classdef TimeIntervalZT < neuro.time.TimeInterval
    %TIMEINTERVALZT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ZeitgeberTime
    end
    
    methods
        function obj = TimeIntervalZT(varargin)
            %TIMEINTERVALZT Construct an instance of this class
            %   Detailed explanation goes here
            if isa(varargin{1},'neuro.time.TimeInterval')
                ti=varargin{1};
                startTime=ti.StartTime;
                sampleRate=ti.SampleRate;
                numberOfPoints=ti.NumberOfPoints;
                zt=varargin{2};
            else
                startTime=varargin{1};
                sampleRate=varargin{2};
                numberOfPoints=varargin{3};
                zt=varargin{4};
            end
            obj@neuro.time.TimeInterval(startTime, sampleRate, numberOfPoints)
            obj.ZeitgeberTime= zt+obj.getDate;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

