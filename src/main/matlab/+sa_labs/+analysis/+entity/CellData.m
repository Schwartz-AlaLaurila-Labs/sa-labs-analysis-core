classdef CellData < sa_labs.analysis.entity.KeyValueEntity
    
    properties
        epochs
        deviceType
    end
    
    properties (Dependent)
        experimentDate
        h5File
        recordingLabel
    end
    
    methods
        
        function obj = CellData()
            obj.attributes = containers.Map();
        end
        
        function [values, parameterDescription] = getEpochValues(obj, parameter, epochIndices)
            
            % getEpochValues - By deafult returns attribute values of epochs
            % for given attribute and epochIndices .
            %
            % If the parameter is a function handle, it applies the function
            % to given epoch and returns its value
            %
            % Parameter - epoch attributes or function handle
            % epochIndices - list of epoch indices to be lookedup
            %
            % Usage -
            %      obj.getEpochValues('r_star', [1:100])
            %      obj.getEpochValues(@(epoch) calculateRstar(epoch), [1:100])
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            [functionHandle, parameterDescription] = getKeyAsFunctionHandle(obj, parameter);
            
            if isempty(functionHandle)
                functionHandle = @(epoch) epoch.get(parameter);
                parameterDescription = parameter;
            end
            
            n = length(epochIndices);
            values = cell(1,n);
            
            for i = 1 : n
                epoch = obj.epochs(epochIndices(i));
                values{i} = obj.getValue(functionHandle(epoch));
            end
            values = obj.formatCells(values);
        end
        
        function [map, parameterDescription] = getEpochValuesMap(obj, parameter, epochIndices)
            
            % getEpochValuesMap - By deafult returns attribute values as key
            % and matching epochs indices as values
            %
            % @ see also getEpochValues
            %
            % If the parameter is a function handle, it applies the function
            % to given epoch and returns its attribute values and epochs
            % indices
            %
            % Parameter - epoch attributes or function handle
            % epochIndices - list of epoch indices to be lookedup
            %
            % Usage -
            %      obj.getEpochValuesMap('r_star', [1:100])
            %      obj.getEpochValuesMap(@(epoch) calculateRstar(epoch), [1:100])
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            [functionHandle, parameterDescription] = getKeyAsFunctionHandle(obj, parameter);
            
            if isempty(functionHandle)
                functionHandle = @(epoch) epoch.get(parameter);
                parameterDescription = parameter;
            end
            map = containers.Map();
            
            import sa_labs.analysis.util.collections.*;
            
            for epochIndex = epochIndices
                value = functionHandle(obj.epochs(epochIndex));
                value = obj.formatCells(value);
                
                try
                    map = addToMap(map, num2str(value), epochIndex);
                catch e %#ok
                    for v = each(value)
                        map = addToMap(map, num2str(v), epochIndex);
                    end
                end
            end
            
            keys = map.keys;
            if isempty([keys{:}])
                map = [];
            end
        end
        
        function keySet = getEpochKeysetUnion(obj, epochIndices)
            
            % getEpochKeysetUnion - returns unqiue attributes from epoch
            % array
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            
            n = length(epochIndices);
            keySet = [];
            
            for i = 1 : n
                epoch = obj.epochs(epochIndices(i));
                keySet = epoch.unionAttributeKeys(keySet);
            end
        end
        
        function [params, vals] = getNonMatchingParamValues(obj, excluded, epochIndices)
            
            % getNonMatchingParamValues - returns attributes & values
            % apart from excluded attributes
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            keys = setdiff(obj.getEpochKeysetUnion(epochIndices), excluded);
            map = containers.Map();
            
            for i = 1 : length(keys)
                key = keys{i};
                values = obj.getEpochValues(key, epochIndices);
                if iscell(values) && ~ iscellstr(values)
                    values = [values{:}];
                end
                map(key) = values;
            end
            params = map.keys;
            vals = map.values;
        end

        function [params, vals] = getUniqueNonMatchingParamValues(obj, excluded, epochIndices)
            
            % getUniqueNonMatchingParamValues - returns unqiue attributes & values
            % apart from excluded attributes
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getNonMatchingParamValues(excluded, epochIndices);
            vals = cellfun(@(val) unique(val, 'stable'), vals, 'UniformOutput', false);
        end

        function [params, vals] = getParamValues(obj, epochIndices)
            
            % getParamValues - returns attributes & values for given epochs
            %
            % see also @getNonMatchingParamValues
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getNonMatchingParamValues([], epochIndices);
        end
        
        function [params, vals] = getUniqueParamValues(obj, epochIndices)
            
            % getUniqueParamValues - returns unqiue attributes & values
            %
            % see also @getUniqueNonMatchingParamValues
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getUniqueNonMatchingParamValues([], epochIndices);
        end
        
        function map = getPropertyMap(obj)
            map = obj.attributes;
        end
        
        function set.h5File(obj, value)
            obj.attributes('h5File') = value;
        end
        
        function fname = get.h5File(obj)
            
            fname = obj.get('h5File');
            if ~ isempty(fname)
                [~ , fname] = fileparts(fname);
            end
        end
        
        function set.recordingLabel(obj, value)
            obj.attributes('recordingLabel') = value;
        end
        
        function label = get.recordingLabel(obj)
            label = strcat(obj.h5File, obj.get('recordingLabel'));
        end            
    end
    
    methods(Access = protected)
        
        function header = getHeader(obj)
            try
                type = obj.get('cellType');
                if isempty(type)
                    type = 'unassigned';
                end
                header = ['Displaying information about ' type ' cell type '];
            catch
                header = getHeader@matlab.mixin.CustomDisplay(obj);
            end
        end
    end
end