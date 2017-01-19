classdef AnalysisDao < handle
    
    methods(Abstract)
        findRawDataFiles(obj, regexp)
        saveCell(obj, cellData)
        findCellNames(obj, regexp)
        findCell(obj, cellName)
        createProject(obj, project)
        saveAnalysisResults(obj, template, results)
    end
    
end

