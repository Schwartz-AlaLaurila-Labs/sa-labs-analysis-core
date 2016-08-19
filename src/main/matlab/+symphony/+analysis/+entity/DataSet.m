classdef DataSet < handle & matlab.mixin.CustomDisplay
    
    properties
        name
        epochIndices
        filter
        quality
    end
    
    methods
        
        function obj = DataSet(epochIndices, filter, name)
            if nargin < 3
                name = 'anonymous';
            end
            obj.epochIndices = epochIndices;
            obj.filter = filter;
            obj.name = num2str(name);
        end
    end
end
