/**
 * Expression handler for "User has downloaded an asset within the last x days"
 *
 * @expressionContexts user
 * @expressionCategory website_user
 * @feature            rulesEngine and websiteUsers and assetManager
 */
component {

	property name="websiteUserActionService" inject="websiteUserActionService";

	/**
	 * @asset.fieldType    asset
	 * @asset.multiple     false
	 */
	private boolean function evaluateExpression(
		  required string  asset
		,          struct  _pastTime
	) {
		var lastPerformedDate = websiteUserActionService.getLastPerformedDate(
			  type        = "asset"
			, action      = "download"
			, userId      = payload.user.id ?: ""
			, identifiers = [ arguments.asset ]
		);

		if ( !IsDate( lastPerformedDate ) ) {
			return false;
		}

		if ( IsDate( _pastTime.from ?: "" ) && lastPerformedDate < _pastTime.from ) {
			return false;
		}
		if ( IsDate( _pastTime.to ?: "" ) && lastPerformedDate > _pastTime.to ) {
			return false;
		}

		return true;
	}

	/**
	 * @objects website_user
	 *
	 */
	private array function prepareFilters(
		  required string asset
		,          struct _pastTime
	) {
		return websiteUserActionService.getUserLastPerformedActionFilter(
			  action     = "download"
			, type       = "asset"
			, datefrom   = arguments._pastTime.from ?: ""
			, dateto     = arguments._pastTime.to   ?: ""
			, identifier = arguments.asset
		);
	}

}