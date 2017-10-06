classdef Feature < handle & matlab.mixin.Heterogeneous
    
    properties
        description
    end
    
    properties (Access = private)
        dataHandler
        downSampled
    end
    
    properties (Dependent)
        data
    end
    
    properties (Hidden)
        uuid
    end
    
    methods
        
        function obj = Feature(desc, dataHandler)
            if nargin < 2
                dataHandler = [];
            end
            
            obj.description = desc;
            obj.dataHandler = dataHandler;
            obj.downSampled = false;
            obj.uuid = char(java.util.UUID.randomUUID); 
        end
        
        function d = get.data(obj)
            d = obj.dataHandler;
            
            if isa(d, 'function_handle')
                d = obj.dataHandler();
                obj.downSampled = false;
            end
            d = obj.formatData(d);
            
        end
        
        function obj = set.data(obj, d)
            obj.dataHandler = d;
        end
        
        function appendData(obj, value)
            import sa_labs.analysis.util.collections.*;

            value = obj.formatData(value);
            
            if isscalar(value)
                d = obj.data;
                d(end + 1) = value;
                obj.data = d;
            elseif iscell(value)
                value = obj.rowMajor(value);
                data = obj.rowMajor(obj.data);
                obj.data = addToCell(data, value);
            else
                obj.data = [obj.data; value];
            end
        end

    end
    
    methods (Access = private)
        
        function data = formatData(obj, data)
            if ischar(data)
                data = cellstr(data);
            end
            data = obj.columnMajor(data);

            factor = obj.description.downSampleFactor;
            if ~ isempty(factor) && ~ iscell(data) && ~ obj.downSampled
                data = downsample(data, factor);
                obj.downSampled = true;
            end
        end

        function data = columnMajor(obj, data)
            [rows, columns] = size(data);
            
            if rows == 1 && columns > 1
                data = data';
            end
        end

        function data = rowMajor(obj, data)
            [rows, columns] = size(data);
            
            if rows > 1 && columns == 1
                data = data';
            end
        end
    end
end