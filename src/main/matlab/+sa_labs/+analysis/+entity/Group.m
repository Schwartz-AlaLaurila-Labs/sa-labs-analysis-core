classdef Group < sa_labs.analysis.entity.KeyValueEntity

	properties (Access = protected)
        featureMap 	 % Feature map with key as FeatureDescription.type and value as @see Feature instance	
    end

    properties(SetAccess = private)
        name 		% Descriptive name of the Abstract Group
        uuid 
    end
    
    methods 

	    function obj = Group(name)
	        obj.name = name;
	        obj.featureMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
	        obj.uuid = char(java.util.UUID.randomUUID);
            obj.attributes = containers.Map();
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
	        
	        id = obj.makeValidKey(id);
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
	    
	    function keySet = getFeatureKey(obj)
	        if numel(obj) > 1
	            result = arrayfun(@(ref) ref.featureMap.keys, obj, 'UniformOutput', false);
	            keySet = unique([result{:}]);
	            return
	        end
	        keySet = obj.featureMap.keys;
	    end

        function data = getFeatureData(obj, key)
            import sa_labs.analysis.app.*;
            
            data = [];
            features = [];
            
            if iscellstr(key) && numel(key) > 1
                throw(Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.create())
            end
            
            if isKey(obj.featureMap, obj.makeValidKey(key))
                features = obj.featureMap(obj.makeValidKey(key));
            end
            
            if ~ isempty(features)
                data = obj.getData(features);
            end
        end

	    function tf = isFeatureEntity(~, refs)
	        tf = all(cellfun(@(ref) isa(ref, 'sa_labs.analysis.entity.Feature'), refs));
	    end

	    function k = makeValidKey(~, key)
	    	k = upper(key);
	    end
	end

	methods (Hidden)

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
	        old = obj.get(key);
	        
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
	        obj.addParameter(key, new);
	    end
	    
	    function update(obj, epochGroup, in, out)
	        
	        % Generic code to handle merge from source epochGroup to destination
	        % obj(epochGroup). It merges following,
	        %
	        %   1. properties
	        %   2. Feature
	        %   3. parameters 'matlab structure'
	        %
	        % arguments
	        % epochGroup - source epochGroup
	        % in  - It may be one of source epochGroup property, parameter and feature
	        % out - It may be one of destination obj(epochGroup) property, parameter and feature
	        
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
	        
	        % case 1 - epochGroup.in and obj.out is present has properties
	        if isprop(obj, out) && isprop(epochGroup, in)
	            old = obj.(out);
	            obj.(out) = addToCell(old, epochGroup.(in));
	            return
	            
	        end
	        % case 2 - epochGroup.in is struct parameters & obj.out is class property
	        if isprop(obj, out)
	            old = obj.(out);
	            obj.(out) = addToCell(old, epochGroup.get(in));
	            return
	        end
	        
	        % case 3 epochGroup.in is class property but obj.out is struct
	        % parameters
	        if isprop(epochGroup, in)
	            obj.appendParameter(out, epochGroup.(in));
	            return
	        end
	        
	        % case 4 in == out and its a key of featureMap
	        keys = epochGroup.featureMap.keys;
	        if ismember(in, keys)
	            
	            if ~ strcmp(in, out)
	                error('in:out:mismatch', 'In and out should be same for appending feature map')
	            end
	            obj.appendFeature(epochGroup.featureMap(in))
	            return
	        end
	        
	        % case 5 just append the in to out struct parameters
	        % for unknown in parameters, it creates empty out paramters
	        obj.appendParameter(out, epochGroup.get(in));
	    end
	end

	methods(Access = protected)
	    
	    function addParameter(obj, property, value)
	        % setParameters - set property, value pair to parameters
	        obj.attributes(property) = value;
	    end

	    function data = getData(obj, features)
	    	try
	    	    data = [features.data];
	    	catch exception
	    	    data = {features.data};
	    	end
	    end

	    function header = getHeader(obj)
	        try
	            header = ['Displaying Epoch group information for [ ' obj.name ' ] for unique values'];
	        catch
	            header = getHeader@matlab.mixin.CustomDisplay(obj);
	        end
	    end    
	end
end