/**
 * Service that provides logic for dealing with rule engine expressions.
 * See [[rules-engine]] for further details.
 *
 * @singleton      true
 * @presideservice true
 * @autodoc        true
 */
component displayName="RulesEngine Expression Service" {


// CONSTRUCTOR
	/**
	 * @expressionReaderService.inject     rulesEngineExpressionReaderService
	 * @fieldTypeService.inject            rulesEngineFieldTypeService
	 * @contextService.inject              rulesEngineContextService
	 * @autoExpressionGenerator.inject     rulesEngineAutoPresideObjectExpressionGenerator
	 * @expressionDirectories.inject       presidecms:directories:/handlers/rules/expressions
	 * @i18n.inject                        coldbox:plugin:i18n
	 *
	 */
	public any function init(
		  required any   expressionReaderService
		, required any   fieldTypeService
		, required any   contextService
		, required any   autoExpressionGenerator
		, required array expressionDirectories
		, required any   i18n
	) {
		_setFieldTypeService( fieldTypeService );
		_setContextService( contextService );
		_setAutoExpressionGenerator( arguments.autoExpressionGenerator );
		_setExpressions( expressionReaderService.getExpressionsFromDirectories( expressionDirectories ) );
		_setI18n( i18n );
		_setRulesEngineExpressionCache( {} );

		return this;
	}

// PUBLIC API
	/**
	 * Returns an array of expressions ordered by their translated
	 * labels and optionally filtered by context
	 *
	 * @autodoc           true
	 * @context.hint      Expression context with which to filter the results
	 * @filterObject.hint Filter expressions by those that can be used as a filter for this object (ID)
	 * @excludeTags.hint  Expressions with any of these tags (comma-separated list) will be ignored
	 */
	public array function listExpressions(
		  string context      = ""
		, string filterObject = ""
		, string excludeTags  = ""
		, struct roleLimits   = getObjectFieldsExpressionRoleLimits( arguments.filterObject )
		, array  userRoles    = _getAdminUserRoles()
	) {
		_lazyLoadDynamicExpressions( argumentCollection=arguments );

		var allExpressions  = _getExpressions();
		var list            = [];
		var hasExclusions   = Len( arguments.excludeTags ) > 0;
		var filterOnContext = Len( arguments.context ) > 0;
		var filterOnObject  = Len( arguments.filterObject ) > 0;

		for( var expressionId in allExpressions ) {
			var contexts     = allExpressions[ expressionId ].contexts ?: [];
			var tags         = allExpressions[ expressionId ].tags     ?: [];
			var roleLimitKey = filterOnObject ? ( arguments.filterObject & "." & ListLast( expressionId, "." ) ) : "";

			if ( hasExclusions && _findListItemInArray( tags, arguments.excludeTags ) ) {
				continue;
			}
			if ( filterOnContext && !(contexts.containsNoCase( "global" ) || contexts.containsNoCase( arguments.context ) ) ) {
				continue;
			}
			if ( filterOnObject && !( ( allExpressions[ expressionId ].filterObjects ?: [] ).len() && allExpressions[ expressionId ].filterObjects.containsNoCase( arguments.filterObject ) ) ) {
				continue;
			}

			if ( filterOnObject && ArrayLen( arguments.userRoles ) && StructKeyExists( arguments.roleLimits, roleLimitKey ) ) {
				var expressionHandler    = allExpressions[ expressionId ].expressionHandler ?: "";
				var expressionIdentifier = ( ListLen( expressionHandler, "." ) eq 5 ) ? ListGetAt( expressionHandler, 4, "." ) : "";
				var hasPermission        = false;
				var propertyRoleLimit    = arguments.roleLimits[ roleLimitKey ];

				for ( var role in arguments.userRoles ) {
					if ( StructKeyExists( propertyRoleLimit, role ) ) {
						hasPermission = hasPermission || ArrayContainsNoCase( propertyRoleLimit[ role ], expressionIdentifier );
					}
				}

				if ( !hasPermission ) {
					continue;
				}
			}

			var getExpressionArgs  = { expressionId = expressionId };
			if ( Len( Trim( arguments.context ) ) ) {
				getExpressionArgs.context = arguments.context;
			}
			if ( Len( Trim( arguments.filterObject ) ) ) {
				getExpressionArgs.objectName = arguments.filterObject;
			}

			ArrayAppend( list, getExpression( argumentCollection=getExpressionArgs ) );
		}

		ArraySort( list, function( a, b ){
			var aCategory = a.category ?: "";
			var bCategory = b.category ?: "";

			if ( aCategory == bCategory ) {
				return a.label > b.label ? 1 : -1;
			}
			return aCategory > bCategory ? 1 : -1;
		} );

		return list;
	}


	/**
	 * Returns a structure with all relevant info about the expression
	 * including:
	 * \n
	 * * fields
	 * * contexts
	 * * translated label
	 * * translated expression text
	 *
	 * @autodoc           true
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 * @context.hint      Context in which the expression is being used
	 */
	public struct function getExpression(
		  required string expressionId
		,          string context    = ""
		,          string objectName = ""
	) {
		_lazyLoadDynamicExpressions( context=arguments.context, filterObject=arguments.objectName );

		var expression      = Duplicate( _getRawExpression( arguments.expressionId ) );
		var translationArgs = { expressionId = arguments.expressionId };

		if ( Len( Trim( arguments.context ) ) ) {
			translationArgs.context = arguments.context;
		}
		if ( Len( Trim( arguments.objectName ) ) ) {
			translationArgs.objectName = arguments.objectName;
		}

		expression.id       = expressionId;
		expression.label    = getExpressionLabel( argumentCollection=translationArgs );
		expression.text     = getExpressionText( argumentCollection=translationArgs );
		expression.fields   = expression.fields ?: {};
		expression.category = translateExpressionCategory( expression.category ?: "default" );

		for( var fieldName in expression.fields ) {
			expression.fields[ fieldName ].defaultLabel = getDefaultFieldLabel( expressionId, fieldName );
		}

		return expression;
	}

	/**
	 * Returns a translated label for the given expression ID. The label
	 * is shown when rendering the expression in the list of optional
	 * expressions to use for the administrator. e.g.
	 * \n
	 * > User is logged in
	 *
	 * @autodoc           true
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 * @context.hint      Optional context in which the expression is being used
	 * @objectName.hint   Optional object name for which a filter is being applied that uses this expression
	 */
	public string function getExpressionLabel(
		  required string expressionId
		,          string context    = ""
		,          string objectName = ""
	) {
		_lazyLoadDynamicExpressions( context=arguments.context, filterObject=arguments.objectName );
		var expression = _getRawExpression( arguments.expressionId );

		if ( $getColdbox().handlerExists( expression.labelHandler ?: "" ) ) {
			var handlerArgs = Duplicate( expression.labelHandlerArgs ?: {} );
			handlerArgs.context    = arguments.context;

			return $getColdbox().runEvent(
				  event          = expression.labelHandler
				, private        = true
				, prePostExempt  = true
				, eventArguments = handlerArgs
			);
		}

		return $translateResource(
			  uri          = "rules.expressions.#arguments.expressionId#:label"
			, defaultValue = arguments.expressionId
		);
	}

	/**
	 * Returns a translated expression text for the given expression ID.
	 * Expression text is the text with placeholders that the administrator
	 * will see when building a condition. e.g.
	 * \n
	 * > User {_is} logged in
	 *
	 * @autodoc
	 * @expressionId.hint ID of the expression, e.g. "loggedIn.global"
	 * @context.hint      Optional context in which the expression is being used
	 * @objectName.hint   Optional object name for which a filter is being applied that uses this expression
	 */
	public string function getExpressionText(
		  required string expressionId
		,          string context    = ""
		,          string objectName = ""
	) {
		_lazyLoadDynamicExpressions( context=arguments.context, filterObject=arguments.objectName );

		var expression = _getRawExpression( arguments.expressionId );

		if ( $getColdbox().handlerExists( expression.textHandler ?: "" ) ) {
			var handlerArgs = Duplicate( expression.textHandlerArgs ?: {} );
			handlerArgs.context    = arguments.context;

			return $getColdbox().runEvent(
				  event          = expression.textHandler
				, private        = true
				, prePostExempt  = true
				, eventArguments = handlerArgs
			);
		}

		return $translateResource(
			  uri          = "rules.expressions.#arguments.expressionId#:text"
			, defaultValue = arguments.expressionId
		);
	}

	/**
	 * Returns the default label for an expression field. This label is used when
	 * an administrator has not yet configured the field after inserting an expression
	 * into their condition builder. e.g.
	 * \n
	 * > Choose an event
	 *
	 * @audotodoc
	 * @expressionId.hint ID of the expression whose field we want to get the label of
	 * @fieldName.hint    Name of the field
	 */
	public string function getDefaultFieldLabel( required string expressionId, required string fieldName ) {
		var rawDefinition     = _getRawExpression( arguments.expressionId );

		if ( Len( Trim( rawDefinition.fields[ arguments.fieldName ].defaultLabel ?: "" ) ) ) {
			var labelUri = rawDefinition.fields[ arguments.fieldName ].defaultLabel;
			return $translateResource( uri=labelUri, defaultValue=labelUri );
		}

		var defaultFieldLabel = $translateResource( uri="rules.fields:#arguments.fieldName#.label", defaultValue=arguments.fieldName );

		return $translateResource( uri="rules.expressions.#arguments.expressionId#:field.#arguments.fieldName#.label", defaultValue=defaultFieldLabel );
	}

	/**
	 * Evaluates an expression, returning true or false,
	 * using the passed context, payload and field configuration.
	 *
	 * @autodoc
	 * @expressionId.hint     The ID of the expression to evaluate
	 * @context.hint          The context in which the expression is being evaluated. e.g. 'request', 'workflow' or 'marketing-automation'
	 * @payload.hint          A structure of data representing a payload against which the expression can be evaluated
	 * @configuredFields.hint A structure of fields configured for the expression instance being evaluated
	 */
	public boolean function evaluateExpression(
		  required string expressionId
		, required string context
		, required struct payload
		, required struct configuredFields
	) {
		_lazyLoadDynamicExpressions( context=arguments.context )
		try {
			var expression = _getRawExpression( expressionId );
		} catch( any e ) {
			$raiseError( e );
			return false;
		}

		var contexts   = expression.contexts ?: [];

		if ( !contexts.containsNoCase( arguments.context ) && !contexts.containsNoCase( "global" ) ) {
			throw(
				  type    = "preside.rule.expression.invalid.context"
				, message = "The expression [#arguments.expressionId#] cannot be used in the [#arguments.context#] context."
			);
		}

		var handlerAction = expression.expressionhandler ?: "rules.expressions." & arguments.expressionId & ".evaluateExpression";
		var eventArgs     = {
			  context = arguments.context
			, payload = arguments.payload
		};

		eventArgs.append( expression.expressionHandlerArgs ?: {} );
		eventArgs.append( preProcessConfiguredFields( arguments.expressionId, arguments.configuredFields ) );

		var result = $getColdbox().runEvent(
			  event          = handlerAction
			, private        = true
			, prePostExempt  = true
			, eventArguments = eventArgs
		);

		return result;
	}

	/**
	 * Returns a prepared filter for the given expression, context
	 * and configured fields.
	 *
	 * @autodoc               true
	 * @expressionId.hint     The ID of the expression whose filters you wish to prepare
	 * @objectName.hint       The object whose records are to be filtered
	 * @configuredFields.hint A structure of fields configured for the expression instance whose filter we are preparing
	 */
	public array function prepareExpressionFilters(
		  required string expressionId
		, required string objectName
		, required struct configuredFields
	) {
		_lazyLoadDynamicExpressions( filterObject=arguments.objectName );

		var expression    = _getRawExpression( expressionid );
		var filterObjects = expression.filterObjects ?: [];

		if ( !filterObjects.containsNoCase( arguments.objectName ) ) {
			throw(
				  type    = "preside.rule.expression.invalid.filter.object"
				, message = "The expression [#arguments.expressionId#] cannot be used to filter the [#arguments.objectName#] object."
			);
		}

		var handlerAction = expression.filterHandler ?: "rules.expressions." & arguments.expressionId & ".prepareFilters";
		var eventArgs     = { objectName=arguments.objectName };

		eventArgs.append( expression.filterHandlerArgs ?: {} );
		eventArgs.append( preProcessConfiguredFields( arguments.expressionId, arguments.configuredFields ) );

		// backward compatibility: see https://presidecms.atlassian.net/browse/PRESIDECMS-2453
		eventArgs.filterPrefix = eventArgs.filterPrefix ?: "";
		// end backward compatibility

		var result = $getColdbox().runEvent(
			  event          = handlerAction
			, private        = true
			, prePostExempt  = true
			, eventArguments = eventArgs
		);

		return result;
	}

	/**
	 * Validates a configured expression for a given context.
	 * Returns true if valid, false otherwise and sets specific
	 * error messages using the passed [[api-validationresult]] object.
	 *
	 * @autodoc
	 * @expressionId.hint     ID of the expression to validate
	 * @fields.hint           Struct of saved field configurations for the expression instance to validate
	 * @context.hint          Context in which the expression is being used
	 * @filterObject.hint     Object for which the expression is being used as a filter
	 * @validationResult.hint [[api-validationresult]] object with which to record errors
	 *
	 */
	public boolean function isExpressionValid(
		  required string expressionId
		, required struct fields
		, required string context
		, required any    validationResult
		,          string filterObject = ""
	) {
		_lazyLoadDynamicExpressions( argumentCollection=arguments );

		var expression = _getRawExpression( arguments.expressionId, false );

		if ( expression.isEmpty() ) {
			arguments.validationResult.setGeneralMessage( "The [#arguments.expressionId#] expression could not be found" );
			return false;
		}

		if ( arguments.filterObject.len() ) {
			if ( !expression.filterObjects.containsNoCase( arguments.filterObject ) ) {
				arguments.validationResult.setGeneralMessage( "The [#arguments.expressionId#] expression cannot be used to filter the [#arguments.filterObject#] object" );
				return false;
			}
		} else {
			if ( !expression.contexts.containsNoCase( arguments.context ) && !expression.contexts.containsNoCase( "global" ) ) {
				arguments.validationResult.setGeneralMessage( "The [#arguments.expressionId#] expression cannot be used in the [#arguments.context#] context" );
				return false;
			}
		}

		for ( var fieldName in expression.fields ) {
			var field    = expression.fields[ fieldName ];
			var required = IsBoolean( field.required ?: "" ) && field.required;

			if ( required && IsEmpty( arguments.fields[ fieldName ] ?: "" ) ) {
				arguments.validationResult.setGeneralMessage( "The [#arguments.expressionId#] expression is missing one or more required fields" );
				return false;
			}
		}

		return true;
	}

	/**
	 * Accepts an expressionId and saved field configuration
	 * and preprocesses all the field values ready for evaluation.
	 *
	 * @autodoc
	 * @expressionId.hint     ID of the expression whose fields are configured
	 * @configuredFields.hint Saved field configuration for the expression instance
	 *
	 */
	public struct function preProcessConfiguredFields( required string expressionId, required struct configuredFields ) {
		var expression       = _getRawExpression( arguments.expressionId );
		var expressionFields = expression.fields ?: {};
		var fieldTypeService = _getFieldTypeService();
		var processed        = {};

		for( var fieldName in configuredFields ) {
			if ( StructKeyExists( expressionFields, fieldName ) ) {
				configuredFields[ fieldName ] = fieldTypeService.prepareConfiguredFieldData(
					  fieldType          = expressionFields[ fieldName ].fieldType
					, fieldConfiguration = expressionFields[ fieldName ]
					, savedValue         = ( configuredFields[ fieldName ] ?: "" )
				);
			}
		}

		return configuredFields;
	}

	/**
	 * Allows developers to dynamically add a new rules engine condition
	 *
	 */
	public void function addExpression(
		  required string id
		, required string expressionHandler
		,          array  contexts              = []
		,          struct fields                = {}
		,          array  filterObjects         = []
		,          string filterHandler         = ""
		,          string labelHandler          = ""
		,          string textHandler           = ""
		,          struct expressionHandlerArgs = {}
		,          struct filterHandlerArgs     = {}
		,          struct labelHandlerArgs      = {}
		,          struct textHandlerArgs       = {}
	) {
		var expressions = _getExpressions();


		if ( StructKeyExists( expressions, arguments.id ) ) {
			expressions[ arguments.id ].contexts.append( arguments.contexts, true );
			expressions[ arguments.id ].filterObjects.append( arguments.filterObjects, true );
		} else {
			var args = Duplicate( arguments );
			args.delete( "id" );
			expressions[ arguments.id ] = args;
		}

	}

	/**
	 * Returns an array of configured objects that can be filtered by this expression
	 *
	 * @autodoc true
	 * @expressionId.hint ID of the expression whose filterable objects you wish to retrieve
	 */
	public array function getFilterObjectsForExpression( required string expressionId ) {
		var expression = _getRawExpression( expressionId, false );
		return Duplicate( expression.filterObjects ?: [] );
	}

	public string function translateExpressionCategory( required string category ){
		var defaultTranslation = $translateResource( "rules.categories:#arguments.category#", "" );

		if ( defaultTranslation.len() ) {
			return defaultTranslation;
		}

		var poService = $getPresideObjectService();
		if ( poService.objectExists( arguments.category ) ) {
			var baseUri       = poService.getResourceBundleUriRoot( arguments.category );
			var objectNameKey = poService.isPageType( arguments.category ) ? "name" : "title.singular";

			return $translateResource(
				  uri          = "rules.categories:object.category"
				, data         = [ $translateResource( baseUri & objectNameKey, arguments.category ) ]
				, defaultValue = arguments.category
			);
		}

		return arguments.category;
	}

	/**
	 * Method that returns a file path of a file
	 * containing json representation of all expressions for the given object
	 *
	 */
	public string function getExpressionsFile( string context="", string filterObject="", string excludeTags="" ) {
		var fileName   = "";
		var filePath   = GetTempDirectory();
		var locale     = $i18n.getFwLocale();
		var roleLimits = getObjectFieldsExpressionRoleLimits( arguments.filterObject );
		var userRoles  = StructCount( roleLimits ) ? _getAdminUserRoles() : [];
		var suffix     = arguments.excludeTags;

		if ( StructCount( roleLimits ) && ArrayLen( userRoles ) ) {
			suffix &= ArrayToList( userRoles );
		}

		if ( Len( arguments.context ) ) {
			fileName = "conditionexpressions-#locale#-#arguments.context#-#Hash( suffix )#.json"
		} else {
			fileName = "filterexpressions-#locale#-#arguments.filterObject#-#Hash( suffix )#.json"
		}
		filePath &= fileName;

		variables._generatedExpressionFiles = variables._generatedExpressionFiles ?: {};
		if ( !StructKeyExists( variables._generatedExpressionFiles, fileName ) || !FileExists( filePath ) ) {
			var expressions = listExpressions( argumentCollection=arguments, roleLimits=roleLimits, userRoles=userRoles );
			FileWrite( filePath, SerializeJson( expressions ) );
			variables._generatedExpressionFiles[ fileName ] = true;
		}

		return filePath;
	}

	public struct function getObjectFieldsExpressionRoleLimits(
		  required string objectName
		,          string structKeyPreffix = ""
	) {
		if ( !Len( Trim( arguments.objectName ) ) ) {
			return {};
		}

		var cache    = _getRulesEngineExpressionCache();
		var cachekey = "autoExpressionRoleLimits" & "_" & arguments.structKeyPreffix & "_" & arguments.objectName;

		if ( StructKeyExists( cache, cacheKey ) ) {
			return cache[ cacheKey ];
		}

		var roleLimit  = {};
		var properties = $getPresideObjectService().getObjectProperties( arguments.objectName );

		for ( var prop in properties ) {
			var propertyDefinition = properties[ prop ];
			var propertyName       = propertyDefinition.name;
			var roleLimitKey       = "#arguments.structKeyPreffix##arguments.objectName#.#propertyName#";

			if ( len( propertyDefinition.relatedTo ?: "" ) && $helpers.isTrue( propertyDefinition.autoGenerateFilterExpressions ?: "" ) ) {
				roleLimit[ roleLimitKey ] = roleLimit[ roleLimitKey ] ?: {};
				structAppend( roleLimit, getObjectFieldsExpressionRoleLimits(
					  objectName       = propertyDefinition.relatedTo
					, structKeyPreffix = arguments.objectName & propertyDefinition.relatedTo
				) );
			}

			for ( var definition in structKeyArray( propertyDefinition ) ) {
				if ( reFindNoCase( "^autoFilterExpressions:(.*)", definition ) ) {
					roleLimit[ roleLimitKey ] = roleLimit[ roleLimitKey ] ?: {};
					roleLimit[ roleLimitKey ][ replaceNoCase( definition, "autoFilterExpressions:", "" ) ] = listToArray( propertyDefinition[ definition ] );
				}
			}
		}

		cache[ cacheKey ] = roleLimit;
		return roleLimit;
	}

// PRIVATE HELPERS
	private boolean function _findListItemInArray( required array array, required string list ) {
		for( var listItem in listToArray( arguments.list ) ) {
			if ( arguments.array.contains( listItem ) ) {
				return true;
			}
		}
		return false;
	}

	private struct function _getRawExpression( required string expressionid, boolean throwOnMissing=true ) {
		var expressions = _getExpressions();

		if ( StructKeyExists( expressions, arguments.expressionId ) ) {
			return expressions[ arguments.expressionId ];
		}

		if ( !arguments.throwOnMissing ) {
			return {};
		}

		throw( type="preside.rule.expression.not.found", message="The expression [#arguments.expressionId#] could not be found." );
	}

	private void function _lazyLoadDynamicExpressions( string context="", string filterObject="" ) {
		variables._lazyLoadDone = variables._lazyLoadDone ?: {};

		var objects = [];
		var contextService = _getContextService();

		if ( Len( Trim( arguments.filterObject ) ) ) {
			objects.append( arguments.filterObject );
		}
		if ( Len( Trim( arguments.context ) ) ) {
			var contextObjects = contextService.getContextObject( arguments.context, true );
			if ( contextObjects.len() ) {
				objects.append( contextObjects, true );
			}
		}

		for( var objectName in objects ) {
			if ( !StructKeyExists( variables._lazyLoadDone, objectName ) ) {
				var expressions = _getAutoExpressionGenerator().getAutoExpressionsForObject( objectName );
				if ( expressions.len() ) {
					contextService.addContext( id="presideobject_" & objectName, object=objectName, visible=false );
					for( var expression in expressions ) {
						addExpression( argumentCollection=expression );
					}
				}
				variables._lazyLoadDone[ objectName ] = true;
			}
		}
	}

	private array function _getAdminUserRoles( string adminUserId=$getAdminLoginService().getLoggedInUserId() ) {
		if ( !$getAdminLoginService().isSystemUser() ) {
			return $getAdminPermissionService().listUserGroupsRoles( userId=arguments.adminUserId );
		}

		return [];
	}

// GETTERS AND SETTERS
	private struct function _getExpressions() {
		return _expressions;
	}
	private void function _setExpressions( required struct expressions ) {
		_expressions = arguments.expressions;
	}

	private any function _getFieldTypeService() {
		return _fieldTypeService;
	}
	private void function _setFieldTypeService( required any fieldTypeService ) {
		_fieldTypeService = arguments.fieldTypeService;
	}

	private any function _getContextService() {
		return _contextService;
	}
	private void function _setContextService( required any contextService ) {
		_contextService = arguments.contextService;
	}

	private struct function _getRulesEngineExpressionCache() {
		return _rulesEngineExpressionCache;
	}
	private void function _setRulesEngineExpressionCache( required struct rulesEngineExpressionCache ) {
		_rulesEngineExpressionCache = arguments.rulesEngineExpressionCache;
	}

	private any function _getI18n() {
		return _i18n;
	}
	private void function _setI18n( required any i18n ) {
		_i18n = arguments.i18n;
	}

	private any function _getAutoExpressionGenerator() {
		return _autoExpressionGenerator;
	}
	private void function _setAutoExpressionGenerator( required any autoExpressionGenerator ) {
		_autoExpressionGenerator = arguments.autoExpressionGenerator;
	}
}