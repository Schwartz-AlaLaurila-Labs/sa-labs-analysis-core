classdef OfflineAnalaysisManager < handle & mdepin.Bean
    
    properties
        analysisDao
        parserFactory
        analysisFactory
        log
    end
    
    methods
        
        function obj = OfflineAnalaysisManager(config)
            obj = obj@mdepin.Bean(config);
            obj.log = logging.getLogger(sa_labs.analysis.app.Constants.ANALYSIS_LOGGER);
        end
        
        function cellDataArray = parseSymphonyFiles(obj, pattern)
            
            % parseSymphonyFiles - parses h5 files from raw data folder based on
            % input pattern and returns the cell data as array
            %
            % If the input pattern is not valid (or)
            % no files were found in the raw data folder then throws
            % no raw data found exception.
            %
            % In case of that excpetion, make sure to check the rawDataFolder
            % whether it has the valid h5 file. If not copy that from the
            % server and trigger the parsing again
            %
            % On successful parsing the cell data will be saved in the
            % analysis folder
            %
            % usage : obj.parseSymphonyFiles('20170505A')
            %         obj.parseSymphonyFiles('201705')
            %         obj.parseSymphonyFiles(date)
            
            
            import sa_labs.analysis.*;
            dao = obj.analysisDao;
            files = dao.findRawDataFiles(pattern);
            
            if isempty(files)
                throw(app.Exceptions.NO_RAW_DATA_FOUND.create('message', char(pattern)));
            end
            n = numel(files);
            cellDataArray = [];
            
            for i = 1 : n
            	try
	                obj.log.info(['parsing ' num2str(i) '/' num2str(n) ' h5 file [ ' strrep(files{i}, '\', '/') ' ]' ]);
	                parser =  obj.parserFactory.getInstance(files{i});
	                results = parser.parse().getResult();
	                
	                for result = each(results)
	                    dao.saveCell(result);
	                    obj.log.info(['saving data set [ ' result.recordingLabel ' ]']);
	                end
	                cellDataArray = [results, cellDataArray]; %#ok
                catch exception
                    disp(getReport(exception, 'extended', 'hyperlinks', 'on'));
                    obj.log.error(exception.message);
                end
            end
        end
        
        function [parsedExperiments, unParsedExperiments] = getParsedAndUnParsedFiles(obj, experiments)
            
            % A simple utility function to get parsed and un-parsed files
            % by experiment name (i.e date)
            
            index = cellfun(@(e) isempty(obj.analysisDao.findCellNames(cellstr(e))), experiments);
            unParsedExperiments = experiments(index);
            parsedExperiments = experiments(~ index);
            
            obj.log.info(['list of parsed files [ ' [parsedExperiments{:}] ' ] unParsed files [ ' [unParsedExperiments{:}] ' ]']);
        end
        
        function obj = createProject(obj, project)
            
            % createProject - creates a new analysis project from project.experimentList.
            % If its already present, then it simply loads the project.
            %
            % returns the manager obj and cell data injected project instance
            %
            % While creating new project, it checks whether it has
            % the required cell data files. If not it attempts to parse the
            % raw data file (h5) and generates the cell data. For the existing celldata
            % it simply finds the serialized object from the dao and saves
            % to the project file
            %
            % usage : obj.createProject(analysisProject)
            
            import sa_labs.analysis.*;
            
            obj.log.info(['creating project [ ' project.identifier ' ]' ]);
            dao = obj.analysisDao;
            [parsedExperiments, unParsedExperiments] = obj.getParsedAndUnParsedFiles(project.experimentList);
            
            for unParsedExp = each(unParsedExperiments)
                obj.parseSymphonyFiles(unParsedExp);
                parsedExperiments{end + 1} = unParsedExp; %#ok <AGROW>
            end
            
            project.clearCellData();
            cellfun(@(id) obj.addCellDataToProject(project, id), dao.findCellNames(parsedExperiments));
            
            dao.saveProject(project);
            obj.log.info(['Project created under location [ ' strrep(project.file, '\', '/') ' ]' ]);
        end

        function d = getParsedCellData(obj, pattern)
            dao = obj.analysisDao;
            [parsedExperiments, unParsedExperiments] = obj.getParsedAndUnParsedFiles(project.experimentList);
            
            for unParsedExp = each(unParsedExperiments)
                obj.parseSymphonyFiles(unParsedExp);
                parsedExperiments{end + 1} = unParsedExp; %#ok <AGROW>
            end
            
            d = linq(dao.findCellNames(parsedExperiments))...
                .select(@(name) dao.findCell(name))...
                .where(@(d) isempty(d.get('recordingLabel'))).toArray();
        end
        
        function preProcess(obj, cellDatas, functions, varargin)
            
            % preproces - apply list of functions to list of cellDatas
            % and serializes the results to disk for later lookup
            %
            % One can control the list of functions to be applied by
            % using boolean array parameter 'enabled' @see usage
            %
            % usage : obj.preProcess(cellData,{@(d) fun1(d), @(d) fun2(d) })
            %         obj.preProcess(cellData,{@(d) fun1(d), @(d) fun2(d) }, 'enabled', [true, true])
            %
            
            n = numel(functions);
            ip = inputParser;
            ip.addParameter('enabled', ones(1, n), @islogical);
            ip.parse(varargin{:});
            enabled = ip.Results.enabled;
            
            for data = each(cellDatas)
                
                for fun = each(functions(enabled))
                    obj.log.info(['pre processing data [ ' data.recordingLabel ' ] for function [ ' char(fun) ' ] ']);
                    try
                        fun(data);
                    catch exception
                        disp(getReport(exception, 'extended', 'hyperlinks', 'on'));
                        obj.log.error(exception.message);
                    end
                end
                obj.analysisDao.saveCell(data);
            end
        end
        
        function project = initializeProject(obj, name)
            
            dao = obj.analysisDao;
            projects = dao.findProjects(name);
            
            if numel(projects) > 1
                obj.log.info('More than one project found using the first project');
            end
            
            project = projects(1);
            tic;
            cellfun(@(id) obj.addCellDataToProject(project, id), project.cellDataIdList);
            elapsedTime = toc;
            obj.log.debug(['Time taken to add cell data to project: ', num2str(elapsedTime)]);
            
            tic;
            cellfun(@(id) project.addResult(id, dao.findAnalysisResult(id)), project.analysisResultIdList);
            elapsedTime = toc;
            obj.log.debug(['Time taken to add analysis results to project: ', num2str(elapsedTime)]);

            obj.log.info(['project [ ' project.identifier ' ] initialized ']);
        end
        
        function project = buildAnalysis(obj, projectName, presets)
            import sa_labs.analysis.*;
            
            project = obj.initializeProject(projectName);
            
            for cellData = each(project.getCellDataArray())
                
                for preset = each(presets)
                    protocol = core.AnalysisProtocol(preset);
                    analysis = obj.analysisFactory.createOfflineAnalysis(protocol, cellData);
                    analysis.service();
                    result = analysis.getResult();
                    obj.analysisDao.saveAnalysisResults(analysis.identifier, result, protocol);
                    project.addResult(analysis.identifier, result);
                end
            end
            obj.analysisDao.saveProject(project);
        end
        
        function finder = applyAnalysis(obj, finder, epochGroup, functions)
            import sa_labs.analysis.*;
            
            project = finder.findEpochGroup('project').splitValue;
            groups = finder.findEpochGroup('analysis');
            
            dao = obj.analysisDao;
            factory = obj.analysisFactory;
            results = tree.empty(0, numel(groups));
            index = 1;
            
            for group = each(groups)
                resultIdArray = strsplit(group.splitValue, '-');
                cellData = dao.findCell(resultIdArray{end});
                protocol = group.parameters.analysisProtocol;
                
                analysis = factory.createOfflineAnalysis(protocol, cellData);
                analysis.featureBuilder.dataStore = dao.findAnalysisResult(group.splitValue);
                analysis.addFeaturesToGroup(epochGroup, functions);
                result = analysis.getResult();
                
                dao.saveAnalysisResults(analysis.identifier, result, protocol);
                
                results(index) = result;
                index = index + 1;
            end
            
            finder = factory.createFeatureFinder('project', project,...
                'data', results);
        end
        
        function finder = getFeatureFinder(obj, name, varargin)
            import sa_labs.analysis.*;
            
            ip = inputParser();
            ip.addParameter('analysisType', '', @ischar);
            ip.addParameter('cellData', '', @ischar);
            ip.addParameter('pattern', true, @islogical);
            ip.parse(varargin{:});
            
            analysisType = ip.Results.analysisType;
            cellData = ip.Results.cellData;
            
            project = obj.initializeProject(name);
            if ip.Results.pattern
                condn = ['(.*' strtrim(analysisType) '.*' strtrim(cellData) '.*)'];
            else
                if isempty(analysisType)
                    condn = strcat('.*' , '-', cellData, '$');
                elseif isempty(cellData)
                    condn = strcat('^', analysisType, '-',  '.*');
                else
                    condn = strcat('^', analysisType, '-',  cellData, '$');
                end
            end
            
            obj.log.debug(['Applying filter [ ' condn ' ]' ]);
            indices = ~ cellfun(@isempty, regexpi(project.analysisResultIdList, condn));
            
            results = project.getAnalysisResultArray();
            results = results(indices);
            
            if isempty(results)
                obj.log.error(['Analysis result not found for cond [ ' condn ' ]']);
                throw(app.Exceptions.NO_ANALYSIS_RESULTS_FOUND.create('message', condn));
            end
            
            finder = obj.analysisFactory.createFeatureFinder('project', name,...
                'data', results);
        end
    end
    
    methods (Access = private)
        
        function addCellDataToProject(obj, project, cellName)
            import sa_labs.analysis.*;
            dao = obj.analysisDao;
            
            cellData = dao.findCell(cellName);
            project.addCellData(cellData.recordingLabel, cellData);
            file = dao.findRawDataFiles(cellData.h5File);
            
            if isempty(file)
                obj.log.error(['raw data file [ ' char(cellData.h5File) ' ] not found']);
                throw(app.Exceptions.NO_RAW_DATA_FOUND.create('message', char(file)));
            end
        end
        
    end
end

