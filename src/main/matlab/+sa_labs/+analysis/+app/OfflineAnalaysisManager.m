classdef OfflineAnalaysisManager < handle & mdepin.Bean
    
    properties
        analysisDao
        parserFactory
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
                obj.log.info(['parsing ' num2str(i) '/' num2str(n) ' h5 file [ ' strrep(files{i}, '\', '/') ' ]' ]);
                parser =  obj.parserFactory.getInstance(files{i});
                results = parser.parse().getResult();

                for result = each(results)
                    dao.saveCell(result);
                    obj.log.info(['saving data set [ ' result.recordingLabel ' ]']);
                end
                cellDataArray = [results, cellDataArray]; %#ok
            end
        end
        
        function [parsedExperiments, unParsedExperiments] = getParsedAndUnParsedFiles(obj, experiments)
            
            % A simple utility function to get parsed and un-parsed files 
            % by experiment name (i.e date)

            index = cellfun(@(e) isempty(obj.analysisDao.findCellNames(e)), experiments);
            unParsedExperiments = experiments(index);
            parsedExperiments = experiments(~ index);
            
            obj.log.info(['list of parsed files [ ' strjoin(parsedExperiments) ' ] unParsed files [ ' strjoin(unParsedExperiments) ' ]']);
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
            cellfun(@(id) obj.addCellDataToProject(project, id), parsedExperiments);

            dao.saveProject(project);
            obj.log.info(['Project created under location [ ' strrep(project.file, '\', '/') ' ]' ]);
        end
        
        function project = initializeProject(obj, name)
            
            dao = obj.analysisDao; 

            cellfun(@(id) obj.addCellDataToProject(project, id), project.cellDataIdList);
            cellfun(@(id) project.addResult(id, dao.findAnalysisResult(id), project.analysisResultNames));
            
            obj.log.info(['project [ ' project.identifier ' ] initialized ']);
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
        
        function project = buildAnalysis(obj, projectName, presets)
            import sa_labs.analysis.*;
            
            project = obj.initializeProject(projectName);
            
            for cellData = each(project.getCellDataArray())

                for preset = each(presets)
                    protocol = core.AnalysisProtocol(preset);
                    analysis = core.OfflineAnalysis(protocol, cellData.recordingLabel);
                    analysis.setEpochSource(cellData);
                    analysis.service();
                    result = analysis.getResult();
                    obj.analysisDao.saveAnalysisResults(analysis.identifier, result, protocol);
                    project.addResult(analysis.identifier, result);
                end
            end
            obj.analysisDao.saveProject(project);
        end
        
        % TODO optimize

        function builder = getFeatureBuilder(obj, projectName, results)
            import sa_labs.analysis.*;
            
            if nargin < 3
                project = obj.initializeProject(projectName);
                results =  project.getAllresult();
            end
            builder = core.factory.createFeatureBuilder('project', projectName,...
                'data', results);
        end
        
        function featureBuilder = applyAnalysis(obj, featureBuilder, featureGroup, functions)
            import sa_labs.analysis.*;
            
            groups = featureBuilder.findFeatureGroup('analysis');
            project = featureBuilder.findFeatureGroup('project').splitValue;
            dao = obj.analysisDao;
            results = tree.empty(0, numel(groups));
            index = 1;
            for group = groups
                resultIdArray = strsplit(group.splitValue, '-');
                cellData = dao.findCell(resultIdArray{end});
                
                protocol = group.parameters.analysisProtocol;
                analysis = core.OfflineAnalysis(protocol, cellData.recordingLabel);
                analysis.setEpochSource(cellData);
                analysis.featureBuilder.dataStore = dao.findAnalysisResult(group.splitValue);
                
                analysis.addFeaturesToGroup(featureGroup, functions);
                
                result = analysis.getResult();
                dao.saveAnalysisResults(analysis.identifier, result, protocol);
                results(index) = result;
                index = index + 1;
            end
            featureBuilder = core.factory.createFeatureBuilder('project', project,...
                'data', results);
        end
    end

    methods (Access = private)

        function addCellDataToProject(obj, project, cellName)
            import sa_labs.analysis.*;
            dao = obj.analysisDao;
            
            for cellData = each(dao.findCell(cellName))

                project.addCellData(cellData.recordingLabel, cellData);
                file = dao.findRawDataFiles(cellData.h5File);

                if isempty(file)
                    obj.log.error(['raw data file [ ' char(cellData.h5File) ' ] not found']);
                    throw(app.Exceptions.NO_RAW_DATA_FOUND.create('message', char(file)));
                end
            end
        end

    end
end

