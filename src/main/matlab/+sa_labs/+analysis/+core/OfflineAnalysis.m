classdef OfflineAnalysis < sa_labs.analysis.core.Analysis
    
    properties (Access = private)
        cellData
    end
    
    properties
        mode = sa_labs.analysis.core.AnalysisMode.OFFLINE_ANALYSIS;
    end
    
    properties (Constant)
        DEFAULT_ROOT_ID = 1;
    end
    
    methods
        
        function obj = OfflineAnalysis(analysisProtocol, recordingLabel)
            obj@sa_labs.analysis.core.Analysis(analysisProtocol, recordingLabel);
        end
        
        function setEpochSource(obj, cellData)
            obj.cellData = cellData;
        end
        
        function epochs = getEpochs(obj, featureGroup)
            epochs = obj.cellData.epochs(featureGroup.epochIndices);
        end

        function devices = getDeviceForGroup(obj, group)
            devices = getDeviceForGroup@sa_labs.analysis.core.Analysis(obj, group);
            
            if isempty(devices)
                obj.log.debug('Split parameter [devices] not found, hence trying cell data specfic device type');
                devices = obj.cellData.deviceType;
                if isempty(devices)
                    obj.log.error('Provide [devices] as split parameter (or) use amplifier specific cell data');
                end
            end
        end 
    end
    
    methods (Access = protected)
        
        function build(obj)
            data = obj.cellData;
            
            obj.log.info(['started building analysis for cell [ ' data.recordingLabel ' ] using  [ ' obj.identifier ' ]']);
            
            for pathIndex = 1 : obj.analysisProtocol.numberOfPaths()
                numberOfEpochs = numel(data.epochs);
                epochGroup = sa_labs.analysis.entity.EpochGroup(1 : numberOfEpochs, data.recordingLabel);
                parameters = obj.analysisProtocol.getSplitParametersByPath(pathIndex);
                obj.add(obj.DEFAULT_ROOT_ID, epochGroup, parameters);
            end
            obj.featureBuilder.curateDataStore();
            
            group = obj.featureBuilder.getFeatureGroups(obj.DEFAULT_ROOT_ID);
            group.setParameters(data.getPropertyMap());
            group.setParameters(struct('analysisProtocol', obj.analysisProtocol));
            
            obj.log.info(['End building analysis for cell [ ' data.recordingLabel ' ]']);
        end
        
        function [map, order] = getFeaureGroupsByProtocol(obj)
            p = obj.analysisProtocol.getSplitParameters();
            map = containers.Map();
            
            for i = 1 : numel(p)
                key = p{i};
                map(key) = obj.featureBuilder.findFeatureGroup(key);
            end
            [~, order] = ismember(p, map.keys);
        end
        
        function copyEpochParameters(obj, featureGroup)
            
            if ~ obj.featureBuilder.isPresent(featureGroup.id)
                obj.log.info(['FeatureGroup with name [ ' featureGroup.name ' ] does not have childrens']);
                return
            end
            
            if obj.featureBuilder.isBasicFeatureGroup(featureGroup)
                obj.setEpochParameters(featureGroup);
            end
            keySet = obj.cellData.getEpochKeysetUnion([featureGroup.epochIndices]);
            
            if isempty(keySet)
                obj.log.warn('keyset is empty, cannot percolate up epoch parameters');
                return
            end

            % validate parameters. It should percolate up only time when 'split
            % parameter' is 'devices' although it has multiple split values
            % Issue https://github.com/Schwartz-AlaLaurila-Labs/sa-labs-analysis-core/issues/5

            if obj.featureBuilder.didCollectParameters(featureGroup)
                
                ids = [featureGroup.id];
                obj.log.trace('collecting epoch parameters ...');
                obj.featureBuilder.collect(ids, keySet, keySet);

                obj.log.trace('collecting cell parameters ...');
                cellKeySet = obj.cellData.getPropertyMap().keys;
                obj.featureBuilder.collect([featureGroup.id], cellKeySet, cellKeySet);
            end
            
            if obj.isFeatureGroupSplitByDevice(featureGroup)
                obj.featureBuilder.disableFurtherCollect(featureGroup);
            end
        end
    end
    
    methods (Access = private)
        
        function add(obj, parentId, epochGroup, params)
            splitBy = params{1};
            data = obj.cellData;
            
            [epochValueMap, filter] = data.getEpochValuesMap(splitBy, epochGroup.epochIndices);
            
            if isempty(epochValueMap)
                obj.log.warn([' splitBy paramter [ ' splitBy ' ] is not found !']);
                return
            end
            splitValues = obj.getSplitValues(epochValueMap, splitBy);
                        
            % If it is the last node to be processed and it has no (or)
            % matching split values for constructing further branches,
            % then there is no point in having it in tree.
            % delete the parent node !
            
            if isempty(splitValues) && length(params) > 1 && parentId > obj.DEFAULT_ROOT_ID
                obj.featureBuilder.removeFeatureGroup(parentId);
            end
            
            for i = 1 : length(splitValues)
                splitValue = splitValues{i};
                epochIndices = epochValueMap(splitValue);
                
                if isempty(epochIndices)
                    obj.log.debug(['no epoch found for [ ' filter ' ]' ]);
                    continue
                end
                
                epochGroup = sa_labs.analysis.entity.EpochGroup(epochIndices, filter, splitValue);
                if ~ isempty(epochGroup)
                    [id, featureGroup] = obj.featureBuilder.addFeatureGroup(parentId, splitBy, splitValue, epochGroup);
                end
                
                if length(params) > 1
                    obj.add(id, epochGroup, params(2 : end));
                end
                obj.copyEpochParameters(featureGroup);
            end
        end
        
        function setEpochParameters(obj, featureGroups)
            data = obj.cellData;
            
            for i = 1 : numel(featureGroups)
                [p, v] = data.getParamValues(featureGroups(i).epochIndices);
                
                if isempty(p)
                    obj.log.warn(['no epoch parameter found for given node ' num2str(featureGroups(i).id)]);
                    continue;
                end
                featureGroups(i).setParameters(containers.Map(p, v));
                featureGroups(i).setParameters(data.getPropertyMap());
                obj.log.trace(['setting epoch parameter for ' featureGroups(i).name ]);
            end
        end
        
        function splitValues = getSplitValues(obj, epochValueMap, splitByParam)
            
            try
                splitValues = obj.analysisProtocol.validateSplitValues(splitByParam, epochValueMap.keys);
            catch exception
                identifier = sa_labs.analysis.app.Exceptions.SPLIT_VALUE_NOT_FOUND.msgId;
                if ~ strcmp(exception.identifier, identifier)
                    rethrow(exception);
                end
                obj.log.warn(exception.message);
                splitValues = [];
            end
        end
    end
end
