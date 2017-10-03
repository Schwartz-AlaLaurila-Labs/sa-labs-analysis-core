classdef EpochGroup < sa_labs.analysis.entity.AbstractGroup
    
    properties
        epochIndices
        filter
        quality
    end

    methods
        
        function obj = EpochGroup(epochIndices, filter, name, epochData)
            if nargin < 3
                name = 'anonymous';
                epochData = [];
            end
            obj = obj@sa_labs.analysis.entity.AbstractGroup(num2str(name));
            obj.epochIndices = epochIndices;
            obj.filter = filter;
        end
    end

    methods (Access = private)

        function populateEpochResponseAsFeature(obj, epoch)
        end

        function populateDerivedEpochResponseAsFeature(obj, epoch)
        end
    end
end
