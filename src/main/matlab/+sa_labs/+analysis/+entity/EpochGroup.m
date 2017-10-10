classdef EpochGroup < sa_labs.analysis.entity.Group
    
    properties
        id                  % Identifier of the epochGroup, assigned by NodeManager @see NodeManager.addEpochGroup
        device              % Amplifier channel name Eg 'Amp1'
    end
    
    properties(SetAccess = immutable)
        splitParameter      % Defines level of epochGroup in tree
        splitValue          % Defines the branch of tree
    end
    
    properties (Hidden)
        epochIndices        % List of epoch indices to be processed in Offline analysis. @see CellData and FeatureExtractor.extract
        parametersCopied     % Avoid redundant collection of epoch parameters
        cellParametersCopied % Avoid redundant collection of cell parameters
    end
    
    methods
        
        function obj = EpochGroup(splitParameter, splitValue, name)
            if nargin < 3
                name = [splitParameter '==' num2str(splitValue)];
            end
            obj = obj@sa_labs.analysis.entity.Group(name);
            obj.splitParameter = splitParameter;
            obj.splitValue = splitValue;
            obj.parametersCopied = false;
            obj.cellParametersCopied = false;
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
                key = obj.makeValidKey(Constants.EPOCH_KEY_SUFFIX);
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
            tf = any(strfind(upper(key), upper(obj.device)));
        end

        function key = makeValidKey(obj, key)
            key = makeValidKey@sa_labs.analysis.entity.Group(obj, key);
            
            if ~ obj.hasDevice(key)
                key = upper(strcat(obj.device, '_', key));
            end
        end
    end
end

