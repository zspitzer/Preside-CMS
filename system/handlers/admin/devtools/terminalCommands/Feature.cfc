component hint="Manage Preside features" extends="preside.system.base.Command" {

	property name="jsonRpc2" inject="JsonRpc2";
	property name="features" inject="coldbox:setting:features";

	private function index( event, rc, prc ) {
		var params          = jsonRpc2.getRequestParams();
		var validOperations = [ "list" ];

		params = IsArray( params.commandLineArgs ?: "" ) ? params.commandLineArgs : [];

		if ( !ArrayLen( params ) || !ArrayContainsNoCase( validOperations, params[ 1 ] ) ) {
			var message = newLine();

			message &= writeText( text="Usage: ", type="help", bold=true );
			message &= writeText( text="feature <operation>", type="help", newline=2 );

			message &= writeText( text="Valid operations:", type="help", newline=2 );

			message &= writeText( text="    list [<filter>\]", type="help", bold=true );
			message &= writeText( text=" : Lists all features, or those matching the optional filter string", type="help", newline=true );

			return message;
		}

		return runEvent(
			  event          = "admin.devtools.terminalCommands.feature.#params[ 1 ]#"
			, private        = true
			, prePostExempt  = true
			, eventArguments = {
				args = {
					params = params
				}
			  }
		);
	}

	private any function list( event, rc, prc, args ) {
		var message = newLine();
		var titles  = "";

		var featureWidth  = 7;
		var enabledWidth  = 7;
		var templateWidth = 13;
		var widgetWdith   = 7;

		var keys         = StructKeyArray( features );
		var filteredKeys = [];
		var filter       = args.params[ 2 ] ?: "";

		if ( Len( Trim( filter ) ) ) {
			filteredKeys = ArrayFilter( keys, function( item ) {
				return ArrayLen( ReMatchNoCase( filter, item ) ) > 0;
			} );
		} else {
			filteredKeys = keys;
		}

		if ( ArrayLen( filteredKeys ) > 0 ) {
			for ( var key in features ) {
				if ( Len( key ) > featureWidth ) {
					featureWidth = Len( key );
				}

				var siteTemplates = ArrayToList( features[ key ].siteTemplates ?: [ "*" ] );
				if ( Len( siteTemplates ) > templateWidth ) {
					templateWidth = Len( siteTemplates );
				}

				var widgets = ArrayToList( features[ key ].widgets ?: [] );
				if ( Len( widgets ) > widgetWdith ) {
					widgetWdith = Len( widgets );
				}
			}

			titles &= "  Feature " & RepeatString( " ", featureWidth-7 );
			titles &= "  Enabled ";
			titles &= "  SiteTemplates " & RepeatString( " ", templateWidth-13 );
			titles &= "  Widgets " & RepeatString( " ", widgetWdith-7 );

			message &= writeText( text=titles, newLine=true );
			message &= writeLine( length=Len( titles ), character="=" );

			ArraySort( filteredKeys, "text", "asc" );

			for ( var key in filteredKeys ) {
				message &= writeText( text="  #key# " & RepeatString( " ", featureWidth-Len( key ) ), type="info", bold=true );

				var status = ToString( features[ key ].enabled );
				message &= writeText( text="  #status# " & RepeatString( " ", enabledWidth-Len( status ) ), type=( features[ key ].enabled ? "success" : "error" ), newLine=false );

				var siteTemplates = ArrayToList( features[ key ].siteTemplates ?: [ "*" ] );
				message &= writeText( text="  #siteTemplates# " & RepeatString( " ", templateWidth-Len( siteTemplates ) ) );

				message &= writeText( text="  " & ArrayToList( features[ key ].widgets ?: [] ), newLine=true );
			}

			message &= writeLine( Len( titles ) );
		} else {
			message &= writeText( text="No features found.", newLine=true );
		}

		return message;
	}

}