/**
 * Provides logic around actions in form builder
 *
 * @autodoc
 * @singleton
 * @presideservice
 */
component {

// CONSTRUCTOR
	/**
	 * @configuredActions.inject           coldbox:setting:formbuilder.actions
	 * @validationEngine.inject            validationEngine
	 * @formsService.inject                formsService
	 * @rulesEngineConditionService.inject rulesEngineConditionService
	 */
	public any function init(
		  required array configuredActions
		, required any   validationEngine
		, required any   formsService
		, required any   rulesEngineConditionService
	) {
		_setValidationEngine( validationEngine );
		_setFormsService( formsService );
		_setConfiguredActions( arguments.configuredActions );
		_setRulesEngineConditionService( arguments.rulesEngineConditionService );

		return this;
	}

// PUBLIC API
	/**
	 * Returns an array of actions that are registered
	 * with the system. Each action will consist of
	 * id, title, description and iconClass keys
	 *
	 * @autodoc
	 *
	 */
	public array function listActions() {
		var configuredActions = _getConfiguredActions();
		var actions           = [];

		for( var action in configuredActions ) {
			actions.append(
				_getConventionsBasedActionConfiguration( action )
			);
		}

		return actions;
	}

	/**
	 * Returns the configuration of the given action
	 *
	 * @autodoc
	 * @action.hint The id of the action, e.g. 'email'
	 *
	 */
	public struct function getActionConfig( required string action ) {
		var configuredActions = _getConfiguredActions();

		if ( ArrayContainsNoCase( configuredActions, arguments.action ) ) {
			return _getConventionsBasedActionConfiguration( arguments.action );
		}

		return {};
	}

	/**
	 * Retuns a form's action from the DB, converted to a useful struct. Keys are
	 * 'id', 'action' (a structure containing action configuration) and 'configuration'
	 * (a structure of configuration options for the action)
	 *
	 * @autodoc
	 * @id.hint ID of the action you wish to get
	 */
	public struct function getFormAction( required string id ) {
		var result = [];
		var items  = $getPresideObject( "formbuilder_formaction" ).selectData(
			  filter       = { id=arguments.id }
			, selectFields = [
				  "id"
				, "action_type"
				, "configuration"
				, "condition"
				, "form"
			  ]
		);

		for( var item in items ) {
			return {
				  id            = item.id
				, formId        = item.form
				, action        = getActionConfig( item.action_type )
				, condition     = item.condition
				, configuration = DeSerializeJson( item.configuration )
			};
		}

		return {};
	}

	/**
	 * Retuns a form's actions in an ordered array
	 *
	 * @autodoc
	 * @id.hint ID of the form whose actions you wish to get
	 */
	public array function getFormActions( required string id ) {
		var result = [];
		var actions  = $getPresideObject( "formbuilder_formaction" ).selectData(
			  filter       = { form=arguments.id }
			, orderBy      = "sort_order"
			, selectFields = [
				  "id"
				, "action_type"
				, "configuration"
				, "condition"
			  ]
		);

		for( var action in actions ) {
			result.append( {
				  id            = action.id
				, action        = getActionConfig( action.action_type )
				, configuration = DeSerializeJson( action.configuration )
				, condition     = action.condition
			} );
		}

		return result;
	}

	/**
	 * Returns the number of actions configured on
	 * a given form
	 *
	 * @autodoc
	 * @formid.hint The ID of the form whose actions you want to count
	 *
	 */
	public numeric function getActionCount( required string formId ) {
		var actions = $getPresideObject( "formbuilder_formaction" ).selectData(
			  filter       = { form=formId }
			, selectFields = [ "Count( id ) as action_count" ]
		);
		return Val( actions.action_count ?: "" );
	}

	/**
	 * Adds a new action to the form. Returns the ID of the
	 * newly generated action
	 *
	 * @autodoc
	 * @formId.hint        ID of the form to which to add the new item
	 * @action.hint        ID of the action, e.g. 'email' or 'webhook', etc.
	 * @configuration.hint Structure of configuration options for the action
	 */
	public string function addAction(
		  required string formId
		, required string action
		, required struct configuration
	) {
		var formActionDao   = $getPresideObject( "formbuilder_formaction" );
		var existingActions = formActionDao.selectData( selectFields=[ "Max( sort_order ) as max_sort_order" ], filter={ form=arguments.formId } );
		var data            = {
			  form          = arguments.formId
			, action_type   = arguments.action
			, configuration = SerializeJson( arguments.configuration )
			, condition     = ( arguments.configuration.condition ?: "" )
			, sort_order    = Val( existingActions.max_sort_order ?: "" ) + 1
		};

		var actionId = formActionDao.insertData( data=data );

		StructAppend( data, _getFormActionAuditDetail( formActionId=actionId ) );

		$audit(
			  action   = "formbuilder_add_action"
			, type     = "formbuilder"
			, recordId = actionId
			, detail   = data
		);

		return actionId;
	}

	/**
	 * Updates the configuration of a given action in the form.
	 *
	 * @autodoc
	 * @id.hint            ID of the action to update
	 * @configuration.hint Configuration to save against the item
	 *
	 */
	public any function saveAction( required string id, required struct configuration ) {
		if ( !Len( Trim( arguments.id ) ) ) {
			return 0;
		}

		var data = {
			  configuration = SerializeJson( arguments.configuration )
			, condition     = ( arguments.configuration.condition ?: "" )
		};

		var recordsCount = $getPresideObject( "formbuilder_formaction" ).updateData( id=arguments.id, data=data );

		StructAppend( data, _getFormActionAuditDetail( formActionId=arguments.id ) );

		$audit(
			  action   = "formbuilder_edit_action"
			, type     = "formbuilder"
			, recordId = arguments.id
			, detail   = data
		);

		return recordsCount;
	}

	/**
	 * Deletes a configured action from a form. Returns true
	 * on success, false otherwise.
	 *
	 * @autodoc
	 * @id.hint The ID of the action you wish to delete
	 *
	 */
	public boolean function deleteAction( required string id ) {
		if ( Len( Trim( arguments.id ) ) ) {
			var formAction = getFormAction( id=arguments.id );

			var data = _getFormActionAuditDetail( formActionId=arguments.id );

			var recordsCount = $getPresideObject( "formbuilder_formaction" ).deleteData( id=arguments.id );

			if ( recordsCount > 0 ) {
				$audit(
					  action   = "formbuilder_delete_action"
					, type     = "formbuilder"
					, recordId = arguments.id
					, detail   = data
				);

				return true;
			} else {
				return false;
			}
		}

		return false;
	}

	/**
	 * Sets the sort order of actions within a form. Returns the number
	 * of actions whose order has been set.
	 *
	 * @autodoc
	 * @items.hint Array of action ids in the order they should be set
	 *
	 */
	public numeric function setActionsSortOrder( required array actions ) {
		var actionDao    = $getPresideObject( "formbuilder_formaction" );
		var updatedCount = 0;

		for( var i=1; i<=Len( arguments.actions ); i++ ){
			var id = arguments.actions[ i ];

			if ( IsSimpleValue( id ) && Len( Trim( id) ) ) {
				updatedCount += actionDao.updateData( id=id, data={ sort_order=i } );
			}
		}

		return updatedCount;
	}

	/**
	 * Validates the configuration for an action within a form. Returns
	 * a Preside validation result object.
	 *
	 * @autodoc
	 * @formId.hint   ID of the form to which the item belongs / will belong
	 * @action.hint   Action name
	 * @config.hint   Configuration struct to validate
	 * @itemId.hint   ID of the form action, should it already exist
	 *
	 */
	public any function validateActionConfig(
		  required string formId
		, required string action
		, required struct config
		,          string actionId = ""
	) {
		var actionConfig     = getActionConfig( action );
		var validationResult = _getValidationEngine().newValidationResult();

		validationResult = _getFormsService().validateForm(
			  formName         = actionConfig.configFormName
			, formData         = config
			, validationResult = validationResult
		);

		return validationResult;
	}

	/**
	 * Fires of submit handlers for each registered action
	 * in the form
	 *
	 * @autodoc
	 * @formId.hint         ID of the form whose actions we are to trigger
	 * @submissionData.hint The form submission itself
	 */
	public void function triggerSubmissionActions( required string formId, required struct submissionData ) {
		var configuredActions = getFormActions( arguments.formId );
		var coldbox           = $getColdbox();
		var conditionService  = _getRulesEngineConditionService();

		for( var savedAction in configuredActions ) {
			var allowedToFire = !Len( Trim( savedAction.condition ?: "" ) ) || conditionService.evaluateCondition(
				  conditionId = savedAction.condition
				, context     = "formbuilderSubmission"
			);

			if ( allowedToFire ) {
				coldbox.runEvent(
					  event          = savedAction.action.submissionHandler
					, eventArguments = { args={ configuration = savedAction.configuration, submissionData=arguments.submissionData } }
					, private        = true
					, prePostExempt  = true
				);
			}
		}
	}

// PRIVATE HELPERS
	private struct function _getConventionsBasedActionConfiguration( required string action ) {
		return {
			  id                = arguments.action
			, configFormName    = "formbuilder.actions." & arguments.action
			, submissionHandler = "formbuilder.actions." & arguments.action & ".onSubmit"
			, title             = $translateResource( uri="formbuilder.actions.#arguments.action#:title"      , defaultValue=arguments.action )
			, description       = $translateResource( uri="formbuilder.actions.#arguments.action#:description", defaultValue=""               )
			, iconClass         = $translateResource( uri="formbuilder.actions.#arguments.action#:iconclass"  , defaultValue="fa-send"        )
		};
	}

	private struct function _getFormActionAuditDetail( required string formActionId ) {
		var formAction = getFormAction( id=arguments.formActionId );

		return {
			  formId         = formAction.formId    ?: ""
			, formActionType = formAction.action.id ?: ""
		};
	}

// GETTERS AND SETTERS
	private array function _getConfiguredActions() {
		return _configuredActions;
	}
	private void function _setConfiguredActions( required array configuredActions ) {
		_configuredActions = [];

		for( var action in arguments.configuredActions ) {
			if ( IsStruct( action ) ) {
				if ( Len( Trim( action.feature ?: "" ) ) && !$isFeatureEnabled( action.feature ) ) {
					continue;
				}
				action = action.id;
			}
			_configuredActions.append( action );
		}
	}

	private any function _getValidationEngine() {
		return _validationEngine;
	}
	private void function _setValidationEngine( required any validationEngine ) {
		_validationEngine = arguments.validationEngine;
	}

	private any function _getFormsService() {
		return _formsService;
	}
	private void function _setFormsService( required any formsService ) {
		_formsService = arguments.formsService;
	}

	private any function _getRulesEngineConditionService() {
		return _rulesEngineConditionService;
	}
	private void function _setRulesEngineConditionService( required any rulesEngineConditionService ) {
		_rulesEngineConditionService = arguments.rulesEngineConditionService;
	}
}
