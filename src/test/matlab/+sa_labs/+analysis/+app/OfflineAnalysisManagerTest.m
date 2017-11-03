classdef OfflineAnalysisManagerTest < matlab.unittest.TestCase
    
    properties
        beanFactory
        manager
        parserFactoryMock
    end

    properties (Constant)
        DATE_FORMAT = 'yyyymmdd'
    end
    
    methods (TestClassSetup)
        
        function initContext(obj)
            import sa_labs.analysis.*;
            obj.beanFactory = mdepin.getBeanFactory(which('TestContext.m'));
            obj.manager = obj.beanFactory.getBean('offlineAnalaysisManager');
        end

        function setUpParserFactory(obj)

            parserMock = Mock();
            parserFactory = Mock();
            parserFactory.when.getInstance(AnyArgs()).thenReturn(parserMock).times(100);
            parserMock.when.parse(AnyArgs()).thenReturn(obj.mockedCellData('test.h5', {'c1', 'c2'})).times(100);
            obj.parserFactoryMock = parserFactory;
        end
    end
    
    methods(Test)
        
        function testParseSymphonyFiles(obj)
            dao = Mock();
            dao.when.findRawDataFiles(AnyArgs()).thenReturn({'20170505A.h5'})...
                                                .thenReturn({'20170504A.h5', '20170505A.h5'})...
                                                    .thenReturn([]);  % for exception scenario

            % Inject the mocks
            obj.manager.analysisDao = dao;    
            obj.manager.parserFactory = obj.parserFactoryMock;
            
            actual = obj.manager.parseSymphonyFiles('20170505A');
            
            obj.verifyLength(actual, 2);
            obj.verifyEmpty(setdiff({actual.recordingLabel}, {'testc1', 'testc2'}));
            
            actual = obj.manager.parseSymphonyFiles('201705');
            obj.verifyLength(actual, 4);
            obj.verifyEmpty(setdiff({actual.recordingLabel},  {'testc1', 'testc2'}));

            handle = @() obj.manager.parseSymphonyFiles('unknown');
            obj.verifyError(handle, sa_labs.analysis.app.Exceptions.NO_RAW_DATA_FOUND.msgId);
        end

        function testGetParsedAndUnParsedFiles(obj)
            dao = Mock();
            dao.when.findCellNames(AnyArgs()).thenReturn({'20170504Ac1', '20170504Ac2', '20170504Ac3'})...
                                                .thenReturn('20170505Ac1')...
                                                .thenReturn([])...
                                                .thenReturn({'20170507Ac1', '20170505Ac2'});
            experiments = {'20170504A', '20170505A', '20170506A', '20170507A'};

            % Few parsed and one un parsed file
            obj.manager.analysisDao = dao; % Inject the mock in dao          
            [actualParsed, actualUnParsed] = obj.manager.getParsedAndUnParsedFiles(experiments);
            obj.verifyEqual(actualParsed, experiments([1, 2, 4]));
            obj.verifyEqual(actualUnParsed, experiments(3));

            % no parsed files        
            dao = Mock();
            dao.when.findCellNames(AnyArgs()).thenReturn([]).times(4);
            obj.manager.analysisDao = dao;     
            [actualParsed, actualUnParsed] = obj.manager.getParsedAndUnParsedFiles(experiments);
            obj.verifyEmpty(actualParsed);
            obj.verifyEqual(actualUnParsed, experiments);

            % all files are parsed
            dao = Mock();
            dao.when.findCellNames(AnyArgs()).thenReturn({'20170504Ac1', '20170504Ac2', '20170504Ac3'})...
                                                .thenReturn('20170505Ac1')...
                                                .thenReturn('20170506Ac1')...
                                                .thenReturn({'20170507Ac1', '20170505Ac2'});

            obj.manager.analysisDao = dao;
            [actualParsed, actualUnParsed] = obj.manager.getParsedAndUnParsedFiles(experiments);
            obj.verifyEqual(actualParsed, experiments);
            obj.verifyEmpty(actualUnParsed);
        end 

        function testCreateProject(obj)

            dao = Mock();
            dao.when.findRawDataFiles(AnyArgs()).thenReturn({'20170505A.h5'})... % coz of parse symphony files
                                                .thenReturn({'20170504A.h5'}).times(3)... % coz of create project loop for parsed file
                                                .thenReturn({'20170505A.h5'}).times(2); % coz of create project loop for un-parsed file

            dao.when.findCellNames(AnyArgs()).thenReturn({'20170504Ac1', '20170504Ac2', '20170504Ac3'})...
                                                .thenReturn([])...
                                                .thenReturn({'20170504Ac1', '20170504Ac2', '20170504Ac3', '20170505Ac1', '20170505Ac2'});
            
            celldatas1 = obj.mockedCellData('20170504A.h5', {'c1', 'c2', 'c3'});
            celldatas2 = obj.mockedCellData('20170505A.h5', {'c1', 'c2'});
            dao.when.findCell(AnyArgs()).thenReturn(celldatas1(1))... % belongs to already parsed file
                                        .thenReturn(celldatas1(2))...
                                        .thenReturn(celldatas1(3))...
                                        .thenReturn(celldatas2(1))... % belongs to un-parsed file
                                        .thenReturn(celldatas2(2));

            experiments = {'20170504A', '20170505A'};
            expectedCellIdList =  [strcat({'20170504A'}, {'c1' , 'c2', 'c3'}), strcat({'20170505A'}, {'c1', 'c2'})];

            % Inject the mocks
            obj.manager.analysisDao = dao; 
            obj.manager.parserFactory = obj.parserFactoryMock; 

            % create a simple project
            p = createProjectEntity(experiments);
            m = obj.manager.createProject(p);

            obj.verifyNotEmpty(m);
            obj.verifyEmpty(setdiff(p.cellDataIdList, expectedCellIdList));
            obj.verifyLength(p.getCellDataArray(), 5);

            % Test the exceptional scenarios - celldata is present and h5 not
            % found
            
            dao = Mock();
            dao.when.findCellNames(AnyArgs()).thenReturn({'20170504Ac1'});
            dao.when.findRawDataFiles(AnyArgs()).thenReturn({});
            dao.when.findCell(AnyArgs()).thenReturn(obj.mockedCellData('20170504A.h5', {'c1'}));
            % Inject the mocks
            obj.manager.analysisDao = dao; 

            p = createProjectEntity({'20170504A'});
            handle = @() obj.manager.createProject(p);
            obj.verifyError(handle, sa_labs.analysis.app.Exceptions.NO_RAW_DATA_FOUND.msgId);

            function p = createProjectEntity(exp)
                p = sa_labs.analysis.entity.AnalysisProject();
                p.identifier = 'test-project';
                p.experimentList = exp;
                p.analysisDate = datestr(now, obj.DATE_FORMAT);
                p.performedBy = 'sathish';
                p.description = 'Test project';
                p.file = 'test';
            end           
        end

        function testPreprocess(obj)
            cellDatas = obj.mockedCellData('test.h5', {'c1', 'c2'});
            obj.manager.preProcessCellData(cellDatas, {@(d) preProcessor1(d), @(d) preProcessor2(d)}, 'enabled', [true, false]);

            obj.verifyEqual(cellDatas(1).attributes('test-p1'), 'test');
            obj.verifyEqual(cellDatas(2).attributes('test-p1'), 'test');
            
            obj.manager.preProcessCellData(cellDatas, {@(d) preProcessor1(d), @(d) preProcessor2(d)}, 'enabled', [true, true]);

            obj.verifyEqual(cellDatas(1).attributes('test-p1'), 'test');
            obj.verifyEqual(cellDatas(1).attributes('test-p2'), 'test');

            obj.verifyEqual(cellDatas(2).attributes('test-p1'), 'test');
            obj.verifyEqual(cellDatas(2).attributes('test-p2'), 'test');

            function preProcessor1(d)
                d.attributes('test-p1') = 'test';
            end

            function preProcessor2(d)
                d.attributes('test-p2') = 'test';
            end
        end

        function testInitilaizeProject(obj)
            % TODO implement
        end 

        function testBuildAnalysis(obj)
            % TODO implement
        end

        function testApplyAnalysis(obj)
            

        end

        function testGetFeatureFinder(obj)
        end
        
    end

    methods

        function cellDatas = mockedCellData(obj, file, labels)
            n = numel(labels);
            cellDatas = sa_labs.analysis.entity.CellData.empty(0, n);
            for i = 1 : n
                cellDatas(i) = sa_labs.analysis.entity.CellData();
                cellDatas(i).attributes('h5File') = file;
                cellDatas(i).attributes('recordingLabel') = labels{i};
            end
        end 
    end
    
end

