/**
 * @expressionContexts  formbuilderSubmission
 * @expressionCategory  formbuilder
 * @expressionTags      formbuilderV1Form
 */
component {

	property name="formBuilderService" inject="formBuilderService";

	/**
	 * @fbform.fieldtype      object
	 * @fbform.object         formbuilder_form
	 * @fbform.objectFilters  formbuilderV1Form
	 * @fbform.multiple       false
	 * @fbformfield.fieldtype formbuilderField
	 * @value.fieldtype       formbuilderFieldMultiChoiceValue
	 *
	 */
	private boolean function evaluateExpression(
		  required string fbform
		, required string fbformfield
		, required string value
		,          string  _all = false
	) {
		var submissionData  = payload.formbuilderSubmission.data ?: {};
		var formId          = payload.formbuilderSubmission.id   ?: "";
		var formItem        = formBuilderService.getFormItem( arguments.fbFormField );
		var fieldName       = formItem.configuration.name ?: "";
		var submittedValues = ListToArray( submissionData[ fieldName ] ?: "" );
		var valuesToMatch   = ListToArray( arguments.value );

		for( var valueToMatch in valuesToMatch ) {
			var found = ArrayContainsNoCase( submittedValues, valueToMatch );

			if ( found && !arguments._all ) {
				return true;
			} else if ( !found && arguments._all ) {
				return false;
			}
		}

		return arguments._all;
	}

}
