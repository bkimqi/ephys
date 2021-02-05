classdef TimeFrequencyMapWavelet < TimeFrequencyMap
    %TIMEFREQUENCYMAPWAVELET Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function obj = TimeFrequencyMapWavelet(...
                matrix, timePoints,frequencyPoints)
            %TIMEFREQUENCYMAPWAVELET Construct an instance of this class
            %   Detailed explanation goes here
            obj@TimeFrequencyMap(matrix, timePoints,frequencyPoints)
            obj.clim=[0 150];
        end
        
        function imsc = plot(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
    
                imsc=imagesc(seconds(obj.timePoints-obj.timePoints(1)),...
                    obj.frequencyPoints,abs(obj.matrix),obj.clim);
                obj.addTimeAxis()
        end
        function phase = getPhase(obj,freq)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            va=angle(obj.matrix(ismember(obj.frequencyPoints,freq),:));
            phase=Channel(num2str(freq),va,obj.timeIntervalCombined);
        end
        function power = getPower(obj,freq)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            va=abs(obj.matrix(ismember(obj.frequencyPoints,freq),:));
            power=Channel(num2str(freq),va,obj.timeIntervalCombined);
        end
    end
end

