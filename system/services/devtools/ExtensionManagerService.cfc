/**
 * @singleton true
 *
 */
component {

// CONSTRUCTOR
	/**
	 * @appMapping.inject       coldbox:setting:appMapping
	 * @ignoreExtensions.inject coldbox:setting:legacyExtensionsNowInCore
	 *
	 */
	public any function init( string appMapping="/app", array ignoreExtensions=[] ) {
		_readExtensions( arguments.appMapping, arguments.ignoreExtensions );

		return this;
	}

// PUBLIC API METHODS
	public array function listExtensions() {
		return _getExtensions();
	}

// PRIVATE HELPERS
	private void function _readExtensions( required string appMapping, required array ignoreExtensions ) {
		var appCacheKey = "__presideappExtensions";

		if ( !StructKeyExists( application, appCacheKey ) ) {
			appMapping = "/" & appMapping.reReplace( "^/", "" );

			var appDir        = ExpandPath( appMapping );
			var extensionsDir = ListAppend( appDir, "extensions", _getDirDelimiter() );
			var manifestFiles = DirectoryList( extensionsDir, true, "path", "manifest.json" );
			var extensions    = [];

			for( var manifestFile in manifestFiles ) {
				if ( !_isExtensionManifest( manifestFile, extensionsDir ) ) {
					continue;
				}

				var extension = _parseManifest( manifestFile, appMapping );
				if ( !ArrayContainsNoCase( arguments.ignoreExtensions, extension.id ) ) {
					ArrayAppend( extensions, extension );
				}
			}

			extensions = _sortExtensions( extensions );
			application[ appCacheKey ] = extensions;
		}

		_setExtensions( application[ appCacheKey ] );
	}

	private struct function _parseManifest( required string manifestFile, required string appMapping ) {
		var missingFields  = [];
		var requiredFields = [ "id", "title", "author", "version" ];
		var manifest       = "";
		var appDir         = ExpandPath( arguments.appMapping );

		try {
			manifest = DeserializeJson( FileRead( arguments.manifestFile ) );
		} catch ( any e ) {}

		if ( !IsStruct( manifest ) ) {
			missingFields = requiredFields;
		} else {
			for( var field in requiredFields ){
				if ( !StructKeyExists( manifest, field ) ) {
					missingFields.append( field );
				}
			}
		}

		if ( missingFields.len() ) {
			var message = "The extension, [#GetDirectoryFromPath( arguments.manifestFile )#], has an invalid manifest file. Missing required fields: ";
			var delim   = ""
			for( var field in missingFields ) {
				message &= delim & "[#field#]";
				delim = ", ";
			}
			throw( type="ExtensionManager.invalidManifest", message=message );
		}

		manifest[ "directory" ] = GetDirectoryFromPath( arguments.manifestFile ).reReplaceNoCase( "[\\/]$", "" ).replace( appDir, appMapping );
		manifest[ "name"      ] = ListLast( manifest.directory, "\/" );
		if ( manifest.name == "preside-extension" ) {
			manifest[ "name" ] = ListGetAt( manifest.directory, ListLen( manifest.directory, "\/" )-1, "\/" );
		}

		manifest[ "dependsOn" ] = manifest.dependson ?: [];
		if ( IsSimpleValue( manifest.dependsOn ) ) {
			manifest.dependsOn = [ manifest.dependsOn ];
		} else if ( !IsArray( manifest.dependsOn ) ) {
			manifest.dependsOn = [];
		}

		return manifest;
	}

	private array function _sortExtensions( required array extensions ) {
		var extensionCount = extensions.len();
		var swapped = false;

		do {
			swapped = false;
			for( var i=1; i<=extensionCount-1; i++ ) {
				var extA = extensions[ i ];
				var extB = extensions[ i+1 ];

				if ( extA.dependsOn.len() ) {
					for( var n=i+1; n<=extensionCount; n++ ) {
						var extC = extensions[ n ];

						if ( extA.dependsOn.containsNoCase( extC.id ) ) {
							arrayDeleteAt(extensions, n);
							arrayInsertAt(extensions, i, extC);
							swapped = true;
							break;
						}
					}
				} else if ( extA.id > extB.id && !extB.dependsOn.containsNoCase( extA.id ) ) {
					var tmp = extB;
					extensions[ i+1 ] = extA;
					extensions[ i ]   = tmp;
					swapped = true;
				}
			}
		} while( swapped );

		return extensions;
	}

	private boolean function _isExtensionManifest( required string manifestPath, required string extensionsDir ) {
		// path should be {extensionsdir}/{extension-id}/manifest.json
		// not an extension manifest if deeper nested than that
		var relativePath = ReReplace( Replace( arguments.manifestPath, arguments.extensionsDir, "" ), "^[\\/]", "" );

		return ListLen( relativePath, "/\" ) == 2;
	}

// GETTERS AND SETTERS
	private string function _getAppDirectory() {
		return _appMapping;
	}

	private void function _setAppDirectory( required string appMapping ) {
		_appMapping = arguments.appMapping;
	}

	private array function _getExtensions() {
		return _extensions;
	}

	private void function _setExtensions( required array extensions ) {
		_extensions = arguments.extensions;
	}

	private string function _getDirDelimiter() {
		if ( IsNull( variables._dirDelimiter ) ) {
			_setDirDelimiter( CreateObject( "java", "java.lang.System" ).getProperty( "file.separator" ) );
		}

		return variables._dirDelimiter;
	}
	private void function _setDirDelimiter( required string dirDelimiter ) {
		variables._dirDelimiter = arguments.dirDelimiter;
	}

// OLD API NO LONGER SUPPORTED
	public void function activateExtension() {
		throw( type="method.no.longer.supported", message="As of Preside 10.9.0, the activateExtension() method is no longer supported" );
	}
	public void function deactivateExtension() {
		throw( type="method.no.longer.supported", message="As of Preside 10.9.0, the deactivateExtension() method is no longer supported" );
	}

	public void function uninstallExtension() {
		throw( type="method.no.longer.supported", message="As of Preside 10.9.0, the uninstallExtension() method is no longer supported" );
	}

	public void function installExtension() {
		throw( type="method.no.longer.supported", message="As of Preside 10.9.0, the installExtension() method is no longer supported" );
	}

	public struct function getExtensionInfo() {
		throw( type="method.no.longer.supported", message="As of Preside 10.9.0, the getExtensionInfo() method is no longer supported" );
	}

}
