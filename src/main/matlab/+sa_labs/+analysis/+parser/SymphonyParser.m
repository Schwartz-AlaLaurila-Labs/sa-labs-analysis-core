classdef SymphonyParser < handle
    
    properties (Access = protected)
        fname
        log
        info
    end
    
    methods
        
        function obj = SymphonyParser(fname)
            obj.log = logging.getLogger(sa_labs.analysis.app.Constants.ANALYSIS_LOGGER);
            obj.fname = fname;
            tic;
            obj.info = h5info(fname);
            elapsedTime = toc;
            [~, name, ~] = fileparts(fname);
            obj.log.debug(['Elapsed Time for genearting info index for file [ ' name ' ] is [ ' num2str(elapsedTime) ' s ]' ]);
        end
        
        function map = mapAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            if ischar(h5group)
                h5group = h5info(obj.fname, h5group);
            end
            attributes = h5group.Attributes;
            
            for i = 1 : length(attributes)
                name = attributes(i).Name;
                root = strfind(name, '/');
                value = attributes(i).Value;
                
                % convert column vectors to row vectors
                if size(value, 1) > 1
                    value = reshape(value, 1, []);
                end
                
                if ~ isempty(root)
                    name = attributes(i).Name(root(end) + 1 : end);
                end
                map(name) = value;
            end
        end
        
        function hrn = convertDisplayName(~, n)
            hrn = regexprep(n, '([A-Z][a-z]+)', ' $1');
            hrn = regexprep(hrn, '([A-Z][A-Z]+)', ' $1');
            hrn = regexprep(hrn, '([^A-Za-z ]+)', ' $1');
            hrn = strtrim(hrn);
            
            % TODO: improve underscore handling, this really only works with lowercase underscored variables
            hrn = strrep(hrn, '_', '');
            
            hrn(1) = upper(hrn(1));
        end
    end
    
    methods(Abstract)
        parse(obj)
        getResult(obj)
    end
    
    methods(Static)
        
        function version = getVersion(fname)
            version = h5readatt(fname, '/', 'version');
        end
    end
end

