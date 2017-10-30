function dt = dotnetTicksToDateTime(datetimeticks)
dt = datetime(datenum(double(datetimeticks) * 1e-7/86400 + 367), 'ConvertFrom', 'datenum');
end

