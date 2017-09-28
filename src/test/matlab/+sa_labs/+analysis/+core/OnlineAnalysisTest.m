classdef OnlineAnalysisTest < matlab.unittest.TestCase
    
    properties
        mode = sa_labs.analysis.core.AnalysisMode.ONLINE_ANALYSIS;
    end
    
    methods(Test)
        
        function testBuildTreeSimple(obj)
            import sa_labs.analysis.*;
            
            % Expected tree for below test case :
            %                                                      test-analysis
            %                                                            |
            %                                                            |
            %                                                      stimTime==20
            %     +-----------+-----------+-----------+-----------+-----+-----+-----------+-----------+-----------+------------+
            %     |           |           |           |           |           |           |           |           |            |
            % rstar==100  rstar==200  rstar==300  rstar==400  rstar==500  rstar==600  rstar==700  rstar==800  rstar==900   rstar==1000
            
            structure = struct();
            structure.type = 'test-analysis';
            structure.buildTreeBy = {'stimTime', 'rstar'};
            structure.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            
            epoch = struct();
            parameterKey = {'preTime', 'stimTime', 'tailTime', 'chan1', 'rstar'};
            
            analysisProtocol = core.AnalysisProtocol(structure);
            analysis = core.OnlineAnalysis(analysisProtocol, 'identifier');
            
            for i = 1 : 10
                epoch.parameters = containers.Map(parameterKey, {300, 20, 500, 'Amp1', i * 100});
                analysis.setEpochSource(epoch)
                analysis.service();
                tree = analysis.getResult();
                obj.verifyEqual(analysis.nodeIdMap('stimTime'), 2);
                obj.verifyEqual(analysis.nodeIdMap('rstar'), 2 + i);
                obj.verifyEqual(tree.nnodes, 2 + i);
            end
            
            tree = analysis.getResult();
            
            % Expected tree for below test case :
            %
            %                                                                  test-analysis
            %                                                            +-----------+------------------------------------------------------------+
            %                                                            |                                                                        |
            %                                                      stimTime==20                                                             stimTime==500
            %     +-----------+-----------+-----------+-----------+-----+-----+-----------+-----------+-----------+------------+           +-----+------+
            %     |           |           |           |           |           |           |           |           |            |           |            |
            % rstar==100  rstar==200  rstar==300  rstar==400  rstar==500  rstar==600  rstar==700  rstar==800  rstar==900   rstar==1000 rstar==500   rstar==1000
            
            % interleaved epochs with stim time of 500
            for i = 1 : 10
                stimTime = 20;
                
                if mod(i, 5) == 0
                    stimTime = 500;
                end
                epoch.parameters = containers.Map(parameterKey, {300, stimTime, 500, 'Amp1', i * 100});
                
                analysis.setEpochSource(epoch)
                analysis.service();
                t = analysis.getResult();
                % TODO replace this with query manager
                
                node = core.FeatureTreeBuilder('name', 'root', t).findFeatureGroup(['stimTime==' num2str(stimTime)]);
                obj.verifyEqual(analysis.nodeIdMap('stimTime'), node.id);
            end
            tree = analysis.getResult();
            expectedNumberOfNodes = tree.nnodes;
            
            % TODO replace this with query manager
            nodes = core.FeatureTreeBuilder('name', 'root', tree).getImmediateChildrensByName('stimTime==500');
            expected = tree.findleaves();
            
            obj.verifyEqual(numel(nodes), 2)
            obj.verifyEqual(nodes(1).id, expected(end - 1));
            obj.verifyEqual(nodes(2).id, expected(end));
            
            % alternate case - 1 if all the epoch parameter is not present
            % in analysis template
            epoch.parameters = containers.Map({'param1', 'param2'}, {300, 500});
            analysis.setEpochSource(epoch)
            analysis.service();
            t = analysis.getResult();
            obj.verifyEqual(t.nnodes, expectedNumberOfNodes);
            
            % alternate case - 2 if any of the epoch parameter is present
            % in analysis template
            epoch.parameters = containers.Map({'stimTime', 'param2'}, {300, 500});
            analysis.setEpochSource(epoch)
            analysis.service();
            t = analysis.getResult();
            obj.verifyEqual(t.nnodes, expectedNumberOfNodes);
        end
        
        function testBuildTreeComplex(obj)
            import sa_labs.analysis.*;
            
            % Expected tree :
            %
            %                                                           complex-analysis
            %                      +-------------------------------------------++--------------------------------------------+
            %                      |                                            |                                            |
            %          protocol==driftingTexture                    protocol==driftingGrating                       protocol==movingBar
            %                      |                                            |                                            |
            %                      |                                            |                                            |
            %              textureAngle==10                             textureAngle==30                               barAngle==90
            %       +-------------++--------------+              +-------------++--------------+              +-------------++--------------+
            %       |              |              |              |              |              |              |              |              |
            % RstarMean==10  RstarMean==20  RstarMean==30  RstarMean==10  RstarMean==20  RstarMean==30  RstarMean==10  RstarMean==20  RstarMean==30
            
            % analysis template structure
            s = struct();
            s.type = 'complex-analysis';
            s.featureManager = 'sa_labs.analysis.core.FeatureTreeManager';
            s.buildTreeBy = {'protocol', 'textureAngle, barAngle, curSpotSize', 'RstarMean'};
            
            analysisProtocol = core.AnalysisProtocol(s);
            analysis = core.OnlineAnalysis(analysisProtocol, 'identifier');
            
            parameterKey1 = {'protocol', 'textureAngle', 'RstarMean'};
            parameterKey2 = {'protocol', 'textureAngle', 'RstarMean'};
            parameterKey3 = {'protocol', 'barAngle', 'RstarMean'};
            parameterKey4 = {'protocol', 'curSpotSize', 'RstarMean'};
            
            epochsInEachProtocol = 3;
            % validate for different RstarMean
            t = validate(parameterKey1, @(i) {'driftingTexture', 10, i * 10}, 1 + 5);
            t = validate(parameterKey2, @(i) {'driftingGrating', 30, i * 10}, t.nnodes + 5);
            t = validate(parameterKey3, @(i) {'movingBar', 90, i * 10}, t.nnodes + 5);
            
            logTree();
            
            % Expected tree :
            %                                                                                                                  complex-analysis
            %                               +--------------------------------------------------------------+---------------+--------------------------------------------+-----------------------------------------------+
            %                               |                                                              |                                                            |                                               |
            %                   protocol==driftingTexture                                      protocol==driftingGrating                                       protocol==movingBar                           protocol==spotMultiSize
            %                      +-------+----------------------+                               +-------+----------------------+                               +------+----------------------+               +--------+--------+
            %                      |                              |                               |                              |                               |                             |               |                 |
            %              textureAngle==10               textureAngle==20                textureAngle==30               textureAngle==60                  barAngle==90                  barAngle==180 curSpotSize==100  curSpotSize==200
            %       +-------------++--------------+                                +-------------++--------------+                                +-------------++--------------+              |
            %       |              |              |               |                |              |              |               |                |              |              |              |               |                 |
            % RstarMean==10  RstarMean==20  RstarMean==30   RstarMean==10    RstarMean==10  RstarMean==20  RstarMean==30   RstarMean==10    RstarMean==10  RstarMean==20  RstarMean==30  RstarMean==10   RstarMean==10     RstarMean==10
            
            epochsInEachProtocol = 2;
            
            % validate for different angle and size
            t = validate(parameterKey1, @(i) {'driftingTexture', i * 10, 10}, t.nnodes + 2);
            t = validate(parameterKey2, @(i) {'driftingGrating', i * 30, 10}, t.nnodes + 2);
            t = validate(parameterKey3, @(i) {'movingBar', i * 90, 10}, t.nnodes + 2);
            t = validate(parameterKey4, @(i) {'spotMultiSize', i * 100, 10}, t.nnodes + 5);
            
            logTree();
            
            function t = validate(k, valueSetHandle, expected)
                %disp(' [INFO] Awesome Breadth expansion ! ...')
                for i = 1 : epochsInEachProtocol
                    epoch.parameters = containers.Map(k, valueSetHandle(i));
                    analysis.setEpochSource(epoch)
                    analysis.service();
                    t = analysis.getResult();
                    %logTree()
                    %pause(1);
                end
                obj.verifyEqual(t.nnodes, expected)
            end
            
            function logTree()
                tree = analysis.getResult();
                disp('analysis tree')
                tree.treefun(@(node) strcat(node.name, [' ( ' num2str(node.id), ' ) '])).tostring()
            end
        end
    end
end
