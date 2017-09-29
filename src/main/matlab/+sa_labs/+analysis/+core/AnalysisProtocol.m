classdef AnalysisProtocol < handle
    
    % AnalysisProtocol contains information about split parameters, split
    % values and extractor functions at the specified tree level
    
    properties (Access = private)
        functionContext         % Map containing key as split parameter and value as extractor functions
        protocolTree
    end
    
    properties (Dependent)
        copyParameters          % List of unique-paramters to copied from epoch to node
        type                    % Type of analysis
        featurebuilderClazz     % Feature extractor class name
        featureDescriptionFile  % Feature description CSV file location
    end
    
    properties
        structure               % Structure from user interface or json
    end
    
    methods
        
        function obj = AnalysisProtocol(structure)
            obj.structure = structure;
            obj.populateFunctionContext();
            obj.buildTree();
        end
        
        function parameters = getSplitParametersByPath(obj, index)
            leafs = obj.protocolTree.findleaves();
            path =  sort(obj.protocolTree.pathtoroot(leafs(index)));
            parameters = arrayfun(@(id) obj.protocolTree.get(id), path, 'UniformOutput', false);
            parameters = parameters(2 : end);
        end
        
        function [parameters, levels] = getSplitParameters(obj)
            buildBy = obj.structure.(sa_labs.analysis.app.Constants.TEMPLATE_BUILD_TREE_BY);
            parameters = {};
            levels = [];
            
            for i = 1 : numel(buildBy)
                branches = strtrim(strsplit(buildBy{i}, ','));
                parameters = {parameters{:}, branches{:}}; %#ok
                levels = [levels, i * ones(1, numel(branches))]; %#ok
            end
        end
        
        function values = validateSplitValues(obj, parameter, values)
            
            % Description - Takes the tree level, split parameter and split
            % value from build tree of analysis class. It validates those
            % parameter with actual analysis template structure
            %
            % returns - array / cell array of value(s)
            templateValues = obj.getSplitValue(parameter);
            
            if ischar(values)
                values = {values};
            end
            
            if isempty(templateValues)
                return
            end
            found = ismember(templateValues, values);
            
            if sum(found) == 0
                message = strcat('[ ', parameter,  ' =  ', char(templateValues), ' ] not found ');
                if size(message, 1) > 1
                    message = strjoin(cellstr(message));
                end
                throw(sa_labs.analysis.app.Exceptions.SPLIT_VALUE_NOT_FOUND.create('message', message));
            end
            values = templateValues(found);
        end
        
        function v = getSplitValue(obj, parameter)
            
            % returns - array / cell array of split values for given split parameter
            % It returns empty
            %   1. If parameter is not defined in template structure
            %   2. If template structure does not have splitValue
            %   3. If split value is a function handle
            
            v = [];
            if ~ isfield(obj.structure, parameter)
                return
            end
            
            split = obj.structure.(parameter);
            desc = sa_labs.analysis.app.Constants.TEMPLATE_SPLIT_VALUE;
            
            if ~ isfield(split, desc) || isempty(split.(desc)) || ...
                    (ischar(split.(desc)) && ~ isempty((strfind(split.(desc), '@')) == 1)) % check for function handle
                return
            end
            import sa_labs.analysis.util.wrapper.*;
            v = stringToCell(split.(desc));
            if ischar(v)
                v = {v};
            end
        end
        
        function f = getExtractorFunctions(obj, parameter)
            
            % returns - extractor function for given parameter if parameter
            % not found returns empty
            import sa_labs.analysis.util.wrapper.*;
            f = [];
            if isKey(obj.functionContext, parameter)
                f = obj.functionContext(parameter);
            end
            f = stringToCell(f);
        end
        
        function p = get.copyParameters(obj)
            import sa_labs.analysis.util.wrapper.*;
            p = [];
            field = sa_labs.analysis.app.Constants.TEMPLATE_COPY_PARAMETERS;
            if isfield(obj.structure, field)
                p = stringToCell(obj.structure.(field));
            end
        end
        
        function p = get.type(obj)
            p = obj.structure.(sa_labs.analysis.app.Constants.TEMPLATE_TYPE);
        end
        
        function f = get.featureDescriptionFile(obj)
            import sa_labs.analysis.*;
            
            f = app.App.getResource(app.Constants.FEATURE_DESC_FILE_NAME);
            descriptionFile = app.Constants.TEMPLATE_FEATURE_DESC_FILE;
            
            if isfield(obj.structure, descriptionFile)
                f = obj.structure.(descriptionFile);
            end
        end
        
        function e = get.featurebuilderClazz(obj)
            clazz = sa_labs.analysis.app.Constants.TEMPLATE_FEATURE_BUILDER_CLASS;
            
            if ~ isfield(obj.structure, clazz)
                e = 'sa_labs.analysis.core.FeatureTreeBuilder';
                return
            end
            e = obj.structure.(clazz);
        end
        
        function n = numberOfPaths(obj)
            n = numel(obj.protocolTree.findleaves());
        end
        
        function t = toTree(obj)
            t = obj.protocolTree;
        end
        
        function functions = addExtractorFunctions(obj, parameter, functions)
            
            if ~ iscell(functions)
                functions = {functions};
            end
            
            values = {};
            if isKey(obj.functionContext, parameter)
                values =  obj.functionContext(parameter);
            end
            
            for i = 1 : numel(functions)
                f = obj.stripSpace(functions{i});
                % TODO check for function name alone rather function
                % arguments
                if ~ any(ismember(values, f))
                    values(end + 1) = {f}; %#ok <AGROW>
                end
                functions{i} = f;
            end
            desc = sa_labs.analysis.app.Constants.TEMPLATE_FEATURE_EXTRACTOR;
            obj.structure.(parameter).(desc) = values;
            obj.functionContext(parameter) = values;
        end
    end
    
    methods (Access = private)
        
        function populateFunctionContext(obj)
            parameters = obj.getSplitParameters();
            desc = sa_labs.analysis.app.Constants.TEMPLATE_FEATURE_EXTRACTOR;
            obj.functionContext = containers.Map();
            
            for i = 1 : numel(parameters)
                p = parameters{i};
                if isfield(obj.structure, p) && isfield(obj.structure.(p), desc)
                    values = obj.structure.(p).(desc);
                    
                    for j = 1 : numel(values)
                        values{j} = obj.stripSpace(values{j});
                    end
                    obj.functionContext(p) = values;
                    obj.structure.(p).(desc) = values;
                end
            end
        end
        
        function buildTree(obj)
            t = tree();
            t = t.addnode(0, obj.type);
            [parameters, levels] = obj.getSplitParameters();
            uniqueLevels = sort(unique(levels));
            
            for i = 1 : numel(uniqueLevels)
                level = uniqueLevels(i);
                p = parameters(levels == level);
                siblings = t.findleaves();
                
                for sibling = siblings
                    for j = 1 : numel(p)
                        t = t.addnode(sibling, p{j});
                    end
                end
            end
            obj.protocolTree = t;
        end
        
        function value = stripSpace(~, value)
            value = strrep(char(value), ' ', '');
        end
    end
end

