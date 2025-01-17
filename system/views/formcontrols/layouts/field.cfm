<!---@feature presideForms--->
<cfscript>
	param name="args.control"  type="string";
	param name="args.label"    type="string";
	param name="args.help"     type="string";
	param name="args.for"      type="string";
	param name="args.error"    type="string";
	param name="args.required" type="boolean";
	param name="args.nolabel"  type="boolean" required="false" default="false";

	hasError = Len( Trim( args.error ) );
</cfscript>

<cfoutput>
	<div class="form-group form-group-grid<cfif hasError> has-error</cfif>">
		<cfif not args.nolabel>
			<label class="control-label no-padding-right" for="#args.for#">
				#args.label#
				<cfif args.required>
					<em class="required" role="presentation">
						<sup><i class="fa fa-asterisk"></i></sup>
						<span>#translateResource( "cms:form.control.required.label" )#</span>
					</em>
				</cfif>

			</label>

		<cfelse>
			<div>&nbsp;</div>
		</cfif>
		<div>
			<div class="clearfix">
				#args.control#
			</div>
			<cfif hasError>
				<div for="#args.for#" class="help-block">#args.error#</div>
			</cfif>
		</div>
		<cfif Len( Trim( args.help ) )>
			<div>
				<span class="help-button fa fa-question" data-rel="popover" data-trigger="hover" data-placement="left" data-content="#HtmlEditFormat( args.help )#" title="#translateResource( 'cms:help.popover.title' )#"></span>
			</div>
		</cfif>
	</div>
</cfoutput>
