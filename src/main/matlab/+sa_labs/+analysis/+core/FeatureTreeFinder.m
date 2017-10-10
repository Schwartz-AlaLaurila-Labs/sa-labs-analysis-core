classdef FeatureTreeFinder < handle
    
    properties (Access = protected)
        tree
        log
    end
    
    methods
        
        function obj = FeatureTreeFinder(dataTree)
            obj.tree = dataTree;
            obj.log = logging.getLogger(sa_labs.analysis.app.Constants.ANALYSIS_LOGGER);
        end
        
        function tf = isPresent(obj, id)
            tf = obj.tree.treefun(@(node) node.id == id).any();
        end
        
        function tf = isBasicEpochGroup(obj, epochGroups)
            tf = ~ isempty(epochGroups) && all(ismember([epochGroups.id], obj.tree.findleaves)) == 1;
        end
        
        function tree = getStructure(obj)
            tree = obj.tree.treefun(@(epochGroup) strcat(epochGroup.name, ' (' , num2str(epochGroup.id), ') '));
        end
        
        function epochGroups = getEpochGroups(obj, ids)
            epochGroups = arrayfun(@(index) obj.tree.get(index), ids, 'UniformOutput', false);
            epochGroups = [epochGroups{:}];
        end
        
        function query = find(obj, name, varargin)
            ip = inputParser;
            ip.addParameter('hasParent', []);
            ip.parse(varargin{:});
            hasParent = ip.Results.hasParent;
            
            parentGroups = obj.findEpochGroup(hasParent);
            if all(isempty(parentGroups))
                query = linq(obj.findEpochGroup(name));
                return;
            end
            indices = [];
            for id = [parentGroups(:).id]
                indices = [indices, obj.findEpochGroupId(name, id)]; %#ok;
            end
            epochGroups = obj.getEpochGroups(indices);
            query = linq(epochGroups);
        end
        
        function groups = findInBranch(obj, group, name)
            groups = [];
            for group = each(obj.getEpochGroups(obj.tree.findpath(group.id, 1)))
                if strcmpi(name, group.splitParameter)
                    groups = [groups, group]; %#ok
                end
            end
        end

        function epochGroups = findEpochGroup(obj, name)
            epochGroups = [];
            
            if isempty(name)
                return
            end
            indices = find(obj.getStructure().regexp(['\w*' name '\w*']).treefun(@any));
            epochGroups = obj.getEpochGroups(indices); %#ok
        end
        
        function id = findEpochGroupId(obj, name, epochGroupId)
            
            if nargin < 3 || isempty(epochGroupId)
                id = find(obj.getStructure().regexp(['\w*' name '\w*']).treefun(@any));
                return;
            end
            subTree = obj.tree.subtree(epochGroupId);
            structure = subTree.treefun(@(epochGroup) epochGroup.name);
            indices = find(structure.regexp(['\w*' name '\w*']).treefun(@any));
            
            id = arrayfun(@(index) subTree.get(index).id, indices);
        end
        
        function epochGroups = getAllChildrensByName(obj, regexp)
            epochGroupsByName = obj.findEpochGroup(regexp);
            epochGroups = [];
            
            for i = 1 : numel(epochGroupsByName)
                epochGroup = epochGroupsByName(i);
                subTree = obj.tree.subtree(epochGroup.id);
                childEpochGroups = arrayfun(@(index) subTree.get(index), subTree.depthfirstiterator, 'UniformOutput', false);
                epochGroups = [epochGroups, childEpochGroups{:}]; %#ok
            end
        end
        
        function epochGroups = getImmediateChildrensByName(obj, regexp)
            epochGroupsByName = obj.findEpochGroup(regexp);
            epochGroups = [];
            
            for i = 1 : numel(epochGroupsByName)
                epochGroup = epochGroupsByName(i);
                childrens = obj.tree.getchildren(epochGroup.id);
                childEpochGroups = obj.getEpochGroups(childrens);
                epochGroups = [epochGroups, childEpochGroups]; %#ok
            end
        end
    end
    
end

