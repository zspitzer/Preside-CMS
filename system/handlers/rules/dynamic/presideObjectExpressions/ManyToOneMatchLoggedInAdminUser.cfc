/**
 * Dynamic expression handler for checking whether or not a preside object
 * many-to-one property's value matches the logged in admin user ID
 *
 */
component extends="preside.system.base.AutoObjectExpressionHandler" {

	property name="presideObjectService" inject="presideObjectService";

	private boolean function evaluateExpression(
		  required string  objectName
		, required string  propertyName
		,          boolean _is   = true
	) {
		return presideObjectService.dataExists(
			  objectName   = arguments.objectName
			, id           = payload[ arguments.objectName ].id ?: ""
			, extraFilters = prepareFilters( argumentCollection=arguments )
		);
	}

	private array function prepareFilters(
		  required string  objectName
		, required string  propertyName
		,          boolean _is   = true
	){
		var paramName = "manyToOneMatchLoggedInAdminUser" & CreateUUId().lCase().replace( "-", "", "all" );
		var operator  = _is ? "=" : "!=";
		var filterSql = "#arguments.objectName#.#propertyName# #operator# :#paramName#";
		var loggedInUserId = event.getAdminUserId();

		if ( !loggedInUserId.len() ) {
			loggedInUserId = CreateUUId();
		}
		var params    = { "#paramName#" = { value=( loggedInUserId.len() ? loggedInUserId : CreateUUId() ), type="cf_sql_varchar" } };

		return [ { filter=filterSql, filterParams=params } ];
	}

	private string function getLabel(
		  required string objectName
		, required string propertyName
		,          string parentObjectName   = ""
		,          string parentPropertyName = ""
	) {
		var relatedToBaseUri    = presideObjectService.getResourceBundleUriRoot( "security_user" );
		var relatedToTranslated = translateResource( relatedToBaseUri & "title", "security_user" );
		var propNameTranslated = translateObjectProperty( objectName, propertyName );

		if ( Len( Trim( parentPropertyName ) ) ) {
			var parentPropNameTranslated = super._getExpressionPrefix( argumentCollection=arguments );
			return translateResource( uri="rules.dynamicExpressions:related.manyToOneMatchLoggedInAdminUser.label", data=[ propNameTranslated, relatedToTranslated, parentPropNameTranslated ] );
		}

		return translateResource( uri="rules.dynamicExpressions:manyToOneMatchLoggedInAdminUser.label", data=[ propNameTranslated, relatedToTranslated ] );
	}

	private string function getText(
		  required string objectName
		, required string propertyName
		,          string parentObjectName   = ""
		,          string parentPropertyName = ""
	){
		var relatedToBaseUri    = presideObjectService.getResourceBundleUriRoot( "security_user" );
		var relatedToTranslated = translateResource( relatedToBaseUri & "title", "security_user" );
		var propNameTranslated = translateObjectProperty( objectName, propertyName );

		if ( Len( Trim( parentPropertyName ) ) ) {
			var parentPropNameTranslated = super._getExpressionPrefix( argumentCollection=arguments );
			return translateResource( uri="rules.dynamicExpressions:related.manyToOneMatchLoggedInAdminUser.text", data=[ propNameTranslated, relatedToTranslated, parentPropNameTranslated ] );
		}

		return translateResource( uri="rules.dynamicExpressions:manyToOneMatchLoggedInAdminUser.text", data=[ propNameTranslated, relatedToTranslated ] );
	}

}