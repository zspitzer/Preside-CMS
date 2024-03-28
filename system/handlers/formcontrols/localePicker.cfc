component output="false" displayname=""  {

	property name="resourceBundleService"  inject="resourceBundleService";
	property name="i18n"                   inject="i18n";
	property name="loginService"           inject="loginService";
	property name="adminLanguages"         inject="coldbox:setting:adminLanguages";

	public string function index( event, rc, prc, args={} ) {
		var locales      = Duplicate( resourceBundleService.listLocales() );
		var adminLocales = IsTrue( args.adminLocales ?: "" );
		var userDetail   = loginService.getLoggedInUserDetails();

		if ( locales.len() ) {
			var defaultLocale = i18n.getDefaultLocale();
			var currentLocale = i18n.getfwLocale();
			args.values       = [];
			args.labels       = [];

			locales.append( defaultLocale );
			if ( adminLocales && adminLanguages.len() ) {
				for( var i=locales.len(); i>0; i-- ) {
					if ( !adminLanguages.containsNoCase( locales[ i ] ) ) {
						locales.deleteAt( i );
					}
				}
			}

			locales = locales.map( function( locale ){
				var language = ListFirst( locale, "_" );
				var country  = ListLen( locale, "_" ) > 1 ? ListRest( locale, "_" ) : "";

				return {
					  locale  = arguments.locale
					, title   = translateResource( uri="locale:title", language=language, country=country )
					, selected = ( arguments.locale == currentLocale )
				}
			} ).sort( function( a, b ){
				if ( a.locale == defaultLocale ) {
					return -1;
				}

				return a.title < b.title ? -1 : 1;
			} );

			for( var i=1 ; i<=arrayLen( locales ); i++ ) {
				arrayAppend( args.values, locales[i].locale );
				arrayAppend( args.labels, locales[i].title );
			}

			args.defaultValue = userDetail.user_language;
			args.multiple     = false;

			return renderView( view="/formcontrols/select/index", args=args );
		}

		return "";
	}

}