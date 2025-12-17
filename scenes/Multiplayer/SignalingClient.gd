extends Node
class_name SignalingClient

## SignalingClient.gd
## WebSocket client for the Python signaling server's /lobby protocol.
## Handles lobby events and emits GDSync-compatible signals.

signal connected
signal disconnected
signal connection_error(error: String)

signal lobby_created(code: String, name: String, host_id: int, your_id: int)
signal lobby_joined(
	code: String, name: String, host_id: int, your_id: int, players: Array
)
signal lobby_left(code: String)
signal lobby_closed(code: String, reason: String)
signal lobby_list_received(lobbies: Array)

signal peer_joined(peer_id: int, player_data: Dictionary)
signal peer_left(peer_id: int)

signal error_received(code: String, message: String)

# Message types (client -> server)
const MSG_CREATE_LOBBY = "create_lobby"
const MSG_LIST_LOBBIES = "list_lobbies"
const MSG_JOIN_LOBBY = "join_lobby"
const MSG_LEAVE_LOBBY = "leave_lobby"
const MSG_PING = "ping"

# Response types (server -> client)
const RESP_WELCOME = "welcome"
const RESP_LOBBY_CREATED = "lobby_created"
const RESP_LOBBY_LIST = "lobby_list"
const RESP_LOBBY_JOINED = "lobby_joined"
const RESP_LOBBY_LEFT = "lobby_left"
const RESP_PONG = "pong"
const RESP_ERROR = "error"
const RESP_PEER_JOINED = "peer_joined"
const RESP_PEER_LEFT = "peer_left"
const RESP_LOBBY_CLOSED = "lobby_closed"
const RESP_SERVER_SHUTDOWN = "server_shutdown"

var _socket: WebSocketPeer = null
var _server_url: String = ""
var _is_connected: bool = false
var _reconnect_attempts: int = 0
var _max_reconnect_attempts: int = 3

var my_peer_id: int = -1
var current_lobby_code: String = ""
var is_host: bool = false

var logger: ColorfulLogger


func _ready() -> void:
	logger = CustomLogger.get_logger(self)
	set_process(false)


func _process(_delta: float) -> void:
	if _socket == null:
		return

	_socket.poll()

	var state = _socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				var packet = _socket.get_packet()
				_handle_packet(packet)
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = _socket.get_close_code()
			var reason = _socket.get_close_reason()
			logger.log_info(
				"WebSocket closed: code=%d, reason=%s" % [code, reason]
			)
			_on_disconnected()


## Connect to the signaling server's /lobby WebSocket endpoint
func connect_to_server(server_url: String) -> Error:
	if _socket != null and _is_connected:
		logger.log_warning("Already connected to server")
		return ERR_ALREADY_IN_USE

	_server_url = server_url.rstrip("/")
	var ws_url = (
		_server_url.replace("http://", "ws://").replace("https://", "wss://")
		+ "/lobby"
	)

	logger.log_info("Connecting to signaling server: " + ws_url)

	_socket = WebSocketPeer.new()
	var err = _socket.connect_to_url(ws_url)
	if err != OK:
		logger.log_error("Failed to connect to server: " + str(err))
		connection_error.emit("Failed to connect: " + str(err))
		return err

	set_process(true)
	return OK


## Disconnect from the server
func disconnect_from_server() -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_is_connected = false
	my_peer_id = -1
	current_lobby_code = ""
	is_host = false
	set_process(false)


## Create a new lobby
func create_lobby(
	name: String,
	public: bool = true,
	player_limit: int = 0,
	player_data: Dictionary = {}
) -> void:
	_send_message(
		{
			"t": MSG_CREATE_LOBBY,
			"name": name,
			"public": public,
			"player_limit": player_limit,
			"player":
			player_data if not player_data.is_empty() else {"name": "Host"}
		}
	)


## List available public lobbies
func list_lobbies() -> void:
	_send_message({"t": MSG_LIST_LOBBIES})


## Join an existing lobby by code or name
func join_lobby(code_or_name: String, player_data: Dictionary = {}) -> void:
	_send_message(
		{
			"t": MSG_JOIN_LOBBY,
			"code": code_or_name.to_upper().strip_edges(),
			"player":
			player_data if not player_data.is_empty() else {"name": "Player"}
		}
	)


## Leave the current lobby
func leave_lobby() -> void:
	if current_lobby_code == "":
		logger.log_warning("Not in a lobby")
		return
	_send_message({"t": MSG_LEAVE_LOBBY})


## Send a ping to keep connection alive
func send_ping() -> void:
	_send_message({"t": MSG_PING})


## Check if connected to the server
func is_connected_to_server() -> bool:
	return _is_connected


## Get the current lobby code
func get_lobby_code() -> String:
	return current_lobby_code


# =============================================================================
# Internal Methods
# =============================================================================


func _send_message(data: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		logger.log_error("Cannot send message: not connected")
		return

	var json = JSON.stringify(data)
	var err = _socket.send_text(json)
	if err != OK:
		logger.log_error("Failed to send message: " + str(err))


func _handle_packet(packet: PackedByteArray) -> void:
	var text = packet.get_string_from_utf8()
	var data = JSON.parse_string(text)

	if data == null:
		logger.log_error("Failed to parse server message: " + text)
		return

	var msg_type = data.get("t", "")
	match msg_type:
		RESP_WELCOME:
			_handle_welcome(data)
		RESP_LOBBY_CREATED:
			_handle_lobby_created(data)
		RESP_LOBBY_LIST:
			_handle_lobby_list(data)
		RESP_LOBBY_JOINED:
			_handle_lobby_joined(data)
		RESP_LOBBY_LEFT:
			_handle_lobby_left(data)
		RESP_PONG:
			pass  # Heartbeat response, nothing to do
		RESP_ERROR:
			_handle_error(data)
		RESP_PEER_JOINED:
			_handle_peer_joined(data)
		RESP_PEER_LEFT:
			_handle_peer_left(data)
		RESP_LOBBY_CLOSED:
			_handle_lobby_closed(data)
		RESP_SERVER_SHUTDOWN:
			_handle_server_shutdown(data)
		_:
			logger.log_warning("Unknown message type: " + msg_type)


func _handle_welcome(data: Dictionary) -> void:
	my_peer_id = data.get("your_id", -1)
	_is_connected = true
	_reconnect_attempts = 0
	logger.log_info(
		"Connected to signaling server. My peer ID: " + str(my_peer_id)
	)
	connected.emit()


func _handle_lobby_created(data: Dictionary) -> void:
	var code = data.get("code", "")
	var name = data.get("name", "")
	var host_id = data.get("host_id", -1)
	var your_id = data.get("your_id", -1)

	current_lobby_code = code
	is_host = true
	my_peer_id = your_id

	logger.log_info(
		"Lobby created: %s '%s' (host_id=%d)" % [code, name, host_id]
	)
	lobby_created.emit(code, name, host_id, your_id)


func _handle_lobby_list(data: Dictionary) -> void:
	var items = data.get("items", [])
	logger.log_info("Received %d lobbies" % items.size())
	lobby_list_received.emit(items)


func _handle_lobby_joined(data: Dictionary) -> void:
	var code = data.get("code", "")
	var name = data.get("name", "")
	var host_id = data.get("host_id", -1)
	var your_id = data.get("your_id", -1)
	var players = data.get("players", [])

	current_lobby_code = code
	is_host = (your_id == host_id)
	my_peer_id = your_id

	logger.log_info(
		(
			"Joined lobby: %s '%s' (host=%d, me=%d, players=%d)"
			% [code, name, host_id, your_id, players.size()]
		)
	)
	lobby_joined.emit(code, name, host_id, your_id, players)


func _handle_lobby_left(data: Dictionary) -> void:
	var code = data.get("code", "")
	logger.log_info("Left lobby: " + code)

	current_lobby_code = ""
	is_host = false
	lobby_left.emit(code)


func _handle_error(data: Dictionary) -> void:
	var code = data.get("code", "UNKNOWN")
	var message = data.get("message", "Unknown error")
	logger.log_error("Server error: %s - %s" % [code, message])
	error_received.emit(code, message)


func _handle_peer_joined(data: Dictionary) -> void:
	var peer_id = data.get("id", -1)
	var player_data = data.get("player", {})
	logger.log_info("Peer joined: %d, data=%s" % [peer_id, str(player_data)])
	peer_joined.emit(peer_id, player_data)


func _handle_peer_left(data: Dictionary) -> void:
	var peer_id = data.get("id", -1)
	logger.log_info("Peer left: " + str(peer_id))
	peer_left.emit(peer_id)


func _handle_lobby_closed(data: Dictionary) -> void:
	var code = data.get("code", "")
	var reason = data.get("reason", "closed")
	logger.log_info("Lobby closed: %s (reason: %s)" % [code, reason])

	current_lobby_code = ""
	is_host = false
	lobby_closed.emit(code, reason)


func _handle_server_shutdown(_data: Dictionary) -> void:
	logger.log_warning("Server is shutting down")
	_on_disconnected()


func _on_disconnected() -> void:
	_is_connected = false
	current_lobby_code = ""
	is_host = false
	set_process(false)
	disconnected.emit()
