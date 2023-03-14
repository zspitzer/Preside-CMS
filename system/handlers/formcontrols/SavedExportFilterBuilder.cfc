component {

	private string function index( event, rc, prc, args={} ) {
		args.object       = rc.filterObject ?: "";
		args.defaultValue = Len( args.defaultValue ?: "" ) ? args.defaultValue : rc.filterExpressions ?: "";

		return renderFormControl(
			  name = "filter"
			, type = "RulesEngineFilterBuilder"
			, argumentCollection = args
		);

	}

}
