classdef CellDataByAmp < handle
    
    properties
        deviceType
        recordingLabel
    end
    
    methods
        
        function obj = CellDataByAmp(recordingLabel, deviceType)
            obj.deviceType = deviceType;
            obj.recordingLabel = strcat(recordingLabel, '_', deviceType);
        end
        
        function updateCellDataForTransientProperties(obj, cellData)
            cellData.deviceType = obj.deviceType;
        end
    end
end