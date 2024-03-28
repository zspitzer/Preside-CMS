component validationProvider=true {

	public boolean function required( required string fieldName, any value="", struct data={} ) validatorMessage="cms:validation.required.default" {
		var value = IsSimpleValue( arguments.value ) ? Trim( arguments.value ) : arguments.value;

		return StructKeyExists( arguments.data, fieldName ) && !IsEmpty( value );
	}

	public boolean function minlength( required string fieldName, string value="", required numeric length, boolean list=false ) validatorMessage="cms:validation.minLength.default" {
		var length = arguments.list ? ListLen( Trim( arguments.value ) ) : Len( Trim( arguments.value ) );

		return not length or length gte arguments.length;
	}

	public boolean function maxlength( required string fieldName, string value="", required numeric length, boolean list=false ) validatorMessage="cms:validation.maxLength.default" {
		var length = arguments.list ? ListLen( Trim( arguments.value ) ) : Len( Trim( arguments.value ) );

		return not length or length lte arguments.length;
	}

	public boolean function rangelength( required string fieldname, string value="", required numeric minLength, required numeric maxLength, boolean list=false ) validatorMessage="cms:validation.rangeLength.default" {
		var length = arguments.list ? ListLen( Trim( arguments.value ) ) : Len( Trim( arguments.value ) );

		return not length or ( length gte arguments.minLength and length lte arguments.maxLength );
	}

	public boolean function min( required string fieldName, string value="", required numeric min ) validatorMessage="cms:validation.min.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return Val( Replace( arguments.value, ",", "", "all" ) ) gte arguments.min;
	}

	public string function min_js() {
		return "function( value, el, param ) { return this.optional( el ) || value.replaceAll( ',', '' ) >= ( ( typeof( param ) == 'object' ) ? param.param : param ); }";
	}

	public boolean function lessThanField( required string value, required struct data, required string field ) validatorMessage="cms:validation.lessThanField.default" {
		if ( !IsNumeric( arguments.value ) || !IsNumeric( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return Val( arguments.value ) < Val( arguments.data[ arguments.field ] );
	}
	public string function lessThanField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || (parseFloat(value) < parseFloat($field.val())); }";
	}

	public boolean function lessThanOrEqualToField( required string value, required struct data, required string field ) validatorMessage="cms:validation.lessThanOrEqualToField.default" {
		if ( !IsNumeric( arguments.value ) || !IsNumeric( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return Val( arguments.value ) <= Val( arguments.data[ arguments.field ] );
	}
	public string function lessThanOrEqualToField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || (parseFloat(value) <= parseFloat($field.val())); }";
	}

	public boolean function max( required string fieldName, string value="", required numeric max ) validatorMessage="cms:validation.max.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return Val( Replace( arguments.value, ",", "", "all" ) ) lte arguments.max;
	}

	public string function max_js() {
		return "function( value, el, param ) { return this.optional( el ) || value.replaceAll( ',', '' ) <= ( ( typeof( param ) == 'object' ) ? param.param : param ); }";
	}

	public boolean function greaterThanField( required string value, required struct data, required string field ) validatorMessage="cms:validation.greaterThanField.default" {
		if ( !IsNumeric( arguments.value ) || !IsNumeric( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return Val( arguments.value ) > Val( arguments.data[ arguments.field ] );
	}
	public string function greaterThanField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || (parseFloat(value) > parseFloat($field.val())); }";
	}

	public boolean function greaterThanOrEqualToField( required string value, required struct data, required string field ) validatorMessage="cms:validation.greaterThanOrEqualToField.default" {
		if ( !IsNumeric( arguments.value ) || !IsNumeric( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return Val( arguments.value ) >= Val( arguments.data[ arguments.field ] );
	}
	public string function greaterThanOrEqualToField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || (parseFloat(value) >= parseFloat($field.val())); }";
	}

	public boolean function range( required string fieldName, string value="", required numeric min, required numeric max ) validatorMessage="cms:validation.range.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		var val = Val( Replace( arguments.value, ",", "", "all" ) );

		return val lte arguments.max and val gte arguments.min;
	}

	public string function range_js() {
		return "function( value, el, param ) { var val = value.replaceAll( ',', '' ); return this.optional( el ) || ( val >= ( ( typeof( param[0] ) == 'object' ) ? param.param[0] : param[0] ) && val <= ( ( typeof( param[1] ) == 'object' ) ? param.param[1] : param[1] ) ); }";
	}

	// 			return this.optional( el ) || ( val >= param[ 0 ] && val <= param[ 1 ] ); }

	public boolean function number( required string value ) validatorMessage="cms:validation.number.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}
		return IsNumeric( Replace( arguments.value, ",", "", "all" ) );
	}

	public boolean function digits( required string value ) validatorMessage="cms:validation.digits.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}
		return ReFind( "^[0-9]+$", arguments.value );
	}

	public boolean function date( required string value, string format="YYYY-MM-DD"  ) validatorMessage="cms:validation.date.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return IsDate( arguments.value );
	}

	public boolean function minimumTime( required string value, required string minimumTime ) validatorMessage="cms:validation.minimumTime.default" {
		if ( !IsDate( arguments.value ) ) {
			return true;
		}

		return ( DateCompare( dateTimeFormat( arguments.value, "HH:nn" ), arguments.minimumTime ) >= 0 );
	}

	public boolean function maximumTime( required string value, required string maximumTime ) validatorMessage="cms:validation.maximumTime.default" {
		if ( !IsDate( arguments.value ) ) {
			return true;
		}

		return ( DateCompare( dateTimeFormat( arguments.value, "HH:nn" ), arguments.maximumTime ) <= 0 );
	}

	public boolean function datetime( required string value ) validatorMessage="cms:validation.date.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return IsDate( arguments.value );
	}
	public string function datetime_js() {
		return "function( value, el, params ) { var parts = value.split( ' ' ); return !value.length || ( !/Invalid|NaN/.test(new Date( parts[0] ).toString()) && ( parts.length == 1 || ( parts.length == 2 && /^(([0-1]?[0-9])|([2][0-3])):([0-5]?[0-9])(:([0-5]?[0-9]))?$/i.test( parts[1] ) ) ) ); }";
	}

	public boolean function languageCode( required string fieldName, string value="" ) validatorMessage="cms:validation.languageCode.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}
		return ReFind( "^[a-zA-Z]{2,3}([_][a-zA-Z]{2,4})?([_][a-zA-Z]{2})?$", arguments.value );
	}
	public string function languageCode_js() {
		return "function( value, el, params ){ return !value.length || value.match( /^[a-zA-Z]{2,3}([_][a-zA-Z]{2,4})?([_][a-zA-Z]{2})?$/ ) !== null }";
	}

	public boolean function match( required string fieldName, string value="", required string regex ) validatorMessage="cms:validation.match.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return ReFind( arguments.regex, arguments.value );
	}
	public string function match_js() {
		return "function( value, el, params ){ return !value.length || value.match( new RegExp( params[0] ) ) !== null }";
	}

	public boolean function sameAs( required string fieldName, string value="", required struct data, required string field ) validatorMessage="cms:validation.sameAs.default" {
		return arguments.value == ( arguments.data[ field ] ?: "" );
	}
	public string function sameAs_js() {
		return "function( value, el, params ){ var $field = $( el ).closest( 'form' ).contains( '[name=' + params[0] + ']' ); return $field.length && value == $field.val(); }";
	}

	public boolean function slug( required string fieldName, string value="" ) validatorMessage="cms:validation.slug.default" {
		return match( fieldName=arguments.fieldName, value=arguments.value, regex="^[a-z0-9\-]+$" );
	}
	public string function slug_js() {
		return "function( value ){ return !value.length || value.match( /^[a-z0-9\-]+$/ ) !== null }";
	}

	public boolean function email( required string fieldName, string value="", boolean multiple=false ) validatorMessage="cms:validation.email.default" {
		var emailRegex = "^[^.\s@]+(?:\.[^.\s@]+)*@(?:[^\s\.@]+\.)+([^\s\.@]{2,})$";
		if ( !arguments.multiple ) {
			return match( fieldName=arguments.fieldName, value=arguments.value, regex=emailRegex );
		}
		for( var email in listToArray( arguments.value, ", " ) ) {
			if ( !match( fieldName=arguments.fieldName, value=email, regex=emailRegex ) ) {
				return false;
			}
		}
		return true;
	}
	public string function email_js() {
		return "function( value, el, params ){
			if ( !value.length ) return true;
			var emailRegex = /^[^.\s@]+(?:\.[^.\s@]+)*@(?:[^\s\.@]+\.)+([^\s\.@]{2,})$/;
			if ( !el.multiple )	return value.match( emailRegex ) !== null;
			var emails = value.split( /[ ,]+/ );
			for( var i=0; i<emails.length; i++ ) {
				if ( emails[ i ].match( emailRegex ) === null ) return false;
			}
			return true;
		}";
	}

	public boolean function uuid( required string value ) validatorMessage="cms:validation.uuid.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}

		return IsValid( "uuid", arguments.value );
	}

	public boolean function money( required string fieldName, string value="" ) validatorMessage="cms:validation.money.default" {
		if ( not Len( Trim( arguments.value ) ) ) {
			return true;
		}
		return !arrayIsEmpty(REMatchNoCase("^(\$?(0|[1-9]\d{0,2}(,?\d{3})?)(\.\d\d?)?|\(\$?(0|[1-9]\d{0,2}(,?\d{3})?)(\.\d\d?)?\))$", arguments.value ));
	}
	public string function money_js() {
		return "function( value, el, param ) {var regex = new RegExp('^[]?([1-9]{1}[0-9]{0,2}(\\,[0-9]{3})*(\\.[0-9]{0,2})?|[1-9]{1}[0-9]{0,}(\\.[0-9]{0,2})?|0(\\.[0-9]{0,2})?|(\\.[0-9]{1,2})?)$');return regex.test(value);}";
	}

	public boolean function fileSize( required string fieldName, any value={}, required string maxSize ) validatorMessage="cms:validation.fileUpload.default" {
		if ( !IsStruct( arguments.value ) || !StructKeyExists( arguments.value, "size" ) || !IsNumeric( arguments.value.size ) ) {
			return true;
		}

		var fileSize     = arguments.value.size / 1024;
		var fileSizeInMB = Round( ( fileSize / 1024 ) * 100 ) / 100 ;

		return fileSizeInMB <= arguments.maxSize;
	}
	public string function fileSize_js() {
		return "function( value, el, params ) {if(el.files[0] != undefined) var fileSize = el.files[0].size / 1024;var fileSizeInMB = Math.round( (fileSize / 1024) * 100) / 100 ; return !value.length || (fileSizeInMB <= params[0]);}";
	}

	public boolean function fileType( required string fieldName, any value={}, required string allowedTypes, required string allowedExtensions ) validatorMessage="cms:validation.fileType.default" {
		if ( !IsStruct( arguments.value ) ) {
			return true;
		}

		var allowedExtensions = listToArray( arguments.allowedExtensions );
		var filesToCheck      = [];
		var validFiles        = 0;

		if ( isStruct( arguments.value.tempFileInfo ?: "" ) ) {
			filesToCheck.append( arguments.value.tempFileInfo );
		} else {
			for( var filename in arguments.value ) {
				if ( isStruct( arguments.value[ filename ].tempFileInfo ?: "" ) ) {
					filesToCheck.append( arguments.value[ filename ].tempFileInfo );
				}
			}
		}

		for ( var fileInfo in filesToCheck ) {
			var serverfileext  = fileInfo.serverfileext  ?: "";
			var contentsubtype = fileInfo.contentsubtype ?: "";

			for( var ext in allowedExtensions ) {
				if ( ext == serverfileext || ext == contentsubtype ) {
					validFiles++;
					break;
				}
			}
		}

		return validFiles == filesToCheck.len();
	}

	public boolean function fileNameSlug( required string fieldName, string value="" ) validatorMessage="cms:validation.fileNameSlug.default" {
		return match( fieldName=arguments.fieldName, value=arguments.value, regex="^[a-zA-Z0-9\-]+$" );
	}
	public string function fileNameSlug_js() {
		return "function( value ){ return !value.length || value.match( /^[a-zA-Z0-9\-]+$/ ) !== null }";
	}

	public boolean function minimumDate( required string value, required date minimumDate ) validatorMessage="cms:validation.minimumDate.default" {
		if ( !IsDate( arguments.value ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.minimumDate ) >= 0 );
	}
	public string function minimumDate_js() {
		return "function( value, el, params ){ return !value.length || value >= params[0]; }";
	}

	public boolean function maximumDate( required string value, required date maximumDate ) validatorMessage="cms:validation.maximumDate.default" {
		if ( !IsDate( arguments.value ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.maximumDate ) <= 0 );
	}
	public string function maximumDate_js() {
		return "function( value, el, params ){ return !value.length || value <= params[0]; }";
	}

	public boolean function laterThanField( required string value, required struct data, required string field ) validatorMessage="cms:validation.laterThanField.default" {
		if ( !IsDate( arguments.value ) || !IsDate( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.data[ arguments.field ] ) > 0 );
	}
	public string function laterThanField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || value > $field.val(); }";
	}

	public boolean function laterThanOrSameAsField( required string value, required struct data, required string field ) validatorMessage="cms:validation.laterThanOrSameAsField.default" {
		if ( !IsDate( arguments.value ) || !IsDate( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.data[ arguments.field ] ) >= 0 );
	}
	public string function laterThanOrSameAsField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || value >= $field.val(); }";
	}

	public boolean function earlierThanField( required string value, required struct data, required string field ) validatorMessage="cms:validation.earlierThanField.default" {
		if ( !IsDate( arguments.value ) || !IsDate( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.data[ arguments.field ] ) < 0 );
	}
	public string function earlierThanField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || value < $field.val(); }";
	}

	public boolean function earlierThanOrSameAsField( required string value, required struct data, required string field ) validatorMessage="cms:validation.earlierThanOrSameAsField.default" {
		if ( !IsDate( arguments.value ) || !IsDate( arguments.data[ arguments.field ] ?: "" ) ) {
			return true;
		}

		return ( DateCompare( arguments.value, arguments.data[ arguments.field ] ) <= 0 );
	}
	public string function earlierThanOrSameAsField_js() {
		return "function( value, el, params ){ var $field = $( '[name=' + params[0] + ']' ); return !value.length || !$field.length || !$field.val().length || value <= $field.val(); }";
	}

	public boolean function url( required string fieldName, any value="" ) validatorMessage="cms:validation.url.default" {
		return IsEmpty( arguments.value ) || ReFindNoCase( "^https?:\/\/([-_A-Z0-9]+\.)+[-_A-Z0-9]+(\/.*)?$", arguments.value );
	}
	public string function url_js() validatorMessage="validationExtras:validation.simpleUrl.default" {
		return "function( value, el, params ){ return !value.length || value.match( /^https?:\/\/([-_A-Z0-9]+\.)+[-_A-Z0-9]+(\/.*)?$/i ) !== null }";
	}
}