classdef EpochGroup < sa_labs.analysis.entity.AbstractGroup
    
    properties
        epochIndices
        filter
        quality
    end

    methods
        
        function obj = EpochGroup(epochIndices, filter, name, epochs)
            if nargin < 3
                name = 'anonymous';
                epochs = [];
            end
            obj = obj@sa_labs.analysis.entity.AbstractGroup(num2str(name));
            obj.epochIndices = epochIndices;
            obj.filter = filter;

            for epoch = each(epochs)
                obj.populateEpochResponseAsFeature(epoch);
            end
        end
    end

    methods (Access = private)

        function populateEpochResponseAsFeature(obj, epoch)
            import sa_labs.analysis.*;

            for device = each(epoch.get('devices'))
                path = epoch.dataLinks(device);
                obj.createFeature([upper(device) '_EPOCH'], @() epoch.responseHandle(path), 'append', true);
            end

            for derivedResponseKey = each(epoch.derivedAttributes.keys)
                obj.createFeature([upper(derivedResponseKey)], @() epoch.derivedAttributes(derivedResponseKey), 'append', true);
            end
        end
    end
end
