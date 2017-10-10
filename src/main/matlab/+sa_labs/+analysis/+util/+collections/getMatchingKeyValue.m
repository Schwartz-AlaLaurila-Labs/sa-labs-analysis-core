function [keys, values] = getMatchingKeyValue(map, pattern)
    parameters = regexpi(map.keys, ['\w*' pattern '\w*'], 'match');
    parameters = [parameters{:}];
    values = cell(0, numel(parameters));
    keys = cell(0, numel(parameters));

    for i = 1 : numel(parameters)
        keys{i} = parameters{i};
        values{i} = map(parameters{i});
    end
end

