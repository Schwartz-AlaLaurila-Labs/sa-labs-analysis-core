classdef KeyValueEntity < handle & matlab.mixin.CustomDisplay
    
    properties
        attributes
    end
    
    methods
        
        function [parameter, description] = getKeyAsFunctionHandle(obj, inputParameter) %#ok
            
            parameter = [];
            description = [];
            
            if isa(inputParameter, 'function_handle')
                description = func2str(inputParameter);
                parameter = inputParameter;
                
            elseif ischar(inputParameter) && strncmp(strtrim(inputParameter), '@', 1)
                description = inputParameter;
                parameter = str2func(inputParameter);
            end
        end
        
        function v = getValue(obj, value) %#ok
            
            if strcmpi(value, 'null')
                v = [];
            elseif isnumeric(value)
                v = double(value);
            else
                v= value;
            end
        end
        
        function values = formatCells(obj, values) %#ok
            
            if ~ iscell(values)
                return;
            end
            
            if all(cellfun(@isnumeric, values))
                values = cell2mat(values);
            elseif all(cellfun(@iscellstr, values))
                values = [values{:}];
            end
        end
        
        function value = get(obj, name)
            
            % Returns the matching value for given name from attributes map
            
            value = [];
            if obj.attributes.isKey(name)
                value = obj.attributes(name);
            end
        end
        
        function [keys, values] = getMatchingKeyValue(obj, pattern)
            
            % keys - Returns the matched parameter for given
            % search string
            %
            % values - Returns the available parameter values for given
            % search string
            %
            % usage :
            %       getMatchingKeyValue('chan1')
            %       getMatchingKeyValue('chan1Mode')
            
            import sa_labs.analysis.util.*;
            [keys, values] = collections.getMatchingKeyValue(obj.attributes, pattern);
        end
        
        function attributeKeys = unionAttributeKeys(obj, attributeKeys)
            
            % unionAttributeKeys - returns the union of { current instance
            % attribute keys } and passed argument {attributeKeys}
            
            if isempty(attributeKeys)
                attributeKeys = obj.attributes.keys;
                return
            end
            attributeKeys = union(attributeKeys, obj.attributes.keys);
        end

        function s = toStructure(obj)
            s = struct();
            names = obj.attributes.keys;
            for name = each(names)
                s.(name) = obj.attributes(name);
            end
        end
        
    end
    
    methods(Access = protected)
        
        function groups = getPropertyGroups(obj)
            try
                attrKeys = obj.attributes.keys;
                groups = matlab.mixin.util.PropertyGroup.empty(0, 2);
                
                display = struct();
                for i = 1 : numel(attrKeys)
                    display.(attrKeys{i}) = obj.attributes(attrKeys{i});
                end
                groups(1) = display;
            catch
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            end
        end
    end
    
end

