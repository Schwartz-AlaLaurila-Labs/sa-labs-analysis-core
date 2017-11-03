classdef AnalysisFolderDao < sa_labs.analysis.dao.AnalysisDao & mdepin.Bean
    
    properties
        repository
    end
    
    methods
        
        function obj = AnalysisFolderDao(config)
            obj = obj@mdepin.Bean(config);
        end
        
        function project = saveProject(obj, project)
            
            projectFile = [obj.repository.analysisFolder filesep 'Projects'...
                filesep project.identifier filesep];
            
            sa_labs.analysis.util.file.overWrite(projectFile);
            projectStruct = struct();
            attributes = properties(project);
            
            for i = 1 : numel(attributes)
                attr = attributes{i};
                projectStruct.(attr) = project.(attr);
            end
            
            file = [projectFile 'project.json'];
            projectStruct.file = file;
            project.file = file;
            savejson('', projectStruct, file);
        end
        
        function projects = findProjects(obj, identifier)
            import sa_labs.analysis.*
            
            path = [obj.repository.analysisFolder filesep 'Projects' filesep];
            info = dir(path);
            index = find(ismember({info.name}, identifier));
            
            if isempty(index)
                throw(app.Exceptions.NO_PROJECT.create());
            end
            
            projects = entity.AnalysisProject.empty(0, numel(index));
            for i = 1 : numel(index)
                structure = loadjson([path info(index(i)).name filesep 'project.json']);
                projects(i) = entity.AnalysisProject(structure);
            end
        end
        
        function fnames = findRawDataFiles(obj, date)
            
            if ~ ischar(date)
                date = obj.repository.dateFormat(date);
            end
            
            path = [obj.repository.rawDataFolder filesep];
            info = dir([path date '*.h5']);
            fnames = arrayfun(@(d) [path d.name], info, 'UniformOutput', false);
        end
        
        function saveCell(obj, cellData)
            dir = [obj.repository.analysisFolder filesep 'cellData' filesep];
            if ~ exist(dir, 'dir')
                mkdir(dir);
            end
            
            if isa(cellData, 'sa_labs.analysis.entity.CellDataByAmp')
                CellDataByAmp = cellData;
                path = [dir CellDataByAmp.recordingLabel];
            else
                cellData.deviceType = '';
                path = [dir cellData.recordingLabel];
            end
            save(path, 'cellData');
        end
        
        function names = findCellNames(obj, pattern)
            
            names = [];
            if isempty(pattern)
                return;
            end
            
            if ~ iscellstr(pattern)
                pattern = obj.repository.dateFormat(pattern);
                pattern = {[pattern '*c']};
            end
            isCellDataByAmp = all(cellfun(@(p) any(strfind(p, 'Amp')), pattern)); 
            
            for i = 1 : numel(pattern)
                p = pattern{i};
                info = dir([obj.repository.analysisFolder filesep 'cellData' filesep char(p) '*.mat']);
                fnames = arrayfun(@(d) {d.name(1 : end-4)}, info);
                names = [fnames; names]; %#ok
            end
            
            % Filter for cell data without amp extension
            if ~ isempty(names) && ~ isCellDataByAmp
                indices = cellfun(@(name) any(strfind(name, '_Amp')), names);
                names = names(~indices);
            end
        end

        function cellData = findCell(obj, cellName)
            pathFun = @(cellName) [obj.repository.analysisFolder filesep 'cellData' filesep cellName '.mat'];
            result = load(pathFun(cellName));
            cellData = result.cellData;

            if isa(cellData, 'sa_labs.analysis.entity.CellDataByAmp')
                cellDataByAmp = cellData;
                result = load(pathFun(cellDataByAmp.cellDataRecordingLabel));
                cellData = result.cellData;
                cellDataByAmp.updateCellDataForTransientProperties(cellData);
            end
        end
        
        function saveAnalysisResults(obj, resultId, result, protocol) %#ok
            dir = [obj.repository.analysisFolder filesep 'analysisTrees' filesep];
            if ~ exist(dir, 'dir')
                mkdir(dir);
            end
            save([dir resultId], 'result');
            savejson('', protocol, [dir resultId '.json']);
        end
        
        function names = findAnalysisResultNames(obj, pattern)
            names = [];
            if isempty(pattern)
                return;
            end
            if ~ iscellstr(pattern)
                pattern = obj.repository.dateFormat(pattern);
            end
            
            for i = 1 : numel(pattern)
                p = pattern{i};
                info = dir([obj.repository.analysisFolder filesep 'analysisTrees' filesep '*' char(p) '*.mat']);
                fnames = arrayfun(@(d) {d.name(1 : end-4)}, info);
                names = [fnames; names]; %#ok
            end
        end
        
        function result = findAnalysisResult(obj, resultId)
            path = [obj.repository.analysisFolder filesep 'analysisTrees' filesep resultId];
            r = load(path);
            result = r.result;
        end
        
        function saveCellDataFilter(obj, filterName, filterTable) %#ok
            dir = [obj.repository.analysisFolder filesep 'filters' filesep 'cellData' filesep];
            if ~ exist(dir, 'dir')
                mkdir(dir);
            end
            save([dir filterName], 'filterTable');
        end
        
        function filterMap = getCellDataFilters(obj)
            filterMap = [];
            directory = [obj.repository.analysisFolder filesep 'filters' filesep 'cellData' filesep];
            if ~ exist(directory, 'dir')
                return;
            end
            info = dir([directory '*.mat']);
            fnames = arrayfun(@(d) {d.name(1 : end-4)}, info);
            filterMap = containers.Map();
            for name = each(fnames)
                filter = load([directory  name '.mat']);
                filterMap(name) = filter.filterTable;
            end
        end
    end

end

