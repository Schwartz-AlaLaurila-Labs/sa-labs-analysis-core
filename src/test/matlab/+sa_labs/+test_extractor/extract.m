function extract(~, epochGroup, varargin)

    ip = inputParser;
    ip.addParameter('param1', 'err', @ischar);
    ip.addParameter('param2', 'err', @ischar);
    ip.parse(varargin{:});
    v = str2double(epochGroup.splitValue);
    epochGroup.createFeature('TEST', v * ones(1, 10), 'param1', ip.Results.param1, 'param2', ip.Results.param2);
end