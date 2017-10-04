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
    
end