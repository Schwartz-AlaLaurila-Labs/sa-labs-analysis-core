classdef CellData < handle & matlab.mixin.CustomDisplay
    
    properties
        recordingLabel                      % recording cluster label
        attributes                          % Map for attributes from data file (h5group root attributes + Nepochs)
        epochs                              % Array of sa_labs.analysis.core.entity.EpochData
        savedEpochGroups                    % Saved Data Sets
        epochGroups                         % TODO
        tags                                % TODO
        savedFileName = ''                  % Current H5 file name without extension
        cellType = ''                       % CellType will be assignment from LabDataGUI
        somaSize = []                       % TODO
        imageFile = ''                      % Cell image
        notes = ''                          % Unstructured text field for adding notes
        location = []                       % [X, Y, whichEye] (X,Y in microns; whichEye is -1 for left eye and +1 for right eye)
    end
    
    methods
        
        function obj = CellData()
            obj.attributes = containers.Map();
            obj.savedEpochGroups = containers.Map();
            obj.tags = containers.Map();
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
            
            functionHandle = @(epoch) epoch.get(parameter);
            parameterDescription = parameter;
            
            if isa(parameter, 'function_handle')
                functionHandle = parameter;
                parameterDescription = func2str(functionHandle);
            end
            n = length(epochIndices);
            values = cell(1,n);
            
            for i = 1 : n
                value = functionHandle(obj.epochs(epochIndices(i)));
                if strcmpi(value, 'null')
                    value = [];
                end
                
                if isnumeric(value)
                    value = double(value);
                end
                
                values{i} = value;
                
            end
            if sum(cellfun(@isnumeric, values)) == n
                values = cell2mat(values);
            end
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
            
            functionHandle = @(epoch) epoch.get(parameter);
            parameterDescription = parameter;
            
            if isa(parameter, 'function_handle')
                functionHandle = parameter;
                parameterDescription = func2str(functionHandle);
            end
            n = length(epochIndices);
            map = containers.Map();
            
            for i = 1 : n
                epochIndex = epochIndices(i);
                epoch = obj.epochs(epochIndex);
                value = functionHandle(epoch);
                map = sa_labs.analysis.util.collections.addToMap(map, num2str(value), epochIndex);
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
        
        function [params, vals] = getUniqueNonMatchingParamValues(obj, excluded, epochIndices)
            
            % getNonMatchingParamValues - returns unqiue attributes & values
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
                map(key) =  unique(values);
            end
            params = map.keys;
            vals = map.values;
        end
        
        function [params, vals] = getUniqueParamValues(obj, epochIndices)
            
            % getUniqueParamValues - returns unqiue attributes & values
            %
            % see also getUniqueNonMatchingParamValues
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getUniqueNonMatchingParamValues([], epochIndices);
        end
        
        function val = get(obj, paramName)
            
            % get - Returns value for given parameter name
            % Tags take precedence over attributes
            
            val = [];
            if obj.tags.isKey(paramName)
                val = obj.tags(paramName);
                return
            end
            
            if obj.attributes.isKey(paramName)
                val = obj.attributes(paramName);
            end
        end
        
        function EpochGroup = filterEpochs(obj, queryString, subSet)
            
            if nargin < 3
                subSet = 1 : obj.get('Nepochs');
            end
            
            n = length(subSet);
            
            if strcmp(queryString, '?') || isempty(queryString)
                EpochGroup = sa_labs.analysis.entity.EpochGroup(1 : n, queryString);
                return
            end
            epochIndices = [];
            functionHandle = str2func(queryString);
            
            for i = 1 : n
                d = obj.epochs(subSet(i));
                if functionHandle(d)
                    epochIndices = [epochIndices subSet(i)]; %#ok
                end
            end
            EpochGroup = sa_labs.analysis.entity.EpochGroup(epochIndices, queryString);
        end
        
        function tf = has(obj, queryString)
            % returns true or false for this cell
            
            if strcmp(queryString, '?') || isempty(queryString)
                tf = true;
                return
            end
            log4m.getLogger().info(class(obj), [ 'QueryString for cell data ', queryString]);
            
            functionHandle = str2func(queryString);
            tf = functionHandle(obj);
        end
        
    end
    
    methods(Access = protected)
        
        function header = getHeader(obj)
            try
                type = obj.cellType;
                if isempty(type)
                    type = 'unassigned';
                end
                header = ['Displaying information about ' type ' cell type '];
            catch
                header = getHeader@matlab.mixin.CustomDisplay(obj);
            end
        end
        
        function groups = getPropertyGroups(obj)
            try
                attrKeys = obj.attributes.keys;
                EpochGroupKeys = obj.savedEpochGroups.keys;
                groups = matlab.mixin.util.PropertyGroup.empty(0, 2);
                
                display = struct();
                for i = 1 : numel(attrKeys)
                    display.(attrKeys{i}) = obj.attributes(attrKeys{i});
                end
                
                groups(1) = display;
                groups(2) = EpochGroupKeys;
            catch
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            end
        end
        
    end
    
end