classdef Analysis < handle
    
    properties (SetAccess = protected)
        identifier
        functionContext
        featureBuilder
        state
    end
    
    properties
        analysisProtocol
        log
    end
    
    properties(Abstract)
        mode
    end
    
    methods
        
        function obj = Analysis(protocol, recordingLabel)
            import sa_labs.analysis.*;
            obj.log = logging.getLogger(app.Constants.ANALYSIS_LOGGER);
            
            obj.state = app.AnalysisState.NOT_STARTED;
            obj.identifier = strcat(protocol.type, '-', recordingLabel);
            obj.analysisProtocol = protocol;
            obj.featureBuilder = factory.AnalysisFactory.createFeatureBuilder('class', protocol.featurebuilderClazz,...
                'name', 'analysis',...
                'value', obj.identifier);
            
            obj.log.debug(['protocol [ ' obj.identifier ' ] is initialized with builder [ ' class(obj.featureBuilder) ' ]' ]);
        end
        
        function service(obj)
            
            if isempty(obj.analysisProtocol)
                error('analysisProtocol is empty'); %TODO replace with exception
            end
            obj.state = sa_labs.analysis.app.AnalysisState.STARTED;
            obj.build();
            obj.log.debug(obj.featureBuilder.getStructure().tostring());
            obj.log.debug('started extracting features ...');
            obj.extractFeatures();
            obj.state = sa_labs.analysis.app.AnalysisState.COMPLETED;
            obj.log.debug('completed analysis ...');
        end
        
        function r = getResult(obj)
            r = obj.featureBuilder.dataStore;
        end
        
        function setEpochSource(obj, source) %#ok
            % will be overriden in the subclass
        end

        function device = getDeviceForGroup(obj, group)
            device = [];

            groups = obj.featureBuilder.findInBranch(group, 'devices');
            if ~ isempty(groups)
                device = groups(1).splitValue;
            end
        end

        function tf = isEpochGroupSplitByDevice(obj, epochGroup)
            tf = strcmpi(epochGroup.splitParameter, 'devices');
        end
        
        function addFeaturesToGroup(obj, groups, functions)
            [map, order] = obj.getFeaureGroupsByProtocol();
            keys = map.keys();
            parameters = keys(order);
            
            for i = numel(parameters) : -1 : 1
                parameter = parameters{i};
                epochGroups = map(parameter);
                valid = ismember({epochGroups.uuid}, {groups.uuid});

                if any(valid)
                    epochGroups = epochGroups(valid);
                    functionsStr = obj.analysisProtocol.addExtractorFunctions(parameter, functions);
                else
                    functionsStr = [];
                end
                
                if ~ isempty(epochGroups)
                    obj.log.debug(['feature extraction for [ ' parameter ' epochGroups id ' num2str([epochGroups.id]) ']']);
                    obj.delegateFeatureExtraction(functionsStr, epochGroups);
                end
            end
            
        end
    end
    
    methods (Access = protected)
        
        function extractFeatures(obj)
            [map, order] = obj.getFeaureGroupsByProtocol();
            keys = map.keys();
            parameters = keys(order);
            
            for i = numel(parameters) : -1 : 1
                parameter = parameters{i};
                functions = obj.analysisProtocol.getExtractorFunctions(parameter);
                epochGroups = map(parameter);
                
                if ~ isempty(epochGroups)
                    obj.log.debug(['feature extraction for [ ' parameter ' epochGroups id ' num2str([epochGroups.id]) ']']);
                    obj.delegateFeatureExtraction(functions, epochGroups);
                end
            end
        end
    end
    
    methods (Access = protected, Abstract)
        build(obj)
        getFeaureGroupsByProtocol(obj)
    end
    
    methods (Access = private)
        
        function delegateFeatureExtraction(obj, functions, epochGroups)
            
            for i = 1 : numel(functions)
                func = str2func(functions{i});
                try
                    for group = epochGroups
                        func(obj, group);
                    end
                    
                    obj.log.debug(['collecting features for function [ ' char(functions{i}) ' ]']);
                    keySet = epochGroups.getFeatureKey();
                    obj.featureBuilder.collect([epochGroups.id], keySet, keySet);
                catch exception
                    disp(getReport(exception, 'extended', 'hyperlinks', 'on'));
                    obj.log.error(exception.message);
                end
            end
            
            if isempty(functions)
                obj.log.debug('collecting child features as feature extractor functions are empty !');
                keySet = epochGroups.getFeatureKey();
                obj.featureBuilder.collect([epochGroups.id], keySet, keySet);
            end
        end
    end
end
