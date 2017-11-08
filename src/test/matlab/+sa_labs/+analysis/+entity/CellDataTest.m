classdef CellDataTest < matlab.unittest.TestCase
    
    properties
        seedGenerator
        epochs
    end
    
    methods (TestClassSetup)
        
        function prepareEpochData(obj)
            import sa_labs.analysis.entity.*;
            
            obj.seedGenerator = rng('default');
            noise = randn(100);
            keys = {'intensity', 'stimTime', 'epochTime'};
            obj.epochs = EpochData.empty(0, 100);
            factor = 1;
            
            for i = 1 : 100
                e = EpochData();
                
                if mod(i, 10) == 0
                    factor = factor + 1;
                end
                e.attributes = containers.Map(keys, {factor * 10,  [num2str(factor * 20) 'ms'], datetime});
                e.dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
                e.responseHandle = @(arg) noise;
                obj.epochs(i) = e;
            end
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
            indices = arrayfun(@(e) repmat(e, 1, 2), [1 : 10], 'UniformOutput', false);
            obj.verifyEqual(values, 10 * [indices{:}]);
            obj.verifyEqual(description, 'intensity');
            
            % double as value test by function handle
            [values, description] = cellData.getEpochValues(@(epoch) obj.intensity2Rstar(epoch), 1 : 5 : 100);
            obj.verifyEqual(values, 1e-2 * [indices{:}]);
            obj.verifyEqual(description, '@(epoch)obj.intensity2Rstar(epoch)');
            
            % string as value test
            [values, description] = cellData.getEpochValues('stimTime', 1 : 5 : 100);
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), [indices{:}]);
            obj.verifyEqual(values, expected);
            obj.verifyEqual(description, 'stimTime');
            
            [values, ~] = cellData.getEpochValues('unknown', 1 : 5 : 100);
            obj.verifyEmpty(values);
            
            % cell array of strings as value test
            handle = @(e) {'Amp1', 'Amp2', 'Amp3'};
            [values, description] = cellData.getEpochValues(handle, 1 : 5 : 100);
            obj.verifyEmpty(setdiff(values, {'Amp1', 'Amp2', 'Amp3'}));
            obj.verifyEqual(description, func2str(handle));
            
        end
        
        function testGetEpochValuesExcluded(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            epochs = cellData.epochs;
            excludedIndices = find(mod(0 : 90, 10) == 0);
            arrayfun(@(e) obj.setExcluded(e, true), epochs(excludedIndices));
            
            % scenario #1 - some excluded epochs
            [values, description] = cellData.getEpochValues('intensity', 1 : 5 : 100);
            obj.verifyEqual(values, 10 * [1 :10]);
            obj.verifyEqual(description, 'intensity');
            
            % double as value test by function handle
            [values, description] = cellData.getEpochValues(@(epoch) obj.intensity2Rstar(epoch), 1 : 5 : 100);
            obj.verifyEqual(values, 1e-2 * [1 :10]);
            obj.verifyEqual(description, '@(epoch)obj.intensity2Rstar(epoch)');
            
            % string as value test
            [values, description] = cellData.getEpochValues('stimTime', 1 : 5 : 100);
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), [1 : 10]);
            obj.verifyEqual(values, expected);
            obj.verifyEqual(description, 'stimTime');
            
            % scenario #2 - all excluded epochs
            
            [values, description] = cellData.getEpochValues('intensity', excludedIndices);
            obj.verifyEmpty(values);
            obj.verifyEqual(description, 'intensity');
            
            % double as value test by function handle
            [values, description] = cellData.getEpochValues(@(epoch) obj.intensity2Rstar(epoch), excludedIndices);
            obj.verifyEmpty(values);
            obj.verifyEqual(description, '@(epoch)obj.intensity2Rstar(epoch)');
            
            % string as value test
            [values, description] = cellData.getEpochValues('stimTime', excludedIndices);
            obj.verifyEmpty(values);
            obj.verifyEqual(description, 'stimTime');
            
            arrayfun(@(e) obj.setExcluded(e, false), epochs(excludedIndices));
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
        
        function testGetEpochValuesMapExcluded(obj)
            
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            epochs = cellData.epochs;
            excludedIndices = find(mod(0 : 90, 10) == 0);
            arrayfun(@(e) obj.setExcluded(e, true), epochs(excludedIndices));
            
            % secanrio #1 - some excluded epochs
            
            [map, description] = cellData.getEpochValuesMap('intensity', 1 : 5 : 100);
            intensities = sort(str2double(map.keys));
            obj.verifyEqual(intensities, (10 * [1: 10]));
            expected = reshape(1 : 5 : 100, 2, 10)';
            expectedColumn = 2;
            
            for i = 1: numel(intensities)
                key = num2str(intensities(i));
                obj.verifyEqual(map(key), expected(i, expectedColumn));
            end
            obj.verifyEqual(description, 'intensity');
            
            [map, ~] = cellData.getEpochValuesMap('unknown', 1 : 5 : 100);
            obj.verifyEmpty(map);
            
            % cell array of strings as value test
            handle = @(e) {'Amp1', 'Amp2', 'Amp3'};
            [values, description] = cellData.getEpochValuesMap(handle, 1 : 5 : 100);
            obj.verifyEmpty(setdiff(values.keys, {'Amp1', 'Amp2', 'Amp3'}));
            obj.verifyEqual(description, func2str(handle));
            
            % scenario #2 - all excluded epochs
            
            [map, ~] = cellData.getEpochValuesMap('intensity', excludedIndices);
            obj.verifyEmpty(map);
            
            [map, ~] = cellData.getEpochValuesMap('unknown', excludedIndices);
            obj.verifyEmpty(map);
            
            % cell array of strings as value test
            handle = @(e) {'Amp1', 'Amp2', 'Amp3'};
            [map, ~] = cellData.getEpochValuesMap(handle, excludedIndices);
            obj.verifyEmpty(map);
            
            arrayfun(@(e) obj.setExcluded(e, false), epochs(excludedIndices));
        end
        
        function testGetEpochKeysetUnion(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            keySet = cellData.getEpochKeysetUnion(1 : 5 : 100);
            obj.verifyEqual(keySet, {'epochTime', 'intensity', 'stimTime'});
            
            keySet = cellData.getEpochKeysetUnion();
            obj.verifyEqual(keySet, {'epochTime', 'intensity', 'stimTime'});
        end
        
        function testGetEpochKeysetUnionExcluded(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
                        
            epochs = cellData.epochs;
            excludedIndices = find(mod(0 : 90, 10) == 0);
            arrayfun(@(e) obj.setExcluded(e, true), epochs(excludedIndices));
            
            % secanrio #1 - all excluded epochs
            keySet = cellData.getEpochKeysetUnion(excludedIndices);
            obj.verifyEmpty(keySet);
            arrayfun(@(e) obj.setExcluded(e, false), epochs(excludedIndices));
        end
        
        function testGetNonMatchingParamValues(obj)
            import sa_labs.analysis.entity.*;
            cellData = CellData();
            cellData.epochs = obj.epochs;
            
            [params, values] = cellData.getNonMatchingParamValues({'intensity', 'epochTime'} ,1 : 5 : 100);
            obj.verifyEqual(params, {'stimTime'});
            
            obj.verifyLength(values{1}, 20);
            % get the first element (value corresponds to 'stimTime') from cell array
            actual = values{1};
            id = repmat(1: 1: 10, 2, 1);
            
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), id(:)');
            obj.verifyEqual(actual, expected);
            
            [params, values] = cellData.getNonMatchingParamValues({'intensity', 'stimTime', 'epochTime'});
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
                obj.verifyEqual(params, {'epochTime', 'intensity', 'stimTime'});
                obj.verifyLength(values{1}, 20);
                obj.verifyLength(values{2}, 20);
                obj.verifyLength(values{3}, 20);
                % test intensity values
                obj.verifyEqual(values{2}, (10 * id(:)'))
                % test again stimTime values
                obj.verifyEqual(values{3}, expected);
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
            obj.verifyEqual(params, {'epochTime', 'stimTime'});
            
            obj.verifyLength(values{2}, 10);
            % get the first element (value corresponds to 'stimTime') from cell array
            actual = values{2};
            id = 1 : 10;
            
            expected = arrayfun(@(i)cellstr([num2str(20 * i) 'ms' ]), id(:)');
            obj.verifyEqual(actual, expected);
            
            [params, values] = cellData.getUniqueNonMatchingParamValues({'epochTime', 'intensity', 'stimTime'});
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
                obj.verifyEqual(params, {'epochTime', 'intensity', 'stimTime'});
                obj.verifyLength(values{1}, 20);
                obj.verifyLength(values{2}, 10);
                % test intensity values
                obj.verifyEqual(values{2}, (10 * id(:)'))
                % test again stimTime values
                obj.verifyEqual(values{3}, expected);
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
            
            % Test experiment date, h5file, recordingLabel, cellType
            fname = which('dummy.txt');
            cellData = CellData();
            cellData.attributes = containers.Map({'h5File', 'recordingLabel'},...
                {fname, 'c1'});
            cellData.deviceType = 'Amp1';
            cellData.cellType = 'on-alpha';
            cellData.epochs = EpochData();
            cellData.epochs(1).attributes = containers.Map({'epochTime'}, {datetime()});
            
            obj.verifyEqual(cellData.experimentDate, datestr(datetime(), 'yyyy-mm-dd'));
            obj.verifyEqual(cellData.h5File, 'dummy');
            obj.verifyEqual(cellData.recordingLabel, 'dummyc1_Amp1');
            obj.verifyEqual(cellData.cellType, 'on-alpha');
        end
    end
    
    methods
        
        function setExcluded(obj, e, tf)
            e.excluded = tf;
        end
        
        function r_star = intensity2Rstar(obj, epoch)
            value = epoch.get('intensity');
            r_star = value * 1e-3;
        end
    end
end