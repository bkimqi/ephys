classdef OptiCSVFileRigidBody<OptiCSVFile
    %OPTICSVFILESINGLEMARKER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function newobj = OptiCSVFileRigidBody(file)
            %OPTICSVFILESINGLEMARKER Construct an instance of this class
            %   Detailed explanation goes here
            newobj@OptiCSVFile(file);
            newobj= newobj.loadData(file);
        end
        
        function obj = loadData(obj,file)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            %% Rigid Body
            
            opts = delimitedTextImportOptions('NumVariables', 9);
            
            % Specify range and delimiter
            opts.DataLines = [8, Inf];
            opts.Delimiter = ',';
            
            % Specify column names and types
            opts.VariableNames = {'Frame', 'Time', 'Xr', 'Yr', 'Zr', 'Wr', 'X', 'Y', 'Z'};
            opts.VariableTypes = {'uint32', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'};
            opts.ExtraColumnsRule = 'ignore';
            opts.EmptyLineRule = 'read';
            
            % Import the data
            obj.table = readtable(file, opts);
        end

    end
end

