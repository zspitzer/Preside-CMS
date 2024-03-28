/**
 * @singleton true
 */
component {

// CONSTRUCTOR
	public any function init() {
		variables._patterns = {};
		return this;
	}

// PUBLIC API METHODS
	public string function dynamicFindAndReplace( required string source, required string regexPattern, required any processor, required boolean recurse, array recursionChain=[] ) {
		var matcher     = _getMatcher( arguments.regexPattern, arguments.source );
		var builder     = [];
		var simpleCache = {};
		var sourceLen   = Len( arguments.source );
		var currentPos  = 1;

		while( matcher.contains() ) {
			var pos = matcher.start() + 1;

			if ( currentPos < pos ) {
				ArrayAppend( builder, Mid( arguments.source, currentPos, pos-currentPos ) );
			}
			currentPos = matcher.end() + 1;

			var fullText = matcher.group( 0 );

			if ( !StructKeyExists( simpleCache, fullText ) ) {
				if ( ArrayContainsNoCase( arguments.recursionChain, fullText ) ) {
					simpleCache[ fullText ] = "";
				} else {
					var captureGroups = [];
					for( var i=0; i <= matcher.groupCount(); i++ ) {
						ArrayAppend( captureGroups, matcher.group( i ) );
					}
					simpleCache[ fullText ] = arguments.processor( captureGroups );
				}

				if ( arguments.recurse && simpleCache[ fullText ] != fullText  ) {
					var thisChain = [ fullText ];
					ArrayAppend( thisChain, arguments.recursionChain, true );
					simpleCache[ fullText ] = dynamicFindAndReplace( argumentCollection=arguments, source=simpleCache[ fullText ], recursionChain=thisChain );
				}
			}

			ArrayAppend( builder, simpleCache[ fullText ] );
		}

		if ( !ArrayLen( builder ) ) {
			return arguments.source;
		}

		if ( sourceLen > currentPos ) {
			ArrayAppend( builder, Right( arguments.source, sourceLen-(currentPos-1) ) );
		}

		return ArrayToList( builder, "" );
	}

// PRIVATE HELPERS
	private function _getMatcher( pattern, source ) {
		if ( !StructKeyExists( variables._patterns, arguments.pattern ) ) {
			variables._patterns[ arguments.pattern ] = CreateObject( "java", "java.util.regex.Pattern" ).compile( arguments.pattern );
		}
		return variables._patterns[ arguments.pattern ].matcher( JavaCast( "string", arguments.source ) );
	}

}