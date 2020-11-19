/**
 * @presideService true
 * @singleton      true
 */
component {

// CONSTRUCTOR
	/**
	 * @host.inject coldbox:setting:socketio.host
	 * @port.inject coldbox:setting:socketio.port
	 *
	 */
	public any function init( required string host, required numeric port ) {
		_setHost( arguments.host );
		_setPort( arguments.port );

		return this;
	}

// PUBLIC API METHODS
	public any function get() {
		return _getIoServer();
	}

	public void function start() {
		_setupServer();
		_getIoServer().start();
	}
	public void function shutdown() {
		if ( _serverIsSetup() ) {
			_getIoServer().shutdown();
		}
	}

	public void function registerAdminNamespace( required string namespace, required string connectionHandler ) {
		var args = arguments;

		_getIoServer().namespace( arguments.namespace ).on( "connect", function( socket ){
			var authenticated = doAdminSocketAuth( socket );

			if ( authenticated ) {
				$runEvent(
					  event          = args.connectionHandler
					, private        = true
					, prepostexempt  = true
					, eventArguments = { socket=socket }
				);
			} else {
				socket.emit( "error", { reason="authenticatio.error" } );
				socket.disconnect( close=true );
			}
		} );
	}

	public boolean function doAdminSocketAuth( required any socket ) {
		// TODO
		return true;
	}

	public string function getAdminSocketIoConnectionUrl( required string namespace ) {

	}

// PRIVATE HELPERS
	private boolean function _serverIsSetup() {
		return StructKeyExists( variables, "_ioServer" );
	}

	private void function _setupServer() {
		if ( !_serverIsSetup() ) {
			_setIoServer( new socketiolucee.models.SocketIoServer(
				  host = _getHost()
				, port = _getPort()
				, start = false
			) );
		}
	}

// GETTERS AND SETTERS
	private string function _getHost() {
	    return _host;
	}
	private void function _setHost( required string host ) {
	    _host = arguments.host;
	}

	private numeric function _getPort() {
	    return _port;
	}
	private void function _setPort( required numeric port ) {
	    _port = arguments.port;
	}

	private any function _getIoServer() {
	    return _ioServer;
	}
	private void function _setIoServer( required any ioServer ) {
	    _ioServer = arguments.ioServer;
	}

}