classdef FeatureTest < matlab.unittest.TestCase
    
    % Test methods for Feature, FeatureDescription
    
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
            obj.verifyEqual(feature.data, {(1 : 10)'});
            
            description.downSampleFactor = 2;
            obj.verifyEqual(feature.data, {(1 : 2 : 10)'});
            
            % verify cell array
            expected = {'abc', 'def'};
            feature = entity.Feature(description, expected);
            obj.verifyEqual(feature.data, {expected'});
        end
        
    end
    
end