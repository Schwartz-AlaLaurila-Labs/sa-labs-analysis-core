classdef FeatureGroupTest < matlab.unittest.TestCase
    
   
    methods(Test)
         
        function testUpdate(obj)
            import sa_labs.analysis.*;

            group = entity.FeatureGroup('test', 'param');
            obj.verifyWarning(@()group.getFeatureData('none'), app.Exceptions.FEATURE_KEY_NOT_FOUND.msgId);
            obj.verifyError(@() group.getFeatureData({'none', 'other'}), app.Exceptions.MULTIPLE_FEATURE_KEY_PRESENT.msgId);

            % create a sample feature group
            featureGroup = entity.FeatureGroup('Child', 'param');
            newFeatureGroup = entity.FeatureGroup('Parent', 'param');
            
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitParameter', 'splitParameter'),'MATLAB:class:SetProhibited');
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitValue', 'splitValue'),'MATLAB:class:SetProhibited');
        end

        function testGetFeatureData(obj)
            
            import sa_labs.analysis.*;
            
            epochs = entity.EpochData.empty(0, 2);
            epochs(1) = entity.EpochData();
            epochs(1).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(1).responseHandle = @(arg) struct('quantity', [1:10]);
            epochs(1).addDerivedResponse('spikes', 1 : 5, 'Amp1');
            epochs(1).addDerivedResponse('spikes', 6 : 10, 'Amp2');

            epochs(2) = entity.EpochData();
            epochs(2).dataLinks = containers.Map({'Amp1', 'Amp2' }, {'response1', 'response2'});
            epochs(2).responseHandle = @(arg) struct('quantity', [11:20]);
            epochs(2).addDerivedResponse('spikes', 11 : 15, 'Amp1');
            epochs(2).addDerivedResponse('spikes', 16 : 20, 'Amp2');

            epochGroup = entity.EpochGroup([1,2], 'some filter', 'name', epochs);

            featureGroup = entity.FeatureGroup('test', 'param');
            featureGroup.device = 'Amp1';
            featureGroup.populateEpochResponseAsFeature(epochs);
            
            featureGroup.device = 'Amp2';
            featureGroup.populateEpochResponseAsFeature(epochs);
            
            obj.verifyEqual(featureGroup.getFeatureData('AMP1_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(featureGroup.getFeatureData('AMP2_EPOCH'), [(1:10)', (11:20)']);
            obj.verifyEqual(featureGroup.getFeatureData('AMP1_SPIKES'), [(1:5)', (11:15)']);
            obj.verifyEqual(featureGroup.getFeatureData('AMP2_SPIKES'), [(6:10)', (16:20)']);

        end
    end    
end