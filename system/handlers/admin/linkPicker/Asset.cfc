component {
	private string function getDefaultLinkText( event, rc, prc, args={} ) {
		var assetId = args.asset ?: "";
		if ( Len( assetId ) ) {
			return renderLabel( "asset", assetId );
		}

		return "";
	}
}