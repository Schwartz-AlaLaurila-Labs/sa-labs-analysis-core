classdef OnlineAnalysis < sa_labs.analysis.core.Analysis
    
    properties (Access = protected, Transient)
        epochStream
        splitParameters
        nodeId
        runningEpochId
    end
    
    properties (SetAccess = private)
        nodeIdMap
    end

    properties
        mode = sa_labs.analysis.core.AnalysisMode.ONLINE_ANALYSIS;
    end
    
    methods
        
        function obj = OnlineAnalysis(analysisProtocol, recordingLabel)
            obj@sa_labs.analysis.core.Analysis(analysisProtocol, recordingLabel);
            obj.runningEpochId = 0;
        end
        
        function setEpochSource(obj, epoch)
            obj.state = sa_labs.analysis.app.AnalysisState.PROCESSING_STREAMS;
            obj.epochStream = epoch;
            obj.runningEpochId = obj.runningEpochId + 1;
            obj.log.debug(['started processing epoch stream id [ ' num2str(obj.runningEpochId) ' ]']);
        end

        function epochs = getEpochs(obj, epochGroup) %#ok
            epochs = obj.epochStream;
        end
    end
    
    methods (Access = protected)
        
        function build(obj)
            obj.nodeIdMap = containers.Map();

            epochParameters = obj.epochStream.parameters;
            obj.splitParameters = obj.getSplitParametersByEpoch();

            obj.nodeId = 1;
            present = true;

            for depth = 1 : numel(obj.splitParameters)
                
                splitParameter = obj.splitParameters{depth};
                splitValue = epochParameters(splitParameter);
                name = [splitParameter '==' num2str(splitValue)];
                
                % possible bottle neck if nodes are > 100,000 on first
                % pause
                id = obj.featureBuilder.findEpochGroupId(name, obj.nodeId);
                if isempty(id)
                    present = false;
                    break;
                end
                obj.nodeId = id;
                obj.nodeIdMap(splitParameter) = id;
            end
            
            if ~ present
                obj.add(obj.splitParameters(depth : end));
            end
        end
        
        function [map, order] = getFeaureGroupsByProtocol(obj)
            p = obj.splitParameters;
            map = containers.Map();
            order = [];
            
            for i = 1 : numel(p)
                key = p{i};
                id = obj.nodeIdMap(key);
                epochGroup = obj.featureBuilder.getEpochGroups(id);
                obj.log.trace([' id ' num2str(id) ' parameter ' key]);
                map(key) = epochGroup;
            end
            if isempty(p)
                return
            end
            [~ , order] = ismember(p, map.keys);
        end

        function copyEpochParameters(obj, nodes)
            keySet = obj.epochStream.parameters.keys;
            
            if ~ obj.featureBuilder.isBasicEpochGroup(nodes)
                obj.featureBuilder.collect([nodes.id], keySet, keySet);
                return
            end

            if isempty(nodes(1).parameters)
                nodes(1).setParameters(obj.epochStream.parameters);
                nodes(1).appendParameter('runningEpochId', obj.runningEpochId);
                return
            end 
            nodes(1).setParameters(obj.epochStream.parameters);
            obj.log.debug('collecting epoch parameters ...');
        end
    end
    
    methods (Access = private)
        
        function p = getSplitParametersByEpoch(obj)
            p = [];
            epochParameters = obj.epochStream.parameters;
            
            for pathIndex = 1 : obj.analysisProtocol.numberOfPaths()
                parameters = obj.analysisProtocol.getSplitParametersByPath(pathIndex);
                if all(ismember(parameters, epochParameters.keys))
                    p = parameters;
                    break;
                end
            end
        end
        
        function add(obj, parameters)
            EMPTY_EPOCH_INDEX = [];
            epochParameters = obj.epochStream.parameters;
            
            for i = 1 : numel(parameters)
                splitBy = parameters{i};
                splitValue = epochParameters(splitBy);
                obj.nodeId = obj.featureBuilder.addEpochGroup(obj.nodeId, splitBy, splitValue, EMPTY_EPOCH_INDEX);
                
                % update node map
                obj.nodeIdMap(splitBy) = obj.nodeId;
            end
        end
    end
end

