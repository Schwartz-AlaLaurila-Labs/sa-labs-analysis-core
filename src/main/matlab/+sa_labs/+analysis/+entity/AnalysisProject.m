classdef AnalysisProject < handle & matlab.mixin.CustomDisplay
    
    properties
        identifier
        cellDataNames
        description
        analysisDate
        experimentDate
        performedBy
        file
    end
    
    properties(Access = private)
        cellDataMap
        resultMap
        protocols
    end
    
    methods
        function obj = AnalysisProject(structure)
            obj.cellDataMap = containers.Map();
            obj.resultMap = containers.Map();

            if nargin < 1
                return
            end
            attributes = fields(structure);
            for i = 1 : numel(attributes)
                attr = attributes{i};
                obj.(attr) = structure.(attr);
            end
        end
        
        function addCellData(obj, cellName, cellData)
            if ~ any(ismember(obj.cellDataNames, cellName))
                obj.cellDataNames{end + 1} = cellName;
            end
            obj.cellDataMap(cellName) = cellData;
        end
        
        function c = getCellData(obj, cellName)
            c = obj.cellDataMap(cellName);
        end

        function list = getCellDataList(obj)
            list = obj.cellDataMap.values;
        end

        function addResult(obj, protocol, analysisResult)
            if ~ isKey(obj.resultMap, protocol.type)
                obj.protocols{end + 1} = protocol;
            end
            obj.resultMap(protocol.type) = analysisResult;
        end
        
        function c = getResult(obj, protocolType)
            c = obj.resultMap(protocolType);
        end

        function list = getAllresult(obj)
            list = obj.resultMap.values;
        end
    end
end