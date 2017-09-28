classdef ParserFactory < handle & mdepin.Bean
    
    methods
      
      function obj = ParserFactory(config)
            obj = obj@mdepin.Bean(config);
        end
    end 

    methods (Static)
        
        function obj = getInstance(fname)
            
            import sa_labs.analysis.parser.*
            version = SymphonyParser.getVersion(fname);
            if version == 2
                obj = SymphonyV2Parser(fname);
            else
                obj = SymphonyV1Parser(fname);
            end
        end
    end
end

