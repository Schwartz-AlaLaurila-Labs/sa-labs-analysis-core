classdef FeatureGroupTest < matlab.unittest.TestCase
    
   
    methods(Test)
         
        function testUpdate(obj)
            import sa_labs.analysis.entity.*;
            
            % create a sample feature group
            featureGroup = FeatureGroup('Child', 'param');
            newFeatureGroup = FeatureGroup('Parent', 'param');
            
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitParameter', 'splitParameter'),'MATLAB:class:SetProhibited');
            obj.verifyError(@()newFeatureGroup.update(featureGroup, 'splitValue', 'splitValue'),'MATLAB:class:SetProhibited');
        end

        function testGetFeatureData(obj)

            import sa_labs.analysis.*;
            featureGroup = entity.FeatureGroup('test', 'param');

            %TODO test for get derived features
        end
    end    
end