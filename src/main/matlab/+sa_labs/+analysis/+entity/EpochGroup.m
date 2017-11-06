classdef EpochGroup < sa_labs.analysis.entity.Group
    
    properties
        id                  % Identifier of the epochGroup, assigned by FeatureTreeBuilder @see FeatureTreeBuilder.addEpochGroup
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
                Exceptions.DEVICE_NOT_PRESENT.create('message', obj.name, 'warning', true);
                return;
            end
        
            for epoch = each(epochs)
                path = epoch.dataLinks(obj.device);
                key = obj.makeValidKey(Constants.EPOCH_KEY_SUFFIX);
                obj.createFeature(key, @() transpose(getfield(epoch.responseHandle(path), 'quantity')), 'append', true);

                for derivedResponseKey = each(epoch.derivedAttributes.keys)
                    if obj.hasDevice(derivedResponseKey)
                        key = obj.makeValidKey(derivedResponseKey);
                        obj.createFeature(key, @() epoch.derivedAttributes(derivedResponseKey), 'append', true);
                    end
                end
            end
        end

        function data = getFeatureData(obj, key)
            
            % Given the key, it tries to fetch the exact (or) nearest feature 
            % match using regular expression. As a next step, it formats the 
            % data on following order
            %
            %   a) In case of array of same size, it concats horizontally
            %   b) In case of array of different size, it creates a cell 
            %      array and concats horizontally
            %   c) special case: if the key is the nearest match rather 
            %      actual key, then it creates the 1d (or) 2d cell array
            %      depends on the actual data 
            %      
            %      Example a): Assume 'f1' = 8 x 2, 'f2' = 8 x 2
            %      obj.getFeatureData('f') results in following 
            %      [8 x 2] [8 x 2] (i.e 1 × 2 cell array )     
            %
            %      Example b) Assume  f1, f2 are 1 × 2 cell array each
            %      'f1' = [3 x 1, 5 x 1] 'f2' = [4 x 1, 2 x 1]
            %      obj.getFeatureData('f') results in following 
            %      [3 x 1] [4 x 1]      
            %      [5 x 1] [2 x 1]  (i.e  2 × 2 cell array)

             
            import sa_labs.analysis.*;

            data = getFeatureData@sa_labs.analysis.entity.Group(obj, key);
            data = columnMajor(data);

            if isempty(data)
                [~, features] = util.collections.getMatchingKeyValue(obj.featureMap, key);
                
                if isempty(features)
                    app.Exceptions.FEATURE_KEY_NOT_FOUND.create('warning', true)
                    return
                end
                
                % data format logic
                data = {};
                for featureCell = each(features)
                    d = obj.getData(featureCell);
                    
                    if ~ iscell(d)
                        d = {d};
                    end
                    
                    if size(d, 1) == 1
                       d = d';
                    end
                    data{end + 1} = d; %#ok <AGROW>
                end
                if all(cellfun(@iscell, data))
                    try
                        data =  [data{:}];
                    catch
                        % do nothing
                    end
                end
            end
            
            function data = columnMajor(data)
                [rows, columns] = size(data);
                
                if rows == 1 && columns > 1
                    data = data';
                end
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

