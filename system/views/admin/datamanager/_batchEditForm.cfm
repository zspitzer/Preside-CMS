<!---@feature admin--->
<cfscript>
	batchEditWarning          = args.batchEditWarning          ?: "";
	multiEditBehaviourControl = args.multiEditBehaviourControl ?: "";
	fieldFormControl          = args.fieldFormControl          ?: "";
	saveChangesAction         = args.saveChangesAction         ?: "";
	cancelAction              = args.cancelAction              ?: "";
	ids                       = args.ids                       ?: "";
	object                    = args.object                    ?: "";
	field                     = args.field                     ?: "";
	batchAll                  = isTrue( args.batchAll          ?: "" );
	batchSrcArgs              = args.batchSrcArgs              ?: "";
</cfscript>
<cfoutput>
	<p class="alert alert-warning">
		<i class="fa fa-fw fa-exclamation-triangle"></i>
		#batchEditWarning#
	</p>

	<form class="form-horizontal" method="post" data-dirty-form="protect" action="#saveChangesAction#">
		<cfif batchAll>
			<input type="hidden" name="batchAll"     value="true">
			<input type="hidden" name="batchSrcArgs" value="#batchSrcArgs#">
		<cfelse>
			<input type="hidden" name="sourceIds"   value="#ids#">
		</cfif>

		<input type="hidden" name="updateField" value="#field#">
		<input type="hidden" name="object"      value="#object#">

		#multiEditBehaviourControl#
		#fieldFormControl#

		<div class="form-actions row">
			<div class="col-md-offset-2">
				<a href="#cancelAction#" class="btn btn-default" data-global-key="c">
					<i class="fa fa-reply bigger-110"></i>
					#translateResource( "cms:datamanager.cancel.btn" )#
				</a>

				<button class="btn btn-info" type="submit" tabindex="#getNextTabIndex()#">
					<i class="fa fa-check bigger-110"></i>
					#translateResource( "cms:save.btn" )#
				</button>
			</div>
		</div>
	</form>
</cfoutput>
