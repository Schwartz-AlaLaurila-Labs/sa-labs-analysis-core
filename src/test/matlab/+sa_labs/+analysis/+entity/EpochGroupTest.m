classdef EpochGroupTest < matlab.unittest.TestCase
    
   
    methods(Test)
         
        function testUpdate(obj)
            import sa_labs.analysis.*;

            group = entity.EpochGroup('test', 'param');
            obj.verifyWarning(@()group.getFeatureData('none'), app.Exceptions.FEATURE_KEY_NOT_FOUND.msgId);
            obj.verifyError(@() group.getFeatureData({'none', 'other'}), app.Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.msgId);

            % create a sample feature group
            epochGroup = entity.EpochGroup('Child', 'param');
            newEpochGroup = entity.EpochGroup('Parent', 'param');
            
            obj.verifyError(@()newEpochGroup.update(epochGroup, 'splitParameter', 'splitParameter'),'MATLAB:class:SetProhibited');
            obj.verifyError(@()newEpochGroup.update(epochGroup, 'splitValue', 'splitValue'),'MATLAB:class:SetProhibited');
        end

        function testGetFeatureData(obj)
            
            import sa_labs.analysis.*;
            
            epochs = entity.EpochData.empty(0, 2);
            epochs(1) = entity.EpochData();
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(1).responseHandle = @(arg) struct('quantity', [1:10]);
            epochs(1).addDerivedResponse('spikes', 1 : 5, 'Amp1');
            epochs(1).addDerivedResponse('spikes', 1 : 8, 'Amp2');

            epochs(2) = entity.EpochData();
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(2).responseHandle = @(arg) struct('quantity', [11:20]);
            epochs(2).addDerivedResponse('spikes', 1 : 3, 'Amp1');
            epochs(2).addDerivedResponse('spikes', 1 : 6, 'Amp2');

            epochGroup = entity.EpochGroup('test', 'param');
            epochGroup.device = 'Amp1';
            epochGroup.populateEpochResponseAsFeature(epochs);
            obj.verifyEqual(epochGroup.getFeatureData('AMP1_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(epochGroup.getFeatureData('AMP1_SPIKES'), {(1:5)', (1:3)'});
            
            epochGroup.device = 'Amp2';
            epochGroup.populateEpochResponseAsFeature(epochs);
            obj.verifyEqual(epochGroup.getFeatureData('AMP2_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(epochGroup.getFeatureData('AMP2_SPIKES'), {(1:8)', (1:6)'});
            
            epochGroup.device = '';
            % epochs are of same size
            obj.verifyEqual(epochGroup.getFeatureData('EPOCH'),...
                 {[(1:10)', (11:20)'],...  % belongs to first epoch
                  [(1:10)', (11:20)']});   % belongs to second epoch

            % spikes are of different size
            obj.verifyEqual(epochGroup.getFeatureData('SPIKES'),...
                 { (1:5)', (1:8)';...
                   (1:3)', (1:6)' });
        end
    end    
end