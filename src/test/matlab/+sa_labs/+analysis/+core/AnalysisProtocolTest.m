classdef AnalysisProtocolTest < matlab.unittest.TestCase
    
    properties
        lightStepStructure
        standardAnalysis
        log
    end
    
    methods
        function obj = AnalysisProtocolTest()
            fname = which('analysis.json');
            obj.lightStepStructure = loadjson(fname);
            fname = which('standard-analysis.json');
            obj.standardAnalysis = loadjson(fname);
            
            obj.log = logging.getLogger('test-logger');
        end
    end
    
    methods(Test)
        
        function testGetSplitParametersByPath(obj)
            protocol = struct();
            protocol.type = 'test-analysis';
            protocol.buildTreeBy = {'a', 'b, c, d', 'e, f', 'g, h, i'};
            
            p = sa_labs.analysis.core.AnalysisProtocol(protocol);
            obj.log.info('Template tree for visual validation : [ 1 -> a, 2 -> bcd, 3 -> ef, 4 -> ghi]');
            obj.log.info(p.toTree().tostring());
            
            obj.verifyEqual(p.numberOfPaths(), 18);
            
            v = p.getSplitParametersByPath(1);
            obj.verifyEqual(v, {'a', 'b', 'e', 'g'});
            v = p.getSplitParametersByPath(18);
            obj.verifyEqual(v, {'a', 'd', 'f', 'i'});
        end
        
        function testValidateSplitValues(obj)
            protocol = sa_labs.analysis.core.AnalysisProtocol(obj.lightStepStructure);
            obj.verifyEmpty(protocol.getSplitValue('unkown'));
            
            values = protocol.validateSplitValues('EpochGroup', 'empty');
            obj.verifyEqual(values, {'empty'});
            
            values = protocol.validateSplitValues('deviceStream', 'Amplifier_ch1');
            obj.verifyEqual(values, {'Amplifier_ch1'});
            
            values = protocol.validateSplitValues('deviceStream', {'Amplifier_ch1', 'Amplifier_ch2'});
            obj.verifyEqual(values, {'Amplifier_ch1'});
            
            expected = {'G1', 'G3'};
            values = protocol.validateSplitValues('grpEpochs',  {'G0', 'G1', 'G3', 'G5'});
            obj.verifyEqual(values, expected);
            
            expected = {'G3'};
            values = protocol.validateSplitValues('grpEpochs',  'G3');
            obj.verifyEqual(values, expected);
            
            handle = @() protocol.validateSplitValues('grpEpochs',  {'unknown'});
            obj.verifyError(handle, sa_labs.analysis.app.Exceptions.SPLIT_VALUE_NOT_FOUND.msgId);
            
            values = protocol.validateSplitValues('rstarMean', 1:5);
            obj.verifyEqual(values, 1:5);
            
            values = protocol.validateSplitValues('epochId', 1:3);
            obj.verifyEqual(values, 1:3);
            
            handle = @()protocol.validateSplitValues('epochId', 6);
            obj.verifyError(handle, sa_labs.analysis.app.Exceptions.SPLIT_VALUE_NOT_FOUND.msgId);
            
            values = protocol.validateSplitValues('epochId', 2:3);
            obj.verifyEqual(values, 2:3);
        end
        
        function testExtractorFunctions(obj)
            import sa_labs.analysis.*;
            protocol = struct();
            protocol.type = 'test-analysis';
            protocol.buildTreeBy = {'a', 'b, c, d', 'e, f', 'g, h, i'};
            
            protocol.a.featureExtractor = {@(a) disp(a), @(a) mean(a)};
            protocol.b.featureExtractor = {'@(a) disp(a)', '@(a) mean(a)'};
            protocol.c.featureExtractor = {@(a) disp(a), '@(a)mean(a)'};
            p = sa_labs.analysis.core.AnalysisProtocol(protocol);
            
            expected = {'@(a)disp(a)', '@(a)mean(a)'};
            
            obj.verifyEqual(p.getExtractorFunctions('a'), expected);
            obj.verifyEqual(p.getExtractorFunctions('b'), expected);
            obj.verifyEqual(p.getExtractorFunctions('c'), expected);
        end
        
        function testAddExtractorFunctions(obj)
            protocol = struct();
            protocol.type = 'test-analysis';
            protocol.buildTreeBy = {'a', 'b', 'c'};
            p = sa_labs.analysis.core.AnalysisProtocol(protocol);
            
            p.addExtractorFunctions('a', @(a)disp(a));
            obj.verifyEqual(p.getExtractorFunctions('a'), {'@(a)disp(a)'});
            
            p.addExtractorFunctions('a', @(a)mean(a));
            expected = {'@(a)disp(a)', '@(a)mean(a)'};
            obj.verifyEqual(p.getExtractorFunctions('a'), expected);
            
            p.addExtractorFunctions('a',  @(a) disp(a));
            obj.verifyEqual(p.getExtractorFunctions('a'), expected);
        end
        
        function testProtocols(obj)
            import sa_labs.analysis.*;
            
            % Light step analysis json
            
            protocol = core.AnalysisProtocol(obj.lightStepStructure);
            obj.verifyEqual(protocol.getExtractorFunctions('rstarMean'), {'MeanExtractor', 'spikeAmplitudeExtractor'});
            obj.verifyEmpty(protocol.getExtractorFunctions('unknown'));
            obj.verifyEqual(protocol.copyParameters, {'ndf', 'etc'});
            obj.verifyEqual(protocol.featurebuilderClazz, 'FeatureBuilder');
            obj.verifyEqual(protocol.getSplitParameters(), {'EpochGroup', 'deviceStream', 'grpEpochs', 'rstarMean', 'epochId'});
            
            % standard analysis json
            
            protocol = core.AnalysisProtocol(obj.standardAnalysis);
            [p, v] = protocol.getSplitParameters();
            obj.verifyEqual(p, {'displayName', 'textureAngle', 'RstarMean', 'barAngle', 'curSpotSize'});
            obj.verifyEqual(v, [1, 2, 2, 2, 2]);
            obj.verifyEqual(4,  protocol.numberOfPaths());
            obj.verifyEqual(protocol.featurebuilderClazz, 'sa_labs.analysis.core.FeatureTreeBuilder');
            v = protocol.getSplitParametersByPath(4);
            obj.verifyEqual(v, {'displayName', 'curSpotSize'});
            
            fname = app.App.getResource(app.Constants.FEATURE_DESC_FILE_NAME);
            obj.verifyNotEmpty(protocol.featureDescriptionFile);
            obj.verifyEqual(protocol.featureDescriptionFile, fname);
        end
        
    end
    
end

