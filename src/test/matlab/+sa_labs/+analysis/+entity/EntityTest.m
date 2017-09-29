classdef EntityTest < matlab.unittest.TestCase
    
    properties
        seedGenerator
        epochs
    end
    
    methods (TestClassSetup)
        
        function prepareEpochData(obj)
            import sa_labs.analysis.entity.*;
            
            obj.seedGenerator = rng('default');
            noise = randn(100);
            keys = {'intensity', 'stimTime'};
            obj.epochs = EpochData.empty(0, 100);
            factor = 1;
            
            for i = 1 : 100
                e = EpochData();
                
                if mod(i, 10) == 0
                    factor = factor + 1;
                end
                e.attributes = containers.Map(keys, {factor * 10,  [num2str(factor * 20) 'ms'] });
                e.dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
                e.responseHandle = @(arg) noise;
                obj.epochs(i) = e;
            end
        end
        
    end
    % Test methods for EpochData
    
    methods(Test)
        
        function testEpochData(obj)
            import sa_labs.analysis.entity.*;
            keys = {'double', 'string', 'cell', 'array'};
            values = {20, 'abc', {'abc', 'def', 'ghi'}, [1, 2, 3, 4, 5]};
            
            epochData = EpochData();
            epochData.attributes = containers.Map(keys, values);
            epochData.parentCell = CellData();
            epochData.dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochData.responseHandle = @(arg)strcat(arg, '-data');
            
            % arbitary test for attribute map
            obj.verifyEqual(epochData.get('double'), 20);
            obj.verifyEqual(epochData.get('string'), 'abc');
            obj.verifyEqual(epochData.get('cell'), {'abc', 'def', 'ghi'});
            obj.verifyEqual(epochData.get('array'), [1, 2, 3, 4, 5]);
            obj.verifyEmpty(epochData.get('unknown'));
            
            % test for epoch data behaviour
            obj.verifyEmpty(epochData.getParameters('mode'));
            obj.verifyEqual(epochData.get('devices'), epochData.dataLinks.keys);
            obj.verifyEqual(epochData.getResponse('Amp1'), 'response1-data');
            obj.verifyError(@() epochData.getResponse('unknown'), 'device:notfound');
            
            keys = {'chanMode', 'chan1Mode', 'chan2Mode'};
            values = {'cell-attached', 'cell-attached', 'whole-cell'};
            epochData.attributes = containers.Map(keys, values);
            [actualKeys, actualValues] = epochData.getParameters('mode');
            obj.verifyEmpty(setdiff(actualKeys, keys));
            obj.verifyEmpty(setdiff(actualValues, values));
            keys{end + 1} = 'unqiue';
            
            obj.verifyEqual(epochData.unionAttributeKeys(keys), sort(keys));
            obj.verifyEqual(sort(epochData.unionAttributeKeys([])), sort(keys(1 : end-1)));
            
            % Test for derived response
            epochData.addDerivedResponse('spikes', 1 : 5, 'Amp1');
            epochData.addDerivedResponse('spikes', 6 : 10, 'Amp2');
            obj.verifyEqual(epochData.getDerivedResponse('spikes', 'Amp1'), 1 : 5);
            obj.verifyEqual(epochData.getDerivedResponse('spikes', 'Amp2'), 6 : 10);

            obj.verifyError(@() epochData.addDerivedResponse('spikes', 1 : 5, 'unknown'), 'device:notfound');
            obj.verifyError(@() epochData.getDerivedResponse('spikes', 'unkonwn'), 'device:notfound');
            obj.verifyError(@() epochData.addDerivedResponse('spikes', 1 : 5), 'device:notfound');
            obj.verifyError(@() epochData.getDerivedResponse('spikes'), 'device:notfound');

            % Add the default deviceType and check for the spikes
            epochData.parentCell.deviceType = 'Amp1';
            epochData.addDerivedResponse('spikes', 11 : 15);            
            obj.verifyEqual(epochData.getDerivedResponse('spikes'), 11 : 15);
            obj.verifyEqual(epochData.getDerivedResponse('spikes', 'Amp2'), 6 : 10);
        end
        
    end
    
    % Test methods for CellData
    
    methods(Test)
        
        function testGetEpochValues(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            % double as value test
            [values, description] = cellData.getEpochValues('intensity', 1 : 5 : 100);
            obj.verifyEqual(unique(values), 10 * [1: 10]);
            obj.verifyEqual(description, 'intensity');
            
            % double as value test by function handle
            [values, description] = cellData.getEpochValues(@(epoch) intensity2Rstar(epoch), 1 : 5 : 100);
            obj.verifyEqual(unique(values), 1e-2 * [ 1: 10]);
            obj.verifyEqual(description, '@(epoch)intensity2Rstar(epoch)');
            
            % string as value test
            [values, description] = cellData.getEpochValues('stimTime', 1 : 5 : 100);
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), 1: 10);
            obj.verifyEqual(sort(unique(values)), sort(expected));
            obj.verifyEqual(description, 'stimTime');
            
            [values, ~] = cellData.getEpochValues('unknown', 1 : 5 : 100);
            obj.verifyEmpty(values);
            
            % cell array of strings as value test
            handle = @(e) {'Amp1', 'Amp2', 'Amp3'};
            [values, description] = cellData.getEpochValues(handle, 1 : 5 : 100);
            obj.verifyEmpty(setdiff(values, {'Amp1', 'Amp2', 'Amp3'}));
            obj.verifyEqual(description, func2str(handle));
            
            function r_star = intensity2Rstar(epoch)
                value = epoch.get('intensity');
                r_star = value * 1e-3;
            end
        end
        
        function testGetEpochValuesMap(obj)
            
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            [map, description] = cellData.getEpochValuesMap('intensity', 1 : 5 : 100);
            actual = sort(str2double(map.keys));
            obj.verifyEqual(actual, (10 * [1: 10]));
            expected = reshape(1 : 5 : 100, 2, 10)';
            
            for i = 1: numel(actual)
                key = num2str(actual(i));
                obj.verifyEqual(map(key), expected(i, :));
            end
            obj.verifyEqual(description, 'intensity');
            
            [map, ~] = cellData.getEpochValuesMap('unknown', 1 : 5 : 100);
            obj.verifyEmpty(map);
            
            % cell array of strings as value test
            handle = @(e) {'Amp1', 'Amp2', 'Amp3'};
            [values, description] = cellData.getEpochValuesMap(handle, 1 : 5 : 100);
            obj.verifyEmpty(setdiff(values.keys, {'Amp1', 'Amp2', 'Amp3'}));
            obj.verifyEqual(description, func2str(handle));
            
        end
        
        function testGetEpochKeysetUnion(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            keySet = cellData.getEpochKeysetUnion(1 : 5 : 100);
            obj.verifyEqual(keySet, {'intensity', 'stimTime'});
            
            keySet = cellData.getEpochKeysetUnion();
            obj.verifyEqual(keySet, {'intensity', 'stimTime'});
        end

        function testGetNonMatchingParamValues(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            [params, values] = cellData.getNonMatchingParamValues({'intensity'} ,1 : 5 : 100);
            obj.verifyEqual(params, {'stimTime'});
            
            obj.verifyLength(values{1}, 20);
            % get the first element (value corresponds to 'stimTime') from cell array
            actual = values{1};
            id = repmat(1: 1: 10, 2, 1);
            
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), id(:)');
            obj.verifyEqual(actual, expected);
            
            [params, values] = cellData.getNonMatchingParamValues({'intensity', 'stimTime'});
            obj.verifyEmpty(params);
            obj.verifyEmpty(values);
            
            % Test for getParamValues
            [params, values] = cellData.getNonMatchingParamValues([] ,1 : 5 : 100);
            verify();
            [params, values] = cellData.getNonMatchingParamValues({} ,1 : 5 : 100);
            verify();

            % Weired case
            [params, values] = cellData.getNonMatchingParamValues('unknown' ,1 : 5 : 100);
            verify();
            
            function verify()
                obj.verifyEqual(params, {'intensity', 'stimTime'});
                obj.verifyLength(values{1}, 20);
                obj.verifyLength(values{2}, 20);
                % test intensity values
                obj.verifyEqual(values{1}, (10 * id(:)'))
                % test again stimTime values
                obj.verifyEqual(values{2}, expected);
            end
            
            % Test for getParamValues
            [params, values] = cellData.getParamValues(1 : 5 : 100);
            verify();
        end

        function testGetUniqueNonMatchingParamValues(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            [params, values] = cellData.getUniqueNonMatchingParamValues({'intensity'} ,1 : 5 : 100);
            obj.verifyEqual(params, {'stimTime'});
            
            obj.verifyLength(values{1}, 10);
            % get the first element (value corresponds to 'stimTime') from cell array
            actual = values{1};
            id = 1 : 10;
            
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), id(:)');
            obj.verifyEqual(actual, expected);
            
            [params, values] = cellData.getUniqueNonMatchingParamValues({'intensity', 'stimTime'});
            obj.verifyEmpty(params);
            obj.verifyEmpty(values);
            
            % Test for getUniqueParamValues
            [params, values] = cellData.getUniqueNonMatchingParamValues([] ,1 : 5 : 100);
            verify();
            [params, values] = cellData.getUniqueNonMatchingParamValues({} ,1 : 5 : 100);
            verify();

            % Weired case
            [params, values] = cellData.getUniqueNonMatchingParamValues('unknown' ,1 : 5 : 100);
            verify();
            
            function verify()
                obj.verifyEqual(params, {'intensity', 'stimTime'});
                obj.verifyLength(values{1}, 10);
                obj.verifyLength(values{2}, 10);
                % test intensity values
                obj.verifyEqual(values{1}, (10 * id(:)'))
                % test again stimTime values
                obj.verifyEqual(values{2}, expected);
            end
            
            [params, values] = cellData.getUniqueParamValues(1 : 5 : 100);
            verify();
        end

        function testGet(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.attributes = containers.Map({'other', 'string'}, {'bla', 'test'});
            obj.verifyEqual(cellData.get('string'), 'test');
            obj.verifyEmpty(cellData.get('unknown'));
            obj.verifyEmpty(cellData.get([]));
        end
    end
    
    % Test methods for FeatureGroup
    
    methods(Test)
        
        
        function testParameters(obj)
            import sa_labs.analysis.entity.*;
            featureGroup = FeatureGroup('root','value');
            params = struct();
            params.preTime = '500ms';
            params.epochId = {1,2};
            
            featureGroup.setParameters([]);
            obj.verifyEmpty(featureGroup.parameters);
            
            featureGroup.setParameters(params);
            obj.verifyEqual(featureGroup.parameters, params);
            
            % combination of map and struct in setParameters
            featureGroup.setParameters(containers.Map({'stimTime', 'tailTime'}, {'500ms', '500ms'}));
            params.stimTime = '500ms';
            params.tailTime = '500ms';
            obj.verifyEqual(featureGroup.parameters, params);
            
            featureGroup.appendParameter('preTime', '20ms');
            featureGroup.appendParameter('epochId', 3);
            
            featureGroup.appendParameter('new', {'param1', 'param2'});
            
            obj.verifyEqual(featureGroup.getParameter('epochId'), [1, 2, 3]);
            obj.verifyEqual(featureGroup.getParameter('preTime'), {'500ms', '20ms'});
            obj.verifyEqual(featureGroup.getParameter('new'), {'param1', 'param2'});
            obj.verifyEmpty(featureGroup.getParameter('unknow'));
            
            featureGroup.appendParameter('new', {'param3', 'param4'});
            obj.verifyEqual(featureGroup.getParameter('new'), {'param1', 'param2', 'param3', 'param4'});
            
            % append mixed data type with out error
            handle = @()featureGroup.appendParameter('epochId', '5');
            obj.verifyWarning(handle, 'mixedType:parameters');
            obj.verifyEqual(featureGroup.getParameter('epochId'), {[1, 2, 3], '5'});
            
            % Testing 1d array in parameters
            featureGroup.appendParameter('array1d', 1 : 10);
            featureGroup.appendParameter('array1d', 11 : 30);
            featureGroup.appendParameter('array1d', 31 : 40);
            obj.verifyEqual(featureGroup.getParameter('array1d'), 1 : 40);
        end
        
        function testFeature(obj)
            import sa_labs.analysis.entity.*;
            featureGroup = FeatureGroup('root', 'param');
            featureGroup.createFeature('TEST_FIRST', []);
            feature = featureGroup.getFeatures('TEST_FIRST');
            
            obj.verifyEmpty(feature.data);
            
            % test append data
            feature.appendData(1 : 1000);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, (1 : 1000)');
            
            % check feature as reference object
            feature.data = feature.data + ones(1000, 1);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, (2 : 1001)');
            
            % scalar check
            feature.appendData(1002);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, (2 : 1002)');
            
            % vector check
            feature.appendData(1003 : 1010);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % adding same feature again shouldnot append to the feature map
            featureGroup.appendFeature(feature);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, (2 : 1010)');
            
            % function handle check
            feature.data = @() 5 * ones(1, 10);
            expected =  5 * ones(10, 1);
            obj.verifyEqual(featureGroup.getFeatures('TEST_FIRST').data, expected);
            
        end
        
        function testUpdate(obj)
            import sa_labs.analysis.entity.*;
            
            % create a sample feature group
            featureGroup = FeatureGroup('Child', 'param');
            
            % create two features
            featureGroup.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            featureGroup.createFeature('TEST_SECOND', ones(1,1000), 'properties', []);
            
            % append some parameter to the feature group
            featureGroup.appendParameter('string', 'Foo bar');
            featureGroup.appendParameter('int', 8);
            featureGroup.appendParameter('cell', {'one', 'two'});
            
            newFeatureGroup = FeatureGroup('Parent', 'param');
            
            newFeatureGroup.appendParameter('int', 1);
            newFeatureGroup.appendParameter('string', 'Foo bar');
            newFeatureGroup.appendParameter('cell', {'three', 'four'});
            
            newFeatureGroup.update(featureGroup, 'TEST_SECOND', 'TEST_SECOND');
            
            % case 1 property check
            featureGroup.epochIndices = [1,2,3];
            newFeatureGroup.update(featureGroup, 'epochIndices', 'epochIndices');
            obj.verifyEqual([newFeatureGroup.epochIndices{:}], [1, 2, 3]);
            
            % case 2 epochIndices(out) and parameter(in) check
            featureGroup.appendParameter('discardedEpoch', [4, 5, 6, 7]);
            newFeatureGroup.update(featureGroup, 'discardedEpoch', 'epochIndices');
            obj.verifyEqual([newFeatureGroup.epochIndices{:}], 1:7);
            
            % case 3 feature map check
            obj.verifyEqual(newFeatureGroup.featureMap.keys, { 'TEST_SECOND' });
            feature = newFeatureGroup.featureMap.values;
            obj.verifyEqual([feature{:}.data], ones(1000, 1));
            
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'TEST_FIRST', 'TEST_SECOND'), 'in:out:mismatch')
            
            % case 4 name(in) and parameter(out) check
            newFeatureGroup.update(featureGroup, 'name', 'cell');
            obj.verifyEqual(sort(newFeatureGroup.getParameter('cell')), {'Child==param', 'four', 'three'});
            
            % case 5 parameter check
            newFeatureGroup.update(featureGroup, 'int', 'int');
            obj.verifyEqual(newFeatureGroup.parameters.int, [1, 8]);
            newFeatureGroup.update(featureGroup, 'unknown', 'unknown');
            obj.verifyEmpty(newFeatureGroup.getParameter('unknown'));
            
            % case 5 parameter with 1d-array
            featureGroup.appendParameter('array1d', 1 : 30);
            newFeatureGroup.update(featureGroup, 'array1d', 'array1d');
            
            featureGroup2 = FeatureGroup('Child2', 'param2');
            featureGroup2.appendParameter('array1d', 31 : 40);
            
            newFeatureGroup.update(featureGroup2, 'array1d', 'array1d');
            obj.verifyEqual(newFeatureGroup.getParameter('array1d'), 1 : 40);
            
            % consistency check for old featureGroup
            obj.verifyEqual(featureGroup.featureMap.keys, {'TEST_FIRST', 'TEST_SECOND'});
            features = featureGroup.featureMap.values;
            features = [features{:}];
            obj.verifyEqual([features(:).data], [(1 : 1000)', ones(1000, 1)]);
            
            
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'name', 'name'),'MATLAB:class:SetProhibited');
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitParameter', 'splitParameter'),'MATLAB:class:SetProhibited');
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitValue', 'splitValue'),'MATLAB:class:SetProhibited');
        end
        
        function testGetFeature(obj)
            
            import sa_labs.analysis.entity.*;
            featureGroup = FeatureGroup('test', 'param');
            property = containers.Map({'id', 'properties'}, {'TEST_FIRST', []});
            
            desc = FeatureDescription(property);
            f = Feature(desc);
            f.data = 1 : 1000;
            featureGroup.appendFeature(f);
            
            property = containers.Map({'id', 'properties'}, {'TEST_SECOND', []});
            desc2 = FeatureDescription(property);
            f = Feature(desc2);
            f.data = 1001 : 2000;
            featureGroup.appendFeature(f);
            
            features = featureGroup.getFeatures({'TEST_FIRST', 'TEST_FIRST'});
            obj.verifyEqual([features(:).data], (1 : 1000)');
            
            features = featureGroup.getFeatures({'TEST_FIRST', 'TEST_SECOND'});
            obj.verifyEqual([features(:).data], [(1 : 1000)', (1001 : 2000)']);
        end
        
        function testGetFeatureData(obj)
            import sa_labs.analysis.*;
            featureGroup = entity.FeatureGroup('test', 'param');
            obj.verifyWarning(@()featureGroup.getFeatureData('none'), app.Exceptions.FEATURE_KEY_NOT_FOUND.msgId);
            obj.verifyError(@() featureGroup.getFeatureData({'none', 'other'}), app.Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.msgId);
            
            featureGroup.createFeature('TEST_FIRST', 1 : 1000, 'properties', []);
            obj.verifyEqual(featureGroup.getFeatureData('TEST_FIRST'),(1 : 1000)');
            
            handle = @() featureGroup.createFeature('TEST_FIRST', ones(1000, 1), 'properties', []);
            obj.verifyWarning(handle, app.Exceptions.OVERWRIDING_FEATURE.msgId);
            
            % TODO - test feature present as a parameter property
        end
    end
    
    % Test methods for Feature and FeatureDescription
    
    methods(Test)
        
        function testFeatureDescriptionInstance(obj)
            import sa_labs.analysis.*;
            
            propertyMap = containers.Map('id', 'FEATURE_ID');
            description = entity.FeatureDescription(propertyMap);
            obj.verifyEqual(description.id, 'FEATURE_ID');
            
            propertyMap('properties') = '"  param1 =   value1  , param2 =   value2   "';
            description = entity.FeatureDescription(propertyMap);
            obj.verifyEqual(description.param1, 'value1');
            obj.verifyEqual(description.param2, 'value2');
            
            propertyMap('properties') = '"1param = value2"';
            obj.verifyWarning(@() entity.FeatureDescription(propertyMap), 'MATLAB:ClassUstring:InvalidDynamicPropertyName');
            
            propertyMap('properties') = '"  param1 =   value2  , param2 "';
            description = obj.verifyWarning(@() entity.FeatureDescription(propertyMap), app.Exceptions.INVALID_PROPERTY_PAIR.msgId);
            obj.verifyEqual(description.param1, 'value2');
            
        end
        
        
        function testFeatureInstance(obj)
            import sa_labs.analysis.*;
            propertyMap = containers.Map('id', 'FEATURE_ID');
            description = entity.FeatureDescription(propertyMap);
            
            feature = entity.Feature(description, @() 1 : 10);
            obj.verifyEqual(feature.data, (1 : 10)');
            
            description.downSampleFactor = 2;
            obj.verifyEqual(feature.data, (1 : 2 : 10)');
            
            % verify vector
            feature.appendData(11 : 2 : 20);
            obj.verifyEqual(feature.data, (1 : 2 : 20)');
            
            % verify scalar
            feature.appendData(21);
            obj.verifyEqual(feature.data, (1 : 2 : 22)');
            
            % verify cell array
            expected = {'abc', 'def'};
            feature = entity.Feature(description, expected);
            obj.verifyEqual(feature.data, expected');
            
            feature.appendData({'ghi', 'jkl'});
            obj.verifyEqual(feature.data, {expected{:}, 'ghi', 'jkl'}');
            
            feature.appendData({'mno', 'pqr'}');
            obj.verifyEqual(feature.data, {expected{:}, 'ghi', 'jkl', 'mno', 'pqr'}');
        end
        
    end
    
    % Test methods for Analysis project
    
    methods(Test)
        
        function testAnalysisProject(obj)
            
            import sa_labs.analysis.*;
            p = entity.AnalysisProject();
            
            obj.verifyEmpty(p.experimentList);
            obj.verifyEmpty(p.cellDataIdList);
            obj.verifyEmpty(p.analysisResultIdList);

            p.addExperiments('20170325');
            obj.verifyEqual(p.experimentList, {'20170325'});

            p.addExperiments({'20170325', '20170324'});
            
            obj.verifyEqual(p.experimentList, {'20170325', '20170324'});
            
            p.addCellData('20170325Ac1', Mock(entity.CellData()));
            p.addCellData('20170324Ac2', Mock(entity.CellData()));
            p.addCellData('20170325Ac1', Mock(entity.CellData()));
            
            obj.verifyEmpty(setdiff(p.cellDataIdList, {'20170325Ac1', '20170324Ac2'}));
            obj.verifyLength(p.getCellDataArray(), 2);
            
            p.addResult('example-analysis-20170325Ac1', tree.example());
            p.addResult('example-analysis-20170325Ac2', tree.example());
            p.addResult('example-analysis1-20170325Ac1', tree.example());
            p.addResult('example-analysis1-20170325Ac2', tree.example());
            p.addResult('example-analysis-20170325Ac1', tree.example());
            
            obj.verifyEmpty(setdiff(p.analysisResultIdList, ...
                {'example-analysis-20170325Ac1', 'example-analysis-20170325Ac2',...
                'example-analysis1-20170325Ac1', 'example-analysis1-20170325Ac2'}));
            obj.verifyLength(p.getAnalysisResultArray(), 4);
            
            p.clearCellData();
            obj.verifyEmpty(p.getCellDataArray());
            
            p.clearAnalaysisResult();
            obj.verifyEmpty(p.getAnalysisResultArray());
        end
        
    end
    
    
end