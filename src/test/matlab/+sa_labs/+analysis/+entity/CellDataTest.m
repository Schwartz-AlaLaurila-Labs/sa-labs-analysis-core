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
end