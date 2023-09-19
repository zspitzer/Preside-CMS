<cfscript>
        NL="
";
        function _getConfig(dir) {
                echo("<pre>");
                loop array=[".CFConfig.json","lucee-server.xml","lucee-web.xml.cfm"] item="local.name" {
                        var file=dir&"/"&name;
                        echo(">>> "&name&"("&fileExists(file)&") ---- "&file&" -------"&NL);
                        if(fileExists(file)) {
                                echo(fileRead(file)&NL&NL);
                        }
                }
                echo("</pre>");        
        }
        function getConfig() {                
                var pc=getPageContext();
                var c=pc.getConfig();                
                _getConfig(c.getConfigDir());
                _getConfig(c.getServerConfigDir());

        }
        getConfig();
	abort;
</cfscript>



<!---
<cfscript>
	reporter  = url.reporter  ?: "simple";
	scope     = url.scope     ?: "full";
	directory = url.directory ?: "";
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
--->