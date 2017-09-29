classdef SymphonyV1Parser < sa_labs.analysis.parser.SymphonyParser
    
    % cell-name.h5
    %   |_ <recorded_by>-<id> (1)
    %     |_epochgroups (1)
    %     |_epochs (2)
    %     |  |_epoch-<id> # epochDataGroups
    %     |       (DS) background
    %     |      |_ protocolParameters (1) epoch attributes
    %     |      |_ responses (2) epoch data links
    %     |         |_ Amplifier_Ch1
    %     |      |_ stimuli
    %     |
    %     |_properties (3) # cell data attributes

    methods
        
        function obj = SymphonyV1Parser(fname)
            obj = obj@sa_labs.analysis.parser.SymphonyParser(fname);
        end
        
        function obj = parse(obj)
            import sa_labs.analysis.*;
            
            data = entity.CellData();
            
            info = hdf5info(obj.fname);
            info = info.GroupHierarchy(1);
            data.attributes = obj.mapAttributes(info.Groups(1).Groups(3));
            n = length(info.Groups);
            
            EpochDataGroups = [];
            for i = 1 : n
                EpochDataGroups = [EpochDataGroups info.Groups(i).Groups(2).Groups]; %#ok
            end
            
            index = 1;
            epochTimes = [];
            for i = 1 : length(EpochDataGroups)
                
                if length(EpochDataGroups(i).Groups) >= 3 %Complete epoch
                    attributeMap = obj.mapAttributes(EpochDataGroups(i));
                    epochTimes(index) = attributeMap('startTimeDotNetDateTimeOffsetUTCTicks'); %#ok
                    okEpochInd(index) = i; %#ok
                    index = index + 1;
                end
            end
            
            nEpochs = length(epochTimes);
            if nEpochs < 0
                return
            end
            
            [epochTimes_sorted, indices] = sort(epochTimes);
            epochTimes_sorted = epochTimes_sorted - epochTimes_sorted(1);
            epochTimes_sorted = double(epochTimes_sorted) / 1E7; % Ticks to second
            
            data.epochs = entity.EpochData.empty(nEpochs, 0);
            for i = 1 : nEpochs
                groupInd = okEpochInd(indices(i));
                epoch = entity.EpochData();
                epoch.attributes('epochStartTime') = epochTimes_sorted(i);
                epoch.attributes('epochNum') = i;
                epoch.parentCell = data;
                epoch.attributes = obj.mapAttributes(EpochDataGroups(groupInd).Groups(1), epoch.attributes);
                epoch.dataLinks = obj.addDataLinks(EpochDataGroups(groupInd).Groups(2).Groups);
                epoch.responseHandle = @(path) h5read(obj.fname, path);
                data.epochs(i) = epoch;
            end
            data.attributes('Nepochs') = nEpochs;
            data.h5File = obj.fname;
            obj.addCellDataByAmps(data);
        end
        
        function map = addDataLinks(~, responseGroups)
            n = length(responseGroups);
            map = containers.Map();
            
            for i = 1 : n
                h5Name = responseGroups(i).Name;
                delimInd = strfind(h5Name, '/');
                streamName = h5Name(delimInd(end) + 1 : end);
                streamLink = [h5Name, '/data'];
                map(streamName) = streamLink;
            end
        end
                
        function map = mapAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            if ischar(h5group)
                error('cannot accept character as epoch group for symphony 1 parser');
            end
            map = mapAttributes@sa_labs.analysis.parser.SymphonyParser(obj, h5group, map);
            keys = map.keys;
            for i = 1 : numel(keys)
                k = keys{i};
                if isa(map(k), 'hdf5.h5string')
                    v = map(k);
                    map(k) = v.data;
                end
            end
        end
    end
    
end

