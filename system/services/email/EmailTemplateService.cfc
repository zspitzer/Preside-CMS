/**
 * @singleton      true
 * @presideService true
 * @autodoc        true
 *
 */
component {

	_timeUnitToCfMapping = {
		  second  = "s"
		, minute  = "n"
		, hour    = "h"
		, day     = "d"
		, week    = "ww"
		, month   = "m"
		, quarter = "q"
		, year    = "yyyy"
	};

	/**
	 * @systemEmailTemplateService.inject systemEmailTemplateService
	 * @emailRecipientTypeService.inject  emailRecipientTypeService
	 * @emailLayoutService.inject         emailLayoutService
	 * @emailSendingContextService.inject emailSendingContextService
	 * @emailStyleInliner.inject          emailStyleInliner
	 * @emailStatsService.inject          emailStatsService
	 * @assetManagerService.inject        assetManagerService
	 * @emailSettings.inject              coldbox:setting:email
	 * @templateCache.inject              cachebox:emailTemplateCache
	 * @timeSeriesUtils.inject            timeSeriesUtils
	 *
	 */
	public any function init(
		  required any systemEmailTemplateService
		, required any emailRecipientTypeService
		, required any emailLayoutService
		, required any emailSendingContextService
		, required any assetManagerService
		, required any emailStyleInliner
		, required any emailStatsService
		, required any emailSettings
		, required any templateCache
		, required any timeSeriesUtils
	) {
		_setSystemEmailTemplateService( arguments.systemEmailTemplateService );
		_setEmailRecipientTypeService( arguments.emailRecipientTypeService );
		_setEmailLayoutService( arguments.emailLayoutService );
		_setEmailSendingContextService( arguments.emailSendingContextService );
		_setEmailStyleInliner( arguments.emailStyleInliner );
		_setEmailStatsService( arguments.emailStatsService );
		_setAssetManagerService( arguments.assetManagerService );
		_setEmailSettings( arguments.emailSettings );
		_setTemplateCache( arguments.templateCache );
		_setTimeSeriesUtils( arguments.timeSeriesUtils );

		return this;
	}

// PUBLIC API
	/**
	 * Prepares an email message ready for sending (returns a struct with
	 * information about the message)
	 *
	 * @autodoc true
	 * @template.hint       The ID of the template to send
	 * @args.hint           Structure of args to provide email specific information about the send (i.e. userId of web user to send to, etc.)
	 * @recipientId.hint    ID of the recipient to send the email to
	 * @to.hint             Optional array of addresses to send the email to (leave empty should the recipient type for the template be able to calculate this for you)
	 * @cc.hint             Optional array of addresses to cc in to the email
	 * @bcc.hint            Optional array of addresses to bcc in to the email
	 * @parameters.hint     Optional struct of variables for use in content token substitution in subject and body
	 * @messageHeaders.hint Optional struct of email message headers to set
	 * @isTest.hint         Whether or not this is for a test send
	 */
	public struct function prepareMessage(
		  required string  template
		, required struct  args
		,          string  recipientId       = ""
		,          array   to                = []
		,          array   cc                = []
		,          array   bcc               = []
		,          struct  parameters        = {}
		,          array   attachments       = []
		,          struct  messageHeaders    = {}
		,          boolean isTest            = false
		,          boolean isPreview         = false
		,          numeric version           = 0
		,          boolean useDefaultContent = false
		,          string  layout            = ""
		,          string  customLayout      = ""
	) {
		$announceInterception( "prePrepareEmailMessage", arguments );

		var messageTemplate  = getTemplate( id=arguments.template, allowDrafts=( arguments.isTest || arguments.isPreview ), version=arguments.version );
		var isSystemTemplate = _getSystemEmailTemplateService().templateExists( arguments.template );

		if ( messageTemplate.isEmpty() ) {
			throw( type="preside.emailtemplateservice.missing.template", message="The email template, [#arguments.template#], could not be found." );
		}

		if ( arguments.useDefaultContent ) {
			messageTemplate.html_body = _getSystemEmailTemplateService().getDefaultHtmlBody( template=messageTemplate.id );
			messageTemplate.text_body = _getSystemEmailTemplateService().getDefaultHtmlBody( template=messageTemplate.id );
		}

		if ( arguments.isPreview ) {
			enableDomainOverwriteForBuildLink( template=messageTemplate );
		}

		if ( !Len( Trim( messageTemplate.layout ?: "" ) ) ) {
			messageTemplate.layout = _getSystemEmailTemplateService().getDefaultLayout( template=messageTemplate.id );
		}

		if ( Len( Trim( arguments.recipientId ) ) ) {
			_getEmailSendingContextService().setContext(
				  recipientType = messageTemplate.recipient_type ?: ""
				, recipientId   = arguments.recipientId
				, templateId    = arguments.template
				, template      = messageTemplate
			);
		}
		try {
			var unsubscribeLink = _getEmailRecipientTypeService().getUnsubscribeLink(
				  recipientType = messageTemplate.recipient_type
				, recipientId   = arguments.recipientId
				, templateId    = arguments.template
			);
			var message = {
				  subject     = messageTemplate.subject
				, from        = messageTemplate.from_address
				, to          = arguments.to
				, cc          = arguments.cc
				, bcc         = arguments.bcc
				, params      = arguments.messageHeaders
				, attachments = arguments.attachments
			};
			var viewOnline = ( IsBoolean( messageTemplate.view_online ?: "" ) && messageTemplate.view_online );

			if ( !arguments.isPreview ) {
				if ( !message.to.len() ) {
					message.to = [ _getEmailRecipientTypeService().getToAddress( recipientType=messageTemplate.recipient_type, recipientId=arguments.recipientId ) ];
				}

				if ( !message.from.len() ) {
					message.from = $getPresideSetting( "email", "default_from_address" );
				}

				message.attachments.append( getAttachments( templateId = arguments.template, allowDrafts=arguments.isTest ), true );
				if ( isSystemTemplate ) {
					message.attachments.append( _getSystemEmailTemplateService().prepareAttachments(
						  template = arguments.template
						, args     = arguments.args
					), true );
				}
			}

			message.textBody = _getEmailLayoutService().renderLayout(
				  layout         = Len( arguments.layout ) ? arguments.layout : messageTemplate.layout
				, emailTemplate  = arguments.template
				, templateDetail = messageTemplate
				, blueprint      = messageTemplate.email_blueprint
				, customLayout   = arguments.customLayout
				, type           = "text"
				, subject        = message.subject
				, body           = messageTemplate.text_body
				, viewOnlineLink = viewOnline ? "{{viewonline}}" : ""
			);

			var preppedHtml = _prepareHtml(
				  argumentCollection = arguments
				, message            = message
				, messageTemplate    = messageTemplate
				, unsubscribeLink    = unsubscribeLink
				, viewOnline         = viewOnline
			);
			message.htmlBody = $renderContent( renderer="richeditor", data=preppedHtml.html, context="email", args={ styles=preppedHtml.styles } );

			var params = Duplicate( arguments.parameters );

			if ( !arguments.isPreview || Len( arguments.recipientId ) ) {
				params.append( prepareParameters(
					  template       = arguments.template
					, recipientType  = messageTemplate.recipient_type
					, recipientId    = arguments.recipientId
					, args           = arguments.args
					, templateDetail = messageTemplate
					, styles         = preppedHtml.styles
					, detectedParams = _detectParams( message.htmlBody & message.textBody & message.subject )
				) );
			} else {
				params.append( getPreviewParameters(
					  template      = arguments.template
					, recipientType = messageTemplate.recipient_type
				) );
			}

			message.subject  = replaceParameterTokens( message.subject , params, "text" );
			message.textBody = replaceParameterTokens( message.textBody, params, "text" );
			message.htmlBody = replaceParameterTokens( message.htmlBody, params, "html", preppedHtml.styles );

			if ( Len( Trim( unsubscribeLink ) ) ) {
				message.htmlBody = replace( message.htmlBody, "{{unsubscribeLink}}", unsubscribeLink );
			}

			if ( viewOnline && !$helpers.isEmptyString( message.htmlBody ) ) {
				var viewOnlineLink = getViewOnlineLink( message.htmlBody );
				message.htmlBody   = replace( message.htmlBody, "{{viewonline}}", viewOnlineLink );
				message.textBody   = replace( message.textBody, "{{viewonline}}", viewOnlineLink );
			}

			if ( Len( Trim( unsubscribeLink ) ) && !StructKeyExists( message.params, "List-Unsubscribe" ) ) {
				message.params[ "List-Unsubscribe" ] = { name="List-Unsubscribe", value=unsubscribeLink };
			}

			$announceInterception( "postPrepareEmailMessage", { message=message, args=arguments } );
		} catch( any e ) {
			rethrow;
		} finally {
			if ( arguments.isPreview ) {
				disableDomainOverwriteForBuildLink();
			}
			_getEmailSendingContextService().clearContext();
		}

		return message;
	}

	/**
	 * Method to allow post processing on dynamic email
	 * content snippets - i.e. inlining css styles into
	 * generated content.
	 *
	 * @autodoc     true
	 * @html.hint   HTML to process
	 * @styles.hint Array of styles to apply when using emailStyleInliner feature (previously extracted from emailStyleInliner.readStyles( html ))
	 *
	 */
	public string function renderHtmlSnippet(
		  required string html
		,          array  styles = []
	) {
		if ( $isFeatureEnabled( "emailStyleInliner" ) && ArrayLen( arguments.styles ) ) {
			return _getEmailStyleInliner().inlineStyles( arguments.html, arguments.styles );
		}

		return arguments.html;
	}

	/**
	 * Prepares an email message ready for preview (returns a struct with
	 * subject, htmlBody + textBody keys)
	 *
	 * @autodoc               true
	 * @template.hint         The ID of the template to send
	 * @allowDrafts.hint      Whether or not to allow draft versions of the template
	 * @version.hint          A specific version number to preview (default is latest)
	 * @previewRecipient.hint Optional ID of a recipient whose preview parameters we will fetch and whose context data to use when rendering the email content
	 */
	public struct function previewTemplate(
		  required string  template
		,          boolean allowDrafts       = false
		,          numeric version           = 0
		,          string  previewRecipient  = ""
		,          boolean useDefaultContent = false
	) {
		return prepareMessage(
			  template          = arguments.template
			, args              = {}
			, recipientId       = arguments.previewRecipient
			, isPreview         = true
			, version           = arguments.version
			, useDefaultContent = arguments.useDefaultContent
		);
	}

	/**
	 * Returns an array of required email params that are missing
	 * from the given content.
	 *
	 * @autodoc       true
	 * @template.hint ID of the template to check against
	 * @content.hint  Text content to check
	 */
	public array function listMissingParams(
		  required string template
		, required string content
	) {
		var messageTemplate = getTemplate( id=arguments.template, allowDrafts=true );

		var expectedParams  = [];
		var missingParams   = [];

		if ( messageTemplate.count() ) {
			if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
				expectedParams.append( _getSystemEmailTemplateService().listTemplateParameters( arguments.template ), true );
			}
			expectedParams.append( _getEmailRecipientTypeService().listRecipientTypeParameters( messageTemplate.recipient_type ), true );
			for( var param in expectedParams ) {
				if ( param.required && !arguments.content.findNoCase( "${#param.id#}" ) ) {
					missingParams.append( "${#param.id#}" );
				}
			}
		}

		return missingParams;
	}

	/**
	 * Returns a boolean defining whether email content for a system template should be
	 * saved or not.
	 *
	 * @autodoc       true
	 * @template.hint ID of the template whose content save setting you wish to get
	 *
	 */
	public boolean function shouldSaveContentForTemplate( required string template ) {
		var messageTemplate = getTemplate( id=arguments.template );

		if ( messageTemplate.count() ) {
			if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
				return _getSystemEmailTemplateService().shouldSaveContentForTemplate( arguments.template );
			}

			if ( isBoolean( messageTemplate.save_content ) ) {
				return messageTemplate.save_content;
			}
		}

		return false;
	}

	/**
	 * How many days the saved content of an email should be retained for. If not
	 * specifically configured, will return the system default.
	 *
	 * @autodoc       true
	 * @template.hint ID of the template whose content expiry setting you wish to get
	 *
	 */
	public numeric function getSavedContentExpiry( required string template ) {
		var defaultExpiry    = _getEmailSettings().defaultContentExpiry;
		var messageTemplate  = getTemplate( id=arguments.template );
		var configuredExpiry = "";

		if ( messageTemplate.count() ) {
			if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
				configuredExpiry = _getSystemEmailTemplateService().getSavedContentExpiry( arguments.template );
			} else {
				configuredExpiry = messageTemplate.save_content_expiry;
			}
		}

		return isNumeric( configuredExpiry ) ? configuredExpiry : defaultExpiry;
	}

	/**
	 * Inserts or updates the given email template
	 *
	 * @autodoc  true
	 * @template Struct containing fields to save
	 * @id       Optional ID of the template to save (if empty, assumes its a new template)
	 *
	 */
	public string function saveTemplate(
		  required struct  template
		,          string  id               = ""
		,          boolean isDraft          = false
		,          boolean forcePublication = false
	) {
		transaction {
			if ( Len( Trim( arguments.id ) ) ) {
				var updated = $getPresideObject( "email_template" ).updateData(
					  id                      = arguments.id
					, data                    = arguments.template
					, isDraft                 = arguments.isDraft
					, forceVersionCreation    = !arguments.isDraft && arguments.forcePublication
					, updateManyToManyRecords = true
				);

				if ( updated ) {
					$audit(
						  action   = arguments.isDraft ? "saveDraftEmailTemplate" : "editEmailTemplate"
						, type     = "emailtemplate"
						, recordId = arguments.id
						, detail   = { isSystemEmail = _getSystemEmailTemplateService().templateExists( id ) }
					);

					_getTemplateCache().clear( "savedrawhtml" & arguments.id );

					return arguments.id;
				}

				arguments.template.id = arguments.id;

			}

			if ( Len( Trim( arguments.template.email_blueprint ?: "" ) ) && !Len( Trim( arguments.template.sending_method ?: "" ) ) ) {
				var blueprint = $getPresideObject( "email_blueprint" ).selectData( id=arguments.template.email_blueprint );

				if ( Len( Trim( blueprint.recipient_type ?: "" ) ) ) {
					var filterObject = _getEmailRecipientTypeService().getFilterObjectForRecipientType( blueprint.recipient_type );
					if ( Len( Trim( filterObject ) ) ) {
						arguments.template.sending_method = "manual";
					} else {
						arguments.template.sending_method = "auto";
					}
				}
			}

			var newId = $getPresideObject( "email_template" ).insertData(
				  data                    = arguments.template
				, isDraft                 = arguments.isDraft
				, insertManyToManyRecords = true
			);
			newId = newId ?: "";
			$audit(
				  action   = arguments.isDraft ? "createDraftEmailTemplate" : "insertEmailTemplate"
				, type     = "emailtemplate"
				, recordId = newId
				, detail   = { isSystemEmail = _getSystemEmailTemplateService().templateExists( id ) }
			);

			return arguments.template.id ?: newId;
		}
	}

	/**
	 * Returns whether or not the given template exists in the database
	 *
	 * @autodoc true
	 * @id.hint ID of the template to check
	 */
	public boolean function templateExists( required string id ) {
		return $getPresideObject( "email_template" ).dataExists( id=arguments.id );
	}

	/**
	 * Returns the saved template from the database
	 *
	 * @autodoc          true
	 * @id.hint          ID of the template to get
	 * @allowDrafts.hint Whether or not to allow draft versions of the template
	 * @version.hint     Specific version from version history to get
	 *
	 */
	public struct function getTemplate(
		  required string  id
		,          boolean allowDrafts       = false
		,          numeric version           = 0
		,          boolean fromVersionTable  = ( arguments.allowDrafts || arguments.version )
		,          array   extraSelectFields = []
	){
		var template = $getPresideObject( "email_template" ).selectData(
			  id                 = arguments.id
			, allowDraftVersions = arguments.allowDrafts
			, fromversionTable   = arguments.fromVersionTable
			, specificVersion    = arguments.version
			, extraSelectFields  = arguments.extraSelectFields
			, useCache           = false
		);

		for( var t in template ) {
			if ( ( t.email_blueprint ?: "" ).len() ) {
				var blueprint = $getPresideObject( "email_blueprint" ).selectData( id=t.email_blueprint );
				if ( blueprint.recordCount ) {
					t.layout           = blueprint.layout;
					t.recipient_type   = blueprint.recipient_type;
					t.blueprint_filter = blueprint.recipient_filter;
					t.service_provider = blueprint.service_provider;
				}
			}

			return t;
		}

		return {};
	}

	/**
	 * Returns a query of templates matching the provided filters
	 *
	 * @autodoc            true
	 * @custom.hint        Whether or not the templates should be custom (if not, they are system)
	 * @recipientType.hint The recipient type of the templates
	 * @allowDrafts.hint   Whether or not to get draft templates
	 */
	public query function getTemplates(
		  required boolean custom
		,          string  recipientType = ""
		,          boolean allowDrafts   = true
	) {
		var filters = [];

		filters.append( { filter={ is_system_email = !arguments.custom } } );

		if ( Len( Trim( arguments.recipientType ) ) ) {
			filters.append( {
				  filter       = "email_template.recipient_type = :recipient_type or ( email_template.recipient_type is null and email_blueprint.recipient_type = :recipient_type )"
				, filterParams = { recipient_type = recipientType }
			} );
		}

		return $getPresideObject( "email_template" ).selectData(
			  extraFilters       = filters
			, allowDraftVersions = arguments.allowDrafts
		);
	}

	/**
	 * Returns whether or not click tracking is enabled for the given template
	 *
	 * @autodoc         true
	 * @templateId.hint ID of the template to check
	 */
	public boolean function isTrackingEnabled( required string templateId ) {
		return arguments.templateId.len() && $getPresideObject( "email_template" ).dataExists(
			filter = { id=arguments.templateId, track_clicks=true }
		);
	}

	/**
	 * Replaces parameter tokens in strings (subject, body) with
	 * passed in values.
	 *
	 * @autodoc true
	 * @text    The raw text that contains the parameter tokens
	 * @params  A struct of params. Each param can either be a simple value or a struct with simple values for `html` and `text` keys
	 * @type    Either 'text' or 'html'
	 *
	 */
	public string function replaceParameterTokens(
		  required string text
		, required struct params
		, required string type
	) {
		arguments.type = arguments.type == "text" ? "text" : "html";
		var replaced = JavaCast( "String", arguments.text );
		var Matcher  = CreateObject( "java", "java.util.regex.Matcher" );

		for( var paramName in arguments.params ) {
			var token = "(?i)\Q${#paramName#}\E";
			var value = IsSimpleValue( arguments.params[ paramName ] ) ? arguments.params[ paramName ] : ( arguments.params[ paramName ][ arguments.type ] ?: "" );

			replaced = replaced.replaceAll( token, Matcher.quoteReplacement( value ) );
		}

		return replaced;
	}

	/**
	 * Prepares params (for use in replacing tokens in subject and body)
	 * for the given email template, recipient type and sending args.
	 *
	 * @autodoc        true
	 * @template       ID of the template of the email that is being prepared
	 * @recipientType  ID of the recipient type of the email that is being prepared
	 * @recipientId    ID of the recipient
	 * @args           Structure of variables that are being used to send / prepare the email
	 * @templateDetail Structure the template record
	 * @styles         Used to do style inlining in any prepared html when feature enabled
	 * @detectedParams Parameters detected in the content that are required to be swapped out
	 */
	public struct function prepareParameters(
		  required string template
		, required string recipientType
		, required string recipientId
		, required struct args
		,          struct templateDetail = {}
		,          array  styles = []
		,          array  detectedParams
	) {
		var anythingToDo = !StructKeyExists( arguments, "detectedParams" ) || ArrayLen( arguments.detectedParams );
		if ( !anythingToDo ) {
			return {};
		}

		var params = _getEmailRecipientTypeService().prepareParameters(
			  recipientType  = arguments.recipientType
			, recipientId    = arguments.recipientId
			, args           = arguments.args
			, template       = arguments.template
			, templateDetail = arguments.templateDetail
			, detectedParams = arguments.detectedParams ?: NullValue()
		);
		if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
			params.append( _getSystemEmailTemplateService().prepareParameters(
				  template       = arguments.template
				, args           = arguments.args
				, templateDetail = arguments.templateDetail
				, detectedParams = arguments.detectedParams ?: NullValue()
			) );
		}

		if ( $isFeatureEnabled( "emailStyleInliner" ) && ArrayLen( arguments.styles ) ) {
			for( var paramName in params ) {
				if ( IsStruct( params[ paramName ] ) && Len( params[ paramName ].html ?: "" ) ) {
					params[ paramName ].html = renderHtmlSnippet( params[ paramName ].html, arguments.styles );
				}
			}
		}

		return params;
	}

	/**
	 * Returns preview  params (for use in replacing tokens in subject and body)
	 * for the given email template and recipient type.
	 *
	 * @autodoc       true
	 * @template      ID of the template of the email that is being prepared
	 * @recipientType ID of the recipient type of the email that is being prepared
	 */
	public struct function getPreviewParameters(
		  required string template
		, required string recipientType
	) {
		var params = _getEmailRecipientTypeService().getPreviewParameters(
			recipientType = arguments.recipientType
		);
		if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
			params.append( _getSystemEmailTemplateService().getPreviewParameters(
				template = arguments.template
			) );
		}

		return params;
	}

	/**
	 * Returns preview  params (for use in replacing tokens in subject and body)
	 * for the given email template and recipient type.
	 *
	 * @autodoc       true
	 * @template      ID of the template of the email that is being prepared
	 * @logId         ID of the email template log entry
	 * @originalArgs  The args originally used and stored in the template log
	 */
	public struct function rebuildArgsForResend(
		  required string template
		, required string logId
		, required struct originalArgs
	) {
		if ( _getSystemEmailTemplateService().templateExists( arguments.template ) ) {
			return _getSystemEmailTemplateService().rebuildArgsForResend(
				  template     = arguments.template
				, logId        = arguments.logId
				, originalArgs = arguments.originalArgs
			);
		}

		return arguments.originalArgs;
	}

	/**
	 * Updates fields related to scheduled sending to maintain schedules
	 *
	 * @autodoc         true
	 * @templateId.hint ID of the template to update
	 * @markAsSent.hint Whether or not to mark a 'fixedschedule' template as sent
	 */
	public string function updateScheduledSendFields( required string templateId, boolean markAsSent=false ) {
		var template    = getTemplate( id=arguments.templateId, allowDrafts=true, fromVersionTable=false );
		var updatedData = { schedule_next_send_date = "" };

		if ( template.sending_method == "scheduled" ) {
			if ( template.schedule_type == "repeat" ) {
				var nowish  = _getNow();
				var expired = ( IsDate( template.schedule_end_date ) && template.schedule_end_date < nowish );

				if( !expired ){
					if( ( IsDate( template.schedule_start_date ) && template.schedule_start_date > nowish ) ){
						updatedData.schedule_next_send_date = template.schedule_start_date;
					} else {
						updatedData.schedule_next_send_date = _calculateNextSendDate( template.schedule_measure, template.schedule_unit, template.schedule_start_date );
					}

					if ( IsDate( template.schedule_end_date ) && updatedData.schedule_next_send_date >= template.schedule_end_date ){
						updatedData.schedule_next_send_date = "";
					}
				}

				updatedData.schedule_date = "";
				updatedData.schedule_sent = "";
			} else {
				updatedData.schedule_start_date = "";
				updatedData.schedule_end_date   = "";
				updatedData.schedule_unit       = "";
				updatedData.schedule_measure    = "";

				if ( arguments.markAsSent ) {
					updatedData.schedule_sent = true;
				} else if ( IsBoolean( template.schedule_sent ?: "" ) && template.schedule_sent && template.schedule_date > Now() ) {
					updatedData.schedule_sent = false;
				}
			}
		} else {
			updatedData = {
				  schedule_type           = ""
				, schedule_date           = ""
				, schedule_start_date     = ""
				, schedule_end_date       = ""
				, schedule_unit           = ""
				, schedule_measure        = ""
				, schedule_sent           = ""
				, schedule_next_send_date = ""
			};
		}

		return saveTemplate( id=arguments.templateId, template=updatedData, isDraft=( template._version_is_draft ?: false ) );
	}

/**
	 * Update the date of last email sent
	 *
	 * @autodoc           true
	 * @templateId.hint   ID of the template to update
	 * @lastSentDate.hint The date of last sent
	 */
	public string function updateLastSentDate(
		  required string templateId
		, required string lastSentDate
	) {
		return saveTemplate( id=arguments.templateId, template={ last_sent_date=arguments.lastSentDate } );
	}

	/**
	 * Returns an array of template IDs of templates
	 * using a fixed date schedule who are due to send
	 *
	 * @autodoc true
	 */
	public array function listDueOneTimeScheduleTemplates() {
		var records = $getPresideObject( "email_template" ).selectData(
			  selectFields       = [ "id" ]
			, filter             = "sending_method = :sending_method and schedule_type = :schedule_type and (schedule_sent is null or schedule_sent = :schedule_sent)"
			, filterParams       = { sending_method="scheduled", schedule_type="fixeddate", schedule_sent=false }
			, extraFilters       = [ { filter="schedule_date <= :schedule_date", filterParams={ schedule_date=_getNow() } } ]
			, orderBy            = "schedule_date"
			, allowDraftVersions = false
			, useCache           = false
		);

		return records.recordCount ? ValueArray( records.id ) : [];
	}

	/**
	 * Returns an array of template IDs of templates
	 * using a repeated schedule who are due to send
	 *
	 * @autodoc true
	 */
	public array function listDueRepeatedScheduleTemplates() {
		var records = $getPresideObject( "email_template" ).selectData(
			  selectFields       = [ "id" ]
			, filter             = { sending_method="scheduled", schedule_type="repeat" }
			, extraFilters       = [ { filter="schedule_next_send_date <= :schedule_next_send_date", filterParams={ schedule_next_send_date=_getNow() } } ]
			, orderBy            = "schedule_next_send_date"
			, allowDraftVersions = false
			, useCache           = false
		);

		return records.recordCount ? ValueArray( records.id ) : [];
	}

	/**
	 * Gets an array of an email template's editorially attached
	 * attachments.
	 *
	 * @autodoc
	 * @templateId.hint ID of the template whose attachments you want to get
	 *
	 */
	public array function getAttachments(
		  required string  templateId
		,          boolean allowDrafts      = false
		,          boolean fromVersionTable = arguments.allowDrafts
  	) {
		var assetManagerService = _getAssetManagerService()
		var attachments         = [];
		var assets              = $getPresideObject( "email_template" ).selectData(
			  id                 = arguments.templateId
			, selectFields       = [ "attachments.id", "attachments.title", "attachments.asset_type" ]
			, orderBy            = "email_template_attachment.sort_order"
			, allowDraftVersions = arguments.allowDrafts
			, fromversionTable   = arguments.fromVersionTable
		);

		for ( var asset in assets ) {
			var binary = assetManagerService.getAssetBinary( id=asset.id, throwOnMissing=false );
			var type   = assetManagerService.getAssetType( name=asset.asset_type, throwOnMissing=false );

			if ( !IsNull( local.binary ) ) {
				attachments.append({
					  binary          = binary
					, name            = asset.title & "." & ( type.extension ?: "" )
					, removeAfterSend = false
				});
			}
		}

		return attachments;
	}

	/**
	 * Gets a count of emails sent in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getSentCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "send_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "sent_date >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "sent_date <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log" ).selectData(
			  selectFields = [ "Count( 1 ) as sent_count" ]
			, filter       = { email_template=arguments.templateId, sent=true }
			, extraFilters = extraFilters
			, useCache     = false
		);

		return Val( result.sent_count ?: "" );
	}

	/**
	 * Gets a count of delivered  emails sent in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getDeliveredCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "delivery_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "delivered_date >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "delivered_date <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log" ).selectData(
			  selectFields = [ "Count( 1 ) as delivered_count" ]
			, filter       = { email_template=arguments.templateId, delivered=true }
			, extraFilters = extraFilters
			, useCache     = false
		);

		return Val( result.delivered_count ?: "" );
	}

	/**
	 * Gets a unique count of opened emails sent in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getUniqueOpenedCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "unique_open_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "opened_date >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "opened_date <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log" ).selectData(
			  selectFields = [ "Count( 1 ) as opened_count" ]
			, filter       = { email_template=arguments.templateId, opened=true }
			, extraFilters = extraFilters
		);

		return Val( result.opened_count ?: "" );
	}

	/**
	 * Gets a comulative count of opened emails sent in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getOpenedCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "open_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "email_template_send_log_activity.datecreated >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "email_template_send_log_activity.datecreated <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log_activity" ).selectData(
			  selectFields = [ "Count( 1 ) as opened_count" ]
			, filter       = { "message.email_template"=arguments.templateId, activity_type="open" }
			, forceJoins   = "inner"
			, extraFilters = extraFilters
		);

		return Val( result.opened_count ?: "" );
	}

	/**
	 * Gets a count of link clicks in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getClickCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "click_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "email_template_send_log_activity.datecreated >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "email_template_send_log_activity.datecreated <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log_activity" ).selectData(
			  selectFields = [ "Count( 1 ) as click_count" ]
			, filter       = { "message.email_template"=arguments.templateId, activity_type="click" }
			, forceJoins   = "inner"
			, extraFilters = extraFilters
		);

		return Val( result.click_count ?: "" );
	}

	/**
	 * Gets a count of emails failed in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 */
	public numeric function getFailedCount(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatCount(
				  templateId = arguments.templateId
				, field      = "fail_count"
				, dateFrom   = arguments.dateFrom
				, dateTo     = arguments.dateTo
			);
		}

		var extraFilters = [];

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "failed_date >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "failed_date <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}
		var result = $getPresideObject( "email_template_send_log" ).selectData(
			  selectFields = [ "Count( 1 ) as failed_count" ]
			, filter       = { email_template=arguments.templateId, failed=true }
			, extraFilters = extraFilters
		);

		return Val( result.failed_count ?: "" );
	}

	/**
	 * Gets a count of queued emails for
	 * the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 */
	public numeric function getQueuedCount(
		  required string templateId
	) {
		var result = $getPresideObject( "email_mass_send_queue" ).selectData(
			  selectFields = [ "Count( 1 ) as queued_count" ]
			, filter       = { template=arguments.templateId }
			, useCache     = false
		);

		return Val( result.queued_count ?: "" );
	}

	/**
	 * Collates various stat counts for the given template in the given
	 * timeframe for the given template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template to get counts for
	 * @dateFrom   Optional date from which to count
	 * @dateTo     Optional date to which to count
	 * @timePoints Optional number of points to break out the stats over time (i.e. for use in graphing)
	 */
	public struct function getStats(
		  required string  templateId
		,          string  dateFrom    = getFirstStatDate( arguments.templateId )
		,          string  dateTo      = getLastStatDate( arguments.templateId )
		,          numeric timePoints  = 1
		,          boolean uniqueOpens = ( arguments.timePoints == 1 )
		,          array   stats       = []
	) {
		if ( arguments.timePoints != 1 && _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getStatsOverTime( argumentCollection=arguments );
		}

		if ( arguments.timePoints == 1 ) {
			return {
				  sent      = getSentCount( argumentCollection=arguments )
				, delivered = getDeliveredCount( argumentCollection=arguments )
				, failed    = getFailedCount( argumentCollection=arguments )
				, opened    = arguments.uniqueOpens ? getUniqueOpenedCount( argumentCollection=arguments ) : getOpenedCount( argumentCollection=arguments )
				, queued    = getQueuedCount( templateId=arguments.templateId )
				, clicks    = getClickCount( argumentCollection=arguments )
			};
		}

		var timeSeriesUtils = _getTimeSeriesUtils();
		var timeResolution  = timeSeriesUtils.calculateTimeResolution( arguments.dateFrom, arguments.dateTo );
		var dates           = timeSeriesUtils.getExpectedTimes( timeResolution, arguments.dateFrom, arguments.dateTo );
		var commonArgs      = {
			  timeResolution    = timeResolution
			, expectedTimes     = dates
			, sourceObject      = "email_template_send_log"
			, startDate         = arguments.dateFrom
			, endDate           = arguments.dateTo
			, valuesOnly        = true
			, aggregateFunction = "count"
		};

		var stats = {
			  sent      = timeSeriesUtils.getTimeSeriesData( argumentCollection=commonArgs, timeField="sent_date"                                   , extraFilters=[ { filter={ email_template=arguments.templateId, sent=true      } } ] )
			, delivered = timeSeriesUtils.getTimeSeriesData( argumentCollection=commonArgs, timeField="delivered_date"                              , extraFilters=[ { filter={ email_template=arguments.templateId, delivered=true } } ] )
			, failed    = timeSeriesUtils.getTimeSeriesData( argumentCollection=commonArgs, timeField="failed_date"                                 , extraFilters=[ { filter={ email_template=arguments.templateId, failed=true    } } ] )
			, opened    = timeSeriesUtils.getTimeSeriesData( argumentCollection=commonArgs, timeField="opened_date"                                 , extraFilters=[ { filter={ email_template=arguments.templateId, opened=true    } } ] )
			, clicks    = timeSeriesUtils.getTimeSeriesData( argumentCollection=commonArgs, timeField="email_template_send_log_activity.datecreated", extraFilters=[ { filter={ "message.email_template"=arguments.templateId, activity_type="click"  } } ], sourceObject="email_template_send_log_activity" )
			, dates     = dates
		};

		for( var i=1; i <= ArrayLen( stats.dates ); i++ ) {
			stats.dates[ i ] = DateTimeFormat( stats.dates[ i ], "yyyy-mm-dd HH:nn" );
		}

		return stats;
	}

	/**
	 * Retrieves the earliest date on which
	 * there are statistics for the given
	 * template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template
	 *
	 */
	public any function getFirstStatDate( required string templateId ) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getFirstStatDate( argumentCollection=arguments );
		}

		var earliestRecord = $getPresideObject( "email_template" ).selectData(
			  id           = arguments.templateId
			, selectFields = [ "min( send_logs.datecreated ) as earliest" ]
			, forceJoins   = "inner"
		);

		return earliestRecord.earliest ?: "";
	}

	/**
	 * Retrieves the latest date on which
	 * there are statistics for the given
	 * template.
	 *
	 * @autodoc    true
	 * @templateId ID of the template
	 *
	 */
	public any function getLastStatDate( required string templateId ) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getLastStatDate( argumentCollection=arguments );
		}

		var dates          = [];
		var latestActivity = $getPresideObject( "email_template" ).selectData(
			  id           = arguments.templateId
			, selectFields = [ "max( send_logs$activities.datecreated ) as latest" ]
			, forceJoins = "inner"
		);
		var latestKeyDates = $getPresideObject( "email_template" ).selectData(
			  id           = arguments.templateId
			, forceJoins   = "inner"
			, selectFields = [
				  "max( send_logs.sent_date           ) as sent_date"
				, "max( send_logs.failed_date         ) as failed_date"
				, "max( send_logs.delivered_date      ) as delivered_date"
				, "max( send_logs.hard_bounced_date   ) as hard_bounced_date"
				, "max( send_logs.opened_date         ) as opened_date"
				, "max( send_logs.marked_as_spam_date ) as marked_as_spam_date"
				, "max( send_logs.unsubscribed_date   ) as unsubscribed_date"
			  ]
		);

		if ( IsDate( latestActivity.latest              ) ) { dates.append( latestActivity.latest              ); }
		if ( IsDate( latestKeyDates.sent_date           ) ) { dates.append( latestKeyDates.sent_date           ); }
		if ( IsDate( latestKeyDates.failed_date         ) ) { dates.append( latestKeyDates.failed_date         ); }
		if ( IsDate( latestKeyDates.delivered_date      ) ) { dates.append( latestKeyDates.delivered_date      ); }
		if ( IsDate( latestKeyDates.hard_bounced_date   ) ) { dates.append( latestKeyDates.hard_bounced_date   ); }
		if ( IsDate( latestKeyDates.opened_date         ) ) { dates.append( latestKeyDates.opened_date         ); }
		if ( IsDate( latestKeyDates.marked_as_spam_date ) ) { dates.append( latestKeyDates.marked_as_spam_date ); }
		if ( IsDate( latestKeyDates.unsubscribed_date   ) ) { dates.append( latestKeyDates.unsubscribed_date   ); }

		if ( dates.len() ) {
			dates.sort( function( a, b ){
				return a > b ? -1 : 1;
			} );

			return dates[ 1 ];
		}

		return "";

	}

	/**
	 * Returns link click stats for a given template
	 *
	 * @autodoc    true
	 * @templateId Id of the template for which to get the count. If not provided, the number of queued emails will be for all templates.
	 * @dateFrom   Optional date from which to fetch link clicking stats
	 * @dateTo     Optional date to which to fetch link clicking stats
	 */
	public struct function getLinkClickStats(
		  required string templateId
		,          string dateFrom = ""
		,          string dateTo   = ""
	) {
		if ( _usePerformantLogging( arguments.templateId ) ) {
			return _getEmailStatsService().getLinkClickStats( argumentCollection=arguments );
		}

		var extraFilters = [{
			filter = { activity_type="click" }
		}];

		extraFilters.append( { filter="email_template_send_log_activity.link is not null" } );

		if ( IsDate( arguments.dateFrom ) ) {
			extraFilters.append({
				  filter = "email_template_send_log_activity.datecreated >= :dateFrom"
				, filterParams = { dateFrom={ type="cf_sql_timestamp", value=arguments.dateFrom } }
			});
		}
		if ( IsDate( arguments.dateTo ) ) {
			extraFilters.append({
				  filter       = "email_template_send_log_activity.datecreated <= :dateTo"
				, filterParams = { dateTo={ type="cf_sql_timestamp", value=arguments.dateTo } }
			});
		}

		var clickStats    = StructNew( "ordered" );
		var rawClickStats = $getPresideObject( "email_template_send_log_activity" ).selectData(
			  filter       = { "message.email_template"=arguments.templateId }
			, selectFields = [ "count( 1 ) as click_count", "link", "link_title", "link_body" ]
			, extraFilters = extraFilters
			, autoGroupBy  = true
			, orderBy      = "click_count desc"
		);

		for( var link in rawClickStats ) {
			if ( !StructKeyExists( clickStats, link.link_body ) ) {
				clickStats[ link.link_body ] = {
					  links      = []
					, totalCount = 0
				};
			}

			ArrayAppend( clickStats[ link.link_body ].links, {
				  link       = link.link
				, title      = link.link_title
				, body       = link.link_body
				, clickCount = link.click_count
			} )

			clickStats[ link.link_body ].totalCount += link.click_count;
		}

		return clickStats;
	}

	/**
	 * Returns a query of queued email counts grouped by email template
	 *
	 * @autodoc    true
	 */
	public query function getQueueStats() {
		return $getPresideObject( "email_mass_send_queue" ).selectData(
			  autoGroupBy  = true
			, orderBy      = "template.name"
			, selectFields = [
				  "Count( email_mass_send_queue.id ) as queued_count"
				, "template.id"
				, "template.name"
			  ]
		);
	}

	/**
	 * Returns number of queued email counts optionally filtered
	 * by template ID
	 *
	 * @autodoc         true
	 * @templateId.hint Optioanl id of the template for which to get the count. If not provided, the number of queued emails will be for all templates.
	 */
	public numeric function getQueueCount( string templateId="" ) {
		var filter = {};

		if ( arguments.templateId.len() ) {
			filter.template = arguments.templateId;
		}

		return $getPresideObject( "email_mass_send_queue" ).selectData(
			  recordCountOnly = true
			, filter          = filter
		);
	}

	/**
	 * Clears queued emails optionally filtered
	 * by template ID
	 *
	 * @autodoc         true
	 * @templateId.hint Optioanl id of the template whose queued emails you wish to clear. If not provided, all queued emails will be cleared
	 */
	public numeric function clearQueue( string templateId="" ) {
		var filter = {};

		if ( arguments.templateId.len() ) {
			filter.template = arguments.templateId;
		}

		return $getPresideObject( "email_mass_send_queue" ).deleteData(
			  filter         = filter
			, forceDeleteAll = !arguments.templateId.len()
		);
	}

	public void function enableDomainOverwriteForBuildLink( required struct template ) {
		if ( !$isFeatureEnabled( "emailOverwriteDomain" ) ) {
			return;
		}

		if ( len( arguments.template.id ?: "" ) && len( arguments.template.layout ?: "" ) && len( arguments.template.email_blueprint ?: "" ) ) {
			var layoutConfig = _getEmailLayoutService().getLayoutConfig(
				  layout        = arguments.template.layout
	            , emailTemplate = arguments.template.id
	            , blueprint     = arguments.template.email_blueprint
	            , merged        = true
			);

			if ( len( layoutConfig.overwrite_domain ?: "" ) ) {
				$getRequestContext().setOverwriteDomainForBuildLink( domain=layoutConfig.overwrite_domain );
			}
		}
	}

	public void function disableDomainOverwriteForBuildLink() {
		if ( !$isFeatureEnabled( "emailOverwriteDomain" ) ) {
			return;
		}

		$getRequestContext().removeOverwriteDomainForBuildLink();
	}

	public void function ensureSystemTemplatesHaveDbEntries() {
		var sysTemplateService = _getSystemEmailTemplateService();
		var systemTemplates    = sysTemplateService.listTemplates();
		var existingTemplates  = _getExistingSystemTemplates();
		var recipientType      = "";

		for( var template in systemTemplates ) {
			recipientType = sysTemplateService.getRecipientType( template.id );
			if ( !existingTemplates.keyExists( template.id ) ) {
				saveTemplate( id=template.id, template={
					  name            = template.title
					, layout          = sysTemplateService.getDefaultLayout( template.id )
					, subject         = sysTemplateService.getDefaultSubject( template.id )
					, html_body       = sysTemplateService.getDefaultHtmlBody( template.id )
					, text_body       = sysTemplateService.getDefaultTextBody( template.id )
					, recipient_type  = recipientType
					, is_system_email = true
				} );
			} else if ( existingTemplates[ template.id ].recipient_type != recipientType ) {
				saveTemplate( id=template.id, template={ recipient_type=recipientType } );
			}
		}
	}

// PRIVATE HELPERS
	private struct function _getExistingSystemTemplates() {
		var templates     = {};
		var templateQuery = $getPresideObject( "email_template" ).selectData(
			  filter       = { is_system_email=true }
			, selectFields = [ "id", "recipient_type" ]
		);

		for( var template in templateQuery ) {
			templates[ template.id ] = template;
		}

		return templates;
	}

	private date function _getNow() {
		return Now(); // abstraction to make testing easier
	}

	private any function _calculateNextSendDate(
		  required numeric measure
		, required string  unit
		, required any     startDate
	) {
		if ( !StructKeyExists( _timeUnitToCfMapping, arguments.unit ) ) {
			return "";
		}

		var nowish = _getNow();
		var cfunit = _timeUnitToCfMapping[ arguments.unit ];

		if ( IsDate( arguments.startDate ) ) {
			var nextDate         = arguments.startDate;

			while( nextDate <= nowish ) {
				nextDate = DateAdd( cfunit, arguments.measure, nextDate );
			}

			return nextDate;
		}

		return DateAdd( cfunit, arguments.measure, nowish );
	}

	/**
	 * Gets the view online content ID
	 * for the given content string (i.e. HTML email)
	 *
	 * @autodoc      true
	 * @content.hint HTML content of the email
	 *
	 */
	public string function getViewOnlineContentId( required string content ) {
		var dao         = $getPresideObject( "email_template_view_online_content" );
		var contentHash = Hash( arguments.content );
		var contentId   = "";
		var existing    = "";

		transaction {
			existing = dao.selectData(
				  selectFields = [ "id" ]
				, filter       = { content_hash = contentHash }
			);

			if ( existing.recordCount ) {
				contentId = existing.id;
			} else {
				try {
					contentId = dao.insertData( {
						  content      = ReplaceNoCase( arguments.content, "{{viewonline}}", "", "all" )
						, content_hash = contentHash
					} );
				} catch( any e ) { // i.e. a duplicate record created due to multithreading
					existing = dao.selectData(
						  selectFields = [ "id" ]
						, filter       = { content_hash = contentHash }
						, useCache     = false
					);

					if ( existing.recordCount ) {
						contentId = existing.id;
					} else {
						rethrow;
					}
				}
			}
		}

		return contentId;
	}

	/**
	 * Gets the view online content
	 * for the given content ID
	 *
	 * @autodoc true
	 * @id.hint ID of the content to get
	 *
	 */
	public string function getViewOnlineContent( required string id ) {
		var dao    = $getPresideObject( "email_template_view_online_content" );
		var record = dao.selectData( id=arguments.id, selectFields=[ "content" ] );

		return Trim( record.content ?: "" );
	}

	/**
	 * Gets the view online link for a given piece of HTML
	 * email content.
	 *
	 * @autodoc      true
	 * @content.hint The content for which to get the link
	 */
	public string function getViewOnlineLink( required string content ) {
		var viewOnlineId = getViewOnlineContentId( arguments.content );

		return $getRequestContext().buildLink(
			  linkTo      = "email.viewOnline"
			, queryString = "mid=#viewOnlineId#"
		);
	}

// PRIVATE HELPERS
	private string function _addIFrameBaseLinkTagForPreviewHtml( required string html ) {
		return html.replace( "</head>", '<base target="_parent"></head>' );
	}

	private struct function _prepareHtml(
		  message
		, messageTemplate
		, unsubscribeLink
		, template
		, viewOnline
	) {
		var cacheKey = ( $helpers.isTrue( arguments.useDefaultContent ?: "" ) ? "default" : "saved" ) & "rawhtml" & arguments.template;
		var fromCache = _getTemplateCache().get( cacheKey );

		if ( !IsNull( local.fromCache ) ) {
			return fromCache;
		}

		var htmlArgs = {
			  layout          = Len( arguments.layout ) ? arguments.layout : arguments.messageTemplate.layout
			, emailTemplate   = arguments.template
			, templateDetail  = arguments.messageTemplate
			, blueprint       = arguments.messageTemplate.email_blueprint
			, customLayout    = arguments.customLayout ?: ""
			, type            = "html"
			, subject         = arguments.message.subject
			, body            = arguments.messageTemplate.html_body
			, unsubscribeLink = Len( Trim( arguments.unsubscribeLink ) ) ? "{{unsubscribeLink}}" : ""
			, viewOnlineLink  = arguments.viewOnline ? "{{viewonline}}" : ""
		};

		var html = _getEmailLayoutService().renderLayout( argumentCollection=htmlArgs );

		if ( $isFeatureEnabled( "emailStyleInliner" ) ) {
			var styles = _getEmailStyleInliner().readStyles( html );
			html = _getEmailStyleInliner().inlineStyles( html, styles );
		}

		var result = {
			  html   = html
			, styles = ( styles ?: [] )
		};

		_getTemplateCache().set( cacheKey, result );

		return result;
	}

	private array function _detectParams( required string content ) {
		var regexPattern = "\$\{([a-zA-Z_\-0-9]+)\}";
		var rawMatches   = ReMatch( regexPattern, arguments.content );
		var params = [];

		for( var rawMatch in rawMatches ) {
			ArrayAppend( params, ReReplace( rawMatch, regexPattern, "\1" ) );
		}

		return params;
	}

	private boolean function _usePerformantLogging( required string templateId ) {
		var requestCacheKey = "_usePerformantLogging#arguments.templateId#";

		if ( !StructKeyExists( request, requestCacheKey ) ) {
			request[ requestCacheKey ] = $getPresideObject( "email_template" ).dataExists( filter={
				  id                       = arguments.templateId
				, stats_collection_enabled = true
			} );
		}

		return request[ requestCacheKey ];
	}

// GETTERS AND SETTERS
	private any function _getSystemEmailTemplateService() {
		return _systemEmailTemplateService;
	}
	private void function _setSystemEmailTemplateService( required any systemEmailTemplateService ) {
		_systemEmailTemplateService = arguments.systemEmailTemplateService;
	}

	private any function _getEmailRecipientTypeService() {
		return _emailRecipientTypeService;
	}
	private void function _setEmailRecipientTypeService( required any emailRecipientTypeService ) {
		_emailRecipientTypeService = arguments.emailRecipientTypeService;
	}

	private any function _getEmailLayoutService() {
		return _emailLayoutService;
	}
	private void function _setEmailLayoutService( required any emailLayoutService ) {
		_emailLayoutService = arguments.emailLayoutService;
	}

	private any function _getEmailSendingContextService() {
		return _emailSendingContextService;
	}
	private void function _setEmailSendingContextService( required any emailSendingContextService ) {
		_emailSendingContextService = arguments.emailSendingContextService;
	}

	private any function _getAssetManagerService() {
		return _assetManagerService;
	}
	private void function _setAssetManagerService( required any assetManagerService ) {
		_assetManagerService = arguments.assetManagerService;
	}

	private any function _getEmailStyleInliner() {
		return _emailStyleInliner;
	}
	private void function _setEmailStyleInliner( required any emailStyleInliner ) {
		_emailStyleInliner = arguments.emailStyleInliner;
	}

	private any function _getEmailSettings() {
		return _emailSettings;
	}
	private void function _setEmailSettings( required any emailSettings ) {
		_emailSettings = arguments.emailSettings;
	}

	private any function _getTemplateCache() {
	    return _templateCache;
	}
	private void function _setTemplateCache( required any templateCache ) {
	    _templateCache = arguments.templateCache;
	}

	private any function _getTimeSeriesUtils() {
	    return _timeSeriesUtils;
	}
	private void function _setTimeSeriesUtils( required any timeSeriesUtils ) {
	    _timeSeriesUtils = arguments.timeSeriesUtils;
	}

	private any function _getEmailStatsService() {
	    return _emailStatsService;
	}
	private void function _setEmailStatsService( required any emailStatsService ) {
	    _emailStatsService = arguments.emailStatsService;
	}
}