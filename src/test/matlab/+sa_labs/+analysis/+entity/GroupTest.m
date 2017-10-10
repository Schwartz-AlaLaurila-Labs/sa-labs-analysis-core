classdef GroupTest < matlab.unittest.TestCase
    

    methods(Test)
        
        function testGetFeature(obj)
            
            import sa_labs.analysis.entity.*;
            group = Group('test==param');
            property = containers.Map({'id', 'properties'}, {'TEST_FIRST', []});
            
            desc = FeatureDescription(property);
            f = Feature(desc);
            f.data = 1 : 1000;
            group.appendFeature(f);
            
            property = containers.Map({'id', 'properties'}, {'TEST_SECOND', []});
            desc2 = FeatureDescription(property);
            f = Feature(desc2);
            f.data = 1001 : 2000;
            group.appendFeature(f);
            
            features = group.getFeatures({'TEST_FIRST', 'TEST_FIRST'});
            obj.verifyEqual([features(:).data], (1 : 1000)');
            
            features = group.getFeatures({'TEST_FIRST', 'TEST_SECOND'});
            obj.verifyEqual([features(:).data], [(1 : 1000)', (1001 : 2000)']);
        end
        
        function testGetFeatureData(obj)
            import sa_labs.analysis.*;
            group = entity.Group('test==param');
            group.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            obj.verifyEqual(group.getFeatureData('TEST_FIRST'),(1 : 1000)');
            
            handle = @() group.createFeature('TEST_FIRST', ones(1000, 1), 'properties', []);
            obj.verifyWarning(handle, app.Exceptions.OVERWRIDING_FEATURE.msgId);
        end

        function testParameters(obj)
            import sa_labs.analysis.entity.*;
            group = Group('root=value');
            params = struct();
            params.preTime = '500ms';
            params.epochId = {1,2};
            
            group.setParameters([]);
            obj.verifyEmpty(group.attributes);
            
            group.setParameters(params);
            obj.verifyEqual(group.toStructure(), params);
            
            % combination of map and struct in setParameters
            group.setParameters(containers.Map({'stimTime', 'tailTime'}, {'500ms', '500ms'}));
            params.stimTime = '500ms';
            params.tailTime = '500ms';
            obj.verifyEqual(group.toStructure, params);
            
            group.appendParameter('preTime', '20ms');
            group.appendParameter('epochId', 3);
            
            group.appendParameter('new', {'param1', 'param2'});
            
            obj.verifyEqual(group.get('epochId'), [1, 2, 3]);
            obj.verifyEqual(group.get('preTime'), {'500ms', '20ms'});
            obj.verifyEqual(group.get('new'), {'param1', 'param2'});
            obj.verifyEmpty(group.get('unknow'));
            
            group.appendParameter('new', {'param3', 'param4'});
            obj.verifyEqual(group.get('new'), {'param1', 'param2', 'param3', 'param4'});
            
            % append mixed data type with out error
            handle = @()group.appendParameter('epochId', '5');
            obj.verifyWarning(handle, 'mixedType:parameters');
            obj.verifyEqual(group.get('epochId'), {[1, 2, 3], '5'});
            
            % Testing 1d array in parameters
            group.appendParameter('array1d', 1 : 10);
            group.appendParameter('array1d', 11 : 30);
            group.appendParameter('array1d', 31 : 40);
            obj.verifyEqual(group.get('array1d'), 1 : 40);
        end
        
        function testFeature(obj)
            import sa_labs.analysis.entity.*;
            group = Group('root==param');
            group.createFeature('TEST_FIRST', []);
            feature = group.getFeatures('TEST_FIRST');
            
            obj.verifyEmpty(feature.data);
            
            % test append data
            feature.appendData(1 : 1000);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, (1 : 1000)');
            
            % check feature as reference object
            feature.data = feature.data + ones(1000, 1);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, (2 : 1001)');
            
            % scalar check
            feature.appendData(1002);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, (2 : 1002)');
            
            % vector check
            feature.appendData(1003 : 1010);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % adding same feature again shouldnot append to the feature map
            group.appendFeature(feature);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % function handle check
            feature.data = @() 5 * ones(1, 10);
            expected =  5 * ones(10, 1);
            obj.verifyEqual(group.getFeatures('TEST_FIRST').data, expected);
            
        end
        
        function testUpdate(obj)
            import sa_labs.analysis.entity.*;
            
            % create a sample feature group
            group = Group('Child==param');
            
            % create two features
            group.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            group.createFeature('TEST_SECOND', ones(1,1000), 'properties', []);
            
            % append some parameter to the feature group
            group.appendParameter('string', 'Foo bar');
            group.appendParameter('int', 8);
            group.appendParameter('cell', {'one', 'two'});
            
            newGroup = Group('Parent==param');
            
            newGroup.appendParameter('int', 1);
            newGroup.appendParameter('string', 'Foo bar');
            newGroup.appendParameter('cell', {'three', 'four'});
            
            newGroup.update(group, 'TEST_SECOND', 'TEST_SECOND');
            
            % feature map check
            obj.verifyEqual(newGroup.getFeatureKey(), { 'TEST_SECOND' });
            data = newGroup.getFeatureData('TEST_SECOND');
            obj.verifyEqual(data, ones(1000, 1));
            
            obj.verifyError(@()newGroup.update(group, 'TEST_FIRST', 'TEST_SECOND'), 'in:out:mismatch')
            
            % name(in) and parameter(out) check
            newGroup.update(group, 'name', 'cell');
            obj.verifyEqual(sort(newGroup.get('cell')), {'Child==param', 'four', 'three'});
            
            % parameter check
            newGroup.update(group, 'int', 'int');
            obj.verifyEqual(newGroup.get('int'), [1, 8]);
            newGroup.update(group, 'unknown', 'unknown');
            obj.verifyEmpty(newGroup.get('unknown'));
            
            % case 5 parameter with 1d=array
            group.appendParameter('array1d', 1 : 30);
            newGroup.update(group, 'array1d', 'array1d');
            
            group2 = Group('Child2==param2');
            group2.appendParameter('array1d', 31 : 40);
            
            newGroup.update(group2, 'array1d', 'array1d');
            obj.verifyEqual(newGroup.get('array1d'), 1 : 40);
            
            % consistency check for old group
            obj.verifyEqual(group.getFeatureKey(), {'TEST_FIRST', 'TEST_SECOND'});
            features = group.getFeatures({'TEST_FIRST', 'TEST_SECOND'});
            obj.verifyEqual([features(:).data], [(1 : 1000)', ones(1000, 1)]);
        end
        
    end
    
end