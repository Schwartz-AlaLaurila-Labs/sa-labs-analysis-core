classdef EpochGroup < sa_labs.analysis.entity.Group
    
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
            obj = obj@sa_labs.analysis.entity.Group(num2str(name));
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
            
            devices = epoch.get('devices');
            if ischar(devices)
                devices = {devices};
            end
            
            for device = each(devices)
                path = epoch.dataLinks(device);
                obj.createFeature([upper(device) '_EPOCH'], @() getfield(epoch.responseHandle(path), 'quantity'), 'append', true);
            end

            for derivedResponseKey = each(epoch.derivedAttributes.keys)
                obj.createFeature([upper(derivedResponseKey)], @() epoch.derivedAttributes(derivedResponseKey), 'append', true);
            end
        end
    end
end
