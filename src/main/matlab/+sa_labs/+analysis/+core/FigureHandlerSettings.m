classdef FigureHandlerSettings < appbox.Settings
    % from https://github.com/Symphony-DAS/symphony-matlab
    
    properties
        figurePosition
        propertyMap
    end
    
    methods
        
        function obj = FigureHandlerSettings(settingsKey)
            obj@appbox.Settings(settingsKey);
        end
        
        function p = get.figurePosition(obj)
            p = obj.get('figurePosition');
        end
        
        function set.figurePosition(obj, p)
            validateattributes(p, {'double'}, {'vector'});
            obj.put('figurePosition', p);
        end
        
        function m = get.propertyMap(obj)
            m = obj.get('propertyMap');
        end
        
        function set.propertyMap(obj, m)
            validateattributes(m, {'containers.Map'}, {'2d'});
            obj.put('propertyMap', m);
        end
        
    end
    
end

