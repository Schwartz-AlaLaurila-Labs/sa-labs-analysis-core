classdef FeatureTreeBuilderTest < matlab.unittest.TestCase
    
    properties
        builder
        treeIndices
    end
    
    methods (TestClassSetup)
        
        function create(obj)
            
            import sa_labs.analysis.*;
            obj.treeIndices = struct();
            obj.builder = core.FeatureTreeBuilder('analysis', 'Light-step-analysis');
            
            obj.treeIndices.amp1 = obj.builder.addEpochGroup(1, 'Amp', 'Amplifier_ch1', 1:500);
            obj.treeIndices.amp2 = obj.builder.addEpochGroup(1, 'Amp', 'Amplifier_ch2', 1:500);
            
            obj.treeIndices.ds1 = obj.builder.addEpochGroup(obj.treeIndices.amp1, 'EpochGroup', 'Light_Step_20', 1:250);
            obj.treeIndices.ds2 = obj.builder.addEpochGroup(obj.treeIndices.amp1, 'EpochGroup', 'Light_Step_400', 251:500);
            obj.treeIndices.ds3 = obj.builder.addEpochGroup(obj.treeIndices.amp2, 'EpochGroup', 'Light_Step_20', 1:250);
            obj.treeIndices.ds4 = obj.builder.addEpochGroup(obj.treeIndices.amp2, 'EpochGroup', 'Light_Step_400', 251:500);
            
            obj.treeIndices.ds1_rstar_0_01 = obj.builder.addEpochGroup(obj.treeIndices.ds1, 'rstar', '0.01', 1:2:250);
            obj.treeIndices.ds1_rstar_0_1 = obj.builder.addEpochGroup(obj.treeIndices.ds1, 'rstar', '0.1', 2:2:250);
            obj.treeIndices.ds2_rstar_0_01 = obj.builder.addEpochGroup(obj.treeIndices.ds2, 'rstar', '0.01', 1:2:250);
            obj.treeIndices.ds2_rstar_0_1 = obj.builder.addEpochGroup(obj.treeIndices.ds2, 'rstar', '0.1', 2:2:250);
            obj.treeIndices.ds3_rstar_0_01 = obj.builder.addEpochGroup(obj.treeIndices.ds3, 'rstar', '0.01', 1:2:250);
            obj.treeIndices.ds3_rstar_0_1 = obj.builder.addEpochGroup(obj.treeIndices.ds3, 'rstar', '0.1', 2:2:250);
            obj.treeIndices.ds4_rstar_0_01 = obj.builder.addEpochGroup(obj.treeIndices.ds4, 'rstar', '0.01', 1:2:250);
            obj.treeIndices.ds4_rstar_0_1 = obj.builder.addEpochGroup(obj.treeIndices.ds4, 'rstar', '0.1', 2:2:250);
            
            disp('Tree information - ');
            obj.builder.getStructure().tostring() % print tree
        end
    end

    methods (Test)
        
        function testAppend(obj)
            % TODO implement the test case
        end

        function testCollect(obj)
            childNodes = obj.builder.findEpochGroup('rstar');
            % prepare child nodes for additional parameters
            parameters = struct();
            parameters.ndf = {'a1a', 'a2a'};
            parameters.array = 1:5;
            for i = 1 : numel(childNodes)
                childNodes(i).setParameters(parameters);
            end
            % get amplifier nodes
            amp1LightstepsNodes = obj.builder.findEpochGroup('Light_Step_20');
            amp1Lightstep = amp1LightstepsNodes(1);
            obj.builder.collect([childNodes(:).id], 'splitValue', 'rstar_from_child')
            
            obj.verifyEqual(amp1Lightstep.get('rstar_from_child'), {'0.01', '0.1'});
            handle = @()obj.builder.collect([childNodes(:).id], 'splitValue', 'splitValue');
            obj.verifyError(handle,'MATLAB:class:SetProhibited');
        end

        function testRemoveEpochGroup(obj)
             % TODO implement the test case
        end

        function testCurateDataStore(obj)
             % TODO implement the test case
        end

        function testIsEpochGroupAlreadyPresent(obj)
             % TODO implement the test case
        end

        function testFindEpochGroup(obj)
            
            % Root node check
            nodes = obj.builder.findEpochGroup('Light-step-analysis');
            obj.verifyLength(nodes, 1);
            obj.verifyEqual(nodes.id, 1);
            
            nodes = obj.builder.findEpochGroup('Amp');
            obj.verifyLength(nodes, 2);
            obj.verifyEqual(nodes(1).id, obj.treeIndices.amp1);
            obj.verifyEqual(nodes(2).id, obj.treeIndices.amp2);
            obj.verifyEqual({nodes(:).name}, { 'Amp==Amplifier_ch1', 'Amp==Amplifier_ch2' });
            
            for i = 1 : numel(nodes)
                obj.verifyEqual(nodes(i).epochIndices, 1:500);
            end
            % Boundry cases
            nodes = obj.builder.findEpochGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findEpochGroup([]);
            obj.verifyEmpty(nodes);
        end
        
        function testGetAllChildrensByName(obj)
            nodes = obj.builder.getAllChildrensByName('Light_Step_20');
            obj.verifyLength(nodes, 6);
            % dfs traversal check
            expected = [obj.treeIndices.ds1, obj.treeIndices.ds1_rstar_0_01, obj.treeIndices.ds1_rstar_0_1,...
                obj.treeIndices.ds3, obj.treeIndices.ds3_rstar_0_01, obj.treeIndices.ds3_rstar_0_1 ];
            obj.verifyEqual([nodes(:).id], expected);
            % Boundry cases
            nodes = obj.builder.findEpochGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findEpochGroup([]);
            obj.verifyEmpty(nodes);
        end
        
        function testGetImmediateChildrensByName(obj)
            nodes = obj.builder.getImmediateChildrensByName('Amp');
            expected = [obj.treeIndices.ds1, obj.treeIndices.ds2, obj.treeIndices.ds3, obj.treeIndices.ds4];
            obj.verifyEqual([nodes(:).id], expected);
            % Boundry cases
            nodes = obj.builder.findEpochGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findEpochGroup([]);
            obj.verifyEmpty(nodes);
        end
        
        function testGetEpochGroups(obj)
            % check for null indices
            n = obj.builder.getEpochGroups([]);
            obj.verifyEmpty(n);
            
            % single node check
            n = obj.builder.getEpochGroups(obj.treeIndices.ds4_rstar_0_1);
            obj.verifyEqual(n.id, obj.treeIndices.ds4_rstar_0_1);
        end
        
        function testFindEpochGroupId(obj)
            id = obj.builder.findEpochGroupId('Amp==Amplifier_ch1');
            obj.verifyEqual(id, obj.treeIndices.amp1);
            
            % search on ds4 subtree
            id = obj.builder.findEpochGroupId('rstar==0.01', obj.treeIndices.ds4);
            obj.verifyEqual(id, obj.treeIndices.ds4_rstar_0_01);
            
            % valid subtree but invalid search expression
            id = obj.builder.findEpochGroupId('Light_Step_500', obj.treeIndices.amp2);
            obj.verifyEmpty(id);            
        end
        
        function validateNodeIdAfterTreeMerge(obj)
            import sa_labs.analysis.*;
            
            expectedFirstLeaf = obj.builder.getEpochGroups(obj.treeIndices.ds1_rstar_0_01);
            expecteLastLeaf = obj.builder.getEpochGroups(obj.treeIndices.ds4_rstar_0_1);
            n = obj.builder.dataStore.nnodes;

            b = factory.AnalysisFactory.createFeatureBuilder('cell', 'ac2');
            b.addEpochGroup(1, 'Amp', 'Amplifier_ch3', 1:500);
            b.addEpochGroup(1, 'Amp', 'Amplifier_ch4', 1:500);
            % validate leaf
            disp(' Merging tree ');
            obj.builder.append(b.dataStore, true);
            actual = obj.builder.getEpochGroups(obj.treeIndices.ds1_rstar_0_01);
            obj.verifyEqual(actual.name, expectedFirstLeaf.name);
            
            actual = obj.builder.getEpochGroups(obj.treeIndices.ds4_rstar_0_1);
            obj.verifyEqual(actual.name, expecteLastLeaf.name);
            
            % non leaf nodes
            actual = obj.builder.findEpochGroup('Amp==Amplifier_ch3');
            obj.verifyEqual(actual.id, n + 2);
            actual = obj.builder.findEpochGroup('Amp==Amplifier_ch4');
            obj.verifyEqual(actual.id, n + 3);
            
            obj.builder.getStructure().tostring() % print tree
        end
        
        function testBasicEpochGroup(obj)
            import sa_labs.analysis.*;
             b = factory.AnalysisFactory.createFeatureBuilder('cell', 'ac2');
            % empty check
            obj.verifyFalse(b.isBasicEpochGroup([]));
            id = b.addEpochGroup(1, 'Amp', 'Amplifier_ch3', 1:500);
            
            obj.verifyTrue(b.isBasicEpochGroup(b.getEpochGroups(id)));
            id = b.addEpochGroup(id, 'rstar', '0.01', 1:500);
            
            obj.verifyFalse(b.isBasicEpochGroup(b.getEpochGroups(1)));
            obj.verifyTrue(b.isBasicEpochGroup(b.getEpochGroups(id)));
            
            b = obj.builder;
            % array of nodes
            obj.verifyTrue(b.isBasicEpochGroup(b.getEpochGroups([obj.treeIndices.ds1_rstar_0_01, obj.treeIndices.ds4_rstar_0_1])));
            obj.verifyFalse(b.isBasicEpochGroup(b.getEpochGroups([obj.treeIndices.ds1_rstar_0_01, obj.treeIndices.ds4_rstar_0_1, obj.treeIndices.ds4])));
        end

    end
end

