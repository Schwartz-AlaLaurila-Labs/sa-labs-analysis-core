classdef AnalysisDao < handle
    
    methods(Abstract)
        saveProject(obj, project)
        findProjects(obj, identifier)
        findRawDataFiles(obj, regexp)
        saveCell(obj, cellData)
        findCell(obj, cellName)
        findCellNames(obj, regexp, isCellDataByAmp)
        saveAnalysisResults(obj, resultId, result, protocol)
        findAnalysisResult(obj, regexp)
    end
    
end

