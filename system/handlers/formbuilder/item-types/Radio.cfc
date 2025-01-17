/**
 * @feature formBuilder
 */
component {

	private string function renderInput( event, rc, prc, args={} ) {
		var controlName = args.name ?: "";

		return renderFormControl(
			  argumentCollection = args
			, name               = controlName
			, type               = "radio"
			, context            = "formbuilder"
			, id                 = args.id ?: controlName
			, layout             = ""
			, required           = IsTrue( args.mandatory ?: "" )
			, values             = ListToArray( args.values ?: "", Chr(10) & Chr(13) )
			, labels             = ListToArray( args.labels ?: "", Chr(10) & Chr(13) )
			, defaultValue       = args.defaultvalue ?: ""
		);
	}

	private string function renderResponse( event, rc, prc, args={} ) {
		var itemConfig = args.itemConfiguration ?: {};
		var response   = args.response;
		var values     = ListToArray( itemConfig.values ?: "", Chr( 10 ) & Chr( 13 ) );
		var labels     = ListToArray( itemConfig.labels ?: "", Chr( 10 ) & Chr( 13 ) );

		for( var i=1; i<=values.len(); i++ ) {
			if ( values[ i ] == response ) {
				if ( labels.len() >= i ) {
					return labels[ i ];
				}
				return response;
			}
		}

		return response;
	}

	private array function renderResponseForExport( event, rc, prc, args={} ) {
		return [ renderResponse( argumentCollection=arguments ) ];
	}

	private string function renderV2ResponsesForDb( event, rc, prc, args={} ) {
		return args.response ?: "";
	}

	private string function getQuestionDataType( event, rc, prc, args={} ) {
		return "shorttext";
	}
}