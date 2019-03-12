classdef FeatureDescription < dynamicprops
    
    properties
        id
        description
        strategy
        unit
        chartType
        xAxis
        downSampleFactor
        isBasicFeature
    end
    
    methods
        
        function obj = FeatureDescription(map)
            props = [];
            
            if isKey(map, 'properties')
                props = map('properties');
                map = remove(map, 'properties');
            end
            cellfun(@(k) obj.set(k, map(k)), map.keys);
            
            if isempty(props)
                return
            end
            obj.isBasicFeature = false;
            obj.setProperties(props);
        end
        
        function setProperties(obj, props)
            import  sa_labs.analysis.app.*;
            
            props = strsplit(props, ',');
            
            for i = 1 : numel(props)
                props = strrep(props, '"', '');
                prop = strsplit(props{i}, '=');
                
                if numel(prop) == 2
                    obj.set(prop{1}, prop{2});
                else
                    Exceptions.INVALID_PROPERTY_PAIR.create('warning', true);
                end
            end
        end
        
        function setFromMap(obj, map)
            cellfun(@(k) obj.set(k, map(k)), map.keys);
        end
        
        function map = toMap(obj)
            keys = properties(obj);
            map = containers.Map();
            
            for key = each(keys)
                map(key) = obj.(key);
            end
        end
        
        function set(obj, k, v)
            try
                if ~ isempty(k)
                    var = strtrim(k);
                    
                    if ~ isprop(obj, var)
                        addprop(obj, var);
                    end
                    % TODO check for data type of v and convert to appropriate
                    if ischar(v)
                        v = strtrim(v);
                    end
                    obj.(var) = v;
                end
            catch exception
                warning(exception.identifier, exception.message)
            end
        end
        
    end
    
end