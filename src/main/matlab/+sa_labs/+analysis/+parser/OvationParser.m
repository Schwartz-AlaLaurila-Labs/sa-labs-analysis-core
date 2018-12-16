classdef OvationParser < handle
	
	properties (SetAccess = private)
		h5file
		auisqlFile
	end

	properties (Transient)
	    log
	end

	methods
    	function obj = OvationParser(fname)
    		 [baseDir, name, ~] = fileparts(fname);
    		 obj.auisqlFile = [baseDir filesep name '.auisql'];
    		 obj.h5file = fname;
    		 mksqlite('open', obj.auisqlFile);
    	end

    	function ids = getCellId(obj)
    		query = 'select distinct(Z_PK) as id from ZCELL';
    		obj.log.debug(query);
    		record = mksqlite(query);
    		ids = [record.id];
    	end
    end
end