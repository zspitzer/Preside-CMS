component {

	property name="formBuilderService" inject="formBuilderService";

	public string function index( event, rc, prc, args={} ) {
		var formId    = args.formId ?: ( rc[ args.formIdField ?: "" ] ?: ( rc.formId ?: ( rc.id ?: "" ) ) );
		var itemTypes = ListToArray( args.itemTypes ?: "" );
		var items     = formBuilderService.getFormItems(
			  id        = formId
			, itemTypes = itemTypes
		);

		if ( !items.Len() ) {
			var renderedTypes = [];

			for ( var type in itemTypes ) {
				arrayAppend( renderedTypes, translateResource( uri="formbuilder.item-types.#type#:title", defaultValue=type ) );
			}

			return "<p class='alert alert-warning'>" & translateResource( uri="cms:formbuilder.fieldPicker.noAvailableTypes.error", data=[ arrayToList( renderedTypes, ", " ) ] ) & "</p>";
		}

		args.values = [ "" ];
		args.labels = [ "" ];
		for( var item in items ) {
			args.values.append( item.id );
			args.labels.append( item.configuration.label ?: item.id );
		}

		return renderView( view="formcontrols/select/index", args=args );
	}
}