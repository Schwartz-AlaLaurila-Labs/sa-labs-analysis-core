classdef EpochGroupTest < matlab.unittest.TestCase
    
   
    methods(Test)

        function testGetFeatureData(obj)

            import sa_labs.analysis.*;
            epochs = entity.EpochData.empty(0, 2);
            epochs(1) = entity.EpochData();
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(1).responseHandle = @(arg) [1:10];
            epochs(1).addDerivedResponse('spikes', 1 : 5, 'Amp1');
            epochs(1).addDerivedResponse('spikes', 6 : 10, 'Amp2');

            epochs(2) = entity.EpochData();
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(2).responseHandle = @(arg) [11:20];
            epochs(2).addDerivedResponse('spikes', 11 : 15, 'Amp1');
            epochs(2).addDerivedResponse('spikes', 16 : 20, 'Amp2');

            epochGroup = entity.EpochGroup([1,2], 'some filter', 'name', epochs);

            obj.verifyEqual(epochGroup.getFeatureData('AMP1_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(epochGroup.getFeatureData('AMP2_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(epochGroup.getFeatureData('AMP1_SPIKES'), [(1:5)', (11:15)']);
            obj.verifyEqual(epochGroup.getFeatureData('AMP2_SPIKES'), [(6:10)', (16:20)']);
        end
    end    
end