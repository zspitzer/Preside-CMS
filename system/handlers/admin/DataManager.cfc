component extends="preside.system.base.AdminHandler" {

	property name="presideObjectService"             inject="presideObjectService";
	property name="multilingualPresideObjectService" inject="multilingualPresideObjectService";
	property name="cloningService"                   inject="presideObjectCloningService";
	property name="dataManagerService"               inject="dataManagerService";
	property name="batchOperationService"            inject="dataManagerBatchOperationService";
	property name="customizationService"             inject="dataManagerCustomizationService";
	property name="dataExportService"                inject="dataExportService";
	property name="dataExportTemplateService"        inject="dataExportTemplateService";
	property name="scheduledExportService"           inject="scheduledExportService";
	property name="formsService"                     inject="formsService";
	property name="siteService"                      inject="siteService";
	property name="versioningService"                inject="versioningService";
	property name="rulesEngineFilterService"         inject="rulesEngineFilterService";
	property name="dtHelper"                         inject="jqueryDatatablesHelpers";
	property name="messageBox"                       inject="messagebox@cbmessagebox";
	property name="sessionStorage"                   inject="sessionStorage";
	property name="applicationsService"              inject="applicationsService";
	property name="loginService"                     inject="loginService";

	public void function preHandler( event, action, eventArguments ) {
		super.preHandler( argumentCollection = arguments );

		if ( !isFeatureEnabled( "datamanager" ) ) {
			event.notFound();
		}

		_loadCommonVariables( argumentCollection=arguments );
		if ( !ReFindNoCase( "action$", arguments.action ) ) {
			_loadCommonBreadCrumbs( argumentCollection=arguments );
			_loadTopRightButtons( argumentCollection=arguments );
			_overrideAdminLayout( argumentCollection=arguments );
		}
	}

	public void function index( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="navigate" );

		prc.objectGroups = dataManagerService.getGroupedObjects();

		prc.pageIcon  = "database";
		prc.pageTitle = translateResource( "cms:datamanager" );
	}

	public void function object( event, rc, prc ) {
		var objectName        = prc.objectName        ?: "";
		var objectTitle       = prc.objectTitlePlural ?: "";
		var objectDescription = prc.objectDescription ?: "";
		var args              = { objectName=objectName };

		prc.pageTitle       = objectTitle;
		prc.pageSubTitle    = objectDescription;

		prc.preRenderListing  = ( customizationService.objectHasCustomization( objectName, "preRenderListing"  ) ? customizationService.runCustomization( objectName=objectName, action="preRenderListing"  , args=args ) : "" );
		prc.postRenderListing = ( customizationService.objectHasCustomization( objectName, "postRenderListing" ) ? customizationService.runCustomization( objectName=objectName, action="postRenderListing" , args=args ) : "" );

		prc.listingView = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "listingViewlet"
			, defaultHandler = "admin.DataManager._objectListingViewlet"
			, args           = {
				  objectName          = objectName
				, gridFields          = prc.gridFields          ?: _getObjectFieldsForGrid( objectName )
				, sortableFields      = prc.sortableFields      ?: _getObjectSortableFields( objectName )
				, hiddenGridFields    = prc.hiddenGridFields    ?: []
				, batchEditableFields = prc.batchEditableFields ?: []
				, isMultilingual      = IsTrue( prc.isMultilingual ?: "" )
				, draftsEnabled       = IsTrue( prc.draftsEnabled  ?: "" )
				, canDelete           = IsTrue( prc.canDelete      ?: "" )
				, canBatchDelete      = IsTrue( prc.canBatchDelete ?: "" )
			}
		);
	}

	private string function _objectListingViewlet( event, rc, prc, args={} ) {
		var objectName  = args.objectName ?: "";
		var listing     = "";

		args.usesTreeView = IsTrue( args.usesTreeView ?: dataManagerService.usesTreeView( objectName ) );
		args.treeOnly     = args.usesTreeView && IsTrue( args.treeOnly ?: "" );

		if ( args.usesTreeView && !args.treeOnly ) {
			var defaultTab = sessionStorage.getVar( name="_datamanagerTabForObject#objectName#", default="tree" );
			var actualTab  = rc.tab ?: defaultTab;

			args.treeView = actualTab != "grid";
			sessionStorage.setVar( "_datamanagerTabForObject#objectName#", actualTab );
		} else {
			args.treeView = args.treeOnly;
		}

		args.append( {
			  gridFields          = args.gridFields          ?: _getObjectFieldsForGrid( objectName )
			, hiddenGridFields    = args.hiddenGridFields    ?: _getObjectHiddenFieldsForGrid( objectName )
			, sortableFields      = args.sortableFields      ?:  _getObjectSortableFields( objectName )
			, batchEditableFields = args.batchEditableFields ?: dataManagerService.listBatchEditableFields( objectName )
			, isMultilingual      = IsTrue( args.isMultilingual ?: multilingualPresideObjectService.isMultilingual( objectName ) )
			, draftsEnabled       = IsTrue( args.draftsEnabled  ?: datamanagerService.areDraftsEnabledForObject( objectName ) )
			, canDelete           = IsTrue( args.canDelete      ?: _checkPermission( argumentCollection=arguments, object=objectName, key="delete", throwOnError=false ) )
			, footerEnabled       = StructKeyExists( args, "footerEnabled" ) && !IsTrue( args.footerEnabled ) ? args.footerEnabled : customizationService.objectHasCustomization( objectName, "renderFooterForGridListing" )
		} );

		args.allowFilter = IsTrue( args.allowFilter ?: true ) && isFeatureEnabled( "rulesengine" );
		if ( args.allowFilter ) {
			args.allowUseFilter    = isTrue( args.allowUseFilter    ?: true ) && _checkPermission( argumentCollection=arguments, key="usefilters"   , object=objectName, throwOnError=false );
			args.allowManageFilter = isTrue( args.allowManageFilter ?: true ) && _checkPermission( argumentCollection=arguments, key="managefilters", object=objectName, throwOnError=false );

			if ( args.allowManageFilter ) {
				args.manageFilterLink = event.buildAdminLink( objectName=objectName, operation="manageFilters" );
			}
		}

		if ( args.treeView ) {
			listing = renderViewlet( event="admin.datamanager._treeView", args=args );

		} else {
			if ( !IsBoolean( args.useMultiActions ?: "" ) || args.useMultiActions ) {
				args.multiActions = customizationService.runCustomization(
					  objectName     = objectName
					, action         = "listingMultiActions"
					, defaultHandler = "admin.datamanager._listingMultiActions"
					, args           = args
				);

				args.append( {
					  useMultiActions = args.multiActions.len()
					, multiActionUrl  = event.buildAdminLink( objectName=objectName, operation="multiRecordAction" )
				} );
			}

			var dataExportPermKey = dataManagerService.getDataExportPermissionKey( objectName );
			args.allowDataExport  = IsTrue( args.allowDataExport ?: true ) && dataManagerService.isDataExportEnabled( objectName ) && _checkPermission( argumentCollection=arguments, object=objectName, key=dataExportPermKey, throwOnError=false );

			var saveExportPermKey = dataManagerService.getSaveExportPermissionKey( objectName );
			args.allowSaveExport = isTrue( args.allowDataExport ) && _checkPermission( argumentCollection=arguments, object=objectName, key=saveExportPermKey, throwOnError=false );

			if ( args.allowSaveExport ) {
				args.savedExportCount = dataExportService.getSavedExportCountForObject( objectName );
				if ( args.savedExportCount ) {
					args.savedExportsLink = event.buildAdminLink( objectName="saved_export", operation="listing", queryString="object_name=#args.objectName#" );
				}
			}

			if ( customizationService.objectHasCustomization( objectName, "getAdditionalQueryStringForBuildAjaxListingLink" ) ) {
				args.exportFilterString = customizationService.runCustomization(
					  objectName = objectName
					, action     = "getAdditionalQueryStringForBuildAjaxListingLink"
					, args       = args
				);
			}

			listing = renderView( view="/admin/datamanager/_objectDataTable", args=args );
		}

		if ( args.usesTreeView && !args.treeOnly ) {
			args.content = listing;
			listing = renderView( view="/admin/datamanager/_treeGridSwitcher", args=args );
		}

		return listing;
	}

	private string function _listingMultiActions( event, rc, prc, args={} ) {
		var actions = customizationService.runCustomization(
			  objectName     = args.objectName ?: ""
			, action         = "getListingMultiActions"
			, defaultHandler = "admin.datamanager._getListingMultiActions"
			, args           = args
		);

		if ( actions.len() ) {
			return renderView( view="/admin/datamanager/_listingMultiActions", args=args );
		}

		return "";
	}

	private string function _selectAllControl( event, rc, prc, args={} ){
		if ( datamanagerService.canBatchSelectAll( args.objectName ?: "" ) ) {
			return renderView( view="/admin/datamanager/_selectAllControl", args=args );
		}

		return "";
	}

	private array function _getListingMultiActions( event, rc, prc, args={} ) {
		var objectName  = args.objectName ?: "";
		var objectTitle = prc.objectTitlePlural ?: "";

		args.actions             = [];
		args.batchEditableFields = [];

		if ( objectName == ( prc.objectName ?: "" ) ) {
			args.batchEditableFields = prc.batchEditableFields ?: [];
		} else {
			args.batchEditableFields = dataManagerService.listBatchEditableFields( objectName );

			objectTitle = translateResource( uri="preside-objects.#objectName#:title" );
		}

		if ( ArrayLen( args.batchEditableFields ) ) {
			args.actions.append( renderView( view="/admin/datamanager/_batchEditMultiActionButton", args=args ) );
		}

		args.batchCustomActions = customizationService.runCustomization(
			  objectName = objectName
			, action     = "getListingBatchActions"
			, args       = args
		);

		announceInterception( "onGetListingBatchActions", args );

		if ( isArray( args.batchCustomActions ?: "" ) && arrayLen( args.batchCustomActions ) ) {
			arrayAppend( args.actions, renderView( view="/admin/datamanager/_batchCustomMultiActionButton", args=args ) );
		}

		if ( IsTrue( args.canDelete ?: ( prc.canDelete ?: "" ) ) && IsTrue( args.canBatchDelete ?: ( prc.canBatchDelete ?: "" ) ) ) {
			var typeToConfirm = dataManagerService.useTypedConfirmationForBatchDeletion( objectName );
			args.actions.append({
				  class     = "btn-danger"
				, label     = translateResource( uri="cms:datamanager.deleteSelected.title" )
				, prompt    = translateResource( uri="cms:datamanager.deleteSelected.prompt", data=[ objectTitle ] )
				, iconClass = "fa-trash-o"
				, name      = "delete"
				, globalKey = "d"
				, match     = typeToConfirm ? datamanagerService.getBatchDeletionConfirmationMatch( objectName ) : ""
			});
		}

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getExtraListingMultiActions"
			, args           = args
		);

		announceInterception( "postGetExtraListingMultiActions", args );

		return args.actions;
	}

	public void function viewRecord( event, rc, prc ) {
		var objectName      = prc.objectName ?: "";
		var recordId        = prc.recordId   ?: ""
		var version         = Val( prc.version ?: "" );
		var language        = rc.language     ?: "";
		var objectTitle     = prc.objectTitle ?: "";
		var recordLabel     = prc.recordLabel ?: "";
		var canTranslate    = IsTrue( prc.canTranslate    ?: "" );
		var useVersioning   = IsTrue( prc.useVersioning   ?: "" );
		var canViewVersions = IsTrue( prc.canViewVersions ?: "" );

		_checkPermission( argumentCollection=arguments, key="read", object=objectName );

		prc.pageTitle    = translateResource( uri="cms:datamanager.viewrecord.page.title"   , data=[ objectTitle ] );
		prc.pageSubtitle = translateResource( uri="cms:datamanager.viewrecord.page.subtitle", data=[ recordLabel ] );

		if ( language.len() ) {
			prc.language = multilingualPresideObjectService.getLanguage( language );

			if ( prc.language.isempty() ) {
				messageBox.error( translateResource( uri="cms:multilingual.language.not.active.error" ) );
				setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="viewRecord", recordId=recordId ) );
			}
			event.setLanguage( language );
			prc.delete( "record" );
			version = rc.version = prc.version = Val( url.version ?: "" );
		}

		if ( useVersioning && canViewVersions ) {
			prc.versionNavigator = customizationService.runCustomization(
				  objectName     = objectName
				, action         = "versionNavigator"
				, defaultHandler = "admin.datamanager.versionNavigator"
				, args = {
					  object  = objectName
					, id      = recordId
					, version = rc.version ?: ""
					, isDraft = IsTrue( prc.record._version_is_draft ?: "" )
					, baseUrl = event.buildAdminLink( objectName=objectName, recordId=id, operation='viewRecord', args={ version="{version}" } )
				  }
			);
		}

		prc.renderedRecord = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "renderRecord"
			, defaultHandler = "admin.dataHelpers.viewRecord"
			, args           = { objectName= objectName, recordId=recordId, version=version }
		);
	}

	public void function addRecord( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="add" );

		var objectName          = prc.objectName ?: "";
		var objectTitleSingular = prc.objectTitle ?: "";
		var addRecordTitle      = translateResource( uri="cms:datamanager.addrecord.title", data=[  objectTitleSingular  ] );

		prc.pageIcon      = "plus";
		prc.pageTitle     = addRecordTitle;
		prc.addRecordForm = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "addRecordForm"
			, defaultHandler = "admin.datamanager._addRecordForm"
			, args = {
				  objectName      = objectName
				, addRecordAction = event.buildAdminLink( objectName=objectName, operation="addRecordAction" )
				, draftsEnabled   = IsTrue( prc.draftsEnabled ?: "" )
				, canSaveDraft    = IsTrue( prc.canSaveDraft  ?: "" )
				, canPublish      = IsTrue( prc.canPublish    ?: "" )
			  }
		);

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.addrecord.breadcrumb.title", data=[ objectTitleSingular ] )
			, link  = ""
		);
	}

	public void function addRecordAction( event, rc, prc ) {
		var objectName = prc.objectName ?: "";

		_checkPermission( argumentCollection=arguments, key="add" );

		if ( customizationService.objectHasCustomization( objectName, "addRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "addRecordAction"
				, args       = { objectName=objectName }
			);
		} else {
			runEvent(
				  event          = "admin.DataManager._addRecordAction"
				, prePostExempt  = true
				, private        = true
				, eventArguments = { audit=true }
			);
		}
	}

	public void function editRecord( event, rc, prc ) {
		var objectName    = prc.objectName ?: "";
		var recordId      = prc.recordId   ?: "";
		var canTranslate  = IsTrue( prc.canTranslate  ?: "" );
		var resultAction  = rc.resultAction ?: "";
		var useVersioning = IsTrue( prc.useVersioning ?: "" );

		_checkPermission( argumentCollection=arguments, key="edit" );

		prc.record = queryRowToStruct( prc.record );
		if ( prc.canTranslate ) {
			prc.translations = multilingualPresideObjectService.getTranslationStatus( objectName, recordId );
		}

		if ( resultAction == "grid" || !datamanagerService.isOperationAllowed( objectName, "read" ) ) {
			prc.cancelAction = event.buildAdminLink( objectName=objectName );
		} else {
			prc.cancelAction = event.buildAdminLink( objectName=objectName, operation="viewRecord", recordId=recordId );
		}

		if ( useVersioning ) {
			prc.versionNavigator = customizationService.runCustomization(
				  objectName     = objectName
				, action         = "versionNavigator"
				, defaultHandler = "admin.datamanager.versionNavigator"
				, args = {
					  object  = objectName
					, id      = recordId
					, version = rc.version ?: ""
					, isDraft = IsTrue( prc.record._version_is_draft ?: "" )
				  }
			);
		}

		prc.editRecordForm = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "editRecordForm"
			, defaultHandler = "admin.datamanager._editRecordForm"
			, args = {
				  objectName       = objectName
				, editRecordAction = event.buildAdminLink( objectName=objectName, operation="editRecordAction" )
				, recordId         = prc.recordId ?: ""
				, useVersioning    = useVersioning
				, draftsEnabled    = IsTrue( prc.draftsEnabled ?: "" )
				, canSaveDraft     = IsTrue( prc.canSaveDraft  ?: "" )
				, canPublish       = IsTrue( prc.canPublish    ?: "" )
				, cancelAction     = prc.cancelAction ?: ""
				, version          = ( rc.version ?: "" )
				, record           = prc.record
			  }
		);

		var recordLabel         = prc.recordLabel ?: "";
		var objectTitleSingular = prc.objectTitle ?: ""
		var editRecordTitle     = translateResource( uri="cms:datamanager.editrecord.title", data=[  objectTitleSingular , recordLabel ] );

		prc.pageIcon  = "pencil";
		prc.pageTitle = editRecordTitle;
		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.editrecord.breadcrumb.title" )
			, link  = ""
		);
	}

	public void function editRecordAction( event, rc, prc ) {
		var objectName    = prc.objectName ?: "";
		var recordId      = prc.recordId   ?: "";

		_checkPermission( argumentCollection=arguments, key="edit" );

		var successUrl = "";
		var resultAction = rc.__resultAction ?: "";

		if ( resultAction == "grid" || !datamanagerService.isOperationAllowed( objectName, "read" ) ) {
			successUrl = event.buildAdminLink( objectName=objectName );
		} else {
			successUrl = event.buildAdminLink( objectName=objectName, operation="viewRecord", recordId=recordId );
		}

		if ( customizationService.objectHasCustomization( objectName, "editRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "editRecordAction"
				, args       = { objectName=objectName, recordId=recordId }
			);
		} else {
			runEvent(
				  event          = "admin.DataManager._editRecordAction"
				, prePostExempt  = true
				, private        = true
				, eventArguments = {
					  audit         = true
					, successUrl    = successUrl
				  }
			);
		}
	}

	public void function cloneRecord( event, rc, prc ) {
		var objectName    = prc.objectName ?: "";
		var recordId      = prc.recordId   ?: "";

		_checkPermission( argumentCollection=arguments, key="clone" );

		prc.record          = queryRowToStruct( prc.record );
		prc.cancelAction    = event.buildAdminLink( objectName=objectName, recordId=recordId )
		prc.cloneRecordForm = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "cloneRecordForm"
			, defaultHandler = "admin.datamanager._cloneRecordForm"
			, args = {
				  objectName        = objectName
				, cloneRecordAction = event.buildAdminLink( objectName=objectName, operation="cloneRecordAction" )
				, recordId          = prc.recordId ?: ""
				, draftsEnabled     = IsTrue( prc.draftsEnabled ?: "" )
				, canSaveDraft      = IsTrue( prc.canSaveDraft  ?: "" )
				, canPublish        = IsTrue( prc.canPublish    ?: "" )
				, cancelAction      = prc.cancelAction ?: ""
				, record            = prc.record
			  }
		);

		var recordLabel         = prc.recordLabel ?: "";
		var objectTitleSingular = prc.objectTitle ?: ""
		var cloneRecordTitle     = translateResource( uri="cms:datamanager.clonerecord.title", data=[  objectTitleSingular , recordLabel ] );

		prc.pageIcon  = "pencil";
		prc.pageTitle = cloneRecordTitle;
		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.clonerecord.breadcrumb.title" )
			, link  = ""
		);
	}

	public void function cloneRecordAction( event, rc, prc ) {
		var objectName = prc.objectName ?: "";
		var recordId   = prc.recordId   ?: "";

		_checkPermission( argumentCollection=arguments, key="clone" );

		if ( customizationService.objectHasCustomization( objectName, "cloneRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "cloneRecordAction"
				, args       = { objectName=objectName, recordId=recordId }
			);
		} else {
			var eventArguments = { audit=true };

			if ( structKeyExists( arguments, "formName" ) ) {
				eventArguments.formName = arguments.formName;
			}

			runEvent(
				  event          = "admin.DataManager._cloneRecordAction"
				, prePostExempt  = true
				, private        = true
				, eventArguments = eventArguments
			);
		}
	}

	public void function deleteRecordAction( event, rc, prc, batch=false, batchAll=false, batchSrcArgs={} ) {
		var objectName = prc.objectName ?: "";
		var recordId   = prc.recordId ?: "";

		_checkPermission( argumentCollection=arguments, key="delete", object=objectName );

		if ( customizationService.objectHasCustomization( objectName, "deleteRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "deleteRecordAction"
				, args       = { objectName=objectName, recordId=recordId, batch=arguments.batch, batchAll=arguments.batchAll, batchSrcArgs=arguments.batchSrcArgs }
			);
		} else {
			runEvent(
				  event          = "admin.DataManager._deleteRecordAction"
				, prePostExempt  = true
				, private        = true
				, eventArguments = {
					  audit        = true
					, batch        = arguments.batch
					, batchAll     = arguments.batchAll
					, batchSrcArgs = arguments.batchSrcArgs
				  }
			);
		}
	}

	public void function flagRecordAction( event, rc, prc, args={} ) {
		var objectName = rc.object ?: "";
		var recordId   = rc.id     ?: "";
		var resultView = rc.result ?: "";
		var successUrl = event.buildAdminLink( objectName=objectName );
		var updated    = false;

		_checkPermission( argumentCollection=arguments, key="edit", object=objectName );
		if ( !isFlaggingEnabled( objectName=objectName ) ) {
			event.adminAccessDenied();
		}

		if ( resultView == "detail" ) {
			successUrl = event.buildAdminLink( objectName=objectName, recordId=recordId, operation="viewRecord" );
		}

		if ( !isEmpty( objectName ) && !isEmpty( recordId ) ) {
			var recordIsFlagged = presideObjectService.recordIsFlagged( objectName=objectName, recordId=recordId );
			var objFlagField    = presideObjectService.getFlagField( objectName=objectName );

			updated = presideObjectService.updateData(
				  objectName = objectName
				, id         = recordId
				, data       = { "#objFlagField#"=!recordIsFlagged }
			);
		}

		if ( isTrue( updated ) ) {
			messageBox.info( translateResource(
				  uri = "cms:datamanager.record#recordIsFlagged ? "un" : ""#flagged.confirmation"
				, data = [ renderLabel( objectName, recordId ) ]
			) );
		} else {
			messageBox.info( translateResource( uri="cms:datamanager.recordFlagged.error" ) );
		}

		setNextEvent( url=successUrl );
	}

	public void function cascadeDeletePrompt( event, rc, prc ) {
		var objectName = prc.objectName ?: "";

		prc.id       = prc.recordId ?: "";
		prc.blockers = rc.blockers  ?: {};

		_checkPermission( argumentCollection=arguments, key="delete", object=objectName );

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.cascadeDelete.breadcrumb.title" )
			, link  = ""
		);

		prc.pageIcon  = "trash";
		prc.pageTitle = translateResource( uri="cms:datamanager.cascadeDelete.title" );
	}

	public void function multiRecordAction( event, rc, prc ) {
		var objectName   = prc.objectName ?: "";
		var action       = rc.multiAction ?: "";
		var ids          = prc.recordId   ?: "";
		var listingUrl   = "";
		var batchAll     = isTrue( rc.batchAll ?: "" );
		var batchSrcArgs = {};

		if ( Len( Trim( rc.postAction ?: "" ) ) ) {
			listingUrl = event.buildAdminLink( linkto=rc.postAction, queryString="id=#objectName#" );
		} else {
			listingUrl = event.buildAdminLink( objectName=objectName );
		}

		if ( batchAll ) {
			batchSrcArgs = _deserializeSourceStringForBatchOperations( argumentCollection=arguments, listingUrl=listingUrl );
		} else if ( !Len( Trim( ids ) ) ) {
			messageBox.error( translateResource( "cms:datamanager.norecordsselected.error" ) );
			setNextEvent( url=listingUrl );
		}

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "multiRecordAction"
			, args           = {
				  action       = action
				, ids          = ListToArray( ids )
				, objectName   = objectName
				, batchAll     = batchAll
				, batchSrcArgs = batchSrcArgs
			  }
		);

		switch( action ){
			case "batchUpdate":
				setNextEvent(
					  url           = event.buildAdminLink( objectName=objectName, operation="batchEditField", queryString="field=#( rc.field ?: '' )#" )
					, persistStruct = { id=ids, batchAll=batchAll, batchSrcArgs=( rc.batchSrcArgs ?: "" ) }
				);
			break;
			case "delete":
				return deleteRecordAction(
					  argumentCollection = arguments
					, batch              = true
					, batchAll           = batchAll
					, batchSrcArgs       = batchSrcArgs
				);
			break;
			default:
				if ( getController().viewletExists( "admin.datamanager.#objectName#.#action#BatchAction" ) ) {
					setNextEvent(
						  url           = event.buildAdminLink( linkto="datamanager.#objectName#.#action#BatchAction" )
						, persistStruct = { ids=ids, batchAll=batchAll, batchSrcArgs=batchSrcArgs }
					);
				}
				break;
		}

		messageBox.error( translateResource( "cms:datamanager.invalid.multirecord.action.error" ) );
		setNextEvent( url=listingUrl );
	}

	public void function batchEditField( event, rc, prc ) {
		var objectName   = prc.objectName  ?: "";
		var objectTitle  = prc.objectTitle ?: "";
		var ids          = prc.recordId    ?: "";
		var batchAll     = isTrue( rc.batchAll    ?: "" );
		var batchSrcArgs = {};
		var field        = rc.field        ?: "";
		var formControl  = {};
		var recordCount  = ListLen( Trim( ids ) );
		var fieldName    = translateResource( uri="#presideObjectService.getResourceBundleUriRoot( objectName )#field.#field#.title", defaultValue=field );
		var listingView  = event.buildAdminLink( objectName=objectName, operation="listing" );

		_checkPermission( argumentCollection=arguments, key="edit", object=objectName );

		if ( batchAll ) {
			batchSrcArgs = _deserializeSourceStringForBatchOperations( argumentCollection=arguments, listingView=listingView );
			recordCount  = batchOperationService.getBatchSourceRecordCount( objectName, batchSrcArgs );
		} else if ( !recordCount ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectTitle  ] ) );
			setNextEvent( url=listingView );
		}

		prc.fieldFormControl = formsService.renderFormControlForObjectField(
		      objectName = objectName
		    , fieldName  = field
		);

		if ( presideObjectService.isManyToManyProperty( objectName, field ) ) {
			prc.multiEditBehaviourControl = renderFormControl(
				  type   = "select"
				, name   = "multiValueBehaviour"
				, label  = translateResource( uri="cms:datamanager.multiValueBehaviour.title" )
				, values = [ "append", "overwrite", "delete" ]
				, labels = [ translateResource( uri="cms:datamanager.multiDataAppend.title" ), translateResource( uri="cms:datamanager.multiDataOverwrite.title" ), translateResource( uri="cms:datamanager.multiDataDeleteSelected.title" ) ]
			);

			prc.batchEditWarning = translateResource(
				  uri  = "cms:datamanager.batch.edit.warning.multi.value" & ( batchAll ? ".filtered" : "" )
				, data = [ "<strong>#objectTitle#</strong>", "<strong>#fieldName#</strong>", "<strong>#NumberFormat( recordCount )#</strong>" ]
			);
		} else {
			prc.batchEditWarning = translateResource(
				  uri  = "cms:datamanager.batch.edit.warning" & ( batchAll ? ".filtered" : "" )
				, data = [ "<strong>#objectTitle#</strong>", "<strong>#fieldName#</strong>", "<strong>#NumberFormat( recordCount )#</strong>" ]
			);
		}

		prc.pageTitle    = translateResource( uri="cms:datamanager.batchEdit.page.title" & ( batchAll ? ".filtered" : "" ), data=[ objectTitle, NumberFormat( recordCount ) ] );
		prc.pageSubtitle = translateResource( uri="cms:datamanager.batchEdit.page.subtitle", data=[ fieldName ] );
		prc.pageIcon     = "pencil";

		var args = {
			  ids          = ids
			, batchAll     = batchAll
			, batchSrcArgs = batchSrcArgs
			, recordCount  = recordCount
			, object       = objectName
			, field        = field
		}

		if ( customizationService.objectHasCustomization( objectName, "preRenderBatchEditRecordsForm" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "preRenderBatchEditRecordsForm"
				, args       = args
			);
		}

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.batchedit.breadcrumb.title", data=[ objectTitle, fieldName ] )
			, link  = ""
		);

		prc.batchAll    = batchAll;
		prc.recordCount = recordCount;

		event.setView( view="/admin/datamanager/batchEditField" );
	}

	public void function batchEditAction( event, rc, prc ) {
		var updateField = rc.updateField  ?: "";
		var objectName  = prc.objectName  ?: "";
		var objectTitle = prc.objectTitle ?: "";
		var sourceIds   = ListToArray( Trim( rc.sourceIds ?: "" ) );
		var listingView = event.buildAdminLink( objectName=objectName, operation="listing" );
		var batchAll    = isTrue( rc.batchAll ?: "" );
		var batchSrcArgs = {};

		_checkPermission( argumentCollection=arguments, key="edit", object=objectName );
		if ( batchAll ) {
			batchSrcArgs = _deserializeSourceStringForBatchOperations( argumentCollection=arguments, listingView=listingView );
		} else if ( !sourceIds.len() ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectTitle ] ) );
			setNextEvent( url=listingView );
		}

		var args = {
			  objectName         = objectName
			, fieldName          = updateField
			, sourceIds          = sourceIds
			, batchAll           = batchAll
			, batchSrcArgs       = batchSrcArgs
			, value              = rc[ updateField ]      ?: ""
			, multiEditBehaviour = rc.multiValueBehaviour ?: "append"
			, userId             = event.getAdminUserId()
			, returnUrl          = listingView
			, resultUrl          = listingView
		};

		if ( customizationService.objectHasCustomization( objectName, "preBatchEditRecordsInBgThread" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "preBatchEditRecordsInBgThread"
				, args       = args
			);
		}

		var taskId = createTask(
			  event                = "admin.datamanager.batchEditInBgThread"
			, runNow               = true
			, adminOwner           = event.getAdminUserId()
			, title                = "cms:datamanager.batchedit.task.title"
			, returnUrl            = args.returnUrl
			, resultUrl            = args.resultUrl
			, discardAfterInterval = CreateTimeSpan( 0, 0, 5, 0 )
			, args                 = args
		);

		setNextEvent( url=event.buildAdminLink(
			  linkTo      = "adhoctaskmanager.progress"
			, queryString = "taskId=" & taskId
		) );
	}

	private boolean function batchEditInBgThread( event, rc, prc, args={}, logger, progress ) {
		return batchOperationService.batchEditField(
			  objectName         = args.objectName         ?: ""
			, fieldName          = args.fieldName          ?: ""
			, sourceIds          = args.sourceIds          ?: []
			, batchAll           = IsTrue( args.batchAll   ?: "" )
			, batchSrcArgs       = args.batchSrcArgs        ?: {}
			, value              = args.value              ?: ""
			, multiEditBehaviour = args.multiEditBehaviour ?: "append"
			, auditUserId        = args.userId             ?: ""
			, logger             = arguments.logger   ?: NullValue()
			, progress           = arguments.progress ?: NullValue()
		);
	}

	public void function recordHistory( event, rc, prc ) {
		var objectName    = prc.objectName  ?: "";
		var objectTitle   = prc.objectTitle ?: "";
		var recordId      = prc.recordId    ?: "";
		var useVersioning = IsTrue( prc.useVersioning ?: "" );

		_checkPermission( argumentCollection=arguments, key="viewversions", object=objectName );

		if ( !useVersioning ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNot.error", data=[ objectTitle ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.recordhistory.breadcrumb.title" )
			, link  = ""
		);

		prc.pageIcon  = "history";
		prc.pageTitle = translateResource( uri="cms:datamanager.recordhistory.title", data=[ prc.recordLabel ?: "", prc.objectTitle ?: "" ] );
	}

	public void function translateRecord( event, rc, prc ) {
		var objectName            = prc.objectName  ?: "";
		var id                    = prc.recordId    ?: "";
		var version               = prc.version     ?: "";
		var fromDataGrid          = rc.fromDataGrid ?: "";
		var objectTitle           = prc.objectTitle ?: "";
		var useVersioning         = IsTrue( prc.useVersioning ?: "" );
		var translationObjectName = multilingualPresideObjectService.getTranslationObjectName( objectName );
		var record                = "";

		_checkPermission( argumentCollection=arguments, key="translate" );

		prc.record = queryRowToStruct( prc.record );
		prc.translations = multilingualPresideObjectService.getTranslationStatus( objectName, id );
		prc.formName = "preside-objects.#translationObjectName#.admin.edit";

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.translaterecord.breadcrumb.title", data=[ prc.language.name ] )
			, link  = ""
		);
		if( isTrue( fromDataGrid ) ) {
			prc.cancelAction     = event.buildAdminLink( objectName=objectName, operation="listing" );
			prc.formAction       = event.buildAdminLink( linkTo="datamanager.translateRecordAction", querystring='fromDataGrid=#fromDataGrid#' );
			prc.translateUrlBase = event.buildAdminLink( objectName=objectName, operation="translateRecord", recordId=id, args={ fromDataGrid=fromDataGrid, language='{language}' } );
		}
		prc.pageIcon  = "pencil";
		prc.pageTitle = translateResource( uri="cms:datamanager.translaterecord.title", data=[ objectTitle, prc.recordLabel, prc.language.name ] );
	}

	public void function translateRecordAction( event, rc, prc ) {
		var id                    = prc.recordId    ?: "";
		var objectName            = prc.objectName  ?: "";
		var objectTitle           = prc.objectTitle ?: "";
		var languageId            = rc.language     ?: "";
		var fromDataGrid          = rc.fromDataGrid ?: "";
		var translationObjectName = multilingualPresideObjectService.getTranslationObjectName( objectName );
		var draftsEnabled         = IsTrue( prc.draftsEnabled ?: "" );
		var isDraft               = draftsEnabled && ( rc._saveaction ?: "" ) != "publish";

		_checkPermission( argumentCollection=arguments, key="translate", object=objectName );

		var record = presideObjectService.selectData( objectName=objectName, filter={ id=id } );
		if ( !record.recordCount ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectTitle  ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		var formName = "preside-objects.#translationObjectName#.admin.edit";
		var version  = rc.version ?: "";
		var formData = event.getCollectionForForm( formName=formName, stripPermissionedFields=true, permissionContext=objectName, permissionContextKeys=[] );
		var obj      = "";
		var persist  = "";

		formData._translation_language = languageId;
		formData.id = multilingualPresideObjectService.getExistingTranslationId(
			  objectName   = objectName
			, id           = id
			, languageId   = languageId
		);

		var validationResult = validateForm( formName=formName, formData=formData, stripPermissionedFields=true, permissionContext=objectName, permissionContextKeys=[] );

		if ( !validationResult.validated() ) {
			messageBox.error( translateResource( "cms:datamanager.data.validation.error" ) );
			persist = formData;
			persist.validationResult = validationResult;
			persist.delete( "id" );

			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="translateRecord", args={ fromDataGrid=true, version=version, language=languageId } ), persistStruct=persist );
		}

		multilingualPresideObjectService.saveTranslation(
			  objectName = objectName
			, id         = id
			, data       = formData
			, languageId = languageId
			, isDraft    = isDraft
		);

		var auditAction = "datamanager_translate_record";
		var auditDetail = QueryRowToStruct( record );
		auditDetail.append( { objectName=objectName, languageId=languageId } );
		if ( draftsEnabled ) {
			if ( isDraft ) {
				auditAction = "datamanager_save_draft_translation";
			} else {
				auditAction = "datamanager_publish_translation";
			}
		}

		event.audit(
			  action   = auditAction
			, type     = "datamanager"
			, recordId = id
			, detail   = auditDetail
		);

		messageBox.info( translateResource( uri="cms:datamanager.recordTranslated.confirmation", data=[ objectTitle ] ) );
		if( isTrue( fromDataGrid ) ) {
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		} else {
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="editRecord", recordId=id ) );
		}
	}

	public void function getObjectRecordsForAjaxDataTables( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="read", object=prc.objectName, checkOperations=false );

		runEvent(
			  event          = "admin.DataManager._getObjectRecordsForAjaxDataTables"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  object              = prc.objectName
				, useMultiActions     = IsTrue( rc.useMultiActions ?: "" )
				, gridFields          = ( rc.gridFields          ?: _getObjectFieldsForGrid( objectName ).toList() )
				, isMultilingual      = IsTrue( rc.isMultilingual ?: 'false' )
				, draftsEnabled       = IsTrue( rc.draftsEnabled  ?: 'false' )
				, includeActions      = !IsTrue( rc.noActions ?: "" )
			}
		);
	}

	public void function getChildObjectRecordsForAjaxDataTables( event, rc, prc ) {
		var objectName      = prc.objectName     ?: "";
		var parentId        = rc.parentId        ?: "";
		var relationshipKey = rc.relationshipKey ?: "";

		runEvent(
			  event          = "admin.DataManager._getObjectRecordsForAjaxDataTables"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  object          = objectName
				, useMultiActions = IsTrue( prc.canDelete ?: "" ) || ArrayLen( prc.batchEditableFields ?: [] )
				, gridFields      = ( rc.gridFields ?: _getObjectFieldsForGrid( objectName ).toList() )
				, actionsView     = "/admin/datamanager/_oneToManyListingActions"
				, filter          = { "#relationshipKey#" : parentId }
			}
		);
	}

	public void function getRecordHistoryForAjaxDataTables( event, rc, prc ) {
		var objectName = prc.objectName  ?: "";
		var recordId   = prc.recordId    ?: "";

		_checkPermission( argumentCollection=arguments, key="viewversions" );

		runEvent(
			  event          = "admin.DataManager._getRecordHistoryForAjaxDataTables"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  object     = objectName
				, recordId   = recordId
				, gridFields = ( rc.gridFields ?: 'datemodified,label' )
			}
		);
	}

	public void function getTranslationRecordHistoryForAjaxDataTables( event, rc, prc ) {
		var objectName = prc.objectName ?: "";
		var recordId   = prc.recordId   ?: "";
		var languageId = rc.language    ?: "";

		_checkPermission( argumentCollection=arguments, key="translate" );
		_checkPermission( argumentCollection=arguments, key="viewversions" );

		runEvent(
			  event          = "admin.DataManager._getTranslationRecordHistoryForAjaxDataTables"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  object     = objectName
				, recordId   = recordId
				, languageId = languageId
				, gridFields = ( rc.gridFields ?: 'datemodified,label' )
			}
		);
	}

	public void function getObjectRecordsForAjaxSelectControl( event, rc, prc ) {
		var objectName     = prc.objectName ?: "";
		var extraFilters   = [];
		var filterByFields = ListToArray( rc.filterByField ?: ( rc.filterByFields ?: "" ) );
		var bypassTenants  = listToArray( rc.bypassTenants ?: "" );
		var filterValue    = "";
		var orderBy        = rc.orderBy       ?: "label";
		var labelRenderer  = rc.labelRenderer ?: "";
		var useCache       = IsTrue( rc.useCache ?: "" );
		var defaultValue   = rc.defaultValue  ?: "";

		for( var filterByField in filterByFields ) {
			filterValue = rc[filterByField] ?: "";
			if( !isEmpty( filterValue ) ){
				extraFilters.append({ filter = { "#filterByField#" = listToArray( filterValue ) } });
			}
		}

		var interceptArgs = {
			  objectName   = rc.object ?: ""
			, defaultValue = defaultValue
			, extraFilters = extraFilters
			, savedFilters = ListToArray( rc.savedFilters ?: "" )
		}
		announceInterception( "preGetObjectRecordsForAjaxSelectControlSelect", interceptArgs );

		var records = dataManagerService.getRecordsForAjaxSelect(
			  objectName    = rc.object  ?: ""
			, maxRows       = rc.maxRows ?: 1000
			, searchQuery   = rc.q       ?: ""
			, savedFilters  = interceptArgs.savedFilters
			, extraFilters  = interceptArgs.extraFilters
			, orderBy       = orderBy
			, ids           = ListToArray( rc.values ?: "" )
			, labelRenderer = labelRenderer
			, bypassTenants = bypassTenants
			, useCache      = useCache
			, idField       = rc.targetIdField ?: ""
		);

		event.renderData( type="json", data=records );
	}

	public void function managePerms( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="manageContextPerms" );

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.managePerms.breadcrumb.title" )
			, link  = ""
		);

		prc.pageIcon     = "lock";
		prc.pageTitle    = translateResource( uri="cms:datamanager.manageperms.title", data=[  prc.objectTitle ?: ""  ] );;
		prc.pageSubTitle = translateResource( uri="cms:datamanager.manageperms.subtitle", data=[  prc.objectTitle ?: ""  ] );;
	}

	public void function savePermsAction( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="manageContextPerms" );

		if ( runEvent( event="admin.Permissions.saveContextPermsAction", private=true ) ) {
			event.audit(
				  action   = "edit_datamanager_object_admin_permissions"
				, type     = "datamanager"
				, recordId = prc.objectName
				, detail   = { objectName=prc.objectName }
			);

			messageBox.info( translateResource( uri="cms:datamanager.permsSaved.confirmation", data=[ prc.objectTitle ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, operation="listing" ) );
		}

		messageBox.error( translateResource( uri="cms:datamanager.permsSaved.error", data=[ prc.objectTitle ] ) );
		setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, operation="managePerms" ) );
	}

	public void function translationRecordHistory( event, rc, prc ) {
		var objectName    = prc.objectName  ?: "";
		var recordId      = prc.recordId    ?: "";
		var objectTitle   = prc.objectTitle ?: "";
		var languageId    = rc.language     ?: "";
		var useVersioning = IsTrue( prc.useVersioning ?: "" );

		_checkPermission( argumentCollection=arguments, key="translate"    );
		_checkPermission( argumentCollection=arguments, key="viewversions" );

		if ( !useVersioning ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectTitle  ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.translaterecord.breadcrumb.title", data=[ prc.language.name ] )
			, link  = event.buildAdminLink( objectName=objectName, operation="translateRecord", recordId=recordId, args={ language=languageId } )
		);
		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.translationRecordhistory.breadcrumb.title" )
			, link  = ""
		);

		prc.pageIcon  = "history";
		prc.pageTitle = translateResource( uri="cms:datamanager.translationRecordhistory.title", data=[ prc.recordLabel ?: "",  prc.objectTitle ?: "", prc.language.name ?: "" ] );
	}

	public void function deleteOneToManyRecordAction( event, rc, prc ) {
		var objectName      = prc.objectName ?: "";
		var relationshipKey = rc.relationshipKey ?: "";
		var parentId        = rc.parentId ?: "";

		if ( !datamanagerService.isOperationAllowed( objectName, "delete"   ) ) {
			event.adminAccessDenied();
		}
		rc.forceDelete = true;

		runEvent(
			  event          = "admin.DataManager._deleteRecordAction"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  postActionUrl = event.buildAdminLink( linkTo="datamanager.manageOneToManyRecords", queryString="object=#objectName#&relationshipKey=#relationshipKey#&parentId=#parentId#" )
				, audit         = true
			}
		);
	}

	public void function addOneToManyRecordAction( event, rc, prc ) {
		var objectName = prc.objectName ?: "";

		if ( !datamanagerService.isOperationAllowed( objectName, "add" ) ) {
			event.adminAccessDenied();
		}

		runEvent(
			  event          = "admin.DataManager._addOneToManyRecordAction"
			, prePostExempt  = true
			, private        = true
		);
	}

	public void function quickAddForm( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="add" );

		var object = prc.objectName ?: "";
		var hasPreFormCustomization       = customizationService.objectHasCustomization( objectName=object, action="preRenderQuickAddRecordForm" );
		var hasPostFormCustomization      = customizationService.objectHasCustomization( objectName=object, action="postRenderQuickAddRecordForm" );

		prc.formName = _getDefaultQuickAddFormName( argumentCollection=arguments, objectName=object );
		prc.preForm  = hasPreFormCustomization       ? customizationService.runCustomization( objectName=object, action="preRenderQuickAddRecordForm" , args=prc ) : "";
		prc.postForm = hasPostFormCustomization      ? customizationService.runCustomization( objectName=object, action="postRenderQuickAddRecordForm", args=prc ) : "";

		if ( customizationService.objectHasCustomization( object, "preQuickAddRecordForm" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preQuickAddRecordForm"
				, args       = { objectName=object }
			);
		}

		event.setView( view="/admin/datamanager/quickAddForm", layout="adminModalDialog", args={
			allowAddAnotherSwitch = IsTrue( rc.multiple ?: "" )
		} );
	}

	public void function quickAddRecordAction( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="add" );

		var object = prc.objectName ?: "";

		if ( customizationService.objectHasCustomization( object, "quickAddRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "quickAddRecordAction"
				, args       = { objectName=object }
			);
		} else {
			runEvent(
				  event          = "admin.DataManager._quickAddRecordAction"
				, prePostExempt  = true
				, private        = true
			);
		}
	}

	public void function superQuickAddAction( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="add" );

		runEvent(
			  event          = "admin.DataManager._superQuickAddRecordAction"
			, prePostExempt  = true
			, private        = true
		);
	}

	public void function quickEditForm( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="edit" );

		prc.record = queryRowToStruct( prc.record );

		var object = prc.objectName ?: "";
		var hasPreFormCustomization       = customizationService.objectHasCustomization( objectName=object, action="preRenderQuickAddRecordForm" );
		var hasPostFormCustomization      = customizationService.objectHasCustomization( objectName=object, action="postRenderQuickAddRecordForm" );

		prc.formName = _getDefaultQuickEditFormName( argumentCollection=arguments, objectName=object );
		prc.preForm  = hasPreFormCustomization       ? customizationService.runCustomization( objectName=object, action="preRenderQuickAddRecordForm" , args=prc ) : "";
		prc.postForm = hasPostFormCustomization      ? customizationService.runCustomization( objectName=object, action="postRenderQuickAddRecordForm", args=prc ) : "";

		if ( customizationService.objectHasCustomization( object, "preQuickEditRecordForm" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preQuickEditRecordForm"
				, args       = { objectName=object }
			);
		}

		event.setView( view="/admin/datamanager/quickEditForm", layout="adminModalDialog" );
	}

	public void function quickEditRecordAction( event, rc, prc ) {
		_checkPermission( argumentCollection=arguments, key="edit" );

		var object = prc.objectName ?: "";

		if ( customizationService.objectHasCustomization( object, "quickEditRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "quickEditRecordAction"
				, args       = { objectName=object }
			);
		} else {
			runEvent(
				  event          = "admin.DataManager._quickEditRecordAction"
				, prePostExempt  = true
				, private        = true
			);
		}
	}

	public void function configuratorForm( event, rc, prc ) {
		var id         = prc.recordId ?: "";
		var fromDb     = rc.__fromDb ?: false;
		var args       = {};
		var record     = "";

		_checkPermission( argumentCollection=arguments, key="add" );

		if ( fromDb ) {
			args.savedData = queryRowToStruct( prc.record );
		}
		args.sourceIdField = rc.sourceIdField ?: "";
		args.sourceId      = rc.sourceId      ?: "";

		event.setView( view="/admin/datamanager/configuratorForm", layout="adminModalDialog", args=args );
	}

	public void function multiOneToManyRecordAction( event, rc, prc ) {
		var objectName      = prc.objectName     ?: "";
		var parentId        = rc.parentId        ?: "";
		var relationshipKey = rc.relationshipKey ?: "";
		var action          = rc.multiAction     ?: "";
		var ids             = rc.id              ?: "";
		var listingUrl      = event.buildAdminLink( linkTo=rc.postAction ?: "datamanager.manageOneToManyRecords", queryString="object=#objectName#&parentId=#parentId#&relationshipKey=#relationshipKey#" );

		_checkObjectExists( argumentCollection=arguments, object=objectName );

		if ( !Len( Trim( ids ) ) ) {
			messageBox.error( translateResource( "cms:datamanager.norecordsselected.error" ) );
			setNextEvent( url=listingUrl );
		}

		switch( action ){
			case "delete":
				return deleteOneToManyRecordAction( argumentCollection = arguments );
			break;
		}

		messageBox.error( translateResource( "cms:datamanager.invalid.multirecord.action.error" ) );
		setNextEvent( url=listingUrl );
	}


	public void function manageOneToManyRecords( event, rc, prc ) {
		var objectName    = prc.objectName  ?: "";
		var objectTitle   = prc.objectTitle ?: "";
		var parentDetails = _getParentDetailsForOneToManyActions( event, rc, prc );

		prc.gridFields    = _getObjectFieldsForGrid( objectName );
		prc.canAdd        = datamanagerService.isOperationAllowed( objectName, "add" );
		prc.delete        = datamanagerService.isOperationAllowed( objectName, "delete" );
		prc.pageTitle     = translateResource( uri="cms:datamanager.oneToManyListing.page.title"   , data=[ objectTitle, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageSubTitle  = translateResource( uri="cms:datamanager.oneToManyListing.page.subtitle", data=[ objectTitle, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageIcon      = "database";

		event.setLayout( "adminModalDialog" );
	}

	public void function addOneToManyRecord( event, rc, prc ) {
		var objectName  = prc.objectName ?: "";
		var objectTitle = prc.objectTitle ?: "";

		if ( !datamanagerService.isOperationAllowed( objectName, "add"   ) ) {
			event.adminAccessDenied();
		}

		var parentDetails = _getParentDetailsForOneToManyActions( event, rc, prc );

		prc.pageTitle     = translateResource( uri="cms:datamanager.oneToMany.addRecord.page.title"   , data=[ objectTitle, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageSubTitle  = translateResource( uri="cms:datamanager.oneToMany.addRecord.page.subtitle", data=[ objectTitle, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageIcon      = "plus";

		event.setLayout( "adminModalDialog" );
	}

	public void function editOneToManyRecord( event, rc, prc ) {
		var objectName      = prc.objectName     ?: "";
		var objectTitle     = prc.objectTitle    ?: "";
		var id              = prc.recordId       ?: "";
		var version         = prc.version        ?: 0;
		var record          = prc.record         ?: QueryNew( '' )
		var parentId        = rc.parentId        ?: "";
		var relationshipKey = rc.relationshipKey ?: "";

		if ( !datamanagerService.isOperationAllowed( objectName, "edit"   ) ) {
			event.adminAccessDenied();
		}

		prc.record = queryRowToStruct( prc.record );

		var parentDetails = _getParentDetailsForOneToManyActions( event, rc, prc );

		prc.pageTitle     = translateResource( uri="cms:datamanager.oneToMany.editRecord.page.title"   , data=[ objectTitle, prc.recordLabel, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageSubTitle  = translateResource( uri="cms:datamanager.oneToMany.editRecord.page.subtitle", data=[ objectTitle, prc.recordLabel, parentDetails.parentObjectTitle, parentDetails.parentRecordLabel ] );
		prc.pageIcon      = "pencil";

		event.setLayout( "adminModalDialog" );
	}

	public void function editOneToManyRecordAction( event, rc, prc ) {
		var id              = prc.recordId       ?: "";
		var objectName      = prc.objectName     ?: "";
		var parentId        = rc.parentId        ?: "";
		var relationshipKey = rc.relationshipKey ?: "";

		rc[ relationshipKey ] = parentId;

		if ( !datamanagerService.isOperationAllowed( objectName, "edit"   ) ) {
			event.adminAccessDenied();
		}

		runEvent(
			  event          = "admin.DataManager._editRecordAction"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  errorUrl   = event.buildAdminLink( linkTo="datamanager.editOneToManyRecord"   , queryString="object=#objectName#&parentId=#parentId#&relationshipKey=#relationshipKey#&id=#id#" )
				, successUrl = event.buildAdminLink( linkTo="datamanager.manageOneToManyRecords", queryString="object=#objectName#&parentId=#parentId#&relationshipKey=#relationshipKey#" )
				, audit      = true
			}
		);
	}

	public void function sortRecords( event, rc, prc ) {
		var objectName        = prc.objectName        ?: "";
		var objectTitle       = prc.objectTitle       ?: "";
		var objectTitlePlural = prc.objectTitlePlural ?: "";
		var getRecordsArgs    = { objectName = objectName };

		if ( !datamanagerService.isSortable( objectName ) ) {
			messageBox.error( translateResource( uri="cms:datamanager.objectNotSortable.error", data=[ objectTitle  ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		_checkPermission( argumentCollection=arguments, key="edit" );

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "preFetchRecordsForSorting"
			, args           = getRecordsArgs
		);

		if ( datamanagerService.usesTreeView( objectName ) ) {
			var treeParentProperty       = datamanagerService.getTreeParentProperty( objectName );
			var firstLevelParentProperty = datamanagerService.getTreeFirstLevelParentProperty( objectName );
			var treeFilter               = {};
			getRecordsArgs.extraFilters  = getRecordsArgs.extraFilters ?: [];

			if ( Len( firstLevelParentProperty ) && Len( rc[ firstLevelParentProperty ] ?: "" ) ) {
				treeFilter[ firstLevelParentProperty ] = rc[ firstLevelParentProperty ];
			}

			treeFilter[ treeParentProperty ] = rc[ treeParentProperty ] ?: "";

			getRecordsArgs.extraFilters.append( { filter=treeFilter } );
		}

		prc.records = datamanagerService.getRecordsForSorting( argumentCollection=getRecordsArgs );

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.sortRecords.breadcrumb.title" )
			, link  = ""
		);
		prc.pageTitle = translateResource( uri="cms:datamanager.sortRecords.title", data=[ objectTitlePlural ] );
		prc.pageIcon  = "sort-amount-asc";
	}

	public void function sortRecordsAction( event, rc, prc ) {
		var objectName        = prc.objectName        ?: "";
		var objectTitle       = prc.objectTitle       ?: "";

		if ( !datamanagerService.isSortable( objectName ) ) {
			messageBox.error( translateResource( uri="cms:datamanager.objectNotSortable.error", data=[ objectTitle  ] ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		_checkPermission( argumentCollection=arguments, key="edit", object=objectName );

		var args = {
			  objectName = objectName
			, sortedIds  = ListToArray( rc.ordered ?: "" )
		};

		if ( customizationService.objectHasCustomization( objectName, "preSortRecordsAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "preSortRecordsAction"
				, args       = args
			);
		}

		datamanagerService.saveSortedRecords(
			  objectName = args.objectName
			, sortedIds  = args.sortedIds
		);

		if ( customizationService.objectHasCustomization( objectName, "postSortRecordsAction" ) ) {
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "postSortRecordsAction"
				, args       = args
			);
		}

		messageBox.info( translateResource( uri="cms:datamanager.recordsSorted.confirmation", data=[ objectTitle  ] ) );
		setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
	}

	public void function dataExportConfigModal( event, rc, prc ) {
		if ( !isFeatureEnabled( "dataexport" ) ) {
			event.notFound();
		}
		var args = {};

		args.objectName = prc.objectName ?: "";
		args.configForm = dataExportTemplateService.renderConfigForm(
			  templateId = ( rc.exportTemplate ?: "" )
			, objectName = args.objectName
		);

		event.setView( view="/admin/datamanager/dataExportConfigModal", layout="adminModalDialog", args=args );
	}

	public void function exportDataAction( event, rc, prc ) {
		if ( !isFeatureEnabled( "dataexport" ) ) {
			event.notFound();
		}

		var objectName = prc.objectName ?: "";

		_checkPermission( argumentCollection=arguments, key="read", object=objectName, checkOperations=false );

		runEvent(
			  event          = "admin.DataManager._exportDataAction"
			, prePostExempt  = true
			, private        = true
		);
	}

	public void function saveExportAction( event, rc, prc ) {
		if ( !isFeatureEnabled( "dataexport" ) ) {
			event.notFound();
		}

		var objectName = prc.objectName ?: "";

		_checkPermission( argumentCollection=arguments, key="read", object=objectName, checkOperations=false );

		var formData = {
			  exporter           = rc.exporter          ?: ""
			, exportTemplate     = rc.exportTemplate          ?: ""
			, exportFields       = rc.exportFields      ?: ""
			, fieldnames         = rc.fieldnames        ?: ""
			, exportFilterString = rc.exportFilterString ?: ""
			, description        = rc.description       ?: ""
			, filterExpressions  = rc.filterExpressions ?: ""
			, object             = rc.object            ?: ""
			, orderby            = rc.orderby           ?: ""
			, savedFilters       = rc.savedFilters      ?: ""
			, searchQuery        = rc.searchQuery       ?: ""
		};

		StructAppend( formData, dataExportTemplateService.getSubmittedConfig(
			  templateId = formData.exportTemplate
			, objectName = formData.object
		) );


		if ( isEmpty( formData.exporter ) or isEmpty( formData.object ) ) {
			messageBox.error( translateResource( uri="cms:datamanager.saveexport.error" ) );
			setNextEvent( url=event.buildAdminLink( objectName=objectName, operation="listing" ) );
		}

		setNextEvent( url=event.buildAdminLink( linkto="dataExport.saveExport" ), persistStruct=formData );
	}

	public void function savedExportDownload( event, rc, prc ) {
		var recordId = rc.id ?: "";

		if ( !isEmpty( recordId ) ) {
			var savedExportDetail = presideObjectService.selectData(
				  objectName   = "saved_export"
				, id           = recordId
				, selectFields = [
					  "file_name"
					, "template"
					, "template_config"
					, "object_name"
					, "fields"
					, "exporter"
					, "filter_string"
					, "filter"
					, "saved_filter"
					, "order_by"
					, "search_query"
				]
			);

			if ( savedExportDetail.recordcount ) {
				rc.exporter           = savedExportDetail.exporter;
				rc.exportTemplate     = savedExportDetail.template;
				rc.object             = savedExportDetail.object_name;
				rc.exportFields       = savedExportDetail.fields;
				rc.fileName           = savedExportDetail.file_name;
				rc.exportFilterString = savedExportDetail.filter_string;
				rc.filterExpressions  = savedExportDetail.filter;
				rc.savedFilters       = savedExportDetail.saved_filter;
				rc.orderBy            = savedExportDetail.order_by;
				rc.searchQuery        = savedExportDetail.search_query;

				if ( IsJson( savedExportDetail.template_config ) ) {
					StructAppend( rc, DeSerializeJson( savedExportDetail.template_config ) );
				}

				runEvent(
					  event          = "admin.DataManager._exportDataAction"
					, prePostExempt  = true
					, private        = true
				);
			}
		} else {
			event.notFound();
		}
	}

	public void function manageFilters( event, rc, prc ) {
		var objectName = prc.objectName ?: "";

		_checkPermission( argumentCollection=arguments, key="manageFilters" );

		prc.useSegmentationFilters = rulesEngineFilterService.objectSupportsSegmentationFilters( objectName );

		prc.pageIcon  = "filter";
		prc.pageTitle = translateResource( uri="cms:datamanager.managefilters.title", data=[ prc.objectTitlePlural ] );
		prc.pageSubtitle = translateResource( uri="cms:datamanager.managefilters.subtitle", data=[ prc.objectTitlePlural ] );
		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.managefilters.breadcrumb.title" )
			, link  = ""
		);
	}

	public void function addSegmentationFilter( event, rc, prc ) {
		var objectName = prc.objectName ?: "";
		var useSegmentationFilters = rulesEngineFilterService.objectSupportsSegmentationFilters( objectName );

		if ( !useSegmentationFilters ) {
			event.notFound();
		}

		_checkPermission( argumentCollection=arguments, key="manageFilters" );

		prc.pageIcon  = "sitemap";
		prc.pageTitle = translateResource( "cms:datamanager.managefilters.addSegmentationFilter.page.title" );
		prc.pageSubTitle = translateResource( "cms:datamanager.managefilters.addSegmentationFilter.page.subtitle" );

		prc.formName     = "preside-objects.rules_engine_condition.admin.add.segmentation.filter";
		prc.submitAction = event.buildAdminLink( linkto="datamanager.addSegmentationFilterAction" );
		prc.cancelAction = event.buildAdminLink( linkto="datamanager.manageFilters", queryString="object=#objectName#&tab=segmentation")

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.managefilters.breadcrumb.title" )
			, link  = prc.cancelAction
		);
		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:datamanager.managefilters.addSegmentationFilter.page.title" )
			, link  = ""
		);
	}

	public void function addSegmentationFilterAction( event, rc, prc ) {
		var objectName = prc.objectName ?: "";
		var useSegmentationFilters = rulesEngineFilterService.objectSupportsSegmentationFilters( objectName );

		if ( !useSegmentationFilters ) {
			event.notFound();
		}

		_checkPermission( argumentCollection=arguments, key="manageFilters" );

		runEvent(
			  event          = "admin.DataManager._addRecordAction"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  formName      = "preside-objects.rules_engine_condition.admin.add.segmentation.filter"
				, object        = "rules_engine_condition"
				, audit         = true
				, errorUrl      = event.buildAdminLink( linkto="datamanager.addSegmentationFilter", queryString="object=#prc.objectName#" )
				, successUrl    = event.buildAdminLink( linkto="datamanager.manageFilters", queryString="object=#prc.objectName#&tab=segmentation" )
			  }
		);
	}

	public void function recalculateSegmentationFilterAction( event, rc, prc ) {
		var objectName = prc.objectName ?: "";
		var recordId   = rc.id ?: "";
		var useSegmentationFilters = rulesEngineFilterService.objectSupportsSegmentationFilters( objectName );

		if ( !useSegmentationFilters || !Len( Trim( recordId ) ) ) {
			event.notFound();
		}
		_checkPermission( argumentCollection=arguments, key="manageFilters" );

		var resultUrl = event.buildAdminLink( objectName=objectName, operation="manageFilters", queryString="tab=segmentation" );
		var taskId = createTask(
			  event                = "admin.datamanager.reCalculateSegmentationFilterInBgThread"
			, runNow               = true
			, adminOwner           = event.getAdminUserId()
			, title                = "cms:datamanager.managefilters.recalculate.segmentation.filter.task.title"
			, returnUrl            = resultUrl
			, resultUrl            = resultUrl
			, discardAfterInterval = CreateTimeSpan( 0, 0, 5, 0 )
			, args                 = { id=recordId }
		);

		setNextEvent( url=event.buildAdminLink(
			  linkTo      = "adhoctaskmanager.progress"
			, queryString = "taskId=" & taskId
		) );
	}

	private boolean function reCalculateSegmentationFilterInBgThread( event, rc, prc, args={}, logger, progress ) {
		rulesEngineFilterService.recalculateSegmentationFilterData(
			  filterId            = args.id ?: ""
			, recalculateChildren = true
			, logger              = arguments.logger   ?: NullValue()
			, progress            = arguments.progress ?: NullValue()
		);

		return true;
	}

// VIEWLETS
	private string function versionNavigator( event, rc, prc, args={} ) {
		var selectedVersion = Val( args.version ?: "" );
		var objectName      = args.object ?: "";
		var id              = args.id     ?: "";

		args.latestVersion          = versioningService.getLatestVersionNumber( objectName=objectName, recordId=id );
		args.latestPublishedVersion = versioningService.getLatestVersionNumber( objectName=objectName, recordId=id, publishedOnly=true );

		args.prevVersion = presideObjectService.getPreviousVersion(
			  objectName     = objectName
			, id             = id
			, currentVersion = ( selectedVersion ? selectedVersion : args.latestVersion )
		);
		if ( !selectedVersion ) {
			selectedVersion = args.latestVersion;
		}

		args.isLatest    = args.latestVersion == selectedVersion;
		args.nextVersion = 0;
		if ( !args.isLatest ) {
			args.nextVersion = presideObjectService.getNextVersion(
				  objectName     = objectName
				, id             = id
				, currentVersion = selectedVersion
			);
		}

		return renderView( view="admin/datamanager/versionNavigator", args=args );
	}

	private string function translationVersionNavigator( event, rc, prc, args={} ) {
		var recordId              = args.id       ?: "";
		var language              = args.language ?: "";
		var translationObjectName = multilingualPresideObjectService.getTranslationObjectName( args.object ?: "" );
		var selectedVersion       = Val( args.version ?: "" );
		var existingTranslation = multilingualPresideObjectService.selectTranslation(
			  objectName   = args.object ?: ""
			, id           = args.id ?: ""
			, languageId   = args.language ?: ""
			, selectFields = [ "id" ]
			, version      = selectedVersion
		);

		if ( !existingTranslation.recordCount ) {
			return "";
		}

		args.version  = args.version ?: selectedVersion;
		args.latestVersion          = versioningService.getLatestVersionNumber(
			  objectName = translationObjectName
			, filter     = { _translation_source_record=recordId, _translation_language=language }
		);
		args.latestPublishedVersion = versioningService.getLatestVersionNumber(
			  objectName    = translationObjectName
			, filter        = { _translation_source_record=recordId, _translation_language=language }
			, publishedOnly = true
		);
		args.prevVersion = presideObjectService.getPreviousVersion(
			  objectName     = translationObjectName
			, id             = existingTranslation.id
			, currentVersion = ( selectedVersion ? selectedVersion : args.latestVersion )
		);
		if ( !selectedVersion && args.prevVersion ) {
			selectedVersion = args.latestVersion;
		}

		args.isLatest    = args.latestVersion == selectedVersion;
		args.nextVersion = 0;
		if ( !args.isLatest ) {
			args.nextVersion = presideObjectService.getNextVersion(
				  objectName     = translationObjectName
				, id             = existingTranslation.id
				, currentVersion = selectedVersion
			);
		}

		args.baseUrl        = args.baseUrl        ?: event.buildAdminLink( objectName=args.object, operation='translateRecord', recordId=args.id, args={ language=language, version='{version}' } );
		args.allVersionsUrl = args.allVersionsUrl ?: event.buildAdminLink( linkTo='datamanager.translationRecordHistory', queryString='object=#args.object#&id=#args.id#&language=#language#' );

		return renderView( view="admin/datamanager/versionNavigator", args=args );
	}

	private string function topRightButtons( event, rc, prc, args={} ){
		var objectName         = args.objectName ?: "";
		var action             = args.action     ?: "";
		var actionsWithButtons = [ "object", "viewrecord", "addrecord", "editrecord", "managefilters" ];
		var rendered = "";

		if ( actionsWithButtons.containsNoCase( action ) ) {
			var actions = customizationService.runCustomization(
				  objectName     = objectName
				, action         = "getTopRightButtonsFor#action#"
				, defaultHandler = "admin.datamanager.getTopRightButtonsFor#action#"
				, args           = args
			);

			customizationService.runCustomization(
				  objectName     = objectName
				, action         = "extraTopRightButtons"
				, args           = { objectName=objectName, action=action, actions=actions }
			);

			announceInterception( "postExtraTopRightButtons", { objectName=objectName, action=action, actions=actions } );

			actions = actions.reverse();

			for( var actionToRender in actions ) {
				if ( IsSimpleValue( actionToRender ) ) {
					rendered &= actionToRender;
				} else {
					rendered &= renderView( view="/admin/datamanager/_topRightButton", args=actionToRender );
				}
			}
		}


		return rendered;
	}

	private array function getTopRightButtonsForObject() {
		var objectName  = args.objectName ?: "";
		var objectTitle = prc.objectTitle ?: "";
		var actions     = [];

		if ( IsTrue( prc.canManagePerms ?: "" ) ) {
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="manageperms" )
				, btnClass  = "btn-default"
				, iconClass = "fa-lock"
				, globalKey = "p"
				, title     = translateResource( uri="cms:datamanager.manageperms.link", data = [ objectTitle ] )
			} );
		}
		if ( IsTrue( prc.canEdit ?: "" ) && dataManagerService.isSortable( objectName ) ) {
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="sortRecords" )
				, btnClass  = "btn-info"
				, iconClass = "fa-sort-amount-asc"
				, globalKey = "o"
				, title     = translateResource( uri="cms:datamanager.sortrecords.link", data = [ objectTitle ] )
			} );
		}
		if ( IsTrue( prc.canAdd ?: "" ) ) {
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="addRecord" )
				, btnClass  = "btn-success"
				, iconClass = "fa-plus"
				, globalKey = "a"
				, title     = translateResource( uri="cms:datamanager.addrecord.title" , data = [ objectTitle ] )
			} );
		}

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "extraTopRightButtonsForObject"
			, args           = { objectName=objectName, actions=actions }
		);

		announceInterception( "postExtraTopRightButtonsForObject", { objectName=objectName, actions=actions } );

		return actions;
	}

	private array function getTopRightButtonsForManageFilters() {
		var objectName  = args.objectName ?: "";
		var objectTitle = prc.objectTitlePlural ?: "";
		var actions     = [];

		actions.append( {
			  link      = event.buildAdminLink( objectName=objectName )
			, btnClass  = "btn-default"
			, iconClass = "fa-reply"
			, title     = translateResource( uri="cms:datamanager.back.to.listing.link", data = [ objectTitle ] )
		} );

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "extraTopRightButtonsForManageFilters"
			, args           = { objectName=objectName, actions=actions }
		);

		announceInterception( "postExtraTopRightButtonsForManageFilters", { objectName=objectName, actions=actions } );

		return actions;
	}

	private array function getTopRightButtonsForViewRecord() {
		var objectName   = args.objectName ?: "";
		var objectTitle  = prc.objectTitle ?: "";
		var recordId     = prc.recordId    ?: "";
		var recordLabel  = prc.recordLabel ?: "";
		var actions      = [];
		var language     = rc.language ?: "";

		if ( IsTrue( prc.canTranslate ?: "" ) ) {
			var translationActions = customizationService.runCustomization(
				  objectName = objectName
				, action     = "getTranslationsActionButton"
				, defaultHandler = "admin.datamanager.getTranslationsActionButton"
				, args       = {
					  objectName = objectName
					, recordId   = recordId
					, operation  = "viewRecord"
				}
			);

			if ( StructCount( translationActions ?: {} ) ) {
				actions.append( translationActions );
			}
		}

		if ( IsTrue( prc.canEdit ?: "" ) ) {
			var link = "";
			if ( IsTrue( prc.canTranslate ?: "" ) && language.len() ) {
				link = event.buildAdminLink( objectName=objectName, operation="translateRecord", recordId=recordId, args={ language=language } );
			} else {
				link = event.buildAdminLink( objectName=objectName, operation="editRecord", recordId=recordId );
			}

			if ( isFlaggingEnabled( objectName=objectName ) ) {
				var recordIsFlagged = presideObjectService.recordIsFlagged(
					  objectName = objectName
					, recordId   = recordId
				);

				actions.append( {
					  link      = event.buildAdminLink( objectName=objectName, recordId=recordId, operation="flagRecordAction", queryString="result=detail" )
					, btnClass  = "#recordIsFlagged ? "btn-danger" : "btn-muted"#"
					, iconClass = "fa-font-awesome-flag"
					, title     = translateResource( uri="cms:datamanager.#recordIsFlagged ? "un" : ""#flagrecord.btn" )
					, prompt    = translateResource( uri="cms:datamanager.#recordIsFlagged ? "un" : ""#flagrecord.prompt", data=[ objectTitle, stripTags( recordLabel ) ] )
					, globalKey = "f"
				} );
			}

			actions.append( {
				  link      = link
				, btnClass  = "btn-success"
				, iconClass = "fa-pencil"
				, globalKey = "e"
				, title     = translateResource( uri="cms:datamanager.editRecord.btn" )
			} );
		}

		if ( IsTrue( prc.canClone ?: "" ) ) {
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="cloneRecord", recordId=recordId )
				, btnClass  = "btn-info"
				, iconClass = "fa-clone"
				, globalKey = "c"
				, title     = translateResource( uri="cms:datamanager.cloneRecord.btn" )
			} );
		}

		if ( IsTrue( prc.canDelete ?: "" ) ) {
			var useTypedConfirmation = dataManagerService.useTypedConfirmationForDeletion( objectName );
			var record = args.record ?: ( prc.record ?: {} );
			if ( isQuery( record ) ) {
				record = QueryRowToStruct( record );
			}
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="deleteRecordAction", recordId=recordId )
				, btnClass  = "btn-danger"
				, iconClass = "fa-trash"
				, globalKey = "d"
				, title     = translateResource( uri="cms:datamanager.deleteRecord.btn" )
				, prompt    = translateResource( uri="cms:datamanager.deleteRecord.prompt", data=[ objectTitle, stripTags( recordLabel ) ] )
				, match     = useTypedConfirmation ? datamanagerService.getDeletionConfirmationMatch( objectName, record ) : ""
			} );
		}

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "extraTopRightButtonsForViewRecord"
			, args           = { objectName=objectName, actions=actions }
		);

		announceInterception( "postExtraTopRightButtonsForViewRecord", { objectName=objectName, actions=actions } );

		return actions;
	}

	private array function getTopRightButtonsForAddRecord() {
		var objectName  = args.objectName ?: "";
		var actions     = [];

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "extraTopRightButtonsForAddRecord"
			, args           = { objectName=objectName, actions=actions }
		);

		announceInterception( "postExtraTopRightButtonsForAddRecord", { objectName=objectName, actions=actions } );

		return actions;
	}

	private array function getTopRightButtonsForEditRecord() {
		var objectName = args.objectName ?: "";
		var recordId   = prc.recordId    ?: "";
		var actions    = [];

		if ( IsTrue( prc.canTranslate ?: "" ) ) {
			var translationActions = customizationService.runCustomization(
				  objectName = objectName
				, action     = "getTranslationsActionButton"
				, defaultHandler = "admin.datamanager.getTranslationsActionButton"
				, args       = {
					  objectName = objectName
					, recordId   = recordId
					, operation  = "translateRecord"
				}
			);

			if ( StructCount( translationActions ?: {} ) ) {
				actions.append( translationActions );
			}
		}

		if ( IsTrue( prc.canClone ?: "" ) ) {
			actions.append( {
				  link      = event.buildAdminLink( objectName=objectName, operation="cloneRecord", recordId=recordId )
				, btnClass  = "btn-info"
				, iconClass = "fa-clone"
				, globalKey = "c"
				, title     = translateResource( uri="cms:datamanager.cloneRecord.btn" )
			} );
		}

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "extraTopRightButtonsForEditRecord"
			, args           = { objectName=objectName, actions=actions }
		);

		announceInterception( "postExtraTopRightButtonsForEditRecord", { objectName=objectName, actions=actions } );

		return actions;
	}

	private struct function getTranslationsActionButton( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var recordId   = args.recordId   ?: "";
		var operation  = args.operation  ?: "translateRecord";

		prc.translations = prc.translations ?: multilingualPresideObjectService.getTranslationStatus( objectName, recordId );
		if ( !prc.translations.len() ) {
			return {};
		}

		var translateUrlBase = event.buildAdminLink( objectName=objectName, operation=operation, recordId=recordId, args={ language="{language}" } );
		var item = {
			  link      = ""
			, btnClass  = "btn-info"
			, iconClass = "fa-globe"
			, globalKey = ""
			, title     = translateResource( uri="cms:datamanager.translate.record.btn" )
			, children  = []
		};

		item.children.append( {
			  link  = translateUrlBase.replace( "{language}", "" )
			, icon  = "fa-eye"
			, title = translateResource( 'cms:datamanager.translate.default.language' )
		} );

		for( var translation in prc.translations ) {
			item.children.append( {
				  link  = translateUrlBase.replace( "{language}", translation.id )
				, icon  = "fa-eye"
				, title = "#translation.name# (#translateResource( 'cms:multilingal.status.#translation.status#' )#)"
			} );
		}

		return item;
	}

	private string function manageSegmentationFilters( event, rc, prc ) {
		var objectName = prc.objectName ?: "";

		_checkPermission( argumentCollection=arguments, key="manageFilters" );

		var useSegmentationFilters = rulesEngineFilterService.objectSupportsSegmentationFilters( objectName );

		if ( !useSegmentationFilters ) {
			return "";
		}

		args.hasAnyFilters = rulesEngineFilterService.hasAnySegmentationFilters( objectName );

		return renderView( view="/admin/datamanager/manageSegmentationFilters", args=args );
	}

// private events for sharing
	private void function _getObjectRecordsForAjaxDataTables(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object          = ( rc.id ?: '' )
		,          string  gridFields      = ( rc.gridFields ?: 'label,datecreated,_version_author' )
		,          string  actionsView     = ""
		,          string  orderBy         = ""
		,          struct  filter          = {}
		,          boolean useMultiActions = true
		,          boolean isMultilingual  = false
		,          boolean draftsEnabled   = false
		,          boolean distinct        = true
		,          boolean forceDistinct   = false
		,          boolean includeActions  = true
		,          array   extraFilters    = []
		,          array   searchFields

	) {
		var getRecordsArgs    = {};
		var excludedArguments = [ "event", "rc", "prc", "actionsView", "useMultiActions", "isMultilingual", "object" ];

		for( var argument in arguments ) {
			if ( !excludedArguments.contains( argument ) ) {
				getRecordsArgs[ argument ] = duplicate( arguments[ argument ] );
			}
		}

		getRecordsArgs.objectName    = arguments.object;
		getRecordsArgs.startRow      = dtHelper.getStartRow();
		getRecordsArgs.maxRows       = dtHelper.getMaxRows();
		getRecordsArgs.orderBy       = dtHelper.getSortOrder();
		getRecordsArgs.searchQuery   = dtHelper.getSearchQuery();
		getRecordsArgs.gridFields    = getRecordsArgs.gridFields.listToArray();

		if ( !isFeatureEnabled( "useDistinctForDatatables" ) ) {
			getRecordsArgs.distinct = false;
		}

		if ( Len( Trim( rc.sFilterExpression ?: "" ) ) ) {
			try {
				getRecordsArgs.extraFilters.append( rulesEngineFilterService.prepareFilter(
					  objectName = object
					, expressionArray = DeSerializeJson( rc.sFilterExpression ?: "" )
				) );
			} catch( any e ){}
		}

		if ( Len( Trim( rc.sSavedFilterExpressions ?: "" ) ) ) {
			for( var filterId in ListToArray( rc.sSavedFilterExpressions ) ) {
				try {
					getRecordsArgs.extraFilters.append( rulesEngineFilterService.prepareFilter(
						  objectName = object
						, filterId   = filterId
					) );
				} catch( any e ){}
			}
		}

		if ( IsEmpty( getRecordsArgs.orderBy ) ) {
			getRecordsArgs.orderBy = arguments.orderBy.len() ? arguments.orderBy : dataManagerService.getDefaultSortOrderForDataGrid( object );
		}

		customizationService.runCustomization(
			  objectName = arguments.object
			, action     = "preFetchRecordsForGridListing"
			, args       = getRecordsArgs
		);

		var results = dataManagerService.getRecordsForGridListing( argumentCollection=getRecordsArgs );
		var records = Duplicate( results.records );

		customizationService.runCustomization(
			  objectName = arguments.object
			, action     = "postFetchRecordsForGridListing"
			, args       = { records=records, objectName=arguments.object }
		);

		if ( arguments.includeActions ) {
			var optionsCol = customizationService.runCustomization(
				  objectName     = arguments.object
				, action         = "getActionsForGridListing"
				, defaultHandler = "admin.datamanager._getActionsForAjaxDataTables"
				, args           = {
					  records     = records
					, objectName  = arguments.object
					, actionsView = actionsView
				}
			);
		}

		customizationService.runCustomization(
			  objectName     = arguments.object
			, action         = "decorateRecordsForGridListing"
			, defaultHandler = "admin.datamanager._decorateObjectRecordsForAjaxDataTables"
			, args           = {
				  records         = records
				, objectName      = arguments.object
				, gridFields      = getRecordsArgs.gridFields
				, useMultiActions = arguments.useMultiActions
				, isMultilingual  = arguments.isMultilingual
				, draftsEnabled   = arguments.draftsEnabled
			}
		);

		customizationService.runCustomization(
			  objectName     = arguments.object
			, action         = "postDecorateRecordsForGridListing"
			, args           = {
				  records         = records
				, objectName      = arguments.object
				, gridFields      = getRecordsArgs.gridFields
				, useMultiActions = arguments.useMultiActions
				, isMultilingual  = arguments.isMultilingual
				, draftsEnabled   = arguments.draftsEnabled
			}
		);

		if ( arguments.includeActions ) {
			QueryAddColumn( records, "_options" , optionsCol );
			ArrayAppend( getRecordsArgs.gridFields, "_options" );
		}

		var result = dtHelper.queryToResult( records, getRecordsArgs.gridFields, results.totalRecords );
		var footer = customizationService.runCustomization(
			  objectName     = arguments.object
			, action         = "renderFooterForGridListing"
			, args           = {
				  records         = records
				, objectName      = arguments.object
				, getRecordsArgs  = getRecordsArgs
			}
		);

		if ( IsSimpleValue( local.footer ?: "" ) && Len( Trim( local.footer ?: "" ) ) ) {
			result.sFooter = footer;
		}

		if ( datamanagerService.canBatchSelectAll( arguments.object ) ) {
			result.sBatchSource = batchOperationService.prepareBatchSourceString( results.selectDataArgs );
		}

		event.renderData( type="json", data=result );
	}

	private array function _getActionsForAjaxDataTables( event, rc, prc, args={} ) {
		var records                       = args.records     ?: QueryNew( '' );
		var objectName                    = args.objectName  ?: "";
		var actionsView                   = args.actionsView ?: "";
		var isTreeView                    = IsTrue( args.treeView ?: "" );
		var optionsCol                    = [];
		var objectTitleSingular           = prc.objectTitle ?: "";
		var hasRecordActionsCustomization = !actionsView.len() && customizationService.objectHasCustomization( objectName, "getRecordActionsForGridListing" );
		var objectHasIdField              = booleanFormat( len( trim( presideObjectService.getIdField( objectName=objectName ) ) ) );

		if ( !actionsView.len() && !hasRecordActionsCustomization ) {
			var parentProperty = isTreeView ? dataManagerService.getTreeParentProperty( objectName ) : "";

			if ( objectName == ( prc.objectName ?: "" ) ) {
				var canView         = IsTrue( prc.canView         ?: "" ) && objectHasIdField;
				var canAdd          = IsTrue( prc.canAdd          ?: "" ) && objectHasIdField;
				var canEdit         = IsTrue( prc.canEdit         ?: "" ) && objectHasIdField;
				var canClone        = IsTrue( prc.canClone        ?: "" ) && objectHasIdField;
				var canDelete       = IsTrue( prc.canDelete       ?: "" ) && objectHasIdField;
				var canSort         = IsTrue( prc.canSort         ?: "" ) && objectHasIdField;
				var canViewVersions = IsTrue( prc.canViewVersions ?: "" ) && objectHasIdField;
				var useVersioning   = IsTrue( prc.useVersioning   ?: "" ) && objectHasIdField && canViewVersions;
			} else {
				var canView         = _checkPermission( argumentCollection=arguments, object=objectName, key="read"        , throwOnError=false ) && objectHasIdField;
				var canAdd          = _checkPermission( argumentCollection=arguments, object=objectName, key="add"         , throwOnError=false ) && objectHasIdField;
				var canEdit         = _checkPermission( argumentCollection=arguments, object=objectName, key="edit"        , throwOnError=false ) && objectHasIdField;
				var canClone        = _checkPermission( argumentCollection=arguments, object=objectName, key="clone"       , throwOnError=false ) && objectHasIdField;
				var canDelete       = _checkPermission( argumentCollection=arguments, object=objectName, key="delete"      , throwOnError=false ) && objectHasIdField;
				var canViewVersions = _checkPermission( argumentCollection=arguments, object=objectName, key="viewversions", throwOnError=false ) && objectHasIdField;
				var canSort         = datamanagerService.isSortable( objectName ) && canEdit;
				var useVersioning   = datamanagerService.isOperationAllowed( objectName, "viewversions" ) && presideObjectService.objectIsVersioned( objectName ) && objectHasIdField;
			}

			var canFlagRecord          = canEdit && isFlaggingEnabled( objectName=objectName );
			var addChildRecordLink     = canAdd && isTreeView  ? event.buildAdminLink( objectName=objectName, operation="addRecord", queryString="#parentProperty#={id}" ) : "";
			var sortChildrenRecordLink = canEdit && isTreeView ? event.buildAdminLink( objectName=objectName, operation="sortRecords", queryString="#parentProperty#={id}" ) : "";
			var viewRecordLink         = canView               ? event.buildAdminLink( objectName=objectName, recordId="{id}" )                                                       : "";
			var cloneRecordLink        = canClone              ? event.buildAdminLink( objectName=objectName, recordId="{id}", operation="cloneRecord" )                              : "";
			var editRecordLink         = canEdit               ? event.buildAdminLink( objectName=objectName, recordId="{id}", operation="editRecord", args={ resultAction="grid" } ) : "";
			var deleteRecordLink       = canDelete             ? event.buildAdminLink( objectName=objectName, recordId="{id}", operation="deleteRecordAction" )                       : "";
			var viewHistoryLink        = canViewVersions       ? event.buildAdminLink( linkTo="datamanager.recordHistory", queryString="object=#objectName#&id={id}" )                : "";
			var deleteRecordTitle      = canDelete             ? translateResource( uri="cms:datamanager.deleteRecord.prompt", data=[ objectTitleSingular, "{recordlabel}" ] )        : "";
			var deleteRecordTitleThis  = canDelete             ? translateResource( uri="cms:datamanager.deleteRecord.this",   data=[ objectTitleSingular ] )                         : "";
			var flagRecordLink         = canFlagRecord         ? event.buildAdminLink( objectName=objectName, recordId="{id}", operation="flagRecordAction" )                         : "";
		}

		for( var record in records ){
			if ( actionsView.len() ) {
				var actionsViewlet = Replace( ReReplace( actionsView, "^/", "" ), "/", ".", "all" );
				var viewletArgs    = Duplicate( record );
				viewletArgs.objectName = objectName;

				ArrayAppend( optionsCol, renderViewlet( event=actionsViewlet, args=viewletArgs ) );
			} else {
				var actions     = [];
				var recordLabel = structKeyExists( record, "id" ) ? renderLabel( objectName, record.id  ) : "";

				if ( hasRecordActionsCustomization ) {
					actions = customizationService.runCustomization(
						  objectName     = objectName
						, action         = "getRecordActionsForGridListing"
						, args           = {
							  record      = record
							, objectName  = objectName
							, treeView    = isTreeView
						}
					);
				} else {
					if ( canView ) {
						actions.append( {
							  link       = viewRecordLink.replace( "{id}", record.id )
							, icon       = "fa-eye"
							, contextKey = "v"
						} );
					}
					if ( canAdd && isTreeView ) {
						actions.append( {
							  link       = addChildRecordLink.replace( "{id}", record.id )
							, icon       = "fa-plus"
							, contextKey = "a"
						} );
					}
					if ( canEdit ) {
						actions.append( {
							  link       = editRecordLink.replace( "{id}", record.id )
							, icon       = "fa-pencil"
							, contextKey = "e"
						} );

					}
					if ( canSort && isTreeView ) {
						actions.append( {
							  link       = sortChildrenRecordLink.replace( "{id}", record.id )
							, icon       = "fa-sort-amount-asc"
							, contextKey = "s"
						} );
					}
					if ( canClone ) {
						actions.append( {
							  link       = cloneRecordLink.replace( "{id}", record.id )
							, icon       = "fa-clone"
							, contextKey = "c"
						} );
					}
					if ( canDelete ) {
						var recordLabel          = record[ prc.labelField ?: "" ] ?: "";
						var useTypedConfirmation = dataManagerService.useTypedConfirmationForDeletion( objectName );

						actions.append( {
							  link       = deleteRecordLink.replace( "{id}", record.id )
							, icon       = "fa-trash-o"
							, contextKey = "d"
							, class      = "confirmation-prompt"
							, title      = isEmptyString( recordLabel ) ? deleteRecordTitleThis : Replace( deleteRecordTitle, "{recordlabel}", recordLabel, "all" )
							, match      = useTypedConfirmation ? datamanagerService.getDeletionConfirmationMatch( objectName, record ) : ""

						} );
					}
					if ( useVersioning ) {
						actions.append( {
							  link       = viewHistoryLink.replace( "{id}", record.id )
							, icon       = "fa-history"
							, contextKey = "h"
						} );
					}
					if ( canFlagRecord ) {
						var recordIsFlagged = presideObjectService.recordIsFlagged(
							  objectName = objectName
							, recordId   = record.id
						);
						var flagRecordTitle = translateResource(
							  uri  = "cms:datamanager.#recordIsFlagged ? "un" : ""#flagRecord.prompt"
							, data = [ objectTitleSingular, "{recordlabel}" ]
						);

						actions.append( {
							  link       = flagRecordLink.replace( "{id}", record.id )
							, icon       = "fa-font-awesome-flag #recordIsFlagged ? "text-danger" : "text-muted"#"
							, class      = "confirmation-prompt"
							, title      = flagRecordTitle.replace( "{recordlabel}", recordLabel, "all" )
							, contextKey = "f"
						} );
					}
				}

				customizationService.runCustomization(
					  objectName     = objectName
					, action         = "extraRecordActionsForGridListing"
					, args           = {
						  record      = record
						, objectName  = objectName
						, actions     = actions
					}
				);

				announceInterception( "postExtraRecordActionsForGridListing", {
					  record      = record
					, objectName  = objectName
					, actions     = actions
				} );

				ArrayAppend( optionsCol, renderView( view="/admin/datamanager/_listingActions", args={ actions=actions } ) );
			}
		}

		return optionsCol;
	}

	private void function _decorateObjectRecordsForAjaxDataTables( event, rc, prc, args={} ) {
		var records              = args.records    ?: QueryNew( '' );
		var objectName           = args.objectName ?: "";
		var gridFields           = args.gridFields ?: [];
		var useMultiActions      = IsTrue( args.useMultiActions ?: "" );
		var isMultilingual       = IsTrue( args.isMultilingual ?: "" );
		var draftsEnabled        = IsTrue( args.draftsEnabled ?: "" );
		var translateUrlBase     = isMultilingual ? event.buildAdminLink( objectName=objectName, operation="translateRecord", recordId="{id}", args={ fromDataGrid=true, language='{language}' } ) : "";
		var hasLinkCustomization = customizationService.objectHasCustomization( objectName=objectName, action="getRecordLinkForGridListing" );
		var checkboxCol          = [];
		var translateStatusCol   = [];
		var statusCol            = [];
		var linkCol              = [];

		for( var record in records ){
			for( var field in gridFields ){
				records[ ListLast( field, "." ) ][ records.currentRow ] = renderField(
					  object  = objectName
					, property= field
					, data    = record[ ListLast( field, "." ) ]
					, record  = record
					, context = [ "adminDataTable", "admin" ]
				);
			}

			if ( useMultiActions ) {
				ArrayAppend( checkboxCol, renderView( view="/admin/datamanager/_listingCheckbox", args={ recordId=record.id } ) );
			}

			if ( isMultilingual ) {
				ArrayAppend( translateStatusCol, renderView( view="/admin/datamanager/_listingTranslations", args={
					  translations     = multilingualPresideObjectService.getTranslationStatus( objectName, record.id )
					, translateUrlBase = translateUrlBase.replace( "{id}", record.id )
				} ) );
			}

			if ( draftsEnabled ) {
				statusCol.append( renderView( view="/admin/datamanager/_recordStatus", args=record ) );
			}

			if ( hasLinkCustomization ) {
				linkCol.append( customizationService.runCustomization(
					  objectName = objectName
					, action     = "getRecordLinkForGridListing"
					, args       = { objectName=objectName, record=record, args=args }
				) );
			} else {
				linkCol.append( "" );
			}
		}

		QueryAddColumn( records, "_link" , linkCol );

		if ( draftsEnabled ) {
			QueryAddColumn( records, "_status" , statusCol );
			ArrayAppend( gridFields, "_status" );
		}
		if ( isMultilingual ) {
			QueryAddColumn( records, "_translateStatus" , translateStatusCol );
			ArrayAppend( gridFields, "_translateStatus" );
		}
		if ( useMultiActions ) {
			QueryAddColumn( records, "_checkbox", checkboxCol );
			ArrayPrepend( gridFields, "_checkbox" );
		}
	}

	private void function _getRecordHistoryForAjaxDataTables(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object      = ( rc.object   ?: '' )
		,          string  recordId    = ( rc.id       ?: '' )
		,          string  property    = ( rc.property ?: '' )
		,          string  actionsView = ""
	) {
		var versionObject       = presideObjectService.getVersionObjectName( object );
		var objectTitleSingular = translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object );
		var optionsCol          = [];
		var results             = dataManagerService.getRecordHistoryForGridListing(
			  objectName  = object
			, recordId    = recordId
			, property    = property
			, startRow    = dtHelper.getStartRow()
			, maxRows     = dtHelper.getMaxRows()
			, orderBy     = dtHelper.getSortOrder()
			, searchQuery = dtHelper.getSearchQuery()
		);
		var records    = Duplicate( results.records );
		var gridFields = [ "published", "datemodified", "_version_author", "_version_changed_fields" ];
		var canView    = IsTrue( prc.canView ?: "" );
		var canEdit    = IsTrue( prc.canEdit ?: "" );

		for( var record in records ){
			for( var field in gridFields ){
				if ( field == "published" ) {
					records[ field ][ records.currentRow ] = renderContent( "boolean", record[ field ], [ "adminDataTable", "admin" ] );
				} else if ( field == "_version_changed_fields" ) {
					var rendered = [];
					for( var changedField in ListToArray( records[ field ][ records.currentRow ] ) ) {
						var translated = translateResource(
							  uri          = "preside-objects.#object#:field.#changedField#.title"
							, defaultValue = translateResource( uri="cms:preside-objects.default.field.#changedField#.title", defaultValue="" )
						);
						if ( Len( Trim( translated ) ) ) {
							rendered.append( translated );
						}
					}
					records[ field ][ records.currentRow ] = '<span title="#HtmlEditFormat( rendered.toList( ', ' ) )#">' & abbreviate( rendered.toList( ", " ), 100 ) & '</span>';
				} else {
					records[ field ][ records.currentRow ] = renderField( versionObject, field, record[ field ], [ "adminDataTable", "admin" ] );
				}
			}

			if ( Len( Trim( actionsView ) ) ) {
				ArrayAppend( optionsCol, renderView( view=actionsView, args=record ) );
			} else {
				ArrayAppend( optionsCol, renderView( view="/admin/datamanager/_historyActions", args={
					  objectName     = object
					, recordId       = recordId
					, canEdit        = canEdit
					, canView        = canView
					, viewRecordLink = canView ? event.buildAdminLink( objectName=object, recordId=record.id, operation="viewRecord", args={ version=record._version_number } ) : ""
					, editRecordLink = canEdit ? event.buildAdminLink( objectName=object, recordId=record.id, operation="editRecord", args={ version=record._version_number } ) : ""
				} ) );
			}
		}

		QueryAddColumn( records, "_options" , optionsCol );
		ArrayAppend( gridFields, "_options" );

		event.renderData( type="json", data=dtHelper.queryToResult( records, gridFields, results.totalRecords ) );
	}

	private void function _getTranslationRecordHistoryForAjaxDataTables(
		  required any    event
		, required struct rc
		, required struct prc
		,          string object      = ( rc.object   ?: '' )
		,          string recordId    = ( rc.id       ?: '' )
		,          string languageId  = ( rc.language ?: '' )
		,          string property    = ( rc.property ?: '' )
		,          string actionsView = ""
	) {
		gridFields = ListToArray( gridFields );

		var translationObject   = multilingualPresideObjectService.getTranslationObjectName( object );
		var translationRecord   = multilingualPresideObjectService.selectTranslation(
			  objectName   = object
			, id           = recordId
			, languageId   = languageId
			, selectFields = [ "id" ]
		);
		var versionObject       = presideObjectService.getVersionObjectName( translationObject );
		var objectTitleSingular = translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object );
		var optionsCol          = [];
		var results             = dataManagerService.getRecordHistoryForGridListing(
			  objectName  = translationObject
			, recordId    = translationRecord.id ?: ""
			, property    = property
			, startRow    = dtHelper.getStartRow()
			, maxRows     = dtHelper.getMaxRows()
			, orderBy     = dtHelper.getSortOrder()
			, searchQuery = dtHelper.getSearchQuery()
			, filter      = { _translation_language = languageId }
		);
		var records    = Duplicate( results.records );
		var gridFields = [ "published", "datemodified", "_version_author", "_version_changed_fields" ];
		var canEdit    = IsTrue( prc.canEdit ?: "" )
		var canView    = IsTrue( prc.canView ?: "" )

		for( var record in records ){
			for( var field in gridFields ){
				if ( field == "published" ) {
					records[ field ][ records.currentRow ] = renderContent( "boolean", record[ field ], [ "adminDataTable", "admin" ] );
				} else if ( field == "_version_changed_fields" ) {
					var rendered = [];
					for( var changedField in ListToArray( records[ field ][ records.currentRow ] ) ) {
						var translated = translateResource(
							  uri          = "preside-objects.#object#:field.#changedField#.title"
							, defaultValue = translateResource( uri="cms:preside-objects.default.field.#changedField#.title", defaultValue="" )
						);
						if ( Len( Trim( translated ) ) ) {
							rendered.append( translated );
						}
					}
					records[ field ][ records.currentRow ] = '<span title="#HtmlEditFormat( rendered.toList( ', ' ) )#">' & abbreviate( rendered.toList( ", " ), 100 ) & '</span>';
				} else {
					records[ field ][ records.currentRow ] = renderField( versionObject, field, record[ field ], [ "adminDataTable", "admin" ] );
				}
			}

			if ( Len( Trim( actionsView ) ) ) {
				ArrayAppend( optionsCol, renderView( view=actionsView, args=record ) );
			} else {
				ArrayAppend( optionsCol, renderView( view="/admin/datamanager/_historyActions", args={
					  objectName     = object
					, recordId       = recordId
					, canEdit        = canEdit
					, canView        = canView
					, editRecordLink = canEdit ? event.buildAdminLink( objectName=object, recordId=recordId, operation="translateRecord", args={ language=languageId, version=record._version_number } ) : ""
					, viewRecordLink = canView ? event.buildAdminLink( objectName=object, recordId=recordId, operation="viewRecord", args={ language=languageId, version=record._version_number } )      : ""
				} ) );
			}
		}

		QueryAddColumn( records, "_options" , optionsCol );
		ArrayAppend( gridFields, "_options" );

		event.renderData( type="json", data=dtHelper.queryToResult( records, gridFields, results.totalRecords ) );
	}

	private any function _addRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object ?: '' )
		,          string  errorAction             = ""
		,          string  errorUrl                = ( errorAction.len() ? event.buildAdminLink( linkTo=errorAction ) : event.buildAdminLink( objectName=arguments.object, operation="addRecord" ) )
		,          string  viewRecordAction        = ""
		,          string  viewRecordUrl           = event.buildAdminLink( linkTo=( viewRecordAction.len() ? viewRecordAction : "datamanager.viewRecord" ), querystring="object=#arguments.object#&id={newid}" )
		,          string  addAnotherAction        = ""
		,          string  addAnotherUrl           = ( addAnotherAction.len() ? event.buildAdminLink( linkTo=addAnotherAction ) : event.buildAdminLink( objectName=arguments.object, operation="addRecord" ) )
		,          string  successAction           = ""
		,          string  successUrl              = ( successAction.len() ? event.buildAdminLink( linkTo=successAction, queryString='id={newid}' ) : event.buildAdminLink( objectname=arguments.object, operation="listing" ) )
		,          boolean redirectOnSuccess       = true
		,          string  formName                = _getDefaultAddFormName( arguments.object )
		,          string  mergeWithFormName       = ""
		,          boolean audit                   = false
		,          string  auditAction             = ""
		,          string  auditType               = "datamanager"
		,          boolean draftsEnabled           = IsTrue( prc.draftsEnabled ?: "" )
		,          boolean canPublish              = IsTrue( prc.canPublish    ?: "" )
		,          boolean canSaveDraft            = IsTrue( prc.canSaveDraft  ?: "" )
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []
		,          any     validationResult
	) {
		arguments.formName = Len( Trim( arguments.mergeWithFormName ) ) ? formsService.getMergedFormName( arguments.formName, arguments.mergeWithFormName ) : arguments.formName;
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var labelField       = presideObjectService.getObjectAttribute( object, "labelfield", "label" );
		var obj              = "";
		var validationResult = "";
		var newId            = "";
		var newRecordLink    = "";
		var persist          = "";
		var isDraft          = false;
		var args             = arguments;

		args.formData = formData;

		validationResult = validateForm( formName=arguments.formName, formData=formData, validationResult=( arguments.validationResult ?: NullValue() ), stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

		args.formData         = formData;
		args.validationResult = validationResult;
		if ( customizationService.objectHasCustomization( object, "preAddRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preAddRecordAction"
				, args       = args
			);
		}

		if ( not validationResult.validated() ) {
			messageBox.error( translateResource( "cms:datamanager.data.validation.error" ) );
			persist = formData;
			persist.validationResult = validationResult;

			setNextEvent( url=errorUrl, persistStruct=persist );
		}

		if ( arguments.draftsEnabled ) {
			isDraft = ( rc._saveaction ?: "" ) != "publish";

			if ( isDraft && !arguments.canSaveDraft ) {
				event.adminAccessDenied();
			}
			if ( !isDraft && !arguments.canPublish ) {
				event.adminAccessDenied();
			}
		}

		obj = presideObjectService.getObject( object );
		newId = obj.insertData( data=formData, insertManyToManyRecords=true, isDraft=isDraft );

		if ( Len( newId ) ) {
			if ( arguments.audit ) {
				var auditDetail = _getAuditDataFromFormData( formData );
				auditDetail.id = newId;
				auditDetail.objectName = arguments.object;
				if ( arguments.auditAction == "" ) {
					if ( arguments.draftsEnabled && isDraft ) {
						arguments.auditAction = "datamanager_add_draft_record";
					} else {
						arguments.auditAction = "datamanager_add_record";
					}
				}
				event.audit(
					  action   = arguments.auditAction
					, type     = arguments.auditType
					, recordId = newId
					, detail   = auditDetail
				);
			}

			if ( customizationService.objectHasCustomization( object, "postAddRecordAction" ) ) {
				args.newId = newId;
				customizationService.runCustomization(
					  objectName = object
					, action     = "postAddRecordAction"
					, args       = args
				);
			}

			if ( !redirectOnSuccess ) {
				return newId;
			}

			newRecordLink = replaceNoCase( viewRecordUrl, "{newid}", newId, "all" );

			messageBox.info( translateResource( uri="cms:datamanager.recordAdded.confirmation", data=[
				  translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object )
				, '<a href="#newRecordLink#">#event.getValue( name=labelField, defaultValue=translateResource( uri="cms:datamanager.record" ) )#</a>'
			] ) );

			if ( Val( event.getValue( name="_addanother", defaultValue=0 ) ) ) {
				setNextEvent( url=addAnotherUrl, persist="_addAnother" );
			} else {
				setNextEvent( url=replaceNoCase( successUrl, "{newid}", newId, "all" ) );
			}
		} else {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotAdded.unknown.error" ) );
			persist = formData;
			setNextEvent( url=errorUrl, persistStruct=persist );
		}
	}

	private any function _addOneToManyRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object          ?: '' )
		,          string  parentId                = ( rc.parentId        ?: '' )
		,          string  relationshipKey         = ( rc.relationshipKey ?: '' )
		,          string  errorAction             = ""
		,          string  viewRecordAction        = ""
		,          string  addAnotherAction        = ""
		,          string  successAction           = ""
		,          boolean redirectOnSuccess       = true
		,          string  formName                = "preside-objects.#arguments.object#.admin.add"
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []
	) {
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var labelField       = presideObjectService.getObjectAttribute( object, "labelfield", "label" );
		var obj              = "";
		var validationResult = "";
		var newId            = "";
		var newRecordLink    = "";
		var persist          = "";
		var args             = arguments;

		formData[ arguments.relationshipKey ] = arguments.parentId;

		validationResult = validateForm( formName=arguments.formName, formData=formData, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

		args.formData         = formData;
		args.validationResult = validationResult;
		if ( customizationService.objectHasCustomization( object, "preAddRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preAddRecordAction"
				, args       = args
			);
		}

		if ( not validationResult.validated() ) {
			messageBox.error( translateResource( "cms:datamanager.data.validation.error" ) );
			persist = formData;
			persist.validationResult = validationResult;
			if ( Len( errorAction ?: "" ) ) {
				setNextEvent( url=event.buildAdminLink( linkTo=errorAction ), persistStruct=persist );
			} else {
				setNextEvent( url=event.buildAdminLink( linkTo="datamanager.addOneToManyRecord", querystring="object=#object#&parentId=#arguments.parentId#&relationshipKey=#arguments.relationshipKey#" ), persistStruct=persist );
			}
		}

		obj = presideObjectService.getObject( object );
		newId = obj.insertData( data=formData, insertManyToManyRecords=true );

		if ( customizationService.objectHasCustomization( object, "postAddRecordAction" ) ) {
			args.newId = newId;
			customizationService.runCustomization(
				  objectName = object
				, action     = "postAddRecordAction"
				, args       = args
			);
		}

		if ( !redirectOnSuccess ) {
			return newId;
		}

		newRecordLink = event.buildAdminLink( linkTo=viewRecordAction ?: "datamanager.viewRecord", queryString="object=#object#&id=#newId#" );

		messageBox.info( translateResource( uri="cms:datamanager.recordAdded.confirmation", data=[
			  translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object )
			, '<a href="#newRecordLink#">#event.getValue( name=labelField, defaultValue=translateResource( uri="cms:datamanager.record" ) )#</a>'
		] ) );

		if ( Val( event.getValue( name="_addanother", defaultValue=0 ) ) ) {
			if ( Len( addAnotherAction ?: "" ) ) {
				setNextEvent( url=event.buildAdminLink( linkTo=addAnotherAction ), persist="_addAnother" );
			} else {
				setNextEvent( url=event.buildAdminLink( linkTo="datamanager.addOneToManyRecord", queryString="object=#object#&parentId=#arguments.parentId#&relationshipKey=#arguments.relationshipKey#" ), persist="_addAnother" );
			}
		} else {
			if ( Len( successAction ?: "" ) ) {
				setNextEvent( url=event.buildAdminLink( linkTo=successAction ) );
			} else {
				setNextEvent( url=event.buildAdminLink( linkTo="datamanager.manageOneToManyRecords", queryString="object=#object#&parentId=#arguments.parentId#&relationshipKey=#arguments.relationshipKey#" ) );
			}
		}
	}

	private void function _quickAddRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object ?: '' )
		,          string  formName                = _getDefaultQuickAddFormName( argumentCollection=arguments, objectName=arguments.object )
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []

	) {
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var validationResult = validateForm( formName=arguments.formName, formData=formData, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

		if ( customizationService.objectHasCustomization( object, "preQuickAddRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preQuickAddRecordAction"
				, args       = {objectName = object,formData: formData,validationResult=validationResult}
			);
		}

		if ( validationResult.validated() ) {
			var obj = presideObjectService.getObject( object );
			var newId = obj.insertData( data=formData, insertManyToManyRecords=true );

			event.renderData( type="json", data={
				  success  = true
				, recordId = newId
			});
		} else {
			event.renderData( type="json", data={
				  success          = false
				, validationResult = translateValidationMessages( validationResult )
			});
		}

		if ( customizationService.objectHasCustomization( object, "postQuickAddRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "postQuickAddRecordAction"
				, args       = {objectName = object,formData: formData,newId: newId ?: ''}
			);
		}
	}

	private void function _superQuickAddRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object = ( rc.object ?: '' )

	) {
		var filterData = {};
		for( var field in ListToArray( rc.filterByFields ?: "" ) ) {
			if ( Len( Trim( rc[ field ] ?: "" ) ) ) {
				filterData[ field ] = ListLen( rc[ field ] ) > 1 ? ListToArray( rc[ field ] ) : rc[ field ];
			}
		}

		event.renderData( type="json", data=dataManagerService.superQuickAdd(
			  objectName        = arguments.object
			, value             = ( rc.value ?: "" )
			, additionalFilters = filterData
		) );
	}

	private void function _deleteRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object            = ( rc.object ?: '' )
		,          string  postAction        = ""
		,          string  postActionUrl     = ( rc.postActionUrl ?: ( Len( Trim( arguments.postAction ) ) ? event.buildAdminLink( linkTo=postAction ) : event.buildAdminLink( objectName=arguments.object, operation="listing" ) ) )
		,          string  cancelUrl         = cgi.http_referer
		,          boolean redirectOnSuccess = true
		,          boolean audit             = false
		,          string  auditAction       = "datamanager_delete_record"
		,          string  auditType         = "datamanager"
		,          struct  auditDetail       = {}
		,          boolean batch             = false
		,          boolean batchAll          = false
		,          struct  batchSrcArgs      = {}
	) {
		var id               = rc.id          ?: "";
		var forceDelete      = rc.forceDelete ?: false;
		var ids              = ListToArray( id );
		var isBatch          = arguments.batch || ArrayLen( ids ) > 1;
		var blockers         = "";
		var objectName       = arguments.object;
		var objectTitle      = translateResource( uri="preside-objects.#object#:title.singular", defaultValue=objectName );
		var recordLabel      = "";

		if ( isFalse( forceDelete ) ) {
			blockers = presideObjectService.listForeignObjectsBlockingDelete( objectName, ids );

			if ( ArrayLen( blockers ) ) {
				setNextEvent( url=event.buildAdminLink( linkTo="datamanager.cascadeDeletePrompt", queryString="object=#objectName#" ), persistStruct={ blockers = blockers, id=ArrayToList(ids), postActionUrl=postActionUrl, cancelUrl=cancelUrl } );
			}
		}

		if ( isBatch ) {
			var taskId = createTask(
				  event                = "admin.datamanager.batchDeleteInBgThread"
				, runNow               = true
				, adminOwner           = event.getAdminUserId()
				, title                = "cms:datamanager.batchdelete.task.title"
				, returnUrl            = event.buildAdminLink( objectName=objectName, operation="listing" )
				, resultUrl            = postActionUrl
				, discardAfterInterval = CreateTimeSpan( 0, 0, 5, 0 )
				, args       = {
					  objectName   = objectName
					, ids          = ids
					, batchAll     = arguments.batchAll
					, batchSrcArgs = arguments.batchSrcArgs
					, audit        = arguments.audit
					, auditAction  = arguments.auditAction
					, auditType    = arguments.auditType
					, userId       = event.getAdminUserId()
				}
			);

			setNextEvent( url=event.buildAdminLink(
				  linkTo      = "adhoctaskmanager.progress"
				, queryString = "taskId=" & taskId
			) );
		}

		recordLabel = renderLabel( objectName, id );

		var args = arguments;
		if ( customizationService.objectHasCustomization( objectName, "preDeleteRecordAction" ) ) {
			args.records = presideObjectService.selectData( objectName=objectName, id=id ); // here for backward compatibility
			customizationService.runCustomization(
				  objectName = objectName
				, action     = "preDeleteRecordAction"
				, args       = args
			);
		}

		if ( forceDelete ) {
			try {
				presideObjectService.deleteRelatedData( objectName=objectName, recordId=id );
			} catch( "PresideObjectService.CascadeDeleteTooDeep" e ) {
				messageBox.error( translateResource( uri="cms:datamanager.cascadeDelete.cascade.too.deep.error", data=[ objectTitle ] ) );
				setNextEvent( url=postActionUrl );
			}
		}

		if ( presideObjectService.deleteData( objectName=objectName, id=id ) ) {
			if ( arguments.audit ) {
				StructAppend( arguments.auditDetail, { id=id, label=recordLabel, objectName=objectName }, false );

				event.audit(
					  action   = arguments.auditAction
					, type     = arguments.auditType
					, recordId = id
					, detail   = arguments.auditDetail
				);
			}

			if ( customizationService.objectHasCustomization( objectName, "postDeleteRecordAction" ) ) {
				args.records = args.records ?: presideObjectService.selectData( objectName=objectName, id=id ); // here for backward compatibility
				customizationService.runCustomization(
					  objectName = objectName
					, action     = "postDeleteRecordAction"
					, args       = args
				);
			}

			if ( redirectOnSuccess ) {
				messageBox.info( translateResource( uri="cms:datamanager.recordDeleted.confirmation", data=[ objectTitle, recordLabel ] ) );
				setNextEvent( url=postActionUrl );
			}
		} else {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotDeleted.unknown.error" ) );
			setNextEvent( url=postActionUrl );
		}
	}

	private boolean function batchDeleteInBgThread( event, rc, prc, args={}, logger, progress ) {
		var ids        = args.ids        ?: [];
		var objectName = args.objectName ?: "";

		return batchOperationService.batchDeleteRecords(
			  objectName         = args.objectName    ?: ""
			, sourceIds          = args.ids           ?: []
			, audit              = isTrue( args.audit ?: "" )
			, auditAction        = args.auditAction   ?: ""
			, auditType          = args.auditType     ?: ""
			, auditUserId        = args.userId        ?: ""
			, batchAll           = IsTrue( args.batchAll ?: "" )
			, batchSrcArgs       = args.batchSrcArgs  ?: {}
			, logger             = arguments.logger   ?: NullValue()
			, progress           = arguments.progress ?: NullValue()
		);
	}

	private void function _editRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object ?: '' )
		,          string  recordId                = ( rc.id     ?: '' )
		,          string  errorAction             = ""
		,          string  errorUrl                = ( errorAction.len() ? event.buildAdminLink( linkTo=errorAction ) : event.buildAdminLink( linkTo="datamanager.editRecord", querystring="object=#arguments.object#&id=#arguments.recordId#" ) )
		,          string  missingUrl              = event.buildAdminLink( objectname=arguments.object, operation="listing" )
		,          string  successAction           = ""
		,          string  successUrl              = ( successAction.len() ? event.buildAdminLink( linkTo=successAction, queryString='id=' & id ) : event.buildAdminLink( objectname=arguments.object, operation="listing" ) )
		,          boolean redirectOnSuccess       = true
		,          string  formName                = _getDefaultEditFormName( arguments.object )
		,          string  mergeWithFormName       = ""
		,          boolean audit                   = false
		,          string  auditAction             = ""
		,          string  auditType               = "datamanager"
		,          boolean draftsEnabled           = IsTrue( prc.draftsEnabled ?: "" )
		,          boolean canPublish              = IsTrue( prc.canPublish    ?: "" )
		,          boolean canSaveDraft            = IsTrue( prc.canSaveDraft  ?: "" )
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []
		,          any     validationResult
	) {
		arguments.formName = Len( Trim( mergeWithFormName ) ) ? formsService.getMergedFormName( formName, mergeWithFormName ) : formName;

		var id               = rc.id      ?: "";
		var version          = rc.version ?: "";
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var objectName       = translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object );
		var obj              = "";
		var validationResult = "";
		var persist          = "";
		var isDraft          = false;
		var forceVersion     = false;
		var existingRecord   = presideObjectService.selectData( objectName=object, filter={ id=id }, allowDraftVersions=arguments.draftsEnabled );

		if ( !existingRecord.recordCount ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectName  ] ) );

			setNextEvent( url=missingUrl );
		}

		formData.id = id;
		validationResult = validateForm( formName=formName, formData=formData, validationResult=( arguments.validationResult ?: NullValue() ), stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

		var args = arguments;

		args.formData         = formData;
		args.existingRecord   = existingRecord;
		args.validationResult = validationResult;
		if ( customizationService.objectHasCustomization( object, "preEditRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preEditRecordAction"
				, args       = args
			);
		}


		if ( not validationResult.validated() ) {
			messageBox.error( translateResource( "cms:datamanager.data.validation.error" ) );
			persist = formData;
			persist.validationResult = validationResult;

			setNextEvent( url=errorUrl, persistStruct=persist );
		}

		if ( arguments.draftsEnabled ) {
			isDraft = ( rc._saveaction ?: "" ) != "publish";

			if ( isDraft && !arguments.canSaveDraft ) {
				event.adminAccessDenied();
			}
			if ( !isDraft && !arguments.canPublish ) {
				event.adminAccessDenied();
			}

			if ( !isDraft ) {
				forceVersion = IsTrue( existingRecord._version_is_draft ) || IsTrue( existingRecord._version_has_drafts );
			}
		}

		if ( presideObjectService.updateData(
			  id                      = id
			, objectName              = object
			, data                    = formData
			, updateManyToManyRecords = true
			, isDraft                 = isDraft
			, forceVersionCreation    = forceVersion
		) ) {
			if ( arguments.audit ) {
				var auditDetail = _getAuditDataFromFormData( formData );
				auditDetail.objectName = arguments.object;
				if ( !Len( Trim( arguments.auditAction ) ) ) {
					if ( arguments.draftsEnabled ) {
						if ( isDraft ) {
							arguments.auditAction = "datamanager_save_draft_record";
						} else {
							arguments.auditAction = "datamanager_publish_record";
						}
					} else {
						arguments.auditAction = "datamanager_edit_record";
					}
				}
				event.audit(
					  action   = arguments.auditAction
					, type     = arguments.auditType
					, recordId = id
					, detail   = auditDetail
				);
			}

			if ( customizationService.objectHasCustomization( object, "postEditRecordAction" ) ) {
				customizationService.runCustomization(
					  objectName = object
					, action     = "postEditRecordAction"
					, args       = args
				);
			}

			if ( redirectOnSuccess ) {
				messageBox.info( translateResource( uri="cms:datamanager.recordEdited.confirmation", data=[ objectName ] ) );

				setNextEvent( url=successUrl );
			}
		} else {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotUpdated.unknown.error" ) );
			persist = formData;
			setNextEvent( url=errorUrl, persistStruct=persist );
		}
	}

	private void function _cloneRecordAction(required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object ?: '' )
		,          string  recordId                = ( rc.id     ?: '' )
		,          string  errorAction             = ""
		,          string  errorUrl                = ( errorAction.len() ? event.buildAdminLink( linkTo=errorAction ) : event.buildAdminLink( objectName=arguments.object, operation="cloneRecord", recordId=arguments.recordId ) )
		,          string  missingUrl              = event.buildAdminLink( objectname=arguments.object, operation="listing" )
		,          string  successAction           = ""
		,          string  successUrl              = ( successAction.len() ? event.buildAdminLink( linkTo=successAction, queryString='id={id}' ) : event.buildAdminLink( objectname=arguments.object, recordId="{id}" ) )
		,          boolean redirectOnSuccess       = true
		,          string  formName                = _getDefaultCloneFormName( arguments.object )
		,          string  mergeWithFormName       = ""
		,          boolean audit                   = false
		,          string  auditAction             = ""
		,          string  auditType               = "datamanager"
		,          boolean draftsEnabled           = IsTrue( prc.draftsEnabled ?: "" )
		,          boolean canPublish              = IsTrue( prc.canPublish    ?: "" )
		,          boolean canSaveDraft            = IsTrue( prc.canSaveDraft  ?: "" )
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []
		,          any     validationResult
	) {
		arguments.formName = Len( Trim( mergeWithFormName ) ) ? formsService.getMergedFormName( formName, mergeWithFormName ) : formName;

		var id               = rc.id      ?: "";
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var objectName       = prc.objectTitle ?: "";
		var obj              = "";
		var validationResult = "";
		var persist          = "";
		var isDraft          = false;
		var forceVersion     = false;
		var existingRecord   = presideObjectService.selectData( objectName=object, filter={ id=id }, allowDraftVersions=arguments.draftsEnabled );

		if ( !existingRecord.recordCount ) {
			messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ objectName  ] ) );

			setNextEvent( url=missingUrl );
		}

		validationResult = validateForm( formName=formName, formData=formData, validationResult=( arguments.validationResult ?: NullValue() ), stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

		var args = arguments;

		args.formData         = formData;
		args.existingRecord   = existingRecord;
		args.validationResult = validationResult;
		if ( customizationService.objectHasCustomization( object, "preCloneRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preCloneRecordAction"
				, args       = args
			);
		}


		if ( not validationResult.validated() ) {
			messageBox.error( translateResource( "cms:datamanager.data.validation.error" ) );
			persist = formData;
			persist.validationResult = validationResult;

			setNextEvent( url=errorUrl, persistStruct=persist );
		}

		if ( arguments.draftsEnabled ) {
			isDraft = ( rc._saveaction ?: "" ) != "publish";

			if ( isDraft && !arguments.canSaveDraft ) {
				event.adminAccessDenied();
			}
			if ( !isDraft && !arguments.canPublish ) {
				event.adminAccessDenied();
			}
		}

		args.newId = cloningService.cloneRecord(
			  objectName = object
			, recordId   = id
			, data       = formData
			, isDraft    = isDraft
		);

		if ( arguments.audit ) {
			var auditDetail = _getAuditDataFromFormData( formData );
			auditDetail.objectName = arguments.object;
			auditDetail.newid = args.newId;

			if ( !Len( Trim( arguments.auditAction ) ) ) {
				if ( arguments.draftsEnabled ) {
					if ( isDraft ) {
						arguments.auditAction = "datamanager_clone_draft_record";
					} else {
						arguments.auditAction = "datamanager_publish_clone_record";
					}
				} else {
					arguments.auditAction = "datamanager_clone_record";
				}
			}
			event.audit(
				  action   = arguments.auditAction
				, type     = arguments.auditType
				, recordId = id
				, detail   = auditDetail
			);
		}

		if ( customizationService.objectHasCustomization( object, "postCloneRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "postCloneRecordAction"
				, args       = args
			);
		}

		if ( redirectOnSuccess ) {
			messageBox.info( translateResource( uri="cms:datamanager.recordCloned.confirmation", data=[ objectName ] ) );

			setNextEvent( url=successUrl.replace( "{id}", args.newId, "all" ) );
		}
	}

	private void function _quickEditRecordAction(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          string  object                  = ( rc.object ?: '' )
		,          string  formName                = _getDefaultQuickEditFormName( argumentCollection=arguments, objectName=arguments.object )
		,          boolean stripPermissionedFields = true
		,          string  permissionContext       = arguments.object
		,          array   permissionContextKeys   = []

	) {
		var id               = rc.id      ?: "";
		var formData         = event.getCollectionForForm( formName=arguments.formName, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );
		var validationResult = "";

		if ( customizationService.objectHasCustomization( object, "preQuickEditRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "preQuickEditRecordAction"
				, args       = {objectName = object,formData: formData}
			);
		}

		if ( presideObjectService.dataExists( objectName=arguments.object, filter={ id=id } ) ) {
			formData.id = id;
			validationResult = validateForm( formName=arguments.formName, formData=formData, stripPermissionedFields=arguments.stripPermissionedFields, permissionContext=arguments.permissionContext, permissionContextKeys=arguments.permissionContextKeys );

			if ( validationResult.validated() ) {
				presideObjectService.updateData( objectName=object, data=formData, id=id, updateManyToManyRecords=true );
				event.renderData( type="json", data={ success  = true } );
			} else {
				event.renderData( type="json", data={
					  success          = false
					, validationResult = translateValidationMessages( validationResult )
				});
			}

		} else {
			event.renderData( type="json", data={ success = false });
		}

		if ( customizationService.objectHasCustomization( object, "postQuickEditRecordAction" ) ) {
			customizationService.runCustomization(
				  objectName = object
				, action     = "postQuickEditRecordAction"
				, args       = {objectName = object,formData: formData}
			);
		}
	}

	private void function _checkObjectExists(
		  required any     event
		, required struct  rc
		, required struct  prc
		, required string  object
	) {
		if ( not presideObjectService.objectExists( object ) ) {
			messageBox.error( translateResource( uri="cms:datamanager.objectNotFound.error", data=[object] ) );
			setNextEvent( url=event.buildAdminLink( linkTo="datamanager.index" ) );
		}
	}

	private any function _checkPermission(
		  required any     event
		, required struct  rc
		, required struct  prc
		, required string  key
		,          string  object          = prc.objectName ?: ""
		,          boolean throwOnError    = true
		,          boolean checkOperations = true
	) {
		if ( customizationService.objectHasCustomization( arguments.object, "checkPermission" ) ) {
			return customizationService.runCustomization( objectName=arguments.object, action="checkPermission", args={
				  key             = arguments.key
				, object          = arguments.object
				, throwOnError    = arguments.throwOnError
				, checkOperations = arguments.checkOperations
			} );
		}

		var operations      = [ "read", "add", "edit", "batchedit", "delete", "batchdelete", "viewversions", "translate", "clone" ];
		var draftOperations = [ "addRecord", "addRecordAction", "editRecord", "editRecordAction", "translateRecord", "translateRecordAction" ];
		var permitted       = true;

		if ( arguments.checkOperations && operations.contains( arguments.key ) && !datamanagerService.isOperationAllowed( arguments.object, arguments.key ) ) {
			permitted = false;
		} else if ( !hasCmsPermission( permissionKey="datamanager.#arguments.key#", context="datamanager", contextKeys=[ arguments.object ] ) && (!arguments.object.len() || !hasCmsPermission( permissionKey="presideobject.#arguments.object#.#arguments.key#" ) ) ) {
			permitted = false;
		} else if ( arguments.object.len() ) {
			var allowedSiteTemplates = presideObjectService.getObjectAttribute( objectName=arguments.object, attributeName="siteTemplates", defaultValue="*" );

			if ( allowedSiteTemplates != "*" && !ListFindNoCase( allowedSiteTemplates, siteService.getActiveSiteTemplate() ) ) {
				permitted = false;
			}
		}

		if ( permitted && IsTrue( prc.draftsEnabled ?: "" ) && draftOperations.containsNoCase( arguments.key ) ) {
			if ( arguments.key.endsWith( "action" ) ) {
				var isDraft = ( rc._saveaction ?: "" ) != "publish";
				permitted = isDraft ? IsTrue( prc.canSaveDraft ?: "" ) : IsTrue( prc.canPublish ?: "" );
			}
			permitted = IsTrue( prc.canPublish ?: "" ) || IsTrue( prc.canSaveDraft ?: "" );
		}

		if ( !permitted && arguments.throwOnError ) {
			event.adminAccessDenied();
		}


		return permitted;
	}

	private any function _batchEditForm(
		  required any     event
		, required struct  rc
		, required struct  prc
		,          struct  args = {}
	) {
		var object      = args.object ?: "";
		var field       = args.field  ?: "";
		var ids         = args.ids    ?: "";
		var batchAll    = isTrue( args.batchAll ?: "" );
		var recordCount = args.recordCount ?: ListLen( ids );
		var objectName  = translateResource( uri="preside-objects.#object#:title.singular", defaultValue=object ?: "" );
		var fieldName   = translateResource( uri="preside-objects.#object#:field.#field#.title", defaultValue=field );

		args.fieldFormControl = formsService.renderFormControlForObjectField(
		      objectName = object
		    , fieldName  = field
		);

		if ( presideObjectService.isManyToManyProperty( object, field ) ) {
			args.multiEditBehaviourControl = renderFormControl(
				  type   = "select"
				, name   = "multiValueBehaviour"
				, label  = translateResource( uri="cms:datamanager.multiValueBehaviour.title" )
				, values = [ "append", "overwrite", "delete" ]
				, labels = [ translateResource( uri="cms:datamanager.multiDataAppend.title" ), translateResource( uri="cms:datamanager.multiDataOverwrite.title" ), translateResource( uri="cms:datamanager.multiDataDeleteSelected.title" ) ]
			);

			args.batchEditWarning = args.batchEditWarning ?: translateResource(
				  uri  = "cms:datamanager.batch.edit.warning.multi.value" & ( batchAll ? ".filtered" : "" )
				, data = [ "<strong>#objectName#</strong>", "<strong>#fieldName#</strong>", "<strong>#NumberFormat( recordCount )#</strong>" ]
			);
		} else {
			args.batchEditWarning = args.batchEditWarning ?: translateResource(
				  uri  = "cms:datamanager.batch.edit.warning" & ( batchAll ? ".filtered" : "" )
				, data = [ "<strong>#objectName#</strong>", "<strong>#fieldName#</strong>", "<strong>#NumberFormat( recordCount )#</strong>" ]
			);
		}

		return renderView( view="/admin/datamanager/_batchEditForm", args=args );
	}

	private void function _exportDataAction(
		  required any    event
		, required struct rc
		, required struct prc
		,          string exportTemplate     = ( rc.exportTemplate     ?: 'default' )
		,          string exporter           = ( rc.exporter           ?: 'CSV' )
		,          string objectName         = ( rc.object             ?: '' )
		,          string exportFields       = ( rc.exportFields       ?: '' )
		,          string filename           = ( rc.fileName           ?: '' )
		,          string filterExpressions  = ( rc.filterExpressions  ?: '' )
		,          string exportFilterString = ( rc.exportFilterString ?: '' )
		,          string savedFilters       = ( rc.savedFilters       ?: '' )
		,          string orderBy            = ( rc.orderBy            ?: '' )
		,          array  extraFilters       = []
		,          string returnUrl          = cgi.http_referer
		,          struct additionalArgs     = {}

	) {
		var exporterDetail = dataExportService.getExporterDetails( arguments.exporter );
		var selectFields   = arguments.exportFields.listToArray();
		var fullFileName   = arguments.fileName & ".#exporterDetail.fileExtension#";
		var args           = {
			  exportTemplate     = exportTemplate
			, exporter           = exporter
			, objectName         = objectName
			, selectFields       = selectFields
			, extraFilters       = arguments.extraFilters
			, autoGroupBy        = true
			, orderBy            = arguments.orderBy
			, exportFilterString = arguments.exportFilterString
			, exportFileName     = fullFileName
			, mimetype           = exporterDetail.mimeType
			, additionalArgs     = arguments.additionalArgs
			, templateConfig     = dataExportTemplateService.getSubmittedConfig( exportTemplate, objectName )
			, expandNestedFields = dataExportTemplateService.templateMethodExists( exportTemplate, "getSelectFields" ) ? false : true
		};

		try {
			args.extraFilters.append( rulesEngineFilterService.prepareFilter(
				  objectName      = objectName
				, expressionArray = DeSerializeJson( arguments.filterExpressions )
			) );
		} catch( any e ){}

		for( var filter in arguments.savedFilters.listToArray() ) {
			try {
				args.extraFilters.append( rulesEngineFilterService.prepareFilter(
					  objectName = objectName
					, filterId   = filter
				) );
			} catch( any e ){}
		}

		if( Len( Trim( rc.searchQuery ?: "" ) ) ){
			try {
				args.extraFilters.append(
					dataManagerService.buildSearchFilter(
						  q            = rc.searchQuery
						, objectName   = objectName
						, gridFields   = _getObjectFieldsForGrid( objectName )
						, searchFields = dataManagerService.listSearchFields( objectName )
						, expandTerms  = true
					)
				);
			} catch( any e ){}
		}

		var taskId = createTask(
			  event             = "admin.datahelpers.exportDataInBackgroundThread"
			, args              = args
			, runNow            = true
			, adminOwner        = event.getAdminUserId()
			, discardOnComplete = false
			, title             = "cms:dataexport.task.title"
			, resultUrl         = event.buildAdminLink( linkto="datahelpers.downloadExport", querystring="taskId={taskId}" )
			, returnUrl         = arguments.returnUrl
		);

		event.audit(
			  action = "export_data"
			, type   = "dataexport"
			, userId = loginService.getLoggedInUserId()
			, detail = { file=fullFileName ?: "" }
		);

		setNextEvent( url=event.buildAdminLink(
			  linkTo      = "adhoctaskmanager.progress"
			, queryString = "taskId=" & taskId
		) );
	}

	private void function _saveReportAction(
		  required any    event
		, required struct rc
		, required struct prc
		,          string exporter           = ( rc.exporter           ?: 'CSV' )
		,          string objectName         = ( rc.object             ?: '' )
		,          string exportFields       = ( rc.exportFields       ?: '' )
		,          string filename           = ( rc.filename           ?: '' )
		,          string filterExpressions  = ( rc.filterExpressions  ?: '' )
		,          string exportFilterString = ( rc.exportFilterString ?: '' )
		,          string savedFilters       = ( rc.savedFilters       ?: '' )
		,          string orderBy            = ( rc.orderBy            ?: '' )

	) {
		var newSavedReportId = "";
		var data             =  {
			  label         = arguments.filename
			, file_name     = arguments.filename
			, object_name   = arguments.objectName
			, fields        = arguments.exportFields
			, exporter      = arguments.exporter
			, order_by      = arguments.orderBy
			, filter_string = arguments.exportFilterString
		};

		if ( isFeatureEnabled( "rulesEngine" ) ) {
			data.filter       = arguments.filterExpressions;
			data.saved_filter = arguments.savedFilters;
		}

		try {
			newSavedReportId = presideObjectService.insertData( objectName="saved_export", data=data );
		} catch ( any e ) {
			logError( e );
		}

		if( !isEmpty( newSavedReportId ) ) {
			messageBox.info( translateResource( uri="cms:datamanager.saveexport.confirmation" ) );
			setNextEvent( url=event.buildAdminLink( objectName=arguments.objectName, operation="listing" ) );
		} else {
			messageBox.error( translateResource( uri="cms:datamanager.saveexport.error" ) );
			setNextEvent( url=event.buildAdminLink( objectName=arguments.objectName, operation="listing" ) );
		}
	}

	private string function _oneToManyListingActions( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		args.canEdit   = datamanagerService.isOperationAllowed( objectName, "edit"   );
		args.canDelete = datamanagerService.isOperationAllowed( objectName, "delete" );

		return renderView( view="/admin/datamanager/_oneToManyListingActions", args=args );
	}

	private string function _addRecordForm( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		var hasPreFormCustomization       = customizationService.objectHasCustomization( objectName=objectName, action="preRenderAddRecordForm" );
		var hasPostFormCustomization      = customizationService.objectHasCustomization( objectName=objectName, action="postRenderAddRecordForm" );

		args.preForm               = hasPreFormCustomization       ? customizationService.runCustomization( objectName=objectName, action="preRenderAddRecordForm" , args=args ) : "";
		args.postForm              = hasPostFormCustomization      ? customizationService.runCustomization( objectName=objectName, action="postRenderAddRecordForm", args=args ) : "";
		args.renderedActionButtons = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "addRecordActionButtons"
			, args           = args
			, defaultHandler = "admin.datamanager._addRecordActionButtons"
		);

		args.allowAddAnotherSwitch = IsTrue( args.allowAddAnotherSwitch ?: true );

		args.formName = _getDefaultAddFormName( objectName );

		return renderView( view="/admin/datamanager/_addRecordForm", args=args );
	}

	private string function _addRecordActionButtons( event, rc, prc, args={} ) {
		args.actionButtons = customizationService.runCustomization(
			  objectName     = args.objectName ?: ""
			, args           = args
			, action         = "getAddRecordActionButtons"
			, defaultHandler = "admin.datamanager._getAddRecordActionButtons"
		);

		return renderView( view="/admin/datamanager/_addOrEditRecordActionButtons", args=args );
	}

	private array function _getAddRecordActionButtons( event, rc, prc, args={} ) {
		args.draftsEnabled = args.draftsEnabled   ?: false;
		args.canPublish    = args.canPublish      ?: false;
		args.canSaveDraft  = args.canSaveDraft    ?: false;
		args.cancelAction  = args.cancelAction    ?: event.buildAdminLink( objectName=args.objectName );
		args.cancelLabel   = args.cancelLabel     ?: translateResource( "cms:datamanager.cancel.btn" );

		var objectTitle = translateObjectName( args.objectName );

		args.actions = [{
			  type      = "link"
			, href      = args.cancelAction
			, class     = "btn-default"
			, globalKey = "c"
			, iconClass = "fa-reply"
			, label     = args.cancelLabel
		}];

		if ( args.draftsEnabled ) {
			if ( args.canSaveDraft ) {
				args.actions.append({
					  type      = "button"
					, class     = "btn-info"
					, iconClass = "fa-save"
					, name      = "_saveAction"
					, value     = "savedraft"
					, label     = args.saveDraftLabel ?: translateResource( uri="cms:datamanager.add.record.draft.btn", data=[ objectTitle ] )
				});
			}
			if ( args.canPublish ) {
				args.actions.append({
					  type      = "button"
					, class     = "btn-warning"
					, iconClass = "fa-globe"
					, name      = "_saveAction"
					, value     = "publish"
					, label     = args.publishLabel ?: translateResource( uri="cms:datamanager.add.record.publish.btn", data=[ objectTitle ] )
				});
			}
		} else {
			args.actions.append({
				  type      = "button"
				, class     = "btn-info"
				, iconClass = "fa-save"
				, name      = "_saveAction"
				, value     = "publish"
				, label     = args.addRecordLabel ?: translateResource( uri="cms:datamanager.addrecord.btn", data=[ objectTitle ] )
			});
		}

		customizationService.runCustomization(
			  objectName = args.objectName ?: ""
			, args       = args
			, action     = "getExtraAddRecordActionButtons"
		);

		announceInterception( "postGetExtraAddRecordActionButtons", args );

		return args.actions;
	}

	private string function _editRecordForm( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var recordId   = args.recordId   ?: "";

		var hasPreFormCustomization       = customizationService.objectHasCustomization( objectName=objectName, action="preRenderEditRecordForm" );
		var hasPostFormCustomization      = customizationService.objectHasCustomization( objectName=objectName, action="postRenderEditRecordForm" );

		args.formName              = _getDefaultEditFormName( objectName );
		args.preForm               = hasPreFormCustomization       ? customizationService.runCustomization( objectName=objectName, action="preRenderEditRecordForm" , args=args ) : "";
		args.postForm              = hasPostFormCustomization      ? customizationService.runCustomization( objectName=objectName, action="postRenderEditRecordForm", args=args ) : "";
		args.renderedActionButtons = customizationService.runCustomization(
			  objectName     = objectName
			, args           = args
			, action         = "editRecordActionButtons"
			, defaultHandler = "admin.datamanager._editRecordActionButtons"
		);

		args.allowAddAnotherSwitch = IsTrue( args.allowAddAnotherSwitch ?: true );


		args.append({
			  object        = ( args.objectName  ?: "" )
			, id            = ( args.recordId      ?: "" )
			, resultAction  = rc.resultAction ?: ""
		});

		args.readOnly = isTrue( prc.readOnly ?: "" );

		return renderView( view="/admin/datamanager/_editRecordForm", args=args );
	}

	private string function _editRecordActionButtons( event, rc, prc, args={} ) {
		args.actionButtons = customizationService.runCustomization(
			  objectName     = args.objectName ?: ""
			, args           = args
			, action         = "getEditRecordActionButtons"
			, defaultHandler = "admin.datamanager._getEditRecordActionButtons"
		);

		return renderView( view="/admin/datamanager/_addOrEditRecordActionButtons", args=args );
	}

	private string function _cloneRecordActionButtons( event, rc, prc, args={} ) {
		args.actionButtons = customizationService.runCustomization(
			  objectName     = args.objectName ?: ""
			, args           = args
			, action         = "getCloneRecordActionButtons"
			, defaultHandler = "admin.datamanager._getCloneRecordActionButtons"
		);

		return renderView( view="/admin/datamanager/_addOrEditRecordActionButtons", args=args );
	}

	private array function _getEditRecordActionButtons( event, rc, prc, args={} ) {
		args.readOnly      = prc.readOnly         ?: false;
		args.draftsEnabled = args.draftsEnabled   ?: false;
		args.canPublish    = args.canPublish      ?: false;
		args.canSaveDraft  = args.canSaveDraft    ?: false;
		args.cancelAction  = args.cancelAction    ?: event.buildAdminLink( objectName=args.object, recordId=args.id, operation="viewRecord" );
		args.cancelLabel   = args.cancelLabel     ?: translateResource( "cms:datamanager.cancel.btn" );

		if ( !Len( Trim( prc.objectTitle ?: "" ) ) ) {
			prc.objectRootUri = presideObjectService.getResourceBundleUriRoot( args.objectName ?: "" );
			prc.objectTitle   = translateResource( uri=prc.objectRootUri & "title.singular", defaultValue=args.objectName ?: "" );
		}

		args.actions = [{
			  type      = "link"
			, href      = args.cancelAction
			, class     = "btn-default"
			, globalKey = "c"
			, iconClass = "fa-reply"
			, label     = args.cancelLabel
		}];

		if ( !args.readOnly ) {
			if ( args.draftsEnabled ) {
				if ( args.canSaveDraft ) {
					args.actions.append({
						  type      = "button"
						, class     = "btn-info"
						, iconClass = "fa-save"
						, name      = "_saveAction"
						, value     = "savedraft"
						, label     = args.saveDraftLabel ?: translateResource( uri="cms:datamanager.edit.record.draft.btn"  , data=[ prc.objectTitle ?: "" ] )
					});
				}
				if ( args.canPublish ) {
					args.actions.append({
						  type      = "button"
						, class     = "btn-warning"
						, iconClass = "fa-globe"
						, name      = "_saveAction"
						, value     = "publish"
						, label     = args.publishLabel ?: translateResource( uri="cms:datamanager.edit.record.publish.btn", data=[ prc.objectTitle ?: "" ] )
					});
				}
			} else {
				args.actions.append({
					  type      = "button"
					, class     = "btn-info"
					, iconClass = "fa-save"
					, name      = "_saveAction"
					, value     = "publish"
					, label     = args.editRecordLabel ?: translateResource( uri="cms:datamanager.savechanges.btn", data=[ prc.objectTitle ?: "" ] )
				});
			}
		}

		customizationService.runCustomization(
			  objectName = args.objectName ?: ""
			, args       = args
			, action     = "getExtraEditRecordActionButtons"
		);

		announceInterception( "postGetExtraEditRecordActionButtons", args );

		return args.actions;
	}

	private array function _getCloneRecordActionButtons( event, rc, prc, args={} ) {
		args.draftsEnabled = args.draftsEnabled   ?: false;
		args.canPublish    = args.canPublish      ?: false;
		args.canSaveDraft  = args.canSaveDraft    ?: false;
		args.cancelAction  = args.cancelAction    ?: event.buildAdminLink( objectName=args.object, recordId=args.id );
		args.cancelLabel   = args.cancelLabel     ?: translateResource( "cms:datamanager.cancel.btn" );

		if ( !Len( Trim( prc.objectTitle ?: "" ) ) ) {
			prc.objectRootUri = presideObjectService.getResourceBundleUriRoot( args.objectName ?: "" );
			prc.objectTitle   = translateResource( uri=prc.objectRootUri & "title.singular", defaultValue=args.objectName ?: "" );
		}

		args.actions = [{
			  type      = "link"
			, href      = args.cancelAction
			, class     = "btn-default"
			, globalKey = "c"
			, iconClass = "fa-reply"
			, label     = args.cancelLabel
		}];

		if ( args.draftsEnabled ) {
			if ( args.canSaveDraft ) {
				args.actions.append({
					  type      = "button"
					, class     = "btn-info"
					, iconClass = "fa-save"
					, name      = "_saveAction"
					, value     = "savedraft"
					, label     = args.saveDraftLabel ?: translateResource( uri="cms:datamanager.clone.record.draft.btn"  , data=[ prc.objectTitle ?: "" ] )
				});
			}
			if ( args.canPublish ) {
				args.actions.append({
					  type      = "button"
					, class     = "btn-warning"
					, iconClass = "fa-globe"
					, name      = "_saveAction"
					, value     = "publish"
					, label     = args.publishLabel ?: translateResource( uri="cms:datamanager.clone.record.publish.btn", data=[ prc.objectTitle ?: "" ] )
				});
			}
		} else {
			args.actions.append({
				  type      = "button"
				, class     = "btn-info"
				, iconClass = "fa-save"
				, name      = "_saveAction"
				, value     = "publish"
				, label     = args.editRecordLabel ?: translateResource( uri="cms:datamanager.clone.btn", data=[ prc.objectTitle ?: "" ] )
			});
		}

		customizationService.runCustomization(
			  objectName = args.objectName ?: ""
			, args       = args
			, action     = "getExtraCloneRecordActionButtons"
		);

		announceInterception( "postGetExtraCloneRecordActionButtons", args );

		return args.actions;
	}


	private string function _cloneRecordForm( event, rc, prc, args={} ) {
		var objectName      = args.objectName ?: "";
		var recordId        = args.recordId   ?: "";
		var cloneableFields = cloningService.listCloneableFields( objectName=objectName, ignoreIdField=false );

		args.formName = _getDefaultCloneFormName( objectName );
		args.cloneableData = {};
		for( var field in cloneableFields ) {
			args.cloneableData[ field ] = args.record[ field ] ?: "";
		}
		args.append({
			  object = ( args.objectName ?: "" )
			, id     = ( args.recordId   ?: "" )
		});

		var hasPreFormCustomization  = customizationService.objectHasCustomization( objectName=objectName, action="preRenderCloneRecordForm" );
		var hasPostFormCustomization = customizationService.objectHasCustomization( objectName=objectName, action="postRenderCloneRecordForm" );

		args.preForm               = hasPreFormCustomization       ? customizationService.runCustomization( objectName=objectName, action="preRenderCloneRecordForm" , args=args ) : "";
		args.postForm              = hasPostFormCustomization      ? customizationService.runCustomization( objectName=objectName, action="postRenderCloneRecordForm", args=args ) : "";
		args.renderedActionButtons = customizationService.runCustomization(
			  objectName     = objectName
			, args           = args
			, action         = "cloneRecordActionButtons"
			, defaultHandler = "admin.datamanager._cloneRecordActionButtons"
		);

		return renderView( view="/admin/datamanager/_cloneRecordForm", args=args );
	}

	private string function _treeView( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		args.parent   = "";
		args.currentLevel = 0;
		args.topLevel = runEvent(
			  event          = "admin.datamanager._getRecordsForTreeView"
			, eventArguments = { args=args }
			, private        = true
			, prepostExempt  = true
		);
		args.baseViewRecordLink = event.buildAdminLink( objectName=objectName, recordId="{recordId}" );

		args.treeFetchUrl = event.buildAdminLink(
			  objectName  = objectName
			, operation   = "getNodesForTreeView"
			, queryString = "gridFields=#ArrayToList( args.gridFields ?: [] )#&hiddenGridFields=#ArrayToList( args.hiddenGridFields ?: [] )#"
		);

		return renderView( view="/admin/datamanager/_treeView", args=args );
	}

	public void function getNodesForTreeView( event, rc, prc ) {
		var objectName = rc.object ?: "";
		var args = {
			  parent             = rc.parentId ?: ""
			, objectName         = objectName
			, currentLevel       = Val( rc.parentLevel ?: "" ) + 1
			, gridFields         = prc.gridFields ?: _getObjectFieldsForGrid( objectName )
			, isMultilingual     = IsTrue( prc.isMultilingual ?: "" )
			, draftsEnabled      = IsTrue( prc.draftsEnabled  ?: "" )
			, baseViewRecordLink = event.buildAdminLink( objectName=objectName, recordId="{recordId}" )
		};

		if ( StructKeyExists( rc, "hiddenGridFields" ) )  {
			args.hiddenGridFields = ListToArray( rc.hiddenGridFields );
		} else {
			args.hiddenGridFields = _getObjectHiddenFieldsForGrid( objectName );
		}

		var nodes = runEvent(
			  event          = "admin.datamanager._getRecordsForTreeView"
			, eventArguments = { args=args }
			, private        = true
			, prepostExempt  = true
		);

		var rendered = "";

		for( var node in nodes ) {
			args.record = node;
			rendered &= renderView( view="/admin/datamanager/_treeNode", args=args );
		}

		event.renderData( data=rendered );
	}

	private query function _getRecordsForTreeView( event, rc, prc, args={} ) {
		var objectName     = args.objectName ?: "";
		var parent         = args.parent     ?: "";
		var getRecordsArgs = {
			  objectName     = objectName
			, treeViewParent = parent
			, treeView       = true
			, extraFilters   = []
			, gridFields     = []
			, orderby        = dataManagerService.getTreeSortOrder( objectName )
			, autoGroupBy    = true
			, maxRows        = 0
		};

		ArrayAppend( getRecordsArgs.gridFields, args.gridFields       ?: [], true );
		ArrayAppend( getRecordsArgs.gridFields, args.hiddenGridFields ?: [], true );

		customizationService.runCustomization(
			  objectName = objectName
			, action     = "preFetchRecordsForGridListing"
			, args       = getRecordsArgs
		);

		var results = dataManagerService.getRecordsForGridListing( argumentCollection=getRecordsArgs );
		var records = Duplicate( results.records );

		customizationService.runCustomization(
			  objectName = objectName
			, action     = "postFetchRecordsForGridListing"
			, args       = { records=records, objectName=objectName }
		);

		customizationService.runCustomization(
			  objectName     = objectName
			, action         = "decorateRecordsForGridListing"
			, defaultHandler = "admin.datamanager._decorateObjectRecordsForAjaxDataTables"
			, args           = {
				  records         = records
				, objectName      = objectName
				, gridFields      = getRecordsArgs.gridFields
				, useMultiActions = false
				, isMultilingual  = args.isMultilingual
				, draftsEnabled   = args.draftsEnabled
			}
		);

		getRecordsArgs.gridFields.delete( "_status" );
		getRecordsArgs.gridFields.delete( "_translateStatus" );

		var optionsCol = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getActionsForGridListing"
			, defaultHandler = "admin.datamanager._getActionsForAjaxDataTables"
			, args           = {
				  records     = records
				, objectName  = objectName
				, treeView    = true
			}
		);
		QueryAddColumn( records, "_options" , optionsCol );

		return records;
	}

// private utility methods
	private array function _getObjectFieldsForGrid( required string objectName ) {
		var rc = getRequestContext().getCollection();
		if ( Len( rc.gridFields ?: "" ) ) {
			return ListToArray( rc.gridFields );
		}

		return dataManagerService.listGridFields( arguments.objectName );
	}

	private array function _getObjectSortableFields( required string objectName ) {
		return listToArray( presideObjectService.getObjectAttribute(
			  objectName    = arguments.objectName
			, attributeName = "datamanagerSortableFields"
			, defaultValue  = ""
		) );
	}

	private array function _getObjectHiddenFieldsForGrid( required string objectName ) {
		return dataManagerService.listHiddenGridFields( arguments.objectName );
	}

	private boolean function _objectCanBeViewedInDataManager( required any event, required string objectName, boolean relocateIfNoAccess=false ) {
		if ( dataManagerService.isObjectAvailableInDataManager( arguments.objectName ) ) {
			return true;
		}

		if ( arguments.relocateIfNoAccess ) {
			messageBox.error( translateResource( uri="cms:datamanager.objectNotManagedByManager.error", data=[ objectName ] ) );
			setNextEvent(
				url = event.buildAdminLink( "datamanager" )
			);
		}
		return false;
	}

	private struct function _getParentDetailsForOneToManyActions( event, rc, prc ) {
		var object          = rc.object          ?: "";
		var parentId        = rc.parentId        ?: "";
		var relationshipKey = rc.relationshipKey ?: "";
		var parentObject    = presideObjectService.getObjectPropertyAttribute(
			  objectName    = object
			, propertyName  = relationshipKey
			, attributeName = "relatedTo"
		);
		var parentRecord      = presideObjectService.selectData( objectName=parentObject, id=parentId, selectFields=[ "${labelfield} as label" ] );
		var parentObjectTitle = "";

		if ( presideObjectService.isPageType( parentObject ) ) {
			parentObjectTitle = translateResource( "page-types.#parentObject#:name" );
		} else {
			parentObjectTitle = translateResource( "preside-objects.#parentObject#:title.singular" );
		}

		return {
			  parentObject      = parentObject
			, parentRecordLabel = parentRecord.label ?: ""
			, parentObjectTitle = parentObjectTitle
		};
	}

	private void function _rootBreadCrumb( event, rc, prc, args={} ) {
		if ( !Len( Trim( args.objectName ?: "" ) ) || dataManagerService.objectIsIndexedInDatamanagerUi( args.objectName ?: "" ) ) {
			event.addAdminBreadCrumb(
				  title = translateResource( "cms:datamanager" )
				, link  = event.buildAdminLink( linkTo="datamanager" )
			);
		}
	}

	private void function _objectBreadCrumb( event, rc, prc, args={} ) {
		var objectName  = args.objectName  ?: "";
		var objectTitle = args.objectTitle  ?: "";

		event.addAdminBreadCrumb(
			  title = objectTitle
			, link  = event.buildAdminLink( objectName=objectName, operation="listing" )
		);
	}

	private void function _recordBreadcrumb( event, rc, prc, args={} ) {
		var objectName  = args.objectName  ?: "";
		var recordLabel = args.recordLabel ?: "";
		var recordId    = args.recordId    ?: "";

		if ( datamanagerService.isOperationAllowed( objectName, "read" ) ) {
			event.addAdminBreadCrumb(
				  title = translateResource( uri="cms:datamanager.viewrecord.breadcrumb.title", data=[ recordLabel ] )
				, link  = event.buildAdminLink( objectName=objectName, recordId=recordId, operation="viewRecord" )
			);
		}
	}

	private string function _getAddRecordFormName( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var rootForm   = "preside-objects.#objectName#";
		var addForm    = "preside-objects.#objectName#.admin.add";

		if ( formsService.formExists( addForm ) ) {
			return addForm;
		}

		return rootForm;
	}

	private string function _getQuickAddRecordFormName( event, rc, prc, args={} ) {
		var objectName   = args.objectName ?: "";
		var rootForm     = "preside-objects.#objectName#";
		var addForm      = "preside-objects.#objectName#.admin.add";
		var quickAddForm = "preside-objects.#objectName#.admin.quickadd";

		if ( formsService.formExists( quickAddForm ) ) {
			return quickAddForm;
		}

		if ( formsService.formExists( addForm ) ) {
			return addForm;
		}

		return rootForm;
	}

	private string function _getQuickEditRecordFormName( event, rc, prc, args={} ) {
		var objectName    = args.objectName ?: "";
		var rootForm      = "preside-objects.#objectName#";
		var editForm      = "preside-objects.#objectName#.admin.edit";
		var quickEditForm = "preside-objects.#objectName#.admin.quickedit";

		if ( formsService.formExists( quickEditForm ) ) {
			return quickEditForm;
		}

		if ( formsService.formExists( editForm ) ) {
			return editForm;
		}

		return rootForm;
	}

	private string function _getEditRecordFormName( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var rootForm   = "preside-objects.#objectName#";
		var editForm   = "preside-objects.#objectName#.admin.edit";

		if ( formsService.formExists( editForm ) ) {
			return editForm;
		}

		return rootForm;
	}

	private string function _getCloneRecordFormName( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var rootForm   = "preside-objects.#objectName#";
		var cloneForm  = "preside-objects.#objectName#.admin.clone";
		var editForm   = "preside-objects.#objectName#.admin.edit";

		if ( formsService.formExists( cloneForm ) ) {
			return cloneForm;
		}

		if ( formsService.formExists( editForm ) ) {
			return editForm;
		}

		return rootForm;
	}

	private void function _loadCommonVariables( event, action, eventArguments, includeAllFormulaFields=( arguments.action == "viewRecord" ) ) {
		var rc  = event.getCollection();
		var prc = event.getCollection( private=true );

		var e   = "";
		var onlyCheckForLoginActions = [ "getObjectRecordsForAjaxSelectControl" ];
		var useAnyWhereActions       = [
			  "getChildObjectRecordsForAjaxDataTables"
			, "getObjectRecordsForAjaxSelectControl"
			, "quickAddForm"
			, "quickAddRecordAction"
			, "quickEditForm"
			, "quickEditRecordAction"
			, "cascadeDeletePrompt"
			, "configuratorForm"
			, "multiOneToManyRecordAction"
			, "manageOneToManyRecords"
			, "addOneToManyRecord"
			, "addOneToManyRecordAction"
			, "editOneToManyRecord"
			, "editOneToManyRecordAction"
			, "deleteOneToManyRecordAction"
			, "dataExportConfigModal"
			, "exportDataAction"
		];

		if( onlyCheckForLoginActions.containsNoCase( arguments.action ) ){
			return;
		}

		prc.objectName            = "";
		prc.objectTitle           = "";
		prc.objectTitlePlural     = "";
		prc.labelField            = "";
		prc.objectIconClass       = "";
		prc.objectDescription     = "";
		prc.recordId              = "";
		prc.record                = "";
		prc.recordLabel           = "";
		prc.objectRootUri         = "";
		prc.version               = 0;
		prc.objectInDatamanagerUi = false;

		switch( arguments.action ) {
			case "index":
				return;
			break;
			case "object":
			case "getObjectRecordsForAjaxDataTables":
			case "getObjectFilterRecordsForAjaxDataTables":
				prc.objectName = rc.id ?: "";
			break;
			case "addRecordAction":
			case "addSegmentationFilter":
			case "addSegmentationFilterAction":
			case "recalculateSegmentationFilterAction":
				prc.objectName = rc.object ?: "";
			break;
			case "__custom":
				prc.objectName = arguments.objectName ?: "";
				prc.recordId   = arguments.recordId   ?: "";
			break;
			default:
				prc.objectName = rc.object ?: "";
				prc.recordId   = rc.id     ?: "";
		}

		if ( Len( Trim( prc.objectName ) ) ) {
			_checkObjectExists( argumentCollection=arguments, object=prc.objectName );
			_checkPermission( argumentCollection=arguments, key="navigate" );

			if ( !useAnyWhereActions.containsNoCase( arguments.action ) ) {
				_objectCanBeViewedInDataManager( event=event, objectName=prc.objectName, relocateIfNoAccess=true );
			}

			prc.objectInDatamanagerUi = dataManagerService.objectIsIndexedInDatamanagerUi( prc.objectName );
			prc.labelField            = presideObjectService.getLabelField( prc.objectName );
			prc.objectRootUri         = presideObjectService.getResourceBundleUriRoot( prc.objectName );
			prc.objectTitle           = translateResource( uri=prc.objectRootUri & "title.singular", defaultValue=prc.objectName );
			prc.objectTitlePlural     = translateResource( uri=prc.objectRootUri & "title"         , defaultValue=prc.objectName );
			prc.objectIconClass       = translateResource( uri=prc.objectRootUri & "iconClass"     , defaultValue="fa-database" );
			prc.objectDescription     = translateResource( uri=prc.objectRootUri & "description"   , defaultValue="" );
			prc.draftsEnabled         = datamanagerService.areDraftsEnabledForObject( prc.objectName );
			prc.canView               = _checkPermission( argumentCollection=arguments, key="read"              , throwOnError=false );
			prc.canAdd                = _checkPermission( argumentCollection=arguments, key="add"               , throwOnError=false );
			prc.canedit               = _checkPermission( argumentCollection=arguments, key="edit"              , throwOnError=false );
			prc.canBatchEdit          = _checkPermission( argumentCollection=arguments, key="batchedit"         , throwOnError=false );
			prc.canDelete             = _checkPermission( argumentCollection=arguments, key="delete"            , throwOnError=false );
			prc.canBatchDelete        = _checkPermission( argumentCollection=arguments, key="batchdelete"       , throwOnError=false );
			prc.canManagePerms        = _checkPermission( argumentCollection=arguments, key="manageContextPerms", throwOnError=false );
			prc.canViewVersions       = _checkPermission( argumentCollection=arguments, key="viewversions"      , throwOnError=false );
			prc.canClone              = _checkPermission( argumentCollection=arguments, key="clone"             , throwOnError=false );
			prc.canSort               = datamanagerService.isSortable( prc.objectName ) && prc.canEdit;
			prc.gridFields            = _getObjectFieldsForGrid( prc.objectName );
			prc.hiddenGridFields      = _getObjectHiddenFieldsForGrid( prc.objectName );
			prc.batchEditableFields   = isTrue( prc.canBatchEdit ) ? dataManagerService.listBatchEditableFields( prc.objectName ) : [];
			prc.isMultilingual        = multilingualPresideObjectService.isMultilingual( prc.objectName );
			prc.canTranslate          = prc.isMultilingual && _checkPermission( argumentCollection=arguments, key="translate", throwOnError=false );
			prc.useVersioning         = datamanagerService.isOperationAllowed( prc.objectName, "viewversions" ) && presideObjectService.objectIsVersioned( prc.objectName );
			prc.canPublish            = prc.draftsEnabled && _checkPermission( argumentCollection=arguments, key="publish"  , object=prc.objectName, throwOnError=false );
			prc.canSaveDraft          = prc.draftsEnabled && _checkPermission( argumentCollection=arguments, key="savedraft", object=prc.objectName, throwOnError=false );
			prc.isTranslationAction   = arguments.action.contains( "translat" ) > 0;
			if ( prc.isMultilingual && ( prc.isTranslationAction || arguments.action == "viewRecord" ) ) {
				prc.translations = multilingualPresideObjectService.getTranslationStatus( prc.objectName, prc.recordId );
			}

			if ( prc.objectIconClass.len() ) {
				prc.pageIcon = prc.objectIconClass.reReplace( "^fa-", "" );
			}

			if ( Len( Trim( prc.recordId ) ) && ListLen( prc.recordId ) == 1 ) {

				if ( prc.useVersioning ) {
					if ( !prc.isTranslationAction ) {
						prc.version = rc.version = Val( rc.version ?: ( presideObjectService.objectIsVersioned( prc.objectName ) ? versioningService.getLatestVersionNumber( prc.objectName, prc.recordId ) : 0 ) );
					} else {
						prc.version = Val( rc.version ?: "" );
					}
				}

				if ( !prc.isTranslationAction ) {
					if ( prc.useVersioning && prc.version ) {
						if ( !presideObjectService.dataExists( objectName=prc.objectName, id=prc.recordId, useCache=false ) ) {
							messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ prc.objectTitle  ] ) );
							setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, operation="listing" ) );
						}

						prc.record = presideObjectService.selectData( objectName=prc.objectName, id=prc.recordId, useCache=false, includeAllFormulaFields=arguments.includeAllFormulaFields, fromVersionTable=true, specificVersion=prc.version, allowDraftVersions=true, autoGroupBy=arguments.includeAllFormulaFields );
					} else {
						prc.record = presideObjectService.selectData( objectName=prc.objectName, id=prc.recordId, useCache=false, includeAllFormulaFields=arguments.includeAllFormulaFields, allowDraftVersions=true, autoGroupBy=arguments.includeAllFormulaFields );
					}

					if ( !prc.record.recordCount ) {
						messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ prc.objectTitle  ] ) );
						setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, operation="listing" ) );
					}
				} else {
					prc.language = multilingualPresideObjectService.getLanguage( rc.language ?: "" );
					if ( prc.language.isempty() ) {
						messageBox.error( translateResource( uri="cms:multilingual.language.not.active.error" ) );
						setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, recordId=prc.recordId, operation="editRecord" ) );
					}

					prc.sourceRecord  = presideObjectService.selectData( objectName=prc.objectName, filter={ id=prc.recordId }, useCache=false );
					if ( !prc.sourceRecord.recordCount ) {
						messageBox.error( translateResource( uri="cms:datamanager.recordNotFound.error", data=[ prc.objectTitle  ] ) );
						setNextEvent( url=event.buildAdminLink( objectName=prc.objectName, operation="listing" ) );
					}
					if ( prc.useVersioning && prc.version ) {
						prc.record = multiLingualPresideObjectService.selectTranslation( objectName=prc.objectName, id=prc.recordId, languageId=prc.language.id, useCache=false, version=prc.version );
					} else {
						prc.record = multiLingualPresideObjectService.selectTranslation( objectName=prc.objectName, id=prc.recordId, languageId=prc.language.id, useCache=false );
					}

				}


				try {
					prc.recordLabel = renderLabel( prc.objectName, prc.recordId );
				} catch ( "PresideObjectService.no.label.field" e ) {
					prc.recordLabel = prc.recordId;
				}
			}
		}
	}

	private void function _loadCommonBreadCrumbs( event, action, eventArguments ) {
		var prc = event.getCollection( private=true );
		var args = {
			  objectName  = prc.objectName        ?: ""
			, objectTitle = prc.objectTitlePlural ?: ""
			, recordId    = prc.recordId          ?: ""
			, recordLabel = prc.recordLabel       ?: ""
		};


		customizationService.runCustomization(
			  objectName     = args.objectName
			, action         = "rootBreadcrumb"
			, defaultHandler = "admin.datamanager._rootBreadcrumb"
			, args           = args
		);

		if ( Len( Trim( args.objectname ?: "" ) ) ) {
			customizationService.runCustomization(
				  objectName     = args.objectName
				, action         = "objectBreadcrumb"
				, defaultHandler = "admin.datamanager._objectBreadcrumb"
				, args           = args
			);

			if ( Len( Trim( args.recordId ?: "" ) ) && ListLen( args.recordId ) == 1 ) {
				customizationService.runCustomization(
					  objectName     = args.objectName
					, action         = "recordBreadcrumb"
					, defaultHandler = "admin.datamanager._recordBreadcrumb"
					, args           = args
				);
			}
		}
	}

	private void function _loadTopRightButtons( event, action, eventArguments ) {
		var objectName = prc.objectName ?: "";

		prc.topRightButtons = customizationService.runCustomization(
			  objectName     = objectName
			, action         = "topRightButtons"
			, defaultHandler = "admin.datamanager.topRightButtons"
			, args           = { objectName=objectName, action=arguments.action }
		);
	}

	private void function _overrideAdminLayout( event, action, eventArguments ) {
		var objectName       = prc.objectName ?: "";

		if ( !len( objectName ) ) {
			return;
		}

		var adminApplication = presideObjectService.getObjectAttribute( objectName=objectName, attributeName="dataManagerAdminApplication", defaultValue="" );
		var adminLayout      = applicationsService.getLayout( adminApplication );

		if ( !len( adminApplication ) || !len( adminLayout ) ) {
			return;
		}

		event.setLayout( adminLayout );
		event.getAdminBreadCrumbs()[ 1 ].link = applicationsService.getDefaultUrl( applicationId=adminApplication, siteId=event.getSiteId() );
	}

	private string function _getDefaultEditFormName( required string objectName ) {
		return customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getEditRecordFormName"
			, defaultHandler = "admin.datamanager._getEditRecordFormName"
			, args           = { objectName=objectName }
		);
	}

	private string function _getDefaultCloneFormName( required string objectName ) {
		return customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getCloneRecordFormName"
			, defaultHandler = "admin.datamanager._getCloneRecordFormName"
			, args           = { objectName=objectName }
		);
	}


	private string function _getDefaultAddFormName( required string objectName ) {
		return customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getAddRecordFormName"
			, defaultHandler = "admin.datamanager._getAddRecordFormName"
			, args           = { objectName=objectName }
		);
	}

	private string function _getDefaultQuickAddFormName( required string objectName ) {
		return customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getQuickAddRecordFormName"
			, defaultHandler = "admin.datamanager._getQuickAddRecordFormName"
			, args           = { objectName=objectName }
		);
	}

	private string function _getDefaultQuickEditFormName( required string objectName ) {
		return customizationService.runCustomization(
			  objectName     = objectName
			, action         = "getQuickEditRecordFormName"
			, defaultHandler = "admin.datamanager._getQuickEditRecordFormName"
			, args           = { objectName=objectName }
		);
	}

	private struct function _getAuditDataFromFormData( required struct formData ) {
		var auditDetail = {};
		var item        = "";

		for( var key in arguments.formData ) {
			item = formData[ key ];
			if ( isStruct( item ) && StructkeyExists( item, "tempFileInfo" ) ) {
				auditDetail[ key ] = {
					  fileName = item.fileName ?: ""
					, size     = item.size     ?: ""
				};
			} else {
				auditDetail[ key ] = formData[ key ];
			}
		}

		return auditDetail;
	}

	private struct function _deserializeSourceStringForBatchOperations( event, rc, prc, listingUrl ) {
		var deserialized = batchOperationService.deserializeBatchSourceString( rc.batchSrcArgs ?: "" );

		if ( StructCount( deserialized ) ) {
			return deserialized;
		}

		messageBox.error( translateResource( "cms:datamanager.batch.all.source.error" ) );
		setNextEvent( url=arguments.listingUrl );
	}
}