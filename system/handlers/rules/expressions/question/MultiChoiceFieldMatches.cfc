/**
 * @expressionContexts  webrequest
 * @expressionCategory  formbuilder
 * @expressionTags      formbuilderV2Form
 */
component {

	property name="formBuilderFilterService" inject="formBuilderFilterService";

	 /**
	 * @question.fieldtype      formbuilderQuestion
	 * @question.objectFilters  formbuilderMultiChoiceFields
	 * @value.fieldtype         formbuilderQuestionChoiceValue
	 */
	private boolean function evaluateExpression(
		  required string question
		, required string value
		,          string _all = false
	) {
		var userId = payload.user.id ?: "";

		if ( !Len( userId ) ) {
			return false;
		}

		return formBuilderFilterService.evaluateQuestionSubmissionResponseMatch(
			  argumentCollection = arguments
			, userId             = userId
			, formId             = payload.formId ?: ""
			, submissionId       = payload.submissionId ?: ""
			, extraFilters       = prepareFilters( argumentCollection=arguments )
		);
	}

	/**
	 * @objects formbuilder_formsubmission
	 */
	private array function prepareFilters(
		  required string  question
		, required string  value
		,          boolean _all = false
	) {
		return formBuilderFilterService.prepareFilterForSubmissionQuestionResponseMatchesChoiceOptions( argumentCollection=arguments );
	}

}
