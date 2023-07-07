<cfscript>
	reporter  = url.reporter  ?: "simple";
	scope     = url.scope     ?: "full";
	directory = url.directory ?: "";

	debug = [];
	debug.append("--------- Directories -------", true);
	q_ext = extensionList();
	loop list="{lucee-web},{lucee-server},{lucee-config},{temp-directory},{home-directory},{web-root-directory},{system-directory},{web-context-hash},{web-context-label}"
		item="dir" {
		debug.append("#dir#, #expandPath(dir)#");
	}

	debug.append("");
	debug.append("--------- context cfcs -------");

	cfcs = directoryList(path=expandPath("{lucee-server}"), recurse=true, filter="*.cfc");
	for (c in cfcs){
		debug.append(c);
	}

	debug.append("");

	if (fileExists(expandPath("{lucee-server}/logs/out.log"))){
		cfg = fileRead(expandPath("{lucee-server}/logs/out.log"));
		debug.append(cfg);
	} else {
		debug.append("out.log missing");
	}
	if (fileExists(expandPath("{lucee-server}/logs/err.log"))){
		cfg = fileRead(expandPath("{lucee-server}/logs/err.log"));
		debug.append(cfg);
	} else {
		debug.append("err.log missing");
	}
	//debug.append("");
	//debug.append(getApplicationSettings().mappings.toJson());
	
	echo("<pre>" & debug.toList(chr(10)))
		flush;

	fileWrite( server.system.environment.GITHUB_STEP_SUMMARY, debug.toList(chr(10)) );

	abort;

	testbox   = new testbox.system.TestBox( options={}, reporter=reporter, directory={
		  recurse  = true
		, mapping  = Len( directory ) ? "integration.api.#directory#" : "integration"
		, filter   = function( required path ){
			if ( scope=="quick" ) {
				excludes = [
					  "presideObjects/PresideObjectServiceTest"
					, "security/CsrfProtectionServiceTest"
					, "admin/LoginServiceTest"
					, "admin/AuditServiceTest"
					, "sitetree/SiteServiceTest"
				];
				for( exclude in excludes ) {
					if ( ReFindNoCase( exclude, path ) ) {
						return false;
					}
				}
				return true;
			}
			return true;
		}
	} );

	results = Trim( testbox.run() );

	content reset=true; echo( results ); abort;
</cfscript>