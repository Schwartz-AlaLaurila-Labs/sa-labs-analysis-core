classdef AbstractGroupTest < matlab.unittest.TestCase
    

    methods(Test)
        
        function testParameters(obj)
            import sa_labs.analysis.entity.*;
            abstractGroup = AbstractGroup('root=value');
            params = struct();
            params.preTime = '500ms';
            params.epochId = {1,2};
            
            abstractGroup.setParameters([]);
            obj.verifyEmpty(abstractGroup.attributes);
            
            abstractGroup.setParameters(params);
            obj.verifyEqual(abstractGroup.toStructure(), params);
            
            % combination of map and struct in setParameters
            abstractGroup.setParameters(containers.Map({'stimTime', 'tailTime'}, {'500ms', '500ms'}));
            params.stimTime = '500ms';
            params.tailTime = '500ms';
            obj.verifyEqual(abstractGroup.toStructure, params);
            
            abstractGroup.appendParameter('preTime', '20ms');
            abstractGroup.appendParameter('epochId', 3);
            
            abstractGroup.appendParameter('new', {'param1', 'param2'});
            
            obj.verifyEqual(abstractGroup.get('epochId'), [1, 2, 3]);
            obj.verifyEqual(abstractGroup.get('preTime'), {'500ms', '20ms'});
            obj.verifyEqual(abstractGroup.get('new'), {'param1', 'param2'});
            obj.verifyEmpty(abstractGroup.get('unknow'));
            
            abstractGroup.appendParameter('new', {'param3', 'param4'});
            obj.verifyEqual(abstractGroup.get('new'), {'param1', 'param2', 'param3', 'param4'});
            
            % append mixed data type with out error
            handle = @()abstractGroup.appendParameter('epochId', '5');
            obj.verifyWarning(handle, 'mixedType:parameters');
            obj.verifyEqual(abstractGroup.get('epochId'), {[1, 2, 3], '5'});
            
            % Testing 1d array in parameters
            abstractGroup.appendParameter('array1d', 1 : 10);
            abstractGroup.appendParameter('array1d', 11 : 30);
            abstractGroup.appendParameter('array1d', 31 : 40);
            obj.verifyEqual(abstractGroup.get('array1d'), 1 : 40);
        end
        
        function testFeature(obj)
            import sa_labs.analysis.entity.*;
            abstractGroup = AbstractGroup('root==param');
            abstractGroup.createFeature('TEST_FIRST', []);
            feature = abstractGroup.getFeatures('TEST_FIRST');
            
            obj.verifyEmpty(feature.data);
            
            % test append data
            feature.appendData(1 : 1000);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, (1 : 1000)');
            
            % check feature as reference object
            feature.data = feature.data + ones(1000, 1);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, (2 : 1001)');
            
            % scalar check
            feature.appendData(1002);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, (2 : 1002)');
            
            % vector check
            feature.appendData(1003 : 1010);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % adding same feature again shouldnot append to the feature map
            abstractGroup.appendFeature(feature);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % function handle check
            feature.data = @() 5 * ones(1, 10);
            expected =  5 * ones(10, 1);
            obj.verifyEqual(abstractGroup.getFeatures('TEST_FIRST').data, expected);
            
        end
        
        function testUpdate(obj)
            import sa_labs.analysis.entity.*;
            
            % create a sample feature group
            abstractGroup = AbstractGroup('Child==param');
            
            % create two features
            abstractGroup.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            abstractGroup.createFeature('TEST_SECOND', ones(1,1000), 'properties', []);
            
            % append some parameter to the feature group
            abstractGroup.appendParameter('string', 'Foo bar');
            abstractGroup.appendParameter('int', 8);
            abstractGroup.appendParameter('cell', {'one', 'two'});
            
            newAbstractGroup = AbstractGroup('Parent==param');
            
            newAbstractGroup.appendParameter('int', 1);
            newAbstractGroup.appendParameter('string', 'Foo bar');
            newAbstractGroup.appendParameter('cell', {'three', 'four'});
            
            newAbstractGroup.update(abstractGroup, 'TEST_SECOND', 'TEST_SECOND');
            
            % feature map check
            obj.verifyEqual(newAbstractGroup.getFeatureKey(), { 'TEST_SECOND' });
            data = newAbstractGroup.getFeatureData('TEST_SECOND');
            obj.verifyEqual(data, ones(1000, 1));
            
            obj.verifyError(@()newAbstractGroup.update(abstractGroup, 'TEST_FIRST', 'TEST_SECOND'), 'in:out:mismatch')
            
            % name(in) and parameter(out) check
            newAbstractGroup.update(abstractGroup, 'name', 'cell');
            obj.verifyEqual(sort(newAbstractGroup.get('cell')), {'Child==param', 'four', 'three'});
            
            % parameter check
            newAbstractGroup.update(abstractGroup, 'int', 'int');
            obj.verifyEqual(newAbstractGroup.get('int'), [1, 8]);
            newAbstractGroup.update(abstractGroup, 'unknown', 'unknown');
            obj.verifyEmpty(newAbstractGroup.get('unknown'));
            
            % case 5 parameter with 1d=array
            abstractGroup.appendParameter('array1d', 1 : 30);
            newAbstractGroup.update(abstractGroup, 'array1d', 'array1d');
            
            abstractGroup2 = AbstractGroup('Child2==param2');
            abstractGroup2.appendParameter('array1d', 31 : 40);
            
            newAbstractGroup.update(abstractGroup2, 'array1d', 'array1d');
            obj.verifyEqual(newAbstractGroup.get('array1d'), 1 : 40);
            
            % consistency check for old abstractGroup
            obj.verifyEqual(abstractGroup.getFeatureKey(), {'TEST_FIRST', 'TEST_SECOND'});
            features = abstractGroup.getFeatures({'TEST_FIRST', 'TEST_SECOND'});
            obj.verifyEqual([features(:).data], [(1 : 1000)', ones(1000, 1)]);
        end
        
        function testGetFeature(obj)
            
            import sa_labs.analysis.entity.*;
            abstractGroup = AbstractGroup('test==param');
            property = containers.Map({'id', 'properties'}, {'TEST_FIRST', []});
            
            desc = FeatureDescription(property);
            f = Feature(desc);
            f.data = 1 : 1000;
            abstractGroup.appendFeature(f);
            
            property = containers.Map({'id', 'properties'}, {'TEST_SECOND', []});
            desc2 = FeatureDescription(property);
            f = Feature(desc2);
            f.data = 1001 : 2000;
            abstractGroup.appendFeature(f);
            
            features = abstractGroup.getFeatures({'TEST_FIRST', 'TEST_FIRST'});
            obj.verifyEqual([features(:).data], (1 : 1000)');
            
            features = abstractGroup.getFeatures({'TEST_FIRST', 'TEST_SECOND'});
            obj.verifyEqual([features(:).data], [(1 : 1000)', (1001 : 2000)']);
        end
        
        function testGetFeatureData(obj)
            import sa_labs.analysis.*;
            abstractGroup = entity.AbstractGroup('test==param');
            obj.verifyWarning(@()abstractGroup.getFeatureData('none'), app.Exceptions.FEATURE_KEY_NOT_FOUND.msgId);
            obj.verifyError(@() abstractGroup.getFeatureData({'none', 'other'}), app.Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.msgId);
            
            abstractGroup.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            obj.verifyEqual(abstractGroup.getFeatureData('TEST_FIRST'),(1 : 1000)');
            
            handle = @() abstractGroup.createFeature('TEST_FIRST', ones(1000, 1), 'properties', []);
            obj.verifyWarning(handle, app.Exceptions.OVERWRIDING_FEATURE.msgId);
        end
    end
    
end