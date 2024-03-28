/**
 * Provides logic for manipulating images.
 *
 * @singleton
 * @autodoc
 * @presideservice
 *
 */
component displayname="Image Manipulation Service" {

	// CONSTRUCTOR
	/**
     * @nativeImageImplementation.inject nativeImageService
     * @imageMagickImplementation.inject imageMagickService
     * @libVipsImplementation.inject     vipsImageSizingService
     *
     */
    public any function init(
          required any nativeImageImplementation
        , required any imageMagickImplementation
        , required any libVipsImplementation
    ) {
        _setNativeImageImplementation( arguments.nativeImageImplementation );
        _setImageMagickImplementation( arguments.imageMagickImplementation );
        _setLibVipsImplementation( arguments.libVipsImplementation );

        return this;
    }

	public string function resize(
		  required string  filePath
		,          numeric width               = 0
		,          numeric height              = 0
		,          string  quality             = "highPerformance"
		,          boolean maintainAspectRatio = false
		,          string  gravity             = 'center'
		,          string  focalPoint          = ""
		,          string  cropHint            = ""
		,          string  useCropHint         = false
		,          string  resizeNoCrop        = false
		,          struct  fileProperties      = {}
		,          string  ignoreDimension     = false
	) {
		var args = arguments;

		if ( $helpers.isTrue( args.resizeNoCrop ) && args.maintainAspectRatio && val( args.width ) && val( args.height ) ) {
			args.paddingColour = "auto";
			return _getImplementation().shrinkToFit( argumentCollection=args );
		}

		if ( arguments.useCropHint && arguments.cropHint.len() ) {
			args.cropHintArea = _getCropHintArea(
				  image           = args.asset
				, width           = args.width
				, height          = args.height
				, cropHint        = args.cropHint
				, ignoreDimension = $helpers.isTrue( args.ignoreDimension )
			);
		}

       	return _getImplementation().resize( argumentCollection=args );
	}

	public binary function shrinkToFit(
		  required string  filePath
		, required numeric width
		, required numeric height
		,          string  quality        = "highPerformance"
		,          string  paddingColour  = ""
		,          struct  fileProperties = {}
	) {
		return _getImplementation().shrinkToFit( argumentCollection=arguments );
	}

	public binary function pdfPreview(
		  required string filePath
		,          string scale
		,          string resolution
		,          string format
		,          string pages
		,          string transparent
		,          struct fileProperties      = {}
		,         boolean vipsEnabled    = true
	) {
		return _getImplementation( vipsEnabled=arguments.vipsEnabled ).pdfPreview( argumentCollection=arguments );
	}

	public struct function getImageInformation( required string asset ) {
		return JavaImageMetaReader::readMeta( arguments.asset );
	}

	public boolean function isValidImageFile( required string path ) {
		try {
			var imageInfo = getImageInformation( arguments.path );
		} catch( any e ) {
			return false;
		}
		return StructKeyExists( imageInfo, "height" );
	}

	private struct function _getCropHintArea(
		  required string  image
		, required numeric width
		, required numeric height
		, required string  cropHint
		,          boolean ignoreDimension=false
	) {
		var imageInfo      = getImageInformation( arguments.image );
		var targetWidth    = arguments.width;
		var targetHeight   = arguments.height;
		var targetRatio    = targetWidth / targetHeight;
		var cropHintCoords = ListToArray( arguments.cropHint );
		var cropX          = int( cropHintCoords[ 1 ] * imageInfo.width );
		var cropY          = int( cropHintCoords[ 2 ] * imageInfo.height );
		var cropWidth      = int( cropHintCoords[ 3 ] * imageInfo.width );
		var cropHeight     = int( cropHintCoords[ 4 ] * imageInfo.height );
		var cropHintRatio  = cropWidth / cropHeight;
		var prevCropWidth  = 0;
		var prevCropHeight = 0;
		var widthRatio     = 0;
		var heightRatio    = 0;

		if ( !arguments.ignoreDimension ) {
			if ( cropHintRatio > targetRatio ) {
				prevCropHeight = cropHeight;
				cropHeight     = int( cropHeight * ( cropHintRatio / targetRatio ) );
				cropY          = int( cropY - ( ( cropHeight - prevCropHeight ) / 2 ) );
			} else if ( cropHintRatio < targetRatio ) {
				prevCropWidth = cropWidth;
				cropWidth     = int( cropWidth * ( targetRatio / cropHintRatio ) );
				cropX         = int( cropX - ( ( cropWidth - prevCropWidth ) / 2 ) );
			}

			if ( targetWidth > cropWidth ) {
				prevCropWidth  = cropWidth;
				widthRatio     = targetWidth / cropWidth;
				cropWidth      = int( cropWidth  * widthRatio );
				cropX          = int( cropX - ( ( cropWidth  - prevCropWidth ) / 2 ) );
			}
			if ( targetHeight > cropHeight ) {
				prevCropHeight = cropHeight;
				heightRatio    = targetHeight / cropHeight;
				cropHeight     = int( cropHeight * heightRatio );
				cropY          = int( cropY - ( ( cropHeight - prevCropHeight ) / 2 ) );
			}


			if ( cropWidth > imageInfo.width || cropHeight > imageInfo.height ) {
				var fitRatio   = min( imageInfo.width / cropWidth, imageInfo.height / cropHeight );
				prevCropWidth  = cropWidth;
				prevCropHeight = cropHeight;
				cropWidth      = int( cropWidth  * fitRatio );
				cropX          = int( cropX - ( ( cropWidth  - prevCropWidth ) / 2 ) );
				cropHeight     = int( cropHeight * fitRatio );
				cropY          = int( cropY - ( ( cropHeight - prevCropHeight ) / 2 ) );
			}
		}

		cropX = max( cropX, 0 );
		cropY = max( cropY, 0 );
		cropX = min( cropX, imageInfo.width - cropWidth );
		cropY = min( cropY, imageInfo.height - cropHeight );

		return {
			  x      = cropX
			, y      = cropY
			, width  = cropWidth
			, height = cropHeight
		}
	}

	private function _getImplementation( boolean vipsEnabled=true ) {
		if ( arguments.vipsEnabled && _getLibVipsImplementation().enabled() ) {
			return _getLibVipsImplementation();
		}

	    var useImageMagick = $getPresideSetting( "asset-manager", "use_imagemagick" );
	    if ( IsBoolean( useImageMagick ) && useImageMagick ) {
	        return _getImageMagickImplementation();
	    }

	    return _getNativeImageImplementation();
	}


	private any function _getNativeImageImplementation() {
		return _nativeImageImplementation;
	}
	private void function _setNativeImageImplementation( required any nativeImageImplementation ) {
		_nativeImageImplementation = arguments.nativeImageImplementation;
	}

	private any function _getImageMagickImplementation() {
		return _imageMagickImplementation;
	}
	private void function _setImageMagickImplementation( required any imageMagickImplementation ) {
		_imageMagickImplementation = arguments.imageMagickImplementation;
	}

	private any function _getLibVipsImplementation() {
	    return _libVipsImplementation;
	}
	private void function _setLibVipsImplementation( required any libVipsImplementation ) {
	    _libVipsImplementation = arguments.libVipsImplementation;
	}

}