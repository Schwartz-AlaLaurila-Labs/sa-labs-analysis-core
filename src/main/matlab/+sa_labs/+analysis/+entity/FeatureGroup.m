classdef FeatureGroup < sa_labs.analysis.entity.Group
    
    properties
        id                  % Identifier of the featureGroup, assigned by NodeManager @see NodeManager.addFeatureGroup
        epochGroup          % Read only dataSet and used as cache
        device
    end
    
    properties(SetAccess = immutable)
        splitParameter      % Defines level of featureGroup in tree
        splitValue          % Defines the branch of tree
    end
    
    properties (Hidden)
        epochIndices        % List of epoch indices to be processed in Offline analysis. @see CellData and FeatureExtractor.extract
        parametersCopied    % Avoid redundant collection of parameters
    end
    
    methods
        
        function obj = FeatureGroup(splitParameter, splitValue, name)
            if nargin < 3
                name = [splitParameter '==' num2str(splitValue)];
            end
            obj = obj@sa_labs.analysis.entity.Group(name);
            obj.splitParameter = splitParameter;
            obj.splitValue = splitValue;
            obj.parametersCopied = false;
        end

        function p = getParameter(obj, key)
            import sa_labs.analysis.app.*;
            p = unique(obj.get(key));
            if numel(p) > 1
                throw(Exceptions.MULTIPLE_VALUE_FOUND.create('warning', true, 'message', obj.name))
            end
        end

        function populateEpochResponseAsFeature(obj, epochs)
            import sa_labs.analysis.app.*;

            if isempty(obj.device)
                throw(Exceptions.DEVICE_NOT_PRESENT.create('message', obj.name))
            end
        
            for epoch = each(epochs)
                path = epoch.dataLinks(obj.device);
                key = obj.makeValidKey(strcat(obj.device, Constants.EPOCH_KEY_SUFFIX));
                obj.createFeature(key, @() getfield(epoch.responseHandle(path), 'quantity'), 'append', true);

                for derivedResponseKey = each(epoch.derivedAttributes.keys)
                    if obj.hasDevice(derivedResponseKey)
                        key = obj.makeValidKey(derivedResponseKey);
                        obj.createFeature(key, @() epoch.derivedAttributes(derivedResponseKey), 'append', true);
                    end
                end
            end
        end

        function data = getFeatureData(obj, key)
            import sa_labs.analysis.*;

            data = getFeatureData@sa_labs.analysis.entity.Group(obj, key);
            if isempty(data)
                [~, features] = util.collections.getMatchingKeyValue(obj.featureMap, key);
                
                if isempty(features)
                    app.Exceptions.FEATURE_KEY_NOT_FOUND.create('warning', true)
                    return
                end
                data = obj.getData([features{:}]);
            end
            

        end

        function tf = hasDevice(obj, key)
            tf = strfind(upper(key), upper(obj.device));
        end
    end
end

