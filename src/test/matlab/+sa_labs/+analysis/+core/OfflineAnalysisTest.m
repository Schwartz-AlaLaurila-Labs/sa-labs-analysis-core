classdef OfflineAnalysisTest < matlab.unittest.TestCase
    
    properties
        simpleAnalysisProtocol
        recordingLabel
    end
    
    methods (TestClassSetup)
        
        function init(obj)
            structure = struct();
            structure.type = 'test-analysis';
            structure.buildTreeBy = {'EpochGroup', 'deviceStream'};
            structure.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            obj.simpleAnalysisProtocol = structure;
            obj.recordingLabel = 'c1';
        end
    end
    
    methods(Test)
        
        function testBuildTreeSimpleTwoLevel(obj)
           
            % 'analysis==test-analysis-c1 ( 1 )  '
            % '                                  '
            % '                |                 '
            % '         group==G1 ( 2 )          '
            % '                                  '
            % '                |                 '
            % '       stimTime==500 ( 3 )        '
            
            import sa_labs.analysis.*;
            
            structure = struct();
            structure.type = 'test-analysis';
            structure.buildTreeBy = {'group', 'stimTime'};
            structure.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            
            % Happy epoch and cell data !
            epochs = entity.EpochData.empty(0, 2);
            
            epochs(1) = entity.EpochData();
            epochs(1).attributes = containers.Map({'stimTime', 'tailTime', 'group'}, {500, 1000, 'G1'});
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(2) = entity.EpochData();
            epochs(2).attributes = containers.Map({'stimTime', 'tailTime', 'group'}, {500, 2000, 'G1'});
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            mockedCellData = entity.CellData();
            mockedCellData.attributes('recordingLabel') = obj.recordingLabel;
            mockedCellData.epochs = epochs;
            mockedCellData.deviceType = 'Amp1';
            
            % Tree with two level - analysis
            tree = obj.testAnalyze(structure, mockedCellData);
            disp('analysis tree')
            tree.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
            
            actual = tree.treefun(@(node) node.name);
            expectedRoot = @(id) strcat('analysis==', id, '-', obj.recordingLabel);
            
            expected = {expectedRoot('test-analysis'); 'group==G1'; 'stimTime==500'};
            % validate branch name
            obj.verifyEqual(actual.Node, expected);
            
            % validate epoch indices
            leaf = tree.findleaves();
            obj.verifyEqual(tree.get(leaf).epochIndices, [1, 2]);
            
            % validate parameters
            actualParentParemeters = tree.get(tree.getparent(leaf)).toStructure();
            obj.verifyEqual(actualParentParemeters.stimTime, [500, 500]);
            obj.verifyEqual(actualParentParemeters.tailTime, [1000, 2000]);
            obj.verifyEqual(actualParentParemeters.group, {'G1', 'G1'});
        end
        
        function testBuildTreeSimpleMultipleBranchesAsAmps(obj)
            
            
            %  '    analysis==test-analysis-c1 ( 1 )      '
            %  '                                          '
            %  '                    |                     '
            %  '             group==G1 ( 2 )              '
            %  '          +---------+----------+          '
            %  '          |                    |          '
            %  ' devices==Amp1 ( 3 )  devices==Amp2 ( 4 ) '
            
            import sa_labs.analysis.*;
            expectedRoot = @(id) strcat('analysis==', id, '-', obj.recordingLabel);
            
            structure = struct();
            structure.type = 'test-analysis';
            structure.buildTreeBy = {'group', 'devices'};
            structure.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            
            epochs = entity.EpochData.empty(0, 2);
            epochs(1) = entity.EpochData();
            epochs(1).attributes = containers.Map({'stimTime', 'tailTime', 'group'}, {500, 1000, 'G1'});
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(2) = entity.EpochData();
            epochs(2).attributes = containers.Map({'stimTime', 'tailTime', 'group'}, {500, 2000, 'G1'});
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            mockedCellData = entity.CellData();
            mockedCellData.attributes('recordingLabel') = obj.recordingLabel;
            mockedCellData.epochs = epochs;
            
            tree = obj.testAnalyze(structure, mockedCellData);
            disp('analysis tree')
            tree.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
            actual = tree.treefun(@(node) node.name);
            
            % validate tree structure
            expected = {expectedRoot('test-analysis'); 'group==G1'; 'devices==Amp1'; 'devices==Amp2'};
            obj.verifyEqual(actual.Node, expected);
            leafs = tree.findleaves();
            obj.verifyLength(leafs, 2);
            
            node1 = tree.get(leafs(1));
            obj.verifyEqual(node1.epochIndices, [1, 2]);
            
            node2 = tree.get(leafs(2));
            obj.verifyEqual(node2.epochIndices, [1, 2]);
            actualParentParemeters = tree.get(tree.getparent(leafs(1))).toStructure();
            obj.verifyEqual(actualParentParemeters.stimTime, [500, 500]);
            obj.verifyEqual(actualParentParemeters.tailTime, [1000, 2000]);
            obj.verifyEqual(actualParentParemeters.group, {'G1', 'G1'});
        end
        
        function  testBuildTreeMutlipleLevelMultipleBranches(obj)
            import sa_labs.analysis.*;
            
            %    '                          analysis==test-analysis-c1 ( 1 )                           '
            %    '                    +--------------------+---------------------+                     '
            %    '                    |                                          |                     '
            %    '          EpochGroup==G1 ( 2 )                       EpochGroup==G2 ( 7 )            '
            %    '          +---------+----------+                    +---------+----------+           '
            %    '          |                    |                    |                    |           '
            %    ' stimTime==20 ( 3 )   stimTime==40 ( 5 )   stimTime==20 ( 8 )   stimTime==40 ( 10 )  '
            %    '          |                    |                    |                                '
            %    '          |                    |                    |                    |           '
            %    ' devices==Amp1 ( 4 )  devices==Amp1 ( 6 )  devices==Amp1 ( 9 ) devices==Amp1 ( 11 )  '

            structure = struct();
            structure.type = 'test-analysis';
            structure.buildTreeBy = {'EpochGroup', 'stimTime', 'devices'};
            structure.devices.splitValue = {'Amp1'};
            structure.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            
            epochs = entity.EpochData.empty(0, 8);
            % epochs for Group (g1)
            epochs(1) = entity.EpochData();
            epochs(1).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 20, 'G1', 0.01});
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(2) = entity.EpochData();
            epochs(2).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 20, 'G1', 0.02});
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(3) = entity.EpochData();
            epochs(3).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 40, 'G1', 0.03});
            epochs(3).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(4) = entity.EpochData();
            epochs(4).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 40, 'G1', 0.04});
            epochs(4).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            % epochs for Group (g2)
            epochs(5) = entity.EpochData();
            epochs(5).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 20, 'G2', 0.01});
            epochs(5).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(6) = entity.EpochData();
            epochs(6).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 20, 'G2', 0.02});
            epochs(6).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(7) = entity.EpochData();
            epochs(7).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 40, 'G2', 0.03});
            epochs(7).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            epochs(8) = entity.EpochData();
            epochs(8).attributes = containers.Map({'stimTime', 'EpochGroup', 'rstars'}, { 40, 'G2', 0.04});
            epochs(8).dataLinks = containers.Map({'Amp1', 'Amp2'}, {'/Amp1', '/Amp2'});
            
            % Amplifier specific cell data
            mockedCellData = entity.CellData();
            mockedCellData.attributes('recordingLabel') = obj.recordingLabel;
            mockedCellData.epochs = epochs;

            tree = obj.testAnalyze(structure, mockedCellData);
            disp('analysis tree')
            tree.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()


            leafs = tree.findleaves();
            obj.verifyEqual(tree.get(leafs(1)).epochIndices, [1, 2]);
            obj.verifyEqual(tree.get(leafs(2)).epochIndices, [3, 4]);
            obj.verifyEqual(tree.get(leafs(3)).epochIndices, [5, 6]);
            obj.verifyEqual(tree.get(leafs(4)).epochIndices, [7, 8]);

            % Start of group = G1
            % ----------------------------
            
            % one level above the leaf (i.e stimTime == 20), expected parameters
            expected1 = struct();
            expected1.stimTime = [20, 20];
            expected1.rstars = [0.01, 0.02];
            expected1.EpochGroup = {'G1', 'G1'};
            expected1.recordingLabel = 'c1';
            
            actualParameters = tree.get(leafs(1)).toStructure();
            obj.verifyEqual(actualParameters, expected1);
            % since device is the leaf, parent should have same parameters
            actualParameters = tree.get(tree.getparent(leafs(1))).toStructure();
            obj.verifyEqual(actualParameters, expected1);
            
            % one level above the leaf (i.e stimTime == 40), expected parameters
            expected2 = struct();
            expected2.stimTime = [40, 40];
            expected2.rstars = [0.03, 0.04];
            expected2.EpochGroup = {'G1', 'G1'};
            expected2.recordingLabel = 'c1';
            
            actualParameters = tree.get(leafs(2)).toStructure();
            obj.verifyEqual(actualParameters, expected2);
            % since device is the leaf, parent should have same parameters
            actualParameters = tree.get(tree.getparent(leafs(2))).toStructure();
            obj.verifyEqual(actualParameters, expected2);
            
            actualParameters = tree.get(tree.getparent(tree.getparent(leafs(2)))).toStructure();
            expected3 = struct();
            expected3.stimTime = [20, 20, 40, 40];
            expected3.rstars = [0.01, 0.02, 0.03, 0.04];
            expected3.EpochGroup = {'G1', 'G1', 'G1', 'G1'};
            expected3.recordingLabel = 'c1';
            obj.verifyEqual(actualParameters, expected3);

            % End of group = G1
            % ----------------------------

            % Start of group = G2
            % ----------------------------

            % one level above the leaf (i.e stimTime == 20), expected parameters
            expected1.EpochGroup = {'G2', 'G2'};
            actualParameters = tree.get(leafs(3)).toStructure();
            obj.verifyEqual(actualParameters, expected1);
            % since device is the leaf, parent should have same parameters
            actualParameters = tree.get(tree.getparent(leafs(3))).toStructure();
            obj.verifyEqual(actualParameters, expected1);

            % one level above the leaf (i.e stimTime == 40), expected parameters
            expected2.EpochGroup = {'G2', 'G2'};
            actualParameters = tree.get(leafs(4)).toStructure();
            obj.verifyEqual(actualParameters, expected2);
            % since device is the leaf, parent should have same parameters
            actualParameters = tree.get(tree.getparent(leafs(4))).toStructure();
            obj.verifyEqual(actualParameters, expected2);
            
            expected3.EpochGroup = {'G2', 'G2', 'G2', 'G2'};
            actualParameters = tree.get(tree.getparent(tree.getparent(leafs(4)))).toStructure();
            obj.verifyEqual(actualParameters, expected3);

            % End of group = G2
            % ----------------------------
        end
        
        
        function testBuildTreeWithGroupedBranches(obj)
            import sa_labs.analysis.*;
            
            % analysis template structure
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'textureAngle; barAngle; curSpotSize', 'RstarMean'};            
            % mocked cell data
            protocols = containers.Map({'MovingBar', 'DriftingGrating', 'DrifitngTexture'}, {1 : 50, 51 : 100, 101: 150});
            
            % level two
            barAngle = containers.Map({10, 20, 30}, {1 : 15,  16 : 30, 31 : 50});
            driftingGratingAngle = containers.Map({10, 20, 30}, {51 : 65,  66 : 80, 81 : 100});
            driftingTextureAngle = containers.Map({10, 20, 30}, {101 : 115,  116 : 130, 131 : 150});
            
            % level three
            rstarMeanBarAngle10 = containers.Map({0.1, 0.2}, {1 : 10,  11 : 15});
            rstarMeanBarAngle20 = containers.Map({0.1, 0.2}, {16 : 20,  21 : 30});
            rstarMeanBarAngle30 = containers.Map({0.1, 0.2}, {31 : 35,  36 : 50});
            
            rstarMeanDriftingGratingAngle10 = containers.Map({0.5, 0.6}, {51 : 60,  61 : 65});
            rstarMeanDriftingGratingAngle20 = containers.Map({0.5, 0.6}, {66 : 86,  87 : 90});
            rstarMeanDriftingGratingAngle30 = containers.Map({0.5, 0.6}, {91 : 95,  96 : 100});
            
            rstarMeanDriftingTextureAngle10 = containers.Map({0.1, 0.2}, {101 : 110,  111 : 115});
            rstarMeanDriftingTextureAngle20 = containers.Map({0.1, 0.2}, {116 : 120,  121 : 130});
            rstarMeanDriftingTextureAngle30 = containers.Map({0.1, 0.2}, {131 : 135,  136 : 150});
            
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs())...
                .thenReturn(protocols, 'protocol')...
                .thenReturn(driftingTextureAngle, 'textureAngle')... % Drifting Texture
                .thenReturn(rstarMeanDriftingTextureAngle10, 'RstarMean')...
                .thenReturn(rstarMeanDriftingTextureAngle20, 'RstarMean')...
                .thenReturn(rstarMeanDriftingTextureAngle30, 'RstarMean')...
                .thenReturn(driftingGratingAngle, 'textureAngle')... % Drifting Grating
                .thenReturn(rstarMeanDriftingGratingAngle10, 'RstarMean')...
                .thenReturn(rstarMeanDriftingGratingAngle20, 'RstarMean')...
                .thenReturn(rstarMeanDriftingGratingAngle30, 'RstarMean')...
                .thenReturn(containers.Map(), 'textureAngle')... % MovingBar
                .thenReturn(protocols, 'protocol')...
                .thenReturn(containers.Map(), 'barAngle')...  % Drifting Texture
                .thenReturn(containers.Map(), 'barAngle')...  % Drifting Grating
                .thenReturn(barAngle, 'barAngle')...          % MovingBar
                .thenReturn(rstarMeanBarAngle10, 'RstarMean')...
                .thenReturn(rstarMeanBarAngle20, 'RstarMean')...
                .thenReturn(rstarMeanBarAngle30, 'RstarMean')...
                .thenReturn(protocols, 'protocol')...
                .thenReturn(containers.Map(), 'curSpotSize')... % Drifting Texture
                .thenReturn(containers.Map(), 'curSpotSize')... % Drifting Grating
                .thenReturn(containers.Map(), 'curSpotSize');   % MovingBar
            
            mockedCellData.when.getParamValues(AnyArgs()).thenReturn({'deviceStream'}, {'Amplifier_Ch1'}).times(100);
            mockedCellData.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'}).times(100);
            mockedCellData.deviceType = 'Amplifier_Ch1';
            analysisProtocol = core.AnalysisProtocol(s);
            offlineAnalysis = core.OfflineAnalysis(analysisProtocol, obj.recordingLabel);
            offlineAnalysis.setEpochSource(mockedCellData);
            offlineAnalysis.service();
            result = offlineAnalysis.getResult();
            
            leafs = result.findleaves();
            
            obj.verifyEqual(result.get(leafs(1)).epochIndices, rstarMeanDriftingTextureAngle10(0.1));
            obj.verifyEqual(result.get(leafs(2)).epochIndices, rstarMeanDriftingTextureAngle10(0.2));
            
            obj.verifyEqual(result.get(leafs(3)).epochIndices, rstarMeanDriftingTextureAngle20(0.1));
            obj.verifyEqual(result.get(leafs(4)).epochIndices, rstarMeanDriftingTextureAngle20(0.2));
            
            obj.verifyEqual(result.get(leafs(5)).epochIndices, rstarMeanDriftingTextureAngle30(0.1));
            obj.verifyEqual(result.get(leafs(6)).epochIndices, rstarMeanDriftingTextureAngle30(0.2));
            
            obj.verifyEqual(result.get(leafs(7)).epochIndices, rstarMeanDriftingGratingAngle10(0.5));
            obj.verifyEqual(result.get(leafs(8)).epochIndices, rstarMeanDriftingGratingAngle10(0.6));
            
            obj.verifyEqual(result.get(leafs(9)).epochIndices, rstarMeanDriftingGratingAngle20(0.5));
            obj.verifyEqual(result.get(leafs(10)).epochIndices, rstarMeanDriftingGratingAngle20(0.6));
            
            obj.verifyEqual(result.get(leafs(11)).epochIndices, rstarMeanDriftingGratingAngle30(0.5));
            obj.verifyEqual(result.get(leafs(12)).epochIndices, rstarMeanDriftingGratingAngle30(0.6));
            
            obj.verifyEqual(result.get(leafs(13)).epochIndices, rstarMeanBarAngle10(0.1));
            obj.verifyEqual(result.get(leafs(14)).epochIndices, rstarMeanBarAngle10(0.2));
            
            obj.verifyEqual(result.get(leafs(15)).epochIndices, rstarMeanBarAngle20(0.1));
            obj.verifyEqual(result.get(leafs(16)).epochIndices, rstarMeanBarAngle20(0.2));
            
            obj.verifyEqual(result.get(leafs(17)).epochIndices, rstarMeanBarAngle30(0.1));
            obj.verifyEqual(result.get(leafs(18)).epochIndices, rstarMeanBarAngle30(0.2));
            
            disp('analysis tree')
            result.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
        end
        
        function testBuildTreeWithMissingEpochParameter(obj)
            import sa_labs.analysis.*;
            
            % analysis template structure
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'RstarMean', 'textureAngle'};
            
            % mocked cell data
            protocols = containers.Map({'01MovingBar', '02DriftingGrating', '03DrifitngTexture'}, {1 : 50, 51 : 100, 101: 150});
            
            % level two
            rstarMeanBar= containers.Map({0.1, 0.2}, {1 : 10,  11 : 15});
            rstarMeanDriftingGrating =  containers.Map({0.5}, {51 : 100});
            rstarMeanDriftingTexture = containers.Map({0.1}, {101 : 150});
            
            % level three only for drifting texture
            driftingGratingAngle = containers.Map({10, 20, 30}, {51 : 65,  66 : 80, 81 : 100});
            driftingTextureAngle = containers.Map({10, 20, 30}, {101 : 115,  116 : 130, 131 : 150});
            
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs())...
                .thenReturn(protocols, 'protocol')...
                .thenReturn(rstarMeanBar, 'RstarMean')... % start of moving bar
                .thenReturn(containers.Map(), 'textureAngle')... % empty for moving bar
                .thenReturn(containers.Map(), 'textureAngle')... % empty for moving bar
                .thenReturn(rstarMeanDriftingGrating, 'RstarMean')... % start of drifting grating
                .thenReturn(driftingGratingAngle, 'textureAngle')...
                .thenReturn(rstarMeanDriftingTexture, 'RstarMean')... % start of drifting texture
                .thenReturn(driftingTextureAngle, 'textureAngle');
            
            mockedCellData.when.getParamValues(AnyArgs()).thenReturn({'deviceStream'}, {'Amplifier_Ch1'}).times(100);
            mockedCellData.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'}).times(100);
            mockedCellData.deviceType = 'Amplifier_Ch1';
            
            result = obj.testAnalyze(s, mockedCellData);
            leafs = result.findleaves();
            disp('analysis tree')
            result.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
            
            obj.verifyLength(leafs, 8);
            obj.verifyEqual(result.get(leafs(1)).epochIndices, rstarMeanBar(0.1));
            obj.verifyEqual(result.get(leafs(2)).epochIndices, rstarMeanBar(0.2));
            
            obj.verifyEqual(result.get(leafs(3)).epochIndices, driftingGratingAngle(10));
            obj.verifyEqual(result.get(leafs(4)).epochIndices, driftingGratingAngle(20));
            obj.verifyEqual(result.get(leafs(5)).epochIndices, driftingGratingAngle(30));
            
            obj.verifyEqual(result.get(leafs(6)).epochIndices, driftingTextureAngle(10));
            obj.verifyEqual(result.get(leafs(7)).epochIndices, driftingTextureAngle(20));
            obj.verifyEqual(result.get(leafs(8)).epochIndices, driftingTextureAngle(30));
        end
        
        function testBuildTreeWithMissingEpochParameterValues(obj)
            import sa_labs.analysis.*;
            
            % analysis template structure
            % case (1)
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'RstarMean', 'textureAngle'};
            s.protocol.splitValue = {'01MovingBar', '04WhiteNoiseFlicker'};
            s.textureAngle.splitValue = {'10'};
            
            protocols = containers.Map({'01MovingBar', '02DriftingGrating', '03DrifitngTexture'}, {1 : 50, 51 : 100, 101: 150});
            
            % level two
            rstarMeanBar= containers.Map({0.1, 0.2}, {1 : 10,  11 : 15});
            rstarMeanDriftingGrating =  containers.Map({0.5}, {51 : 100});
            rstarMeanDriftingTexture = containers.Map({0.1}, {101 : 150});
            
            % level three only for drifting texture
            driftingGratingAngle = containers.Map({'10', '20', '30'}, {51 : 65,  66 : 80, 81 : 100});
            driftingTextureAngle = containers.Map({'10', '20', '30'}, {101 : 115,  116 : 130, 131 : 150});
            
            mockedCellData = createMockedData();
            mockedCellData.deviceType = 'Amplifier_Ch1';
            result = obj.testAnalyze(s, mockedCellData);
            
            leafs = result.findleaves();
            disp('analysis tree')
            result.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
            
            obj.verifyLength(leafs, 2);
            obj.verifyEqual(result.get(leafs(1)).epochIndices, rstarMeanBar(0.1));
            obj.verifyEqual(result.get(leafs(2)).epochIndices, rstarMeanBar(0.2));
            
            % case (2)
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'RstarMean', 'textureAngle'};
            s.protocol.splitValue = {'04WhiteNoiseFlicker'};
            s.textureAngle.splitValue = {'10'};
            
            mockedCellData = createMockedData();
            result = obj.testAnalyze(s, mockedCellData);
            
            obj.verifyLength(result.findleaves(), 1);
            
            function mock = createMockedData()
                
                mock = Mock(sa_labs.analysis.entity.CellData());
                mock.when.getEpochValuesMap(AnyArgs())...
                    .thenReturn(protocols, 'protocol')...
                    .thenReturn(rstarMeanBar, 'RstarMean')... % start of moving bar
                    .thenReturn(containers.Map(), 'textureAngle')... % empty for moving bar
                    .thenReturn(containers.Map(), 'textureAngle')... % empty for moving bar
                    .thenReturn(rstarMeanDriftingGrating, 'RstarMean')... % start of drifting grating
                    .thenReturn(driftingGratingAngle, 'textureAngle')...
                    .thenReturn(rstarMeanDriftingTexture, 'RstarMean')... % start of drifting texture
                    .thenReturn(driftingTextureAngle, 'textureAngle');
                mock.when.getParamValues(AnyArgs()).thenReturn({'deviceStream'}, {'Amplifier_Ch1'}).times(100);
                mock.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'}).times(100);
            end
            
        end
    end
    
    methods
        
        function t = testAnalyze(obj, structure, mockedCellData)
            import sa_labs.analysis.*;
            
            protocol = core.AnalysisProtocol(structure);
            offlineAnalysis = core.OfflineAnalysis(protocol, obj.recordingLabel);
            offlineAnalysis.setEpochSource(mockedCellData);
            offlineAnalysis.service();
            t = offlineAnalysis.getResult();
        end
    end
end
