classdef FeatureGroup < handle & matlab.mixin.CustomDisplay
    
    properties
        id                  % Identifier of the featureGroup, assigned by NodeManager @see NodeManager.addFeatureGroup
        epochGroup          % Read only dataSet and used as cache
    end
    
    properties(SetAccess = immutable)
        name                % Descriptive name of the featureGroup, except root its usually of format [splitParameter = splitValue]
        splitParameter      % Defines level of featureGroup in tree
        splitValue          % Defines the branch of tree
    end
    
    properties(SetAccess = private, Hidden)
        parameters          % Matlab structure to store other properties and value (types are scalar or cell arrays)
        uuid
    end
    
    properties (Hidden)
        featureMap          % Feature map with key as FeatureDescription.type and value as @see Feature instance
        epochIndices        % List of epoch indices to be processed in Offline analysis. @see CellData and FeatureExtractor.extract
        parametersCopied    % Avoid redundant collection of parameters
    end
    
    methods
        
        function obj = FeatureGroup(splitParameter, splitValue, name)
            if nargin < 3
                name = [splitParameter '==' num2str(splitValue)];
            end
            
            obj.featureMap = containers.Map();
            obj.name = name;
            obj.splitParameter = splitParameter;
            obj.splitValue = splitValue;
            obj.uuid = char(java.util.UUID.randomUUID);
            obj.parametersCopied = false;
        end
        
        function value = getParameter(obj, property)
            
            % getParameter - get the value from obj.parameters for
            % given property
            % Return data type of value is scalar or cell array
            
            value = [];
            if  isfield(obj.parameters, property)
                value = obj.parameters.(property);
            end
        end
        
        function feature = createFeature(obj, id, data, varargin)
            import sa_labs.analysis.*;
            
            key = varargin(1 : 2 : end);
            value = varargin(2 : 2 : end);
            propertyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            if ~ isempty(key)
                for i = 1 : numel(key)
                    propertyMap(key{i}) = value{i};
                end
            end
            
            propertyMap('id') = id;
            description = entity.FeatureDescription(propertyMap);
            description.id = id;
            
            oldFeature = obj.getFeatures(id);
            feature = entity.Feature(description, data);
            
            if ~ isempty(oldFeature) && isKey(propertyMap, 'append') && propertyMap('append')
                obj.appendFeature(feature);
                return
            end
            
            if ~ isempty(oldFeature)
                feature.uuid = oldFeature.uuid;
                app.Exceptions.OVERWRIDING_FEATURE.create('warning', true, 'message', strcat(id, ' for  node ', obj.name));
            end
            obj.featureMap(id) = feature;
        end
        
        function data = getFeatureData(obj, key)
            import sa_labs.analysis.app.*;
            
            data = [];
            if iscellstr(key) && numel(key) > 1
                throw(Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.create())
            end
            
            if isKey(obj.featureMap, key)
                features = obj.featureMap(key);
            elseif isfield(obj.parameters, key)
                features = obj.getParameter(key);
            else
                Exceptions.FEATURE_KEY_NOT_FOUND.create('warning', true)
                return
            end
            try
                data = [features.data];
            catch exception
                data = {features.data};
            end
        end
        
        function features = getFeatures(obj, keys)
            
            % getFeatures - returns the feature based on FeatureDescription
            % reference
            features = [];
            if ischar(keys)
                keys = {keys};
            end
            
            keys = unique(keys);
            for i = 1 : numel(keys)
                key = keys{i};
                if isKey(obj.featureMap, key)
                    feature = obj.featureMap(key);
                    features = [features, feature]; %#ok
                end
            end
        end
        
        function appendFeature(obj, newFeatures)
            
            for i = 1 : numel(newFeatures)
                key = newFeatures(i).description.id;
                
                f = obj.getFeatures(key);
                if ~ isempty(f) && ismember({newFeatures(i).uuid}, {f.uuid})
                    continue;
                end
                obj.featureMap = sa_labs.analysis.util.collections.addToMap(obj.featureMap, key, newFeatures(i));
            end
        end
        
        function keySet = getFeatureKey(obj)
            if numel(obj) > 1
                result = arrayfun(@(ref) ref.featureMap.keys, obj, 'UniformOutput', false);
                keySet = unique([result{:}]);
                return
            end
            keySet = obj.featureMap.keys;
        end
        
        function setParameters(obj, parameters)
            
            % setParameters - Copies from parameters to obj.parameters
            % @see setParameter
            
            if isempty(parameters)
                return
            end
            
            if isstruct(parameters)
                names = fieldnames(parameters);
                for i = 1 : length(names)
                    obj.addParameter(names{i}, parameters.(names{i}));
                end
            end
            
            if isa(parameters,'containers.Map')
                names = parameters.keys;
                for i = 1 : length(names)
                    obj.addParameter(names{i}, parameters(names{i}));
                end
            end
        end
        
        function appendParameter(obj, key, value)
            
            % append key, value pair to obj.parameters. On empty field it
            % creates the new field,value else it appends to existing value
            % if it NOT exist
            % @see setParameter
            
            if isempty(value)
                return
            end
            old = obj.getParameter(key);
            
            if isempty(old)
                obj.addParameter(key, value);
                return
            end
            
            new = sa_labs.analysis.util.collections.addToCell(old, value);
            if all(cellfun(@isnumeric, new))
                new = cell2mat(new);
            elseif obj.isFeatureEntity(new)
                new = [new{:}];
            end
            
            try
                % helps to check if the parameter has any mixed type
                % TODO : find alternative way
                unique(new, 'stable'); 
            catch e
                warning('mixedType:parameters', e.message);
            end
            obj.addParameter(key, new);
        end
        
        function update(obj, featureGroup, in, out)
            
            % Generic code to handle merge from source featureGroup to destination
            % obj(featureGroup). It merges following,
            %
            %   1. properties
            %   2. Feature
            %   3. parameters 'matlab structure'
            %
            % arguments
            % featureGroup - source featureGroup
            % in  - It may be one of source featureGroup property, parameter and feature
            % out - It may be one of destination obj(featureGroup) property, parameter and feature
            
            import sa_labs.analysis.util.collections.*;
            % safe casting
            
            if nargin < 4
                out = in;
            end
            
            in = char(in);
            out = char(out);
            
            if strcmp(out, 'id')
                error('id:update:prohibited', 'cannot updated instance id');
            end
            
            % case 1 - featureGroup.in and obj.out is present has properties
            if isprop(obj, out) && isprop(featureGroup, in)
                old = obj.(out);
                obj.(out) = addToCell(old, featureGroup.(in));
                return
                
            end
            % case 2 - featureGroup.in is struct parameters & obj.out is class property
            if isprop(obj, out)
                old = obj.(out);
                obj.(out) = addToCell(old, featureGroup.getParameter(in));
                return
            end
            
            % case 3 featureGroup.in is class property but obj.out is struct
            % parameters
            if isprop(featureGroup, in)
                obj.appendParameter(out, featureGroup.(in));
                return
            end
            
            % case 4 in == out and its a key of featureMap
            keys = featureGroup.featureMap.keys;
            if ismember(in, keys)
                
                if ~ strcmp(in, out)
                    error('in:out:mismatch', 'In and out should be same for appending feature map')
                end
                obj.appendFeature(featureGroup.featureMap(in))
                return
            end
            
            % case 5 just append the in to out struct parameters
            % for unknown in parameters, it creates empty out paramters
            obj.appendParameter(out, featureGroup.getParameter(in));
        end
        
    end
    
    methods(Access = private)
        
        function addParameter(obj, property, value)
            % setParameters - set property, value pair to parameters
            property = strtrim(property);
            obj.parameters.(property) = value;
        end
        
        function tf = isFeatureEntity(~, refs)
            tf = all(cellfun(@(ref) isa(ref, 'sa_labs.analysis.entity.Feature'), refs));
        end
    end
end

