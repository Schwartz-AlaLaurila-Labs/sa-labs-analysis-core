classdef AnalysisProjectTest < matlab.unittest.TestCase
    

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