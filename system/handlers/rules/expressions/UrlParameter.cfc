/**
 * Expression handler for "URL parameter contains text" expression
 *
 * @expressionCategory browser
 * @expressionContexts webrequest
 */
component {

	private boolean function evaluateExpression(
		  required string  paramName
		,          string  value           = ""
		,          string  _stringOperator = "contains"
	) {
		var stringToMatch = url[ arguments.paramName ] ?: "";

		switch ( arguments._stringOperator ) {
			case "eq"            : return stringToMatch == arguments.value;
			case "neq"           : return stringToMatch != arguments.value;
			case "notcontains"   : return FindNoCase( stringToMatch, arguments.value ) == 0;
			case "startsWith"    : return stringToMatch.left( Len( arguments.value ) ) == arguments.value;
			case "notstartsWith" : return stringToMatch.left( Len( arguments.value ) ) != arguments.value;
			case "endsWith"      : return stringToMatch.right( Len( arguments.value ) ) == arguments.value;
			case "notendsWith"   : return stringToMatch.right( Len( arguments.value ) ) != arguments.value;
		}
	}

}