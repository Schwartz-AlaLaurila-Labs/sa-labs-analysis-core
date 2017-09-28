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
            obj.recordingLabel = 'label';
        end
    end
    
    methods(Test)
        
        function testBuildTreeSimpleTwoLevel(obj)
            import sa_labs.analysis.*;
            expectedRoot = @(id) strcat('analysis==', id, '-', obj.recordingLabel);
            
            levelOne = containers.Map({'LightStep_20'}, {1 : 50});
            levelTwo = containers.Map({'Amplifier_Ch1'}, {1 : 50});
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs()).thenReturn(levelOne, 'EpochGroup')...
                .thenReturn(levelTwo, 'deviceStream');
            
            mockedAmpParameters = cell(1, 50);
            mockedAmpParameters(:) = {'Amplifier_Ch1'};
            mockedCellData.when.getParamValues(AnyArgs()).thenReturn({'deviceStream', 'stimTime'}, {mockedAmpParameters, 20 * ones(1, 50)});
            mockedCellData.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'});
            
            % Tree with two level - analysis
            tree = obj.testAnalyze(obj.simpleAnalysisProtocol, mockedCellData);
            actual = tree.treefun(@(node) node.name);
            
            expected = {expectedRoot('test-analysis'); 'EpochGroup==LightStep_20'; 'deviceStream==Amplifier_Ch1'};
            obj.verifyEqual(actual.Node, expected);
            leaf = tree.findleaves();
            obj.verifyEqual(tree.get(leaf).epochIndices, 1:50);

            expectedParameters.deviceStream = mockedAmpParameters;
            expectedParameters.stimTime = 20 * ones(1, 50);
            obj.verifyEqual(tree.get(leaf).parameters, expectedParameters);
            obj.verifyEqual(tree.get(tree.getparent(leaf)).parameters, expectedParameters);
        end
        
        function testBuildTreeSimpleMultipleBranches(obj)
            import sa_labs.analysis.*;
            expectedRoot = @(id) strcat('analysis==', id, '-', obj.recordingLabel);
            
            % Tree with two level and one branch - analysis
            % Tree with two level - analysis
            levelOne = containers.Map({'LightStep_20', 'LightStep_500'}, {1 : 50, 51 : 100});
            levelTwo = containers.Map({'Amplifier_Ch1'}, {1 : 50});
            levelTwoOtherBranch = containers.Map({'Amplifier_Ch1'}, {51 : 100});
            
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs())...
                .thenReturn(levelOne, 'EpochGroup')...
                .thenReturn(levelTwo, 'deviceStream')...
                .thenReturn(levelTwoOtherBranch, 'deviceStream');
            
            mockedAmpParameters = cell(1, 50);
            mockedAmpParameters(:) = {'Amplifier_Ch1'};
            
            mockedCellData.when.getParamValues(AnyArgs())...
                .thenReturn({'deviceStream', 'stimTime'}, {mockedAmpParameters, 20 * ones(1, 50)})...
                .thenReturn({'deviceStream', 'stimTime', 'tailTime'}, {mockedAmpParameters, 500 * ones(1, 50), []});
            
            mockedCellData.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'});
            
            tree = obj.testAnalyze(obj.simpleAnalysisProtocol, mockedCellData);
            actual = tree.treefun(@(node) node.name);
            
            expected = {expectedRoot('test-analysis'); 'EpochGroup==LightStep_20'; 'deviceStream==Amplifier_Ch1'; 'EpochGroup==LightStep_500'; 'deviceStream==Amplifier_Ch1'};
            obj.verifyEqual(actual.Node, expected);
            leafs = tree.findleaves();
            
            node1 = tree.get(leafs(1));
            obj.verifyEqual(node1.epochIndices, 1:50);
            expectedParameters.deviceStream = mockedAmpParameters;
            expectedParameters.stimTime = 20 * ones(1, 50);
            obj.verifyEqual(node1.parameters, expectedParameters);
            
            node2 = tree.get(leafs(2));
            obj.verifyEqual(node2.epochIndices, 51:100);
            expectedParameters.deviceStream = mockedAmpParameters;
            expectedParameters.stimTime = 500 * ones(1, 50);
            expectedParameters.tailTime = [];
            obj.verifyEqual(node2.parameters, expectedParameters);
        end
        
        function  testBuildTreeMutlipleLevelMultipleBranches(obj)
            import sa_labs.analysis.*;
            expectedRoot = @(id) strcat('analysis==', id, '-', obj.recordingLabel);
            % Tree with two level and two branch - analysis
            levelOne = containers.Map({'LightStep_20', 'LightStep_500'}, {1 : 50, 51 : 100});
            levelTwo = containers.Map({'Amplifier_Ch1', 'Amplifier_Ch2'}, {1 : 50, 1 : 50});
            levelTwoOtherBranch = containers.Map({'Amplifier_Ch1', 'Amplifier_Ch2'}, {51 : 100, 51 : 100});
            
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs())...
                .thenReturn(levelOne, 'EpochGroup')...
                .thenReturn(levelTwo, 'deviceStream')...
                .thenReturn(levelTwoOtherBranch, 'deviceStream');
            
            paramterNames = {'deviceStream', 'stimTime', 'rstars', 'ndfs'};
            mockedCellData.when.getParamValues(AnyArgs())...
                .thenReturn(paramterNames, {'Amplifier_Ch1', 20, [0.01, 0.1, 1], {'A1A', 'A2A', 'A3A'}})...
                .thenReturn(paramterNames, {'Amplifier_Ch2', 20, [0.01, 0.1, 1], {'B1A', 'A2A', 'A3A'}})...
                .thenReturn(paramterNames, {'Amplifier_Ch1', 500, [10, 5, 100], {'Empty', 'A2A', 'A3A'}})...
                .thenReturn(paramterNames, {'Amplifier_Ch2', 500, [10, 5, 100], {'A1A', 'A2A', 'A3A'}});
            
            mockedCellData.when.getEpochKeysetUnion(AnyArgs())...
                .thenReturn(paramterNames)...
                .thenReturn(paramterNames);
            
            tree = obj.testAnalyze(obj.simpleAnalysisProtocol, mockedCellData);
            actual = tree.treefun(@(node) node.name);
            
            expected = {expectedRoot('test-analysis'); 'EpochGroup==LightStep_20'; 'deviceStream==Amplifier_Ch1';'deviceStream==Amplifier_Ch2';...
                'EpochGroup==LightStep_500'; 'deviceStream==Amplifier_Ch1';'deviceStream==Amplifier_Ch2'};
            
            obj.verifyEqual(actual.Node, expected);
            leafs = tree.findleaves();
            obj.verifyEqual(tree.get(leafs(1)).epochIndices, 1:50);
            obj.verifyEqual(tree.get(leafs(2)).epochIndices, 1:50);
            obj.verifyEqual(tree.get(leafs(3)).epochIndices, 51:100);
            obj.verifyEqual(tree.get(leafs(4)).epochIndices, 51:100);
            
            expected = struct('stimTime', [20, 20], 'rstars', [0.01, 0.1, 1, 0.01, 0.1, 1]);
            expected.deviceStream = {'Amplifier_Ch1', 'Amplifier_Ch2'};
            % tree will have all the epoch parameters in the same epoch
            % order
            % exception - if there is no variation it just gets the unique
            % parameter
            expected.ndfs = {'A1A', 'A2A', 'A3A', 'B1A', 'A2A', 'A3A'};
            
            actualParameters = tree.get(tree.getparent(leafs(1))).parameters;
            obj.verifyEqual(actualParameters, expected);
            actualParameters = tree.get(tree.getparent(leafs(2))).parameters;
            obj.verifyEqual(actualParameters, expected);
            
            expected.stimTime = [500, 500];
            expected.rstars = [10, 5, 100, 10, 5, 100];
            % tree will have all the epoch parameters in the same epoch
            % order
            % exception - if there is no variation it just gets the unique
            % parameter
            expected.ndfs = {'Empty', 'A2A', 'A3A', 'A1A', 'A2A', 'A3A'};
            actualParameters = tree.get(tree.getparent(leafs(4))).parameters;
            obj.verifyEqual(actualParameters, expected);
        end
        
        
        function testBuildTreeComplex(obj)
            import sa_labs.analysis.*;
            
            levelOne = containers.Map({'LightStep_20', 'LightStep_500'}, {1 : 50, 51 : 100});
            
            levelTwo = containers.Map({'Amplifier_Ch1', 'Amplifier_Ch2'}, {1 : 50,  1 : 25});
            levelThree = containers.Map({'G1', 'G2'}, {1 : 25,  26 : 50});
            levelThreeOtherBranch = containers.Map({'G1', 'G2', 'G3'}, {1 : 11,  12 : 22, 23: 25});
            
            leafGroupOne = containers.Map({0.01, 0.02}, {1 : 12, 13 : 25});
            leafGroupTwo = containers.Map({0.01, 0.02}, {26 : 35, 36 : 50});
            
            leafGroupThree = containers.Map({0.01, 0.02}, {1 : 5, 6 : 11});
            leafGroupFour = containers.Map({0.01, 0.02}, {12 : 17, 18 : 22});
            leafGroupFive = containers.Map({0.01, 0.02}, {[23, 24], 25});
            
            mockedCellData = Mock(entity.CellData());
            mockedCellData.when.getEpochValuesMap(AnyArgs())...
                .thenReturn(levelOne, 'EpochGroup')...
                .thenReturn(levelTwo, 'deviceStream')...
                .thenReturn(levelThree, 'groups')...
                .thenReturn(leafGroupOne, 'rstar')...
                .thenReturn(leafGroupTwo, 'rstar')...
                .thenReturn(levelThreeOtherBranch, 'groups')...
                .thenReturn(leafGroupThree, 'rstar')...
                .thenReturn(leafGroupFour, 'rstar')...
                .thenReturn(leafGroupFive, 'rstar');
            
            mockedCellData.when.getParamValues(AnyArgs()).thenReturn({'deviceStream'}, {'Amplifier_Ch1'}).times(100);
            mockedCellData.when.getEpochKeysetUnion(AnyArgs()).thenReturn({'deviceStream', 'stimTime'}).times(100);
            
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'EpochGroup', 'deviceStream', 'epochgroups', 'rstar'};
            s.EpochGroup.splitValue = 'LightStep_20';
            s.deviceStream = {'Amplifier_Ch1', 'Amplifier_Ch2'};
            s.epochgroups = {'G1', 'G2', 'G3'};
            s.rstar = {0.01, 0.02};
            
            tree = obj.testAnalyze(s, mockedCellData);
            
            leafs = tree.findleaves();
            obj.verifyEqual(tree.get(leafs(1)).epochIndices, leafGroupOne(0.01));
            obj.verifyEqual(tree.get(leafs(2)).epochIndices, leafGroupOne(0.02));
            
            obj.verifyEqual(tree.get(leafs(3)).epochIndices, leafGroupTwo(0.01));
            obj.verifyEqual(tree.get(leafs(4)).epochIndices, leafGroupTwo(0.02));
            
            obj.verifyEqual(tree.get(leafs(5)).epochIndices, leafGroupThree(0.01));
            obj.verifyEqual(tree.get(leafs(6)).epochIndices, leafGroupThree(0.02));
            
            obj.verifyEqual(tree.get(leafs(7)).epochIndices, leafGroupFour(0.01));
            obj.verifyEqual(tree.get(leafs(8)).epochIndices, leafGroupFour(0.02));
            
            obj.verifyEqual(tree.get(leafs(9)).epochIndices, leafGroupFive(0.01));
            obj.verifyEqual(tree.get(leafs(10)).epochIndices, leafGroupFive(0.02));
        end
        
        function testBuildTreeWithGroupedBranches(obj)
            import sa_labs.analysis.*;
            
            % analysis template structure
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'textureAngle, barAngle, curSpotSize', 'RstarMean'};
            
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
