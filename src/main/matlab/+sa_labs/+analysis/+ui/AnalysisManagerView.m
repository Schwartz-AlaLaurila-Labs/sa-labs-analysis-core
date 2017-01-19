classdef AnalysisManagerView < appbox.View
    
    events
        SelectedNodes
        SelectedAnalysisGroupSignal
        SelectedFeatureSignal
        OpenAxesInNewWindow
        AddFeatureGroup
        AddFeature
    end
    
    properties (Access = private)
        analysisTree
        analysisGroupsFolderNode
        detailCardPanel
        emptyCard
        analysisGroupCard
        featureCard
    end
    
    properties (Constant)
        EMPTY_CARD         = 1
    end
    
    methods
        
        function createUi(obj)
            import appbox.*;
            import sa_labs.analysis.ui.*
            
            set(obj.figureHandle, ...
                'Name', 'Analysis Manager', ...
                'Position', screenCenter(611, 450));
            
            mainLayout = uix.HBoxFlex( ...
                'Parent', obj.figureHandle, ...
                'DividerMarkings', 'off', ...
                'DividerBackgroundColor', [160/255 160/255 160/255], ...
                'Spacing', 1);
            
            masterLayout = uix.HBox( ...
                'Parent', mainLayout);
            
            obj.analysisTree = uiextras.jTree.Tree( ...
                'Parent', masterLayout, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'BorderType', 'none', ...
                'SelectionChangeFcn', @(h,d)notify(obj, 'SelectedNodes'), ...
                'SelectionType', 'discontiguous');
            
            root = obj.analysisTree.Root;
            set(root, 'Value', struct('entity', [], 'type', AnalysisNodeType.SUMMARY));
            set(root, 'Name', 'Result');
            rootMenu = uicontextmenu('Parent', obj.figureHandle);
            rootMenu = obj.addEntityContextMenus(rootMenu);
            set(root, 'UIContextMenu', rootMenu);
            
            groups = uiextras.jTree.TreeNode( ...
                'Parent', root, ...
                'Name', 'Analysis Group', ...
                'Value', struct('entity', [], 'type', AnalysisNodeType.ANALYSIS_GROUP));
            obj.analysisGroupsFolderNode = groups;
            menu = uicontextmenu('Parent', obj.figureHandle);
            uimenu( ...
                'Parent', menu, ...
                'Label', 'Add Feature...', ...
                'Callback', @(h,d)notify(obj, 'AddFeatureGroup'));
            menu = obj.addEntityContextMenus(menu);
            
            set(groups, 'UIContextMenu', menu);
            
            detailLayout = uix.VBox( ...
                'Parent', mainLayout, ...
                'Padding', 11);
            
            obj.detailCardPanel = uix.CardPanel( ...
                'Parent', detailLayout);
            
            % Empty card.
            emptyLayout = uix.VBox( ...
                'Parent', obj.detailCardPanel);
            uix.Empty('Parent', emptyLayout);
            obj.emptyCard.text = uicontrol( ...
                'Parent', emptyLayout, ...
                'Style', 'text', ...
                'HorizontalAlignment', 'center');
            uix.Empty('Parent',emptyLayout);
            set(emptyLayout, ...
                'Heights', [-1 23 -1], ...
                'UserData', struct('Height', -1));
            
            % Feature group card.
            analysisGroupLayout = uix.VBox( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            analysisGroupGrid = uix.Grid( ...
                'Parent', analysisGroupLayout, ...
                'Spacing', 7);
            
            Label( ...
                'Parent', analysisGroupGrid, ...
                'String', 'Analysis:');
            
            % figure handler at analysis group level
            obj.analysisGroupCard.signalPopupMenu = MappedPopupMenu( ...
                'Parent', analysisGroupGrid, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @(h,d)notify(obj, 'SelectedAnalysisGroupSignal'));
            obj.analysisGroupCard.panel = uipanel( ...
                'Parent', analysisGroupLayout, ...
                'BorderType', 'line', ...
                'HighlightColor', [130/255 135/255 144/255], ...
                'BackgroundColor', 'w');
            obj.analysisGroupCard.axes = axes( ...
                'Parent', obj.analysisGroupCard.panel, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            set(analysisGroupGrid, ...
                'Widths', [60 -1], ...
                'Heights', [23 23]);
            set(analysisGroupLayout, ...
                'Heights', [layoutHeight(analysisGroupGrid) -1]);
            
            % Feature card.
            featureLayout = uix.VBox( ...
                'Parent', obj.detailCardPanel, ...
                'Spacing', 7);
            featureGrid = uix.Grid( ...
                'Parent', featureLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', featureGrid, ...
                'String', 'Plotted signal:');
            obj.featureCard.signalPopupMenu = MappedPopupMenu( ...
                'Parent', featureGrid, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @(h,d)notify(obj, 'SelectedFeatureSignal'));
            set(featureGrid, ...
                'Widths', [80 -1], ...
                'Heights', 23);
            obj.featureCard.panel = uipanel( ...
                'Parent', featureLayout, ...
                'BorderType', 'line', ...
                'HighlightColor', [130/255 135/255 144/255], ...
                'BackgroundColor', 'w');
            obj.featureCard.axes = axes( ...
                'Parent', obj.featureCard.panel, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            axesMenu = uicontextmenu('Parent', obj.figureHandle);
            uimenu( ...
                'Parent', axesMenu, ...
                'Label', 'Open in new window', ...
                'Callback', @(h,d)notify(obj, 'OpenAxesInNewWindow'));
            set(obj.featureCard.axes, 'UIContextMenu', axesMenu);
            set(obj.featureCard.panel, 'UIContextMenu', axesMenu);
            set(featureLayout, ...
                'Heights', [layoutHeight(featureGrid) -1]);
            
        end
        
        function nodes = getSelectedNodes(obj)
            nodes = obj.analysisTree.SelectedNodes;
        end
        
        function n = getSummaryNode(obj)
            n = obj.analysisTree.Root;
        end
        
        function e = getNodeEntity(obj, node) %#ok<INUSL>
            v = get(node, 'Value');
            e = v.entity;
        end
        
        function n = addAnalysisGroupsNode(obj, parent, name, entity)
            value.entity = entity;
            value.type = sa_labs.analysis.ui.AnalysisNodeType.ANALYSIS_GROUP;
            n = uiextras.jTree.TreeNode( ...
                'Parent', parent, ...
                'Name', name, ...
                'Value', value);
            menu = uicontextmenu('Parent', obj.figureHandle);
            uimenu( ...
                'Parent', menu, ...
                'Label', 'Add Feature Group ..', ...
                'Callback', @(h,d)notify(obj, 'AddFeatureGroup'));
            menu = obj.addEntityContextMenus(menu);
            set(n, 'UIContextMenu', menu);
        end
        
        function n = getAnalysisGroupsNodes(obj)
            n = obj.analysisTree.Root.Children;
        end
        
        function n = addFeatureGroupNode(obj, parent, name, entity)
            value.entity = entity;
            value.type = sa_labs.analysis.ui.AnalysisNodeType.FEATURE_GROUP;
            n = uiextras.jTree.TreeNode( ...
                'Parent', parent, ...
                'Name', name, ...
                'Value', value);
            menu = uicontextmenu('Parent', obj.figureHandle);
            uimenu( ...
                'Parent', menu, ...
                'Label', 'Add Feature ..', ...
                'Callback', @(h,d)notify(obj, 'AddFeature'));
            menu = obj.addEntityContextMenus(menu);
            set(n, 'UIContextMenu', menu);
        end
        
        function n = addFeatureNode(obj, parent, name, entity)
            value.entity = entity;
            value.type = sa_labs.analysis.ui.AnalysisNodeType.FEATURE;
            n = uiextras.jTree.TreeNode( ...
                'Parent', parent, ...
                'Name', name, ...
                'Value', value);
            menu = uicontextmenu('Parent', obj.figureHandle);
            menu = obj.addEntityContextMenus(menu);
            set(n, 'UIContextMenu', menu);
        end
        
    end
    
    methods (Access = private)
        
        function menu = addEntityContextMenus(obj, menu)
            uimenu( ...
                'Parent', menu, ...
                'Label', 'Send to Workspace', ...
                'Separator', appbox.onOff(~isempty(get(menu, 'Children'))), ...
                'Callback', @(h,d)notify(obj, 'SendEntityToWorkspace'));
        end
    end
end