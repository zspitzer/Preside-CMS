component hint="Dev helper to toggle various debugging features" extends="preside.system.base.Command" {

	property name="jsonRpc2Plugin" inject="JsonRpc2";
	property name="sessionStorage" inject="sessionStorage";

	private function index( event, rc, prc ) {
		var params          = jsonRpc2Plugin.getRequestParams();
		var validOperations = [ "i18n" ];

		params = IsArray( params.commandLineArgs ?: "" ) ? params.commandLineArgs : [];

		if ( !params.len() || !ArrayContainsNoCase( validOperations, params[1] ) ) {
			var message = newLine();

			message &= writeText( text="Usage: ", type="help", bold=true );
			message &= writeText( text="debug <operation>", type="help", newline=2 );

			message &= writeText( text="Valid operations:", type="help", newline=2 );

			message &= writeText( text="    i18n", type="help", bold=true );
			message &= writeText( text=" : Toggles i18n debugging", type="help", newline=true );

			return message;
		}

		return runEvent( event="admin.devtools.terminalCommands.debug.#params[1]#", private=true, prePostExempt=true );
	}

	private function i18n( event, rc, prc ) {
		var isDebuggingEnabled = sessionStorage.getVar( "_i18nDebugMode" );
		var newValue           = !( IsTrue( isDebuggingEnabled ?: "" ) );
		var style              = newValue ? "b;white;green" : "b;white;red";
		var status             = newValue ? " ON " : " OFF ";

		sessionStorage.setVar( "_i18nDebugMode", newValue );

		return newLine()
			& writeText( text="i18n debugging has been turned ", type="info" )
			& writeText( text=status, style=style )
			& writeText( text=". Please refresh the page.", type="info", newline=true );
	}
}