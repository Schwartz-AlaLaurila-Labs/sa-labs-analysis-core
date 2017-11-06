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
        
        function epochs = getEpochs(obj, epochGroup)
            epochs = obj.cellData.epochs(epochGroup.epochIndices);
        end

        function devices = getDeviceForGroup(obj, group)
            devices = getDeviceForGroup@sa_labs.analysis.core.Analysis(obj, group);
            
            if isempty(devices)
                obj.log.debug('Split parameter [devices] not found, hence trying cell data specfic device type');
                devices = obj.cellData.deviceType;
                if isempty(devices)
                    obj.log.warn(['No parent with [devices] as split parameter found for group [ ' group.name ' ]']);
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
                parameters = obj.analysisProtocol.getSplitParametersByPath(pathIndex);
                obj.add(obj.DEFAULT_ROOT_ID, 1 : numberOfEpochs, parameters);
            end
            obj.featureBuilder.curateDataStore();
            
            group = obj.featureBuilder.getEpochGroups(obj.DEFAULT_ROOT_ID);
            group.setParameters(data.getPropertyMap());
            group.setParameters(struct('analysisProtocol', obj.analysisProtocol));
            
            obj.log.info(['End building analysis for cell [ ' data.recordingLabel ' ]']);
        end
        
        function [map, order] = getFeaureGroupsByProtocol(obj)
            p = obj.analysisProtocol.getSplitParameters();
            map = containers.Map();
            
            for i = 1 : numel(p)
                key = p{i};
                map(key) = obj.featureBuilder.findEpochGroup(key);
            end
            [~, order] = ismember(p, map.keys);
        end
        
        function copyEpochParameters(obj, epochGroup)
            
            if ~ obj.featureBuilder.isPresent(epochGroup.id)
                obj.log.info(['EpochGroup with name [ ' epochGroup.name ' ] does not have childrens']);
                return
            end
            
            if obj.featureBuilder.isBasicEpochGroup(epochGroup)
                obj.setEpochParameters(epochGroup);
            end
            keySet = obj.cellData.getEpochKeysetUnion([epochGroup.epochIndices]);
            
            if isempty(keySet)
                obj.log.warn('keyset is empty, cannot percolate up epoch parameters');
                return
            end

            % validate parameters. It should percolate up only when 'split
            % parameter' is 'devices' although it has multiple split values
            % Issue https://github.com/Schwartz-AlaLaurila-Labs/sa-labs-analysis-core/issues/5

            if obj.featureBuilder.didCollectEpochParameters(epochGroup)
                
                ids = [epochGroup.id];
                obj.log.trace('collecting epoch parameters ...');
                obj.featureBuilder.collect(ids, keySet, keySet);
            end

            if obj.featureBuilder.didCollectCellParameters(epochGroup)
                obj.log.trace('collecting cell parameters ...');
                cellKeySet = obj.cellData.getPropertyMap().keys;
                obj.featureBuilder.collect([epochGroup.id], cellKeySet, cellKeySet);
                obj.featureBuilder.disableFurtherCollectForCellParameter(epochGroup);
            end
            
            if obj.isEpochGroupSplitByDevice(epochGroup)
                obj.featureBuilder.disableFurtherCollectForEpochParameters(epochGroup);
            end
        end
    end
    
    methods (Access = private)
        
        function add(obj, parentId, epochIndices, params)
            splitBy = params{1};
            data = obj.cellData;
            
            [epochValueMap, filter] = data.getEpochValuesMap(obj.analysisProtocol.getValidSplitParameter(splitBy), epochIndices);
            
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
                obj.featureBuilder.removeEpochGroup(parentId);
            end
            
            for i = 1 : length(splitValues)
                splitValue = splitValues{i};
                epochIndices = epochValueMap(splitValue);
                
                if isempty(epochIndices)
                    obj.log.debug(['no epoch found for [ ' filter ' ]' ]);
                    continue
                end

                [id, epochGroup] = obj.featureBuilder.addEpochGroup(parentId, splitBy, splitValue, epochIndices);
                
                if length(params) > 1
                    obj.add(id, epochIndices, params(2 : end));
                end
                % Make sure the device is set to active amplifier channel.
                % Before copying the epoch parameters
                device = obj.getDeviceForGroup(epochGroup);
                epochGroup.device = device;
                obj.copyEpochParameters(epochGroup);
                obj.log.trace(['setting epoch parameter for ' epochGroup.name ' having device [ ' device ' ]']);
            end
        end
        
        function setEpochParameters(obj, epochGroups)
            data = obj.cellData;
            
            for i = 1 : numel(epochGroups)
                group = epochGroups(i);
                [p, v] = data.getParamValues(group.epochIndices);
                
                if isempty(p)
                    obj.log.warn(['no epoch parameter found for given node ' num2str(group.id)]);
                    continue;
                end
                % Set all the epoch parameters
                group.setParameters(containers.Map(p, v));
                group.setParameters(data.getPropertyMap());
                % Add all the epoch specific feature in the group
                group.populateEpochResponseAsFeature(data.epochs(group.epochIndices));
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
