classdef OvationParserTest < matlab.unittest.TestCase
    
    properties
        skipTest = false
        skipMessage
        path
    end

    properties(Constant)
    	SQL_LITE_FILE = '022211B.auisql'
    	H5_FILE = '022211B.h5'
    end
    
    methods (TestClassSetup)
        function setSkipTest(obj)
            obj.path = [fileparts(which('test.m')) filesep 'fixtures' filesep 'parser' filesep];

            if ~ exist(obj.path, 'file')
                mkdir(obj.path)
            end

            if ~ exist([obj.path obj.SQL_LITE_FILE], 'file') && ~ exist([obj.path obj.H5_FILE], 'file')
                obj.skipTest = true;
            end
            obj.skipMessage = @(test)(['Skipping ' class(obj) '.' test ' ; '...
                obj.SQL_LITE_FILE ' and ' obj.H5_FILE...
                ' are not found in matlab path']);
        end
    end

    methods(Test)

        function testGetInstance(obj)
            if(obj.skipTest)
                disp(obj.skipMessage('testGetInstance'));
                return;
            end
            import sa_labs.analysis.*;

            ref = factory.ParserFactory.getInstance([obj.path obj.H5_FILE]);
            obj.verifyClass(ref, ?sa_labs.analysis.parser.OvationParser);
            obj.verifyEqual(ref.auisqlFile, [obj.path obj.SQL_LITE_FILE]);
            obj.verifyEqual(ref.h5file, [obj.path obj.H5_FILE]);
        end

        function testGetCellId(obj)
        	import sa_labs.analysis.factory.*;
            if(obj.skipTest)
                disp(obj.skipMessage('testGetCellId'));
                return;
            end
        	ref = ParserFactory.getInstance([obj.path obj.H5_FILE]);
        	obj.verifyEqual(ref.getCellId(), [1:10]);
        end
    end
end

