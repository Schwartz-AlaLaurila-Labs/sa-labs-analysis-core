function cellArray = stringToCell(string)

% Becuase of stupid string data type in latest release of
% matlab (2017a). Make sure it returns the cell array

cellArray = string;
if isstring(string)
    cellArray = cellstr(string);
end
end

