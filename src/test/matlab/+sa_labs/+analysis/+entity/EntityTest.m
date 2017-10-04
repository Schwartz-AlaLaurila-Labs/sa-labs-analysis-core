classdef EntityTest < matlab.unittest.TestCase
    
    % Test methods for Feature, FeatureDescription and Analysis project
    
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