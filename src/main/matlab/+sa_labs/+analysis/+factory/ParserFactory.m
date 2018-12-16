classdef ParserFactory < handle & mdepin.Bean

    methods

      function obj = ParserFactory(config)
            obj = obj@mdepin.Bean(config);
        end
    end

    methods (Static)

        function obj = getInstance(fname)

            import sa_labs.analysis.*

            if factory.ParserFactory.isOvationFile(fname)
                obj = parser.OvationParser(fname);
                return
            end

            version = parser.SymphonyParser.getVersion(fname);
            if version == 2
                obj = parser.SymphonyV2Parser(fname);
            else
                obj = parser.SymphonyV1Parser(fname);
            end
        end
        
        function tf = isOvationFile(fname)
            [baseDir, name, ~] = fileparts(fname);
            tf = exist([baseDir filesep name '.auisql'], 'file');
        end
    end
end

