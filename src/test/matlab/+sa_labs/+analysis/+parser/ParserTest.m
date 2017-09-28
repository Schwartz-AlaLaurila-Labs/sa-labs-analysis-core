classdef ParserTest < matlab.unittest.TestCase
    
    properties
        skipTest = false
        skipMessage
        path
    end
    
    properties(Constant)
        SYMPHONY_V1_FILE = 'symphony_v1.h5'
        SYMPHONY_V2_FILE = 'symphony_v2.h5'   % TODO replace with json or other format
        TEST_FILE = 'test.h5';
        SYMPHONY_2_EXP_FILE = '2017-09-27.h5';
    end
    
    methods (TestClassSetup)
        function setSkipTest(obj)
            obj.path = [fileparts(which('test.m')) filesep 'fixtures' filesep 'parser' filesep];

            if ~ exist(obj.path, 'file')
                mkdir(obj.path)
            end
            
            if ~ exist([obj.path obj.SYMPHONY_V1_FILE], 'file') && ~ exist([obj.path obj.SYMPHONY_V2_FILE], 'file')
                obj.skipTest = true;
            end
            obj.skipMessage = @(test)(['Skipping ' class(obj) '.' test ' ; '...
                obj.SYMPHONY_V1_FILE ' and ' obj.SYMPHONY_V2_FILE...
                ' are not found in matlab path']);
        end
    end
    
    
    methods(TestMethodTeardown)
        function deleteTestFile(obj)
            fname = [obj.path, obj.TEST_FILE];
            if exist(fname, 'file')
                delete(fname);
            end
        end
    end
    
    
    methods(Test)
        
        function testGetInstance(obj)
            if(obj.skipTest)
                disp(obj.skipMessage('testGetInstance'));
                return;
            end
            import sa_labs.analysis.*;
            
            ref = factory.ParserFactory.getInstance([obj.path obj.SYMPHONY_V1_FILE]);
            obj.verifyClass(ref, ?sa_labs.analysis.parser.SymphonyV1Parser);
            ref = factory.ParserFactory.getInstance([obj.path obj.SYMPHONY_V2_FILE]);
            obj.verifyClass(ref, ?sa_labs.analysis.parser.SymphonyV2Parser);
        end
        
        function testMapAttributes(obj)
            import sa_labs.analysis.*;
            
            % version 2 validation          
            fname = [obj.path obj.TEST_FILE];
            h5create(fname ,'/test' , [10 20]);
            h5writeatt(fname, '/', 'version', 2);
            h5writeatt(fname, '/', 'int', 1);
            h5writeatt(fname, '/', 'double', 1.2);
            h5writeatt(fname, '/', 'string', 'test');

            ref = factory.ParserFactory.getInstance(fname);
            map = ref.mapAttributes('/');
            obj.verifyEqual(sort(map.keys), {'double', 'int', 'string', 'version'});
            obj.verifyEqual(map.values, {1.2, 1, 'test', 2});
            
            % version 1 validation
            h5writeatt(fname, '/', 'version', 1);
            ref = factory.ParserFactory.getInstance(fname);
            info = hdf5info(fname);
            map = ref.mapAttributes(info.GroupHierarchy(1));
            obj.verifyEqual(sort(map.keys), {'double', 'int', 'string', 'version'});
            obj.verifyEqual(map.values, {1.2, 1, 'test', 1});
            
        end
        
        function testSymphonyParse(obj)
            if(obj.skipTest)
                disp(obj.skipMessage('testParse'));
                return;
            end
            import sa_labs.analysis.*;
            
            % Parse symphony_v2 file and validate
            fname = [obj.path obj.SYMPHONY_V2_FILE];
            ref = factory.ParserFactory.getInstance(fname);
            info = h5info(fname);
            epochValues = ref.getEpochsByCellLabel(info.Groups(1).Groups(2).Groups).values;
            epochs = epochValues{:};
            obj.verifyEqual(numel(epochs), 17);
            [~, name, ~] = ref.getProtocolId(epochs(1).Name);
            obj.verifyEqual(name, 'fi.helsinki.biosci.ala_laurila.protocols.LedPulse')
            validate('Amp1');
            
            % Parse symphony_v1 file and validate
            fname = [obj.path obj.SYMPHONY_V1_FILE];
            ref = factory.ParserFactory.getInstance(fname);
            validate('Amplifier_Ch1');
            
            function validate(amplifier)
                
                cellData = ref.parse().getResult();
                cellData = cellData(1) %#ok
                epochs = cellData.epochs;
                previousEpochTime = -1;
                
                for i = 1 : numel(epochs)
                    time = epochs(i).attributes('epochStartTime');
                    obj.verifyGreaterThan(time, previousEpochTime);
                    obj.verifyEqual(epochs(i).attributes('epochNum'), i);
                    previousEpochTime = time;
                end
                epoch = epochs(1) %#ok
                duration = epoch.attributes('preTime') + epoch.attributes('stimTime') + epoch.attributes('tailTime'); % (ms)
                samplingRate = epoch.attributes('sampleRate');
                data = epoch.getResponse(amplifier);
                obj.verifyEqual(numel(data.quantity), (duration / 10^3) * samplingRate);
            end
        end
        
        function testSymphony2Parse(obj)
            import sa_labs.analysis.*;
            fname = [obj.path obj.SYMPHONY_2_EXP_FILE];
            ref = factory.ParserFactory.getInstance(fname);
            result = ref.parse().getResult();
        end
    end
end

