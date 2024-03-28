/**
 * Service that provides logic for logging email sends and updates to email delivery status
 *
 * @autodoc        true
 * @singleton      true
 * @presideService true
 */
component {

	variables._lib       = [];
	variables._jsoup     = "";
	variables._oneMinute = CreateTimespan( 0, 0, 1, 0 );

// CONSTRUCTOR
	/**
	 * @recipientTypeService.inject     emailRecipientTypeService
	 * @emailTemplateService.inject     emailTemplateService
	 * @sqlRunner.inject                sqlRunner
	 * @emailStatsService.inject        emailStatsService
	 * @emailBotDetectionService.inject emailBotDetectionService
	 *
	 */
	public any function init(
		  required any   recipientTypeService
		, required any   emailTemplateService
		, required any   sqlRunner
		, required any   emailStatsService
		, required any   emailBotDetectionService
	) {
		_setRecipientTypeService( arguments.recipientTypeService );
		_setEmailTemplateService( arguments.emailTemplateService );
		_setSqlRunner( arguments.sqlRunner );
		_setEmailStatsService( arguments.emailStatsService );
		_setEmailBotDetectionService( arguments.emailBotDetectionService );

		_jsoup = _new( "org.jsoup.Jsoup" );

		return this;
	}

// PUBLIC API METHODS
	/**
	 * Creates an email log entry and returns its ID (useful for future
	 * status updates to email delivery)
	 *
	 * @autodoc            true
	 * @template.hint      ID of the email template that is being sent
	 * @recipientType.hint ID of the recipient type configured for the template
	 * @recipient.hint     email address of the recipient
	 * @sender.hint        email address of the sender
	 * @subject.hint       Subject line of the email
	 * @sendArgs.hint      Structure of args that were original sent to the email send() method
	 */
	public string function createEmailLog(
		  required string template
		, required string recipientType
		, required string recipientId
		, required string recipient
		, required string sender
		, required string subject
		,          string resendOf = ""
		,          struct sendArgs = {}
		,          string layoutOverride = ""
		,          string customLayout   = ""
	) {
		var data = {
			  email_template  = arguments.template
			, recipient       = arguments.recipient
			, sender          = arguments.sender
			, subject         = arguments.subject
			, resend_of       = arguments.resendOf
			, send_args       = SerializeJson( arguments.sendArgs )
			, layout_override = arguments.layoutOverride
			, custom_layout   = arguments.customLayout
		};

		if ( Len( Trim( arguments.recipientType ) ) ) {
			data.append( _getAdditionalDataForRecipientType( arguments.recipientType, arguments.recipientId, arguments.sendArgs ) );
		}

		return $getPresideObject( "email_template_send_log" ).insertData( data );
	}

	/**
	 * Saves the email content of a sent email, to be used to view exact content
	 * sent, and for resending the original email
	 *
	 * @autodoc            true
	 * @template.hint      ID of the email template
	 * @id.hint            ID of the email template log record
	 * @htmlBody.hint      HTML content of the email
	 * @textBody.hint      Plain-text content of the email
	 */
	public void function logEmailContent(
		  required string template
		, required string id
		, required string htmlBody
		, required string textBody
	) {
		if ( !$isFeatureEnabled( "emailCenterResend" ) ) {
			return;
		}
		if ( !_getEmailTemplateService().shouldSaveContentForTemplate( arguments.template ) ) {
			return;
		}

		var contentExpiry = _getEmailTemplateService().getSavedContentExpiry( arguments.template );
		if ( contentExpiry <= 0 ) {
			return;
		}

		var expires       = now().add( "d", contentExpiry );
		var contentId     = $getPresideObject( "email_template_send_log_content" ).insertData( {
			  html_body = arguments.htmlBody
			, text_body = arguments.textBody
			, expires   = expires
		} );

		$getPresideObject( "email_template_send_log" ).updateData( id=arguments.id, data={
			content = contentId
		} );
	}

	/**
	 * Marks the given email as sent
	 *
	 * @autodoc         true
	 * @id.hint         ID of the email to mark as sent
	 * @templateId.hint ID of the email template
	 *
	 */
	public void function markAsSent(
		  required string id
		,          string templateId = ""
	) {
		var now     = _getNow();
		var updated = $getPresideObject( "email_template_send_log" ).updateData( id=arguments.id, data={
			  sent      = true
			, sent_date = now
		} );

		if ( updated ) {
			if ( !$helpers.isEmptyString( arguments.templateId ) ) {
				_getEmailTemplateService().updateLastSentDate( templateId=arguments.templateId, lastSentDate=now );
			}

			recordActivity(
				  messageId = arguments.id
				, activity  = "send"
			);
		}
	}

	/**
	 * Marks the given email as failed
	 *
	 * @autodoc     true
	 * @id.hint     ID of the email to mark as failed
	 * @reason.hint Failure reason to record
	 * @code.hint   Failure code to record
	 *
	 */
	public void function markAsFailed( required string id, required string reason, string code="" ) {
		var errorCode = Len( Trim( arguments.code ) ) ? Val( arguments.code ) : "";
		var updated = $getPresideObject( "email_template_send_log" ).updateData(
			  filter       = "id = :id and ( failed is null or failed = :failed ) and ( opened is null or opened = :opened )"
			, filterParams = { id=arguments.id, failed=false, opened=false }
			, data={
				  failed        = true
				, failed_date   = _getNow()
				, failed_reason = arguments.reason
				, failed_code   = errorCode
			  }
		);

		if ( updated ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "fail"
				, extraData = { reason=arguments.reason, code=errorCode }
			);
		}
	}


	/**
	 * Marks the given email as 'marked as spam'
	 *
	 * @autodoc     true
	 * @id.hint     ID of the email to mark as marked as spam
	 *
	 */
	public void function markAsMarkedAsSpam( required string id ) {
		var updated = $getPresideObject( "email_template_send_log" ).updateData(
			  filter       = "id = :id and ( marked_as_spam is null or marked_as_spam = :marked_as_spam )"
			, filterParams = { id=arguments.id, marked_as_spam=false }
			, data={
				  marked_as_spam      = true
				, marked_as_spam_date = _getNow()
			  }
		);

		if ( updated ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "markasspam"
			);
		}
	}

	/**
	 * Marks the given email as 'unsubscribed'
	 *
	 * @autodoc     true
	 * @id.hint     ID of the email to mark as unsubsribed
	 *
	 */
	public void function markAsUnsubscribed( required string id ) {
		var updated = $getPresideObject( "email_template_send_log" ).updateData(
			  filter       = "id = :id and ( unsubscribed is null or unsubscribed = :unsubscribed )"
			, filterParams = { id=arguments.id, unsubscribed=false }
			, data={
				  unsubscribed      = true
				, unsubscribed_date = _getNow()
			  }
		);

		if ( updated ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "unsubscribe"
			);
		}
	}

	/**
	 * Marks the given email as hard bounced (cannot deliver due to address unkown)
	 *
	 * @autodoc     true
	 * @id.hint     ID of the email to mark as failed
	 * @reason.hint Failure reason to record
	 * @code.hint   Failure code to record
	 *
	 */
	public void function markAsHardBounced( required string id, required string reason, string code="" ) {
		var updated = $getPresideObject( "email_template_send_log" ).updateData(
			  filter       = "id = :id and ( hard_bounced is null or hard_bounced = :hard_bounced ) and ( opened is null or opened = :opened )"
			, filterParams = { id=arguments.id, hard_bounced=false, opened=false }
			, data={
				  hard_bounced      = true
				, hard_bounced_date = _getNow()
			  }
		);

		if ( updated ) {
			markAsFailed(
				  id     = arguments.id
				, reason = arguments.reason
				, code   = arguments.code
			);
		}
	}

	/**
	 * Marks the given email as delivered
	 *
	 * @autodoc       true
	 * @id.hint       ID of the email to mark as delivered
	 * @softMark.hint Used when some other action has occurred that indicates that the message was therefore delivered. i.e. we may not know *when* but we do now know that it *was* delivered.
	 */
	public void function markAsDelivered( required string id, boolean softMark=false ) {
		var data = {
			  delivered         = true
			, hard_bounced      = false
			, hard_bounced_date = ""
			, failed            = false
			, failed_date       = ""
			, failed_reason     = ""
			, failed_code       = ""
		};

		if ( !arguments.softMark ) {
			data.delivered_date = _getNow();
		}

		var updated = $getPresideObject( "email_template_send_log" ).updateData(
			  filter       = "id = :id and ( delivered is null or delivered = :delivered )"
			, filterParams = { id=arguments.id, delivered=false }
			, data         = data
		);

		if ( updated ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "deliver"
			);
		}

	}

	public void function processOpenEvent(
		  required string messageId
		, required string userAgent
		, required string ipAddress
	) {
		if ( !$isFeatureEnabled( "emailTrackingBotDetection" ) ) {
			markAsOpened( argumentCollection=arguments, id=arguments.messageId );
			return;
		}

		$createTask(
			  event                = "email.tracking.processOpenEventWithBotDetection"
			, args                 = arguments
			, runIn                = _oneMinute
			, discardAfterInterval = _oneMinute
			, reference            = arguments.messageId
		);
	}

	public void function recordBotOpen( required string id ) {
		_processEventForStatsTables(
			  message  = arguments.id
			, activity = "bot_open"
		);
	}

	public void function processOpenEventWithBotDetection(
		  required string messageId
		, required string userAgent
		, required string ipAddress
		, required date   eventDate
	) {
		if ( _getEmailBotDetectionService().isBot( argumentCollection=arguments ) ) {
			recordBotOpen( arguments.messageId );
		} else {
			markAsOpened( argumentCollection=arguments, id=arguments.messageId );
		}
	}

	/**
	 * Marks the given email as opened
	 *
	 * @autodoc       true
	 * @id.hint       ID of the email to mark as opened
	 * @softMark.hint Used when some other action has occurred that indicates that the message was therefore opened. i.e. we may not know *when* but we do now know that it *was* opened.
	 *
	 */
	public void function markAsOpened(
		  required string  id
		,          boolean softMark  = false
		,          string  userAgent = cgi.http_user_agent
		,          string  ipAddress = cgi.remote_addr
		,          date    eventDate = Now()
 	) {
		var data = { opened = true, opened_count=1 };

		if ( !arguments.softMark ) {
			data.opened_date = _getNow();
		}

		var dao     = $getPresideObject( "email_template_send_log" );
		var updated = dao.updateData(
			  filter       = "id = :id and ( opened is null or opened = :opened )"
			, filterParams = { id=arguments.id, opened=false }
			, data         = data
		);

		if ( !updated ) {
			_getSqlRunner().runSql(
				  dsn        = dao.getDsn()
				, sql        = _getRecordOpenSql()
				, params     = _getRecordOpenParams( arguments.id )
				, returnType = "info"
			);
		}

		markAsDelivered( arguments.id, true );
		if ( !( arguments.softmark && !updated ) ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "open"
				, first     = ( updated > 0 )
				, userIp    = arguments.ipAddress
				, userAgent = arguments.userAgent
				, eventDate = arguments.eventDate
			);
		}
	}

	/**
	 * Records a "click" to a "honeypot" link for bot detection
	 */
	public void function recordHoneyPotHit(
		  required string messageId
		,          string userAgent = cgi.http_user_agent
		,          string ipAddress = cgi.remote_addr
	) {
		recordActivity(
			  messageId = arguments.messageId
			, activity  = "honeypotclick"
			, userIp    = arguments.ipAddress
			, userAgent = arguments.userAgent
		);
	}

	public void function processClickEvent(
		  required string messageId
		, required string link
		,          string linkTitle = ""
		,          string linkBody  = ""
		,          string userAgent = cgi.http_user_agent
		,          string ipAddress = cgi.remote_addr
	) {
		if ( !$isFeatureEnabled( "emailTrackingBotDetection" ) ) {
			recordClick( argumentCollection=arguments, id=arguments.messageId );
			return;
		}

		$createTask(
			  event                = "email.tracking.processClickEventWithBotDetection"
			, args                 = arguments
			, runIn                = _oneMinute
			, discardAfterInterval = _oneMinute
			, reference            = arguments.messageId
		);
	}

	public void function recordBotClick( required string id ) {
		_processEventForStatsTables(
			  message  = arguments.id
			, activity = "bot_click"
		);
	}

	public void function processClickEventWithBotDetection(
		  required string messageId
		, required string link
		, required date   eventDate
		,          string linkTitle = ""
		,          string linkBody  = ""
		,          string userAgent = cgi.http_user_agent
		,          string ipAddress = cgi.remote_addr
	) {
		if ( _getEmailBotDetectionService().isBot( argumentCollection=arguments ) ) {
			recordBotClick( arguments.messageId );
		} else {
			recordClick( argumentCollection=arguments, id=arguments.messageId );
		}
	}

	/**
	 * Records a link click for an email
	 *
	 */
	public void function recordClick(
		  required string id
		, required string link
		,          string linkTitle = ""
		,          string linkBody  = ""
		,          date   eventDate = Now()
		,          string userAgent = cgi.http_user_agent
		,          string ipAddress = cgi.remote_addr
	) {
		var dao           = $getPresideObject( "email_template_send_log" );
		var updated       = false;
		var wasFirstClick = updated = dao.updateData(
			  filter = { id=arguments.id, click_count=0 }
			, data   = { clicked=true, click_count=1 }
		);

		if ( !updated ) {
			updated = _getSqlRunner().runSql(
				  dsn        = dao.getDsn()
				, sql        = _getRecordClickSql()
				, params     = _getRecordClickParams( arguments.id )
				, returnType = "info"
			);
			updated =  Val( updated.recordCount ?: 0 ) > 0
		}

		if ( updated ) {
			recordActivity(
				  messageId = arguments.id
				, activity  = "click"
				, extraData = { link=arguments.link, link_title=arguments.linkTitle, link_body=arguments.linkBody }
				, first     = wasFirstClick
				, userIp    = arguments.ipAddress
				, userAgent = arguments.userAgent
				, eventDate = arguments.eventDate
			);
		}

		markAsOpened( id=id, softMark=true, userAgent=arguments.userAgent, ipAddress=arguments.ipAddress );
	}

	/**
	 * Resends an email. A duplicate of the original content is sent
	 *
	 */
	public void function resendOriginalEmail( required string id ) {
		var dao                    = $getPresideObject( "email_template_send_log");
		var message                = dao.selectData(
			  id           = arguments.id
			, selectFields = [
				  "email_template_send_log.*"
				, "content.html_body as html_body"
				, "content.text_body as text_body"
			  ]
		);
		var template               = _getEmailTemplateService().getTemplate( message.email_template );
		var recipientIdLogProperty = _getRecipientTypeService().getRecipientIdLogPropertyForRecipientType( template.recipient_type );
		var sendArgs               = deserializeJson( message.send_args );

		var resentMessageId        = $sendEmail(
		      template              = message.email_template
		    , recipientId           = message[ recipientIdLogProperty ] ?: ""
		    , to                    = [ message.recipient ]
		    , from                  = message.sender
		    , subject               = message.subject
		    , htmlBody              = message.html_body
		    , textBody              = message.text_body
		    , args                  = sendArgs
		    , resendOf              = message.id
		    , returnLogId           = true
		    , overwriteTemplateArgs = true
			, layout                = message.layout_override
			, customLayout          = message.custom_layout
		);

		$audit(
			  action   = "resend_original_email"
			, type     = "emailresend"
			, recordId = resentMessageId
			, detail   = { subject=message.subject, recipient=message.recipient, originalMessageId=arguments.id }
		);

		recordActivity(
			  messageId = arguments.id
			, activity  = "resend"
			, userAgent = ""
			, extraData = { resentMessageId=resentMessageId, resendType="original" }
		);

	}

	/**
	 * Resends an email. Email is regenerated using the original sendArgs
	 *
	 */
	public void function rebuildAndResendEmail( required string id ) {
		var dao                    = $getPresideObject( "email_template_send_log");
		var message                = dao.selectData( id=arguments.id );
		var template               = _getEmailTemplateService().getTemplate( message.email_template );
		var recipientIdLogProperty = _getRecipientTypeService().getRecipientIdLogPropertyForRecipientType( template.recipient_type );
		var originalArgs           = deserializeJson( message.send_args );
		var sendArgs               = _getEmailTemplateService().rebuildArgsForResend( template=message.email_template, logId=id, originalArgs=originalArgs );
		var resentMessageId        = $sendEmail(
			  template     = message.email_template
			, recipientId  = message[ recipientIdLogProperty ] ?: ""
			, to           = !len( message[ recipientIdLogProperty ] ?: "" ) ? [ message.recipient ] : []
			, args         = sendArgs
			, resendOf     = message.id
			, returnLogId  = true
			, layout       = message.layout_override
			, customLayout = message.custom_layout
		);

		$audit(
			  action   = "rebuild_and_resend_email"
			, type     = "emailresend"
			, recordId = resentMessageId
			, detail   = { subject=message.subject, recipient=message.recipient, originalMessageId=arguments.id }
		);

		recordActivity(
			  messageId = arguments.id
			, activity  = "resend"
			, userAgent = ""
			, extraData = { resentMessageId=resentMessageId, resendType="rebuild" }
		);

	}

	/**
	 * Delete expired email content and it's send log
	 *
	 */
	public boolean function deleteExpiredContent( any logger ) {
		var canLog   = StructKeyExists( arguments, "logger" );
		var canInfo  = canLog && logger.canInfo();
		var canError = canLog && logger.canError();
		var dao      = $getPresideObject( "email_template_send_log_content");

		if ( canInfo ) { logger.info( "Deleting expired email content from logs..." ); }

		var deleted  = dao.deleteData(
			  filter       = "expires <= :expires"
			, filterParams = { expires=now() }
		);

		if ( canInfo ) { logger.info( "Content of [#deleted#] emails deleted." ); }

		var emailSettings = $getPresideCategorySettings( "email" );
		if ( $helpers.isTrue( emailSettings.remove_view_online_content ?: "" ) && ( val( emailSettings.view_online_content_expiry ?: "" ) > 0 ) ) {
			var deleted = $getPresideObject( "email_template_view_online_content").deleteData(
				  filter       = "datecreated <= :datecreated"
				, filterParams = { datecreated=dateAdd( "d", -val( emailSettings.view_online_content_expiry ), now() ) }
			);

			if ( canInfo ) { logger.info( "[#deleted#] emails' view online contents deleted." ); }
		}

		return true;
	}

	/**
	 * Inserts a tracking pixel into the given HTML email
	 * content (based on the given message ID). Returns
	 * the HTML with the inserted tracking pixel
	 *
	 * @autodoc          true
	 * @messageId.hint   ID of the message (log id)
	 * @messageHtml.hint HTML content of the message
	 */
	public string function insertTrackingPixel(
		  required string messageId
		, required string messageHtml
	) {
		var trackingUrl   = $getRequestContext().buildLink( linkto="email.tracking.open", queryString="mid=" & arguments.messageId );
		var trackingPixel = "<img src=""#trackingUrl#"" width=""1"" height=""1"" style=""width:1px;height:1px"" />";

		if ( $isFeatureEnabled( "emailTrackingBotDetection" ) ) {
			var honeyPotUrl = $getRequestContext().buildLink( linkto="email.tracking.honeypot", queryString="mid=" & arguments.messageId );
			trackingPixel = '<a href="#honeyPotUrl#">#trackingPixel#</a>';
		}

		if ( FindNoCase( "</body>", messageHtml ) ) {
			return ReplaceNoCase( messageHtml, "</body>", trackingPixel & "</body>" );
		}

		return messageHtml & trackingPixel;
	}

	/**
	 * converts links in html email to tracking links,
	 * Returns the HTML with the inserted tracking links.
	 *
	 * @autodoc          true
	 * @messageId.hint   ID of the message (log id)
	 * @messageHtml.hint HTML content of the message
	 */
	public string function insertClickTrackingLinks(
		  required string messageId
		, required string messageHtml
	) {
		var doc             = "";
		var links           = "";
		var link            = "";
		var attribs         = "";
		var href            = "";
		var title           = "";
		var body            = "";
		var linkHash        = "";
		var shortenedLinkId = "";
		var storeInDb       = $isFeatureEnabled( "emailLinkShortener" );
		var baseTrackingUrl = $getRequestContext().buildLink( linkto="email.tracking.click", queryString="mid=#arguments.messageId#&link=" );
		var linkDao         = storeInDb ? $getPresideObject( "email_template_shortened_link" ) : "";

		try {
			doc = _jsoup.parse( arguments.messageHtml );
			links = doc.select( "A" );
		} catch( any e ) {
			$raiseError( e );
			return arguments.messageHtml;
		}

		for( link in links ) {
			attribs = link.attributes();
			href = Trim( attribs.get( "href" ) );

			if ( Len( href ) && ReFindNoCase( "^https?://", href ) && !ReFindNoCase( "^https?://[^/]+/e/t/h/", href ) ) {
				if ( storeInDb ) {
					title           = Trim( attribs.get( "title" ) );
					body            = Trim( link.text() );
					linkHash        = Hash( href & title & body );
					shortenedLinkId = linkDao.selectData( filter={ link_hash=linkhash }, selectFields=[ "id" ] ).id;

					if ( !Len( shortenedLinkId ) ) {
						try {
							shortenedLinkId = linkDao.insertData( {
								  link_hash = linkhash
								, href      = href
								, title     = title
								, body      = body
							} );
						} catch( any e ) {
							shortenedLinkId = linkDao.selectData( filter={ link_hash=linkhash }, selectFields=[ "id" ], useCache=false ).id;

							if ( !shortenedLinkId.len() ) {
								rethrow;
							}
						}
					}

					link.attr( "href", baseTrackingUrl & shortenedLinkId );
				} else {
					link.attr( "href", baseTrackingUrl & ToBase64( href ) );
				}
			}
		}

		if ( $isFeatureEnabled( "emailStyleInlinerAscii" ) ) {
			doc.outputSettings().charset( "ASCII" );
		}

		return doc.html();
	}

	/**
	 * Records an activity performed against an specific sent email.
	 * e.g. opened, clicked link, etc.
	 *
	 * @autodoc true
	 * @messageId.hint ID of the message (send log) to record against
	 * @activity.hint  The activity type performed (see system ENUM, `emailActivityType`)
	 * @extraData.hint Structure of additional data that may be useful in email send log viewer (e.g. URL of clicked link)
	 *
	 */
	public void function recordActivity(
		  required string  messageId
		, required string  activity
		,          struct  extraData = {}
		,          string  userIp    = cgi.remote_addr
		,          string  userAgent = cgi.http_user_agent
		,          boolean first     = false
		,          date    eventDate = Now()
	) {
		var fieldsToAddFromExtraData = [ "link", "code", "reason", "link_title", "link_body" ];
		var extra = StructCopy( arguments.extraData );
		var data = {
			  message       = arguments.messageId
			, activity_type = arguments.activity
			, user_ip       = arguments.userIp
			, user_agent    = arguments.userAgent
			, datecreated   = arguments.eventDate
		};

		for( var field in extra ) {
			if ( ArrayContains( fieldsToAddFromExtraData, LCase( field ) ) ) {
				data[ field ] = extra[ field ];
				extra.delete( field );
			}
		}
		data.extra_data = SerializeJson( extra );

		try {
			$announceInterception( "onEmail#arguments.activity#", data );
		} catch( any e ) {
			$raiseError( e );
		}

		try {
			$getPresideObject( "email_template_send_log_activity" ).insertData( data );
			_processEventForStatsTables(
				  message  = data.message
				, activity = arguments.activity
				, data     = data
				, first    = arguments.first
			);
		} catch( database e ) {
			// ignore missing logs when recording activity - but record the error for
			// info only
			$raiseError( e );
		}
	}

	/**
	 * Returns a struct of the log (by given id)
	 *
	 * @autodoc
	 * @id.hint ID of the log record
	 */
	public struct function getLog( required string id ) {
		var selectFields = [
			  "email_template_send_log.id"
			, "email_template_send_log.recipient"
			, "email_template_send_log.sender"
			, "email_template_send_log.subject"
			, "email_template_send_log.sent"
			, "email_template_send_log.failed"
			, "email_template_send_log.delivered"
			, "email_template_send_log.opened"
			, "email_template_send_log.marked_as_spam"
			, "email_template_send_log.unsubscribed"
			, "email_template_send_log.sent_date"
			, "email_template_send_log.failed_date"
			, "email_template_send_log.failed_reason"
			, "email_template_send_log.delivered_date"
			, "email_template_send_log.opened_date"
			, "email_template_send_log.marked_as_spam_date"
			, "email_template_send_log.unsubscribed_date"
			, "email_template_send_log.click_count"
			, "email_template_send_log.email_template"
			, "email_template_send_log.datecreated"
			, "email_template_send_log.resend_of"
			, "email_template.name"
			, "email_template.recipient_type"
		];
		if ( $isFeatureEnabled( "emailCenterResend" ) ) {
			selectFields.append( "content.html_body" );
			selectFields.append( "content.text_body" );
		}

		var logRecord = $getPresideObject( "email_template_send_log" ).selectData( id=arguments.id, selectFields=selectFields );

		for( var l in logRecord ) {
			return l;
		}

		return {};
	}

	/**
	 * Returns a query of an individual log's activity
	 *
	 * @autodoc
	 * @id.hint  ID of the log record
	 */
	public query function getActivity( required string id ) {
		return $getPresideObject( "email_template_send_log_activity" ).selectData(
			  filter  = { message = arguments.id }
			, orderBy = "datecreated"
		);
	}

	/**
	 * Security check on incoming links for link tracking.
	 * Block links that are not authorized. This is to prevent malicious
	 * manipulation of link tracking URLs from damaging
	 * reputation of the website.
	 *
	 * @autodoc
	 * @link.hint      The link to check
	 * @messageId.hint The ID of the send log message used to check against the content of the email to send
	 *
	 */
	public boolean function clickLinkIsValid( required string link, required string messageId ) {
		var poService = $getPresideObjectService();
		var event     = $getRequestContext();

		// links that just start with a slash, internal website links - no probs
		if ( ReFindNoCase( "^/", arguments.link ) ) {
			return true;
		}

		// otherwise, if they're not valid http resource, no good any way
		if ( !ReFindNoCase( "^https?://", arguments.link ) ) {
			return false;
		}

		if ( $helpers.isTrue( $getPresideSetting( "email", "disable_link_checking" ) ) ) {
			return true;
		}

		// is the domain of the link one that we host ourselves? (if so, fine)
		var linkMinusQs = ListFirst( arguments.link, "?&" );
		var domain = ReReplace( linkMinusQs, "^https?://([^/]+).*$", "\1" );
		if ( !Len( domain ) ) {
			return false;
		}

		if ( domain == event.getServerName() ) {
			return true;
		}


		if ( $isFeatureEnabled( "sites" ) ) {
			var currentSite = event.getSite();
			if ( domain == ( currentSite.domain ?: "" ) ) {
				return true;
			}
			var siteDomainObjects = [ "site", "site_alias_domain", "site_redirect_domain" ];
			for( var objName in siteDomainObjects ) {
				var domainExists = poService.dataExists( objectName=objName, filter={ domain=domain } );
				if ( domainExists ) {
					return true;
				}
			}
		} else {
			var allowedDomains = $getColdbox().getSetting( "allowedDomains" );

			if ( IsArray( allowedDomains ) && ArrayContainsNoCase( allowedDomains, domain ) ) {
				return true;
			}
		}

		// Check domain against allowed domains setting
		var allowedDomains = _getDomainAllowlist();
		var domainRegex     = "";
		for( var allowedDomain in allowedDomains ) {
			if ( domain == allowedDomain ) {
				return true;
			}
			if ( Left( allowedDomain, 1 ) == "*" ) {
				domainRegex = replace( allowedDomain, "*", "" ) & "$";
				if ( reFindNoCase( domainRegex, domain ) ) {
					return true;
				}
			}
		}

		// is the link in our link table
		var linkExists =  $getPresideObject( "link" ).dataExists( filter="type = :type and external_address like :external_address", filterParams={
			  type             = "url"
			, external_address = ReReplace( linkMinusQs, "^https?://", "" ) & "%"
		} )
		if ( linkExists ) {
			return true;
		}


		// is the link included in the email content
		var versionObjName = poService.getVersionObjectName( "email_template" );
		var emailTemplate  = poService.selectData(
			  objectName   = "email_template_send_log"
			, id           = arguments.messageId
			, selectFields = [ "email_template.id", "email_template.html_body" ]
		);

		// layers of depth for encoded links found in nested widgets :o
		var encodedLinks = [ UrlEncodedFormat( linkMinusQs ) ];
		ArrayAppend( encodedLinks, UrlEncodedFormat( ArrayLast( encodedLinks ) ) );
		ArrayAppend( encodedLinks, UrlEncodedFormat( ArrayLast( encodedLinks ) ) );
		ArrayAppend( encodedLinks, UrlEncodedFormat( ArrayLast( encodedLinks ) ) );
		ArrayAppend( encodedLinks, UrlEncodedFormat( ArrayLast( encodedLinks ) ) );
		ArrayAppend( encodedLinks, UrlEncodedFormat( ArrayLast( encodedLinks ) ) );
		var contentFilter = { filter = "html_body like :html_body", filterParams={ html_body="%#arguments.link#%" } };
		for( var i=1; i<=ArrayLen( encodedLinks ); i++  ) {
			contentFilter.filter &= " or html_body like :html_body_#i#";
			contentFilter.filterParams[ "html_body_#i#" ] = { type="cf_sql_varchar", value="%#encodedLinks[ i ]#%" };
		}

		if ( emailTemplate.recordCount ) {
			if ( Find( linkMinusQs, emailTemplate.html_body ) ) {
				return true;
			}
			for( var encodedLink in encodedLinks ) {
				if ( Find( encodedLink, emailTemplate.html_body ) ) {
					return true;
				}
			}

			// or any previous versions of the email content?!
			if ( Len( Trim( versionObjName ) ) ) {
				return poService.dataExists(
					  objectName   = versionObjName
					, id           = emailTemplate.id
					, extraFilters = [ contentFilter ]
				);
			}

			return false;
		}

		// the email log no longer exists - have we included this link in *any* of
		// our historical email templates?!
		var start = GetTickCount();
		return poService.dataExists(
			  objectName   = ( Len( versionObjName ) ? versionObjName : "email_template" )
			, extraFilters = [ contentFilter ]
		);
	}

// PRIVATE HELPERS
	private struct function _getAdditionalDataForRecipientType( required string recipientType, required string recipientId, required struct sendArgs ) {
		var additional           = {};
		var recipientTypeService = _getRecipientTypeService();

		if ( recipientType.len() ) {
			var fkColumn            = recipientTypeService.getRecipientIdLogPropertyForRecipientType( recipientType );
			var additionalSelectors = recipientTypeService.getRecipientAdditionalLogProperties( recipientType );

			if ( fkColumn.len() ) {
				additional[ fkColumn ] = arguments.recipientId
			}
			if ( additionalSelectors.count() ) {
				var fields = [];
				for( var additionalSelector in additionalSelectors ) {
					fields.append( "#additionalSelectors[ additionalSelector ]# as #additionalSelector#" );
				}
				var record = $getPresideObject( recipientTypeService.getFilterObjectForRecipientType( arguments.recipientType ) ).selectData(
					  id           = arguments.recipientId
					, selectFields = fields
					, autoGroupBy  = true
				);
				for( var r in record ) {
					additional.append( r );
				}
			}
		}

		return additional;
	}

	private date function _getNow() {
		return Now(); // abstracting this makes testing easier
	}

	private any function _new( required string className ) {
		return CreateObject( "java", arguments.className, _getLib() );
	}

	private array function _getLib() {
		if ( !_lib.len() ) {
			var libDir = GetDirectoryFromPath( getCurrentTemplatePath() ) & "/lib";
			_lib = DirectoryList( libDir, false, "path", "*.jar" );
		}
		return _lib;
	}

	private array function _getDomainAllowlist() {
		var allowList = $getPresideSetting( "email", "link_checking_allowlist" );

		return ListToArray( Trim( allowList ), " #chr(9)##chr(10)##chr(13)#" );
	}


	private function _getRecordClickSql() {
		if ( !StructKeyExists( variables, "_recordClickSql" ) ) {
			var dao = $getPresideObject( "email_template_send_log" );
			var adapter = dao.getDbAdapter();
			var tableName = adapter.escapeEntity( dao.getTableName() );
			var countCol  = adapter.escapeEntity( "click_count" );
			var idCol = adapter.escapeEntity( "id" );

			variables._recordClickSql = "update #tableName# set #countCol# = #countCol# + 1 where #idCol# = :id";
		}

		return variables._recordClickSql;
	}

	private function _getRecordClickParams( sendLogId ) {
		return [{
			  type = "cf_sql_varchar"
			, value = arguments.sendLogId
			, name = "id"
		}];
	}

	private function _getRecordOpenSql() {
		if ( !StructKeyExists( variables, "_recordOpenSql" ) ) {
			var dao = $getPresideObject( "email_template_send_log" );
			var adapter = dao.getDbAdapter();
			var tableName = adapter.escapeEntity( dao.getTableName() );
			var countCol  = adapter.escapeEntity( "open_count" );
			var idCol = adapter.escapeEntity( "id" );

			variables._recordOpenSql = "update #tableName# set #countCol# = #countCol# + 1 where #idCol# = :id";
		}

		return variables._recordOpenSql;
	}

	private function _getRecordOpenParams( sendLogId ) {
		return [{
			  type = "cf_sql_varchar"
			, value = arguments.sendLogId
			, name = "id"
		}];
	}

	private function _processEventForStatsTables( message, activity, data={}, first ) {
		if ( !Len( arguments.message ) ) {
			return;
		}

		var ignoredActivities = [ "honeypotclick", "resend" ];
		if ( ArrayContains( ignoredActivities, arguments.activity ) ) {
			return;
		}

		var template = $getPresideObjectService().selectData(
			  objectName   = "email_template_send_log"
			, selectFields = [ "email_template" ]
			, forceJoins   = "inner"
			, filter       = {
				  id                                        = arguments.message
				, "email_template.stats_collection_enabled" = true
			  }
		);

		if ( Len( template.email_template ) ) {
			_getEmailStatsService().recordHit(
				  emailTemplateId = template.email_template
				, hitDate         = Now()
				, hitStat         = _activityToHitStat( arguments.activity )
				, first           = arguments.first
				, data            = arguments.data
			);
		}
	}

	private function _activityToHitStat( activity ) {
		switch( arguments.activity ) {
			case "deliver": return "delivery";
			case "markasspam": return "spam";
		}

		return arguments.activity;
	}



// GETTERS AND SETTERS
	private any function _getRecipientTypeService() {
		return _recipientTypeService;
	}
	private void function _setRecipientTypeService( required any recipientTypeService ) {
		_recipientTypeService = arguments.recipientTypeService;
	}

	private any function _getEmailTemplateService() {
		return _emailTemplateService;
	}
	private void function _setEmailTemplateService( required any emailTemplateService ) {
		_emailTemplateService = arguments.emailTemplateService;
	}

	private any function _getEmailBotDetectionService() {
		return _emailBotDetectionService;
	}
	private void function _setEmailBotDetectionService( required any emailBotDetectionService ) {
		_emailBotDetectionService = arguments.emailBotDetectionService;
	}

	private any function _getSqlRunner() {
		return _sqlRunner;
	}
	private void function _setSqlRunner( required any sqlRunner ) {
		_sqlRunner = arguments.sqlRunner;
	}

	private any function _getEmailStatsService() {
		return _emailStatsService;
	}
	private void function _setEmailStatsService( required any emailStatsService ) {
		_emailStatsService = arguments.emailStatsService;
	}

}