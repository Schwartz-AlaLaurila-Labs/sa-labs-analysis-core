%% mock objects
if exist('v', 'var')
    v.close();
end
close all;
clear all;

clc;

import sa_labs.analysis.*;

props = containers.Map();
props('id') = 'response';
props('properties') = 'endOffset = 0, baseLineEnd = 0';
description = sa_labs.analysis.entity.FeatureDescription(props);

epochParameters = struct('preTime', 500, 'stimTime', 1000, 'tailTime', 1000, 'responseLength', 25000, 'sampleRate', 10000);
noise = randn(1, 25000);

f1 = entity.Feature(description, noise);
f1.id = 'epoch (1)';
f2 = entity.Feature(description, noise);
f2.id = 'epoch (2)';
f3 = entity.Feature(description, noise);
f3.id = 'epoch (3)';
f4 = entity.Feature(description, noise);
f4.id = 'epoch (4)';

groupOne = Mock(entity.EpochGroup('rstar', '0.01'));
groupOne.when.getFeature(AnyArgs())...
    .thenReturn([f1, f2, f3, f4]);

%% testing view

v = ui.AnalysisManagerView();
v.show();
v.getAnalysisGroupsNodes().Name = 'Light step';
groupNode = v.addEpochGroupNode(v.getAnalysisGroupsNodes, groupOne.name , groupOne);
arrayfun(@(f) v.addFeatureNode(groupNode, f.id, f), groupOne.getFeature(description.id), 'UniformOutput', false);

