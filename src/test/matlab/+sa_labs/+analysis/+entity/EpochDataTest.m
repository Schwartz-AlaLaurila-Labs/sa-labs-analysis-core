classdef EpochDataTest < matlab.unittest.TestCase

    % Test methods for EpochData
    
    methods(Test)
        
        function testGet(obj)
            import sa_labs.analysis.entity.*;
            keys = {'double', 'string', 'cell', 'array'};
            values = {20, 'abc', {'abc', 'def', 'ghi'}, [1, 2, 3, 4, 5]};
            
            epochData = EpochData();
            epochData.attributes = containers.Map(keys, values);
            
            % arbitary test for attribute map
            obj.verifyEqual(epochData.get('double'), 20);
            obj.verifyEqual(epochData.get('string'), 'abc');
            obj.verifyEqual(epochData.get('cell'), {'abc', 'def', 'ghi'});
            obj.verifyEqual(epochData.get('array'), [1, 2, 3, 4, 5]);
            obj.verifyEmpty(epochData.get('unknown'));
        end
        
        function testGetParameters(obj)
        	import sa_labs.analysis.entity.*;

        	epochData = EpochData();
        	keys = {'chanMode', 'chan1Mode', 'chan2Mode'};
        	values = {'cell-attached', 'cell-attached', 'whole-cell'};
        	epochData.attributes = containers.Map(keys, values);

        	[actualKeys, actualValues] = epochData.getParameters('mode');
        	obj.verifyEmpty(setdiff(actualKeys, keys));
        	obj.verifyEmpty(setdiff(actualValues, values));
        end

        function testUnionAttributeKeys(obj)
        	import sa_labs.analysis.entity.*;
        	keys = {'double', 'string', 'cell', 'array'};
        	values = {20, 'abc', {'abc', 'def', 'ghi'}, [1, 2, 3, 4, 5]};
        	
        	epochData = EpochData();
        	epochData.attributes = containers.Map(keys, values);
        	keys{end + 1} = 'additional';

        	obj.verifyEqual(epochData.unionAttributeKeys(keys), sort(keys));
        	obj.verifyEqual(sort(epochData.unionAttributeKeys([])), sort(keys(1 : end-1)));        	
        end

        function testGetResponse(obj)
        	import sa_labs.analysis.entity.*;
        	epochData = EpochData();
        	epochData.dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
        	epochData.responseHandle = @(arg)strcat(arg, '-data');
            epochData.parentCell = CellData();

        	% test for epoch data specific behaviour
        	obj.verifyEqual(epochData.get('devices'), epochData.dataLinks.keys);
        	obj.verifyEqual(epochData.getResponse('Amp1'), 'response1-data');
        	obj.verifyError(@() epochData.getResponse('unknown'), 'device:notfound');
            
            epochData.parentCell.deviceType = 'Amp1';
            obj.verifyEqual(epochData.get('devices'), 'Amp1');
        end

        function testDerivedResponse(obj)
        	import sa_labs.analysis.entity.*;
			epochData = EpochData();
			epochData.dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
			epochData.responseHandle = @(arg)strcat(arg, '-data');
			epochData.parentCell = CellData();

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
end