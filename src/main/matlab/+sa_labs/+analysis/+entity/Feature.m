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
    end
    
    methods (Access = private)
        
        function data = formatData(obj, data)
            if isempty(data)
                data = {[]};
                return
            end
            
            if ischar(data)
                data = cellstr(data);
                return
            end
            data = obj.columnMajor(data);
            factor = obj.description.downSampleFactor;
            if ~ isempty(factor) && ~ iscell(data) && ~ obj.downSampled
                data = downsample(data, factor);
                obj.downSampled = true;
            end
            % if its more than one dimension wrap in a cell array
            if any(size(data) > 1)
                data = {data};
                return
            end
        end

        function data = columnMajor(~, data)
            [rows, columns] = size(data);
            
            if rows == 1 && columns > 1
                data = data';
            end
        end
    end
end