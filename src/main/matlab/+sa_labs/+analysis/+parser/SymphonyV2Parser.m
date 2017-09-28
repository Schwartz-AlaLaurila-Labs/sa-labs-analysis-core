classdef SymphonyV2Parser < sa_labs.analysis.parser.SymphonyParser
    
    % experiement (1)
    %   |__devices (1)
    %   |__epochGroups (2)
    %       |_epochGroup-uuid
    %           |_epochBlocks (1)
    %               |_<protocol_class>-uuid (1) #protocols
    %                   |_epochs (1)
    %                   |   |_epoch-uuid (1)    #h5EpochLinks
    %                   |      |_background (1)
    %                   |      |_protocolParameters (2)
    %                   |      |_responses (3)
    %                   |        |_<device>-uuid (1)
    %                   |            |_data (1)
    %                   |_protocolParameters(2)
    
    properties
        cellDataArray
    end
    
    methods
        
        function obj = SymphonyV2Parser(fname)
            obj = obj@sa_labs.analysis.parser.SymphonyParser(fname);
        end
        
        function obj = parse(obj)
            import sa_labs.analysis.*;
            
            epochsByCellMap = obj.getEpochsByCellLabel(obj.info.Groups(1).Groups(2).Groups);
            sourceLinks = obj.info.Groups(1).Groups(5).Links;
            sourceTree = tree();
            
            tic;
            for i = 1 : numel(sourceLinks)
                sourceTree = sourceTree.graft(1, obj.buildSourceTree(sourceLinks(i).Value{:}));
            end
            elapsedTime = toc;
            obj.log.debug(['Generating source tree in [ ' num2str(elapsedTime) ' s ]' ]);
            
            numberOfClusters = numel(epochsByCellMap.keys);
            cells = entity.CellData.empty(0, numberOfClusters);
            labels = epochsByCellMap.keys;
            
            for i = 1 : numberOfClusters
                h5epochs =  epochsByCellMap(labels{i});
                tic;
                cluster = obj.buildCellData(labels{i}, h5epochs);
                cluster.attributes = obj.getSourceAttributes(sourceTree, labels{i}, cluster.attributes);
                
                for device = each(unique(cluster.getEpochValues('devices')))
                    cell = entity.CellData();
                    cell.attributes = cluster.attributes;
                    cell.epochs = cluster.epochs;
                    cell.attributes('recordingLabel') =  strcat(cell.attributes('recordingLabel'), '_', device);
                    cells(end + 1) = cell;  %#ok <AGROW> Amplifer specific cell data
                end
                cells(end + 1) = cluster;  %#ok <AGROW> All the amplifier grouped in one cell data
            end
            obj.cellDataArray = cells;
        end
        
        function d = getResult(obj)
            d = obj.cellDataArray;
        end
        
        function eyeIndex = getEyeIndex(~, location)
            if strcmpi(location, 'left')
                eyeIndex = -1;
            elseif strcmpi(location, 'right')
                eyeIndex = 1;
            end
        end
        
        function cell = buildCellData(obj, label, h5Epochs)
            import sa_labs.analysis.constants.*;
            import sa_labs.analysis.*;
            
            cell = entity.CellData();
            
            epochsTime = arrayfun(@(epoch) h5readatt(obj.fname, epoch.Name, 'startTimeDotNetDateTimeOffsetTicks'), h5Epochs);
            [time, indices] = sort(epochsTime);
            sortedEpochTime = double(time - time(1)).* 1e-7;
            
            lastProtocolId = [];
            epochData = entity.EpochData.empty(numel(h5Epochs), 0);
            
            for i = 1 : numel(h5Epochs)
                
                index = indices(i);
                epochPath = h5Epochs(index).Name;
                [protocolId, name, protocolPath] = obj.getProtocolId(epochPath);
                
                if ~ strcmp(protocolId, lastProtocolId)
                    % start of new protocol
                    parameterMap = obj.buildAttributes(protocolPath);
                    name = strsplit(name, '.');
                    name = obj.convertDisplayName(name{end});
                    parameterMap('displayName') = name;
                    
                    % add epoch group properties to current prtoocol
                    % parameters
                    group = h5Epochs(index).Name;
                    endOffSet = strfind(group, '/epochBlocks');
                    try
                        parameterMap = obj.buildAttributes([group(1 : endOffSet) 'properties'], parameterMap);
                    catch e %#ok
                        obj.log.debug(['properties not found for protocol [ ' name ' ] having label [ ' label ' ]']);
                    end
                end
                lastProtocolId = protocolId;
                parameterMap = obj.buildAttributes(h5Epochs(index).Groups(2), parameterMap);
                parameterMap('epochNum') = i;
                parameterMap('epochStartTime') = sortedEpochTime(i);
                
                e = entity.EpochData();
                e.parentCell = cell;
                e.attributes = containers.Map(parameterMap.keys, parameterMap.values);
                e.dataLinks = obj.getResponses(h5Epochs(index).Groups(3).Groups);
                e.responseHandle = @(path) h5read(obj.fname, path);
                epochData(i) = e;
            end
            
            cell.attributes = containers.Map();
            cell.epochs = epochData;
            cell.attributes('Nepochs') = numel(h5Epochs);
            cell.attributes('symphonyVersion') = 2.0;
            cell.attributes('h5File') = obj.fname;
            cell.attributes('recordingLabel') =  ['c' char(regexp(label, '[0-9]+', 'match'))];
        end
        
        function epochGroupMap = getEpochsByCellLabel(obj, epochGroups)
            epochGroupMap = containers.Map();
            import sa_labs.analysis.util.collections.*;
            
            for i = 1 : numel(epochGroups)
                h5Epochs = flattenByProtocol(epochGroups(i).Groups(1).Groups);
                label = obj.getSourceLabel(epochGroups(i));
                epochGroupMap = addToMap(epochGroupMap, label, h5Epochs');
            end
            
            function epochs = flattenByProtocol(protocols)
                epochs = arrayfun(@(p) p.Groups(1).Groups, protocols, 'UniformOutput', false);
                idx = find(~ cellfun(@isempty, epochs));
                epochs = cell2mat(epochs(idx));
            end
        end
        
        function label = getSourceLabel(obj, epochGroup)
            
            % check if it is h5 Groups
            % if not present it should be in links
            if numel(epochGroup.Groups) >= 4
                source = epochGroup.Groups(end).Name;
            else
                source = epochGroup.Links(2).Value{:};
            end
            try
                label = h5readatt(obj.fname, source, 'label');
            catch
                source = epochGroup.Links(2).Value{:};
                label = h5readatt(obj.fname, source, 'label');
            end
        end
        
        function attributeMap = buildAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            attributeMap = obj.mapAttributes(h5group, map);
        end
        
        function sourceTree = buildSourceTree(obj, sourceLink, sourceTree, level)
            % The most time consuming part while parsing the h5 file

            if nargin < 3
                sourceTree = tree();
                level = 0;
            end
            sourceGroup = h5info(obj.fname, sourceLink);
            
            label = h5readatt(obj.fname, sourceGroup.Name, 'label');
            map = containers.Map();
            map('label') = label;
            
            sourceProperties = [sourceGroup.Name '/properties'];
            map = obj.mapAttributes(sourceProperties, map);
            
            sourceTree = sourceTree.addnode(level, map);
            level = level + 1;
            childSource = h5info(obj.fname, [sourceGroup.Name '/sources']);
            
            for i = 1 : numel(childSource.Groups)
                sourceTree = obj.buildSourceTree(childSource.Groups(i).Name, sourceTree, level);
            end
        end
        
        function [id, name, path] = getProtocolId(~, epochPath)
            
            indices = strfind(epochPath, '/');
            id = epochPath(indices(end-2) + 1 : indices(end-1) - 1);
            path = [epochPath(1 : indices(end-1) - 1) '/protocolParameters'] ;
            nameArray = strsplit(id, '-');
            name = nameArray{1};
        end
        
        function map = getResponses(~, responseGroups)
            map = containers.Map();
            
            for i = 1 : numel(responseGroups)
                devicePath = responseGroups(i).Name;
                indices = strfind(devicePath, '/');
                id = devicePath(indices(end) + 1 : end);
                deviceArray = strsplit(id, '-');
                
                name = deviceArray{1};
                path = [devicePath, '/data'];
                map(name) = path;
            end
        end
        
        function map = getSourceAttributes(~, sourceTree, label, map)
            import sa_labs.analysis.util.collections.*;
            id = find(sourceTree.treefun(@(node) ~isempty(node) && strcmp(node('label'), label)));
            
            while id > 0
                currentMap = sourceTree.get(id);
                id = sourceTree.getparent(id);
                
                if isempty(currentMap)
                    continue;
                end
                
                keys = currentMap.keys;
                for i = 1 : numel(keys)
                    k = keys{i};
                    map = addToMap(map, k, currentMap(k));
                end
            end
        end
        
    end
    
end

