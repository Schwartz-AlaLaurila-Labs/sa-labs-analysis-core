classdef Exceptions < handle
    
    enumeration
        NO_CELL_DATA('createProject:nocellData', @(msg) [ msg ' not found. Please run parser and try again '])
        NO_PROJECT('findProject:noProjectFound', @(msg) [ msg ' not found. check the project name and try again '])
        NO_RAW_DATA_FOUND('parseSymphonyFiles:h5fileNotFound', @(msg) [ msg ' not found. check the raw data folder try again '])
        NO_ANALYSIS_RESULTS_FOUND('anaylsisResult:notFound',  @(msg) [ msg ' not found. Try building analysis'])

        NO_DATA_SET_FOUND('buildTree:noEpochGroup', @(msg) ['No data set found for split value = ' msg ])
        SPLIT_VALUE_NOT_FOUND('validateLevel:splitValueNotFound', @(msg) ['No matching split value; ' msg ' while building the tree' ])

        MULTIPLE_FEATURE_KEY_PRESENT('getFeatureData:multipleFeatureIdErr', @(msg) 'cannot fetch features. Supplied feature ids are different')
        FEATURE_KEY_NOT_FOUND('getFeatureData:featureIdNotPresent', @(msg)['Feature Id ' msg ' is not found in the feature map'])

        INVALID_PROPERTY_PAIR('properties:invalid', @(msg) 'properties deos not have valid param value pair')
        OVERWRIDING_FEATURE('overriding:oldfeature', @(msg) ['overriding old feature with new one for key [ ' msg ' ]'])

        MULTIPLE_VALUE_FOUND('values:notunique',  @(msg) [msg ' has more than one unique value for group'])
        DEVICE_NOT_PRESENT('device:notpresent', @(msg) ['device not present for feature group [ ' msg ' ] '] );


    end
    
    properties
        msgId
        description
    end

    methods
        
        function obj = Exceptions(id, desc)
            obj.msgId = id;
            obj.description = desc;
        end
        
        function e = create(obj, varargin)
            ip = inputParser;
            ip.addParameter('warning', false, @islogical);
            ip.addParameter('message', '', @ischar);
            ip.parse(varargin{:});
            e = [];
            message = obj.description(ip.Results.message);
            if ip.Results.warning
                warning(obj.msgId, message);
                return
            end
            e = MException(obj.msgId, message);
        end
        
    end
end

