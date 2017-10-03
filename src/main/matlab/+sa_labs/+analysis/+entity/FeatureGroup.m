classdef FeatureGroup < sa_labs.analysis.entity.AbstractGroup
    
    properties
        id                  % Identifier of the featureGroup, assigned by NodeManager @see NodeManager.addFeatureGroup
        epochGroup          % Read only dataSet and used as cache
    end
    
    properties(SetAccess = immutable)
        splitParameter      % Defines level of featureGroup in tree
        splitValue          % Defines the branch of tree
    end
    
    properties (Hidden)
        epochIndices        % List of epoch indices to be processed in Offline analysis. @see CellData and FeatureExtractor.extract
        parametersCopied    % Avoid redundant collection of parameters
    end
    
    methods
        
        function obj = FeatureGroup(splitParameter, splitValue, name)
            if nargin < 3
                name = [splitParameter '==' num2str(splitValue)];
            end
            obj = obj@sa_labs.analysis.entity.AbstractGroup(name);
            obj.splitParameter = splitParameter;
            obj.splitValue = splitValue;
            obj.parametersCopied = false;
        end
    end

    methods (Access = protected)

        function features = getDerivedFeatures(obj, key)
            features = [];
            if isempty(obj.epochGroup)
                return
            end
            features = obj.epochGroup.getFeatures(key);
        end
    end
end

