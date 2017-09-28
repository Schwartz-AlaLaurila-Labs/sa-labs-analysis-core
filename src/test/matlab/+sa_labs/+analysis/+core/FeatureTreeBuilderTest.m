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
            
            obj.treeIndices.amp1 = obj.builder.addFeatureGroup(1, 'Amp', 'Amplifier_ch1', entity.EpochGroup(1:500, 'none'));
            obj.treeIndices.amp2 = obj.builder.addFeatureGroup(1, 'Amp', 'Amplifier_ch2', entity.EpochGroup(1:500, 'none'));
            
            obj.treeIndices.ds1 = obj.builder.addFeatureGroup(obj.treeIndices.amp1, 'EpochGroup', 'Light_Step_20', entity.EpochGroup(1:250, 'Light_Step_20'));
            obj.treeIndices.ds2 = obj.builder.addFeatureGroup(obj.treeIndices.amp1, 'EpochGroup', 'Light_Step_400', entity.EpochGroup(251:500, 'Light_Step_400'));
            obj.treeIndices.ds3 = obj.builder.addFeatureGroup(obj.treeIndices.amp2, 'EpochGroup', 'Light_Step_20', entity.EpochGroup(1:250, 'Light_Step_20'));
            obj.treeIndices.ds4 = obj.builder.addFeatureGroup(obj.treeIndices.amp2, 'EpochGroup', 'Light_Step_400', entity.EpochGroup(251:500, 'Light_Step_400'));
            
            obj.treeIndices.ds1_rstar_0_01 = obj.builder.addFeatureGroup(obj.treeIndices.ds1, 'rstar', '0.01',  entity.EpochGroup(1:2:250, 'rstar'));
            obj.treeIndices.ds1_rstar_0_1 = obj.builder.addFeatureGroup(obj.treeIndices.ds1, 'rstar', '0.1',  entity.EpochGroup(2:2:250, 'rstar'));
            obj.treeIndices.ds2_rstar_0_01 = obj.builder.addFeatureGroup(obj.treeIndices.ds2, 'rstar', '0.01', entity.EpochGroup(1:2:250, 'rstar'));
            obj.treeIndices.ds2_rstar_0_1 = obj.builder.addFeatureGroup(obj.treeIndices.ds2, 'rstar', '0.1',  entity.EpochGroup(2:2:250, 'rstar'));
            obj.treeIndices.ds3_rstar_0_01 = obj.builder.addFeatureGroup(obj.treeIndices.ds3, 'rstar', '0.01', entity.EpochGroup(1:2:250, 'rstar'));
            obj.treeIndices.ds3_rstar_0_1 = obj.builder.addFeatureGroup(obj.treeIndices.ds3, 'rstar', '0.1',  entity.EpochGroup(2:2:250, 'rstar'));
            obj.treeIndices.ds4_rstar_0_01 = obj.builder.addFeatureGroup(obj.treeIndices.ds4, 'rstar', '0.01', entity.EpochGroup(1:2:250, 'rstar'));
            obj.treeIndices.ds4_rstar_0_1 = obj.builder.addFeatureGroup(obj.treeIndices.ds4, 'rstar', '0.1',  entity.EpochGroup(2:2:250, 'rstar'));
            
            disp('Tree information - ');
            obj.builder.getStructure().tostring() % print tree
        end
    end

    methods (Test)
        
        function testAppend(obj)
            % TODO implement the test case
        end

        function testCollect(obj)
            childNodes = obj.builder.findFeatureGroup('rstar');
            % prepare child nodes for additional parameters
            parameters = struct();
            parameters.ndf = {'a1a', 'a2a'};
            parameters.array = 1:5;
            for i = 1 : numel(childNodes)
                childNodes(i).setParameters(parameters);
            end
            % get amplifier nodes
            amp1LightstepsNodes = obj.builder.findFeatureGroup('Light_Step_20');
            amp1Lightstep = amp1LightstepsNodes(1);
            obj.builder.collect([childNodes(:).id], 'splitValue', 'rstar_from_child')
            
            obj.verifyEqual(amp1Lightstep.getParameter('rstar_from_child'), {'0.01', '0.1'});
            handle = @()obj.builder.collect([childNodes(:).id], 'splitValue', 'splitValue');
            obj.verifyError(handle,'MATLAB:class:SetProhibited');
        end

        function testRemoveFeatureGroup(obj)
             % TODO implement the test case
        end

        function testCurateDataStore(obj)
             % TODO implement the test case
        end

        function testIsFeatureGroupAlreadyPresent(obj)
             % TODO implement the test case
        end

        function testFindFeatureGroup(obj)
            
            % Root node check
            nodes = obj.builder.findFeatureGroup('Light-step-analysis');
            obj.verifyLength(nodes, 1);
            obj.verifyEqual(nodes.id, 1);
            
            nodes = obj.builder.findFeatureGroup('Amp');
            obj.verifyLength(nodes, 2);
            obj.verifyEqual(nodes(1).id, obj.treeIndices.amp1);
            obj.verifyEqual(nodes(2).id, obj.treeIndices.amp2);
            obj.verifyEqual({nodes(:).name}, { 'Amp==Amplifier_ch1', 'Amp==Amplifier_ch2' });
            
            for i = 1 : numel(nodes)
                obj.verifyEqual(nodes(i).epochIndices, 1:500);
            end
            % Boundry cases
            nodes = obj.builder.findFeatureGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findFeatureGroup([]);
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
            nodes = obj.builder.findFeatureGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findFeatureGroup([]);
            obj.verifyEmpty(nodes);
        end
        
        function testGetImmediateChildrensByName(obj)
            nodes = obj.builder.getImmediateChildrensByName('Amp');
            expected = [obj.treeIndices.ds1, obj.treeIndices.ds2, obj.treeIndices.ds3, obj.treeIndices.ds4];
            obj.verifyEqual([nodes(:).id], expected);
            % Boundry cases
            nodes = obj.builder.findFeatureGroup('unknown');
            obj.verifyEmpty(nodes);
            nodes = obj.builder.findFeatureGroup([]);
            obj.verifyEmpty(nodes);
        end
        
        function testGetFeatureGroups(obj)
            % check for null indices
            n = obj.builder.getFeatureGroups([]);
            obj.verifyEmpty(n);
            
            % single node check
            n = obj.builder.getFeatureGroups(obj.treeIndices.ds4_rstar_0_1);
            obj.verifyEqual(n.id, obj.treeIndices.ds4_rstar_0_1);
        end
        
        function testFindFeatureGroupId(obj)
            id = obj.builder.findFeatureGroupId('Amp==Amplifier_ch1');
            obj.verifyEqual(id, obj.treeIndices.amp1);
            
            % search on ds4 subtree
            id = obj.builder.findFeatureGroupId('rstar==0.01', obj.treeIndices.ds4);
            obj.verifyEqual(id, obj.treeIndices.ds4_rstar_0_01);
            
            % valid subtree but invalid search expression
            id = obj.builder.findFeatureGroupId('Light_Step_500', obj.treeIndices.amp2);
            obj.verifyEmpty(id);            
        end
        
        function validateNodeIdAfterTreeMerge(obj)
            import sa_labs.analysis.*;
            
            expectedFirstLeaf = obj.builder.getFeatureGroups(obj.treeIndices.ds1_rstar_0_01);
            expecteLastLeaf = obj.builder.getFeatureGroups(obj.treeIndices.ds4_rstar_0_1);
            n = obj.builder.dataStore.nnodes;

            b = factory.AnalysisFactory.createFeatureBuilder('cell', 'ac2');
            b.addFeatureGroup(1, 'Amp', 'Amplifier_ch3', entity.EpochGroup(1:500, 'none'));
            b.addFeatureGroup(1, 'Amp', 'Amplifier_ch4', entity.EpochGroup(1:500, 'none'));
            % validate leaf
            disp(' Merging tree ');
            obj.builder.append(b.dataStore, true);
            actual = obj.builder.getFeatureGroups(obj.treeIndices.ds1_rstar_0_01);
            obj.verifyEqual(actual.name, expectedFirstLeaf.name);
            
            actual = obj.builder.getFeatureGroups(obj.treeIndices.ds4_rstar_0_1);
            obj.verifyEqual(actual.name, expecteLastLeaf.name);
            
            % non leaf nodes
            actual = obj.builder.findFeatureGroup('Amp==Amplifier_ch3');
            obj.verifyEqual(actual.id, n + 2);
            actual = obj.builder.findFeatureGroup('Amp==Amplifier_ch4');
            obj.verifyEqual(actual.id, n + 3);
            
            obj.builder.getStructure().tostring() % print tree
        end
        
        function testBasicFeatureGroup(obj)
            import sa_labs.analysis.*;
             b = factory.AnalysisFactory.createFeatureBuilder('cell', 'ac2');
            % empty check
            obj.verifyFalse(b.isBasicFeatureGroup([]));
            id = b.addFeatureGroup(1, 'Amp', 'Amplifier_ch3', entity.EpochGroup(1:500, 'none'));
            
            obj.verifyTrue(b.isBasicFeatureGroup(b.getFeatureGroups(id)));
            id = b.addFeatureGroup(id, 'rstar', '0.01', entity.EpochGroup(1:500, 'none'));
            
            obj.verifyFalse(b.isBasicFeatureGroup(b.getFeatureGroups(1)));
            obj.verifyTrue(b.isBasicFeatureGroup(b.getFeatureGroups(id)));
            
            b = obj.builder;
            % array of nodes
            obj.verifyTrue(b.isBasicFeatureGroup(b.getFeatureGroups([obj.treeIndices.ds1_rstar_0_01, obj.treeIndices.ds4_rstar_0_1])));
            obj.verifyFalse(b.isBasicFeatureGroup(b.getFeatureGroups([obj.treeIndices.ds1_rstar_0_01, obj.treeIndices.ds4_rstar_0_1, obj.treeIndices.ds4])));
        end

    end
end

