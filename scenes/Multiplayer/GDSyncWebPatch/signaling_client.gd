extends Node
class_name SignalingClient

## SignalingClient.gd
## HTTP + SSE client for the Python signaling server.
## Uses REST API for lobby operations and SSE for real-time events.

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

signal game_packet_received(from_peer: int, packet_data: String)

signal error_received(code: String, message: String)

# SSE Event types
const EVT_WELCOME = "welcome"
const EVT_PEER_JOINED = "peer_joined"
const EVT_PEER_LEFT = "peer_left"
const EVT_LOBBY_JOINED = "lobby_joined"
const EVT_LOBBY_CLOSED = "lobby_closed"
const EVT_GAME_PACKET = "game_packet"
const EVT_ERROR = "error"
const EVT_HEARTBEAT = "heartbeat"

var _server_url: String = ""
var _is_connected: bool = false
var _sse_client: HTTPClient = null
var _sse_buffer: String = ""

var my_peer_id: int = -1
var current_lobby_code: String = ""
var is_host: bool = false

var logger: ColorfulLogger

# HTTP request nodes (created dynamically)
var _pending_requests: Array[HTTPRequest] = []


func _ready() -> void:
	logger = CustomLogger.get_logger(self)
	set_process(false)


func _process(_delta: float) -> void:
	if _sse_client == null:
		return

	# Poll SSE connection
	_sse_client.poll()

	var status = _sse_client.get_status()
	match status:
		HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_BODY:
			# Read available data
			if _sse_client.has_response():
				var chunk = _sse_client.read_response_body_chunk()
				if chunk.size() > 0:
					_sse_buffer += chunk.get_string_from_utf8()
					_process_sse_buffer()
		HTTPClient.STATUS_DISCONNECTED:
			logger.log_warning("SSE connection disconnected")
			_on_disconnected()
		HTTPClient.STATUS_CONNECTION_ERROR:
			logger.log_error("SSE connection error")
			_on_disconnected()


func _process_sse_buffer() -> void:
	# SSE format: "event: <type>\ndata: <json>\n\n"
	while true:
		var event_end = _sse_buffer.find("\n\n")
		if event_end == -1:
			break

		var event_block = _sse_buffer.substr(0, event_end)
		_sse_buffer = _sse_buffer.substr(event_end + 2)

		_parse_sse_event(event_block)


func _parse_sse_event(block: String) -> void:
	var event_type = ""
	var event_data = ""

	for line in block.split("\n"):
		if line.begins_with("event: "):
			event_type = line.substr(7).strip_edges()
		elif line.begins_with("data: "):
			event_data = line.substr(6)

	if event_type == "" or event_data == "":
		return

	var data = JSON.parse_string(event_data)
	if data == null:
		logger.log_error("Failed to parse SSE data: " + event_data)
		return

	_handle_sse_event(event_type, data)


func _handle_sse_event(event_type: String, data: Dictionary) -> void:
	logger.log_info(
		"SSE event received: type=%s data=%s" % [event_type, str(data)]
	)
	match event_type:
		EVT_WELCOME:
			var peer_id = data.get("peer_id", -1)
			logger.log_info("SSE connected, peer_id: " + str(peer_id))
			# my_peer_id should already be set from connect response
		EVT_PEER_JOINED:
			var peer_id = data.get("id", -1)
			var player_data = data.get("player", {})
			logger.log_info("Peer joined: " + str(peer_id))
			peer_joined.emit(peer_id, player_data)
		EVT_PEER_LEFT:
			var peer_id = data.get("id", -1)
			logger.log_info(
				"Peer left: " + str(peer_id) + " - emitting peer_left signal"
			)
			peer_left.emit(peer_id)
		EVT_LOBBY_CLOSED:
			var code = data.get("code", "")
			var reason = data.get("reason", "closed")
			logger.log_info("Lobby closed: " + code + " reason: " + reason)
			current_lobby_code = ""
			is_host = false
			lobby_closed.emit(code, reason)
		EVT_GAME_PACKET:
			var from_peer = data.get("from", -1)
			var packet = data.get("packet", "")
			game_packet_received.emit(from_peer, packet)
		EVT_ERROR:
			var code = data.get("code", "UNKNOWN")
			var message = data.get("message", "Unknown error")
			logger.log_error("Server error: " + code + " - " + message)
			error_received.emit(code, message)
		EVT_HEARTBEAT:
			pass  # Just keep-alive, nothing to do
		_:
			logger.log_warning("Unknown SSE event: " + event_type)


## Connect to the signaling server
func connect_to_server(server_url: String) -> Error:
	if _is_connected:
		logger.log_warning("Already connected to server")
		return ERR_ALREADY_IN_USE

	_server_url = server_url.rstrip("/")
	logger.log_info("Connecting to server: " + _server_url)

	# Send GDSync's client_id to the server - use the ID that GDSync already generated
	var gdsync_client_id = GDSync.get_client_id()
	assert(
		gdsync_client_id > 0,
		(
			"SignalingClient: GDSync client_id must be positive, got: %d"
			% gdsync_client_id
		)
	)

	# Make HTTP POST to /api/lobby/connect with our client_id
	var result = await _http_post(
		"/api/lobby/connect", {"client_id": gdsync_client_id}
	)
	if result == null or not result.get("success", false):
		var err_msg = "Failed to connect"
		if result:
			err_msg = result.get("message", err_msg)
		logger.log_error(err_msg)
		connection_error.emit(err_msg)
		return ERR_CANT_CONNECT

	my_peer_id = result.get("peer_id", -1)
	assert(
		my_peer_id == gdsync_client_id,
		(
			"SignalingClient: Server returned different peer_id (%d) than requested (%d)"
			% [my_peer_id, gdsync_client_id]
		)
	)
	logger.log_info("Connected! Peer ID: " + str(my_peer_id))

	# Start SSE connection
	var sse_err = await _start_sse_connection()
	if sse_err != OK:
		logger.log_error("Failed to start SSE connection")
		connection_error.emit("SSE connection failed")
		return sse_err

	_is_connected = true
	connected.emit()
	return OK


func _start_sse_connection() -> Error:
	_sse_client = HTTPClient.new()

	# Parse server URL
	var url = _server_url
	var host = ""
	var port = 80
	var use_ssl = false

	if url.begins_with("https://"):
		use_ssl = true
		port = 443
		url = url.substr(8)
	elif url.begins_with("http://"):
		url = url.substr(7)

	var port_idx = url.find(":")
	if port_idx != -1:
		host = url.substr(0, port_idx)
		port = int(url.substr(port_idx + 1))
	else:
		host = url

	logger.log_info("SSE connecting to " + host + ":" + str(port))

	# Godot 4 requires TLSOptions object instead of boolean
	var tls_options: TLSOptions = TLSOptions.client() if use_ssl else null
	var err = _sse_client.connect_to_host(host, port, tls_options)
	if err != OK:
		logger.log_error("Failed to connect SSE: " + str(err))
		return err

	# Wait for connection
	while (
		_sse_client.get_status() == HTTPClient.STATUS_CONNECTING
		or _sse_client.get_status() == HTTPClient.STATUS_RESOLVING
	):
		_sse_client.poll()
		await get_tree().process_frame

	if _sse_client.get_status() != HTTPClient.STATUS_CONNECTED:
		logger.log_error(
			"SSE connection failed, status: " + str(_sse_client.get_status())
		)
		return ERR_CANT_CONNECT

	# Send GET request for SSE
	var headers = [
		"Accept: text/event-stream",
		"Cache-Control: no-cache",
	]

	var path = "/api/lobby/events?peer_id=" + str(my_peer_id)
	err = _sse_client.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		logger.log_error("Failed to request SSE: " + str(err))
		return err

	# Wait for response headers
	while _sse_client.get_status() == HTTPClient.STATUS_REQUESTING:
		_sse_client.poll()
		await get_tree().process_frame

	if not _sse_client.has_response():
		logger.log_error("No SSE response")
		return ERR_CANT_CONNECT

	var response_code = _sse_client.get_response_code()
	if response_code != 200:
		logger.log_error("SSE response code: " + str(response_code))
		return ERR_CANT_CONNECT

	logger.log_info("SSE stream connected")
	_sse_buffer = ""
	set_process(true)

	return OK


## Disconnect from the server
func disconnect_from_server() -> void:
	if not _is_connected:
		return

	# Notify server
	await _http_post("/api/lobby/disconnect", {"peer_id": my_peer_id})

	_cleanup()


func _cleanup() -> void:
	if _sse_client:
		_sse_client.close()
		_sse_client = null

	_is_connected = false
	my_peer_id = -1
	current_lobby_code = ""
	is_host = false
	_sse_buffer = ""
	set_process(false)


func _on_disconnected() -> void:
	_cleanup()
	disconnected.emit()


## Create a new lobby
func create_lobby(
	lobby_name: String,
	public: bool = true,
	player_limit: int = 0,
	player_data: Dictionary = {}
) -> void:
	var body = {
		"peer_id": my_peer_id,
		"name": lobby_name,
		"public": public,
		"player_limit": player_limit,
		"player":
		player_data if not player_data.is_empty() else {"name": "Host"}
	}

	var result = await _http_post("/api/lobby/create", body)
	if result == null:
		error_received.emit("REQUEST_FAILED", "Failed to create lobby")
		return

	if not result.get("success", false):
		error_received.emit(
			result.get("error", "UNKNOWN"),
			result.get("message", "Failed to create lobby")
		)
		return

	current_lobby_code = result.get("code", "")
	is_host = true

	logger.log_info("Lobby created: %s '%s'" % [current_lobby_code, lobby_name])
	lobby_created.emit(
		result.get("code", ""),
		result.get("name", ""),
		result.get("host_id", -1),
		result.get("your_id", -1)
	)


## List available public lobbies
func list_lobbies() -> void:
	var result = await _http_get("/api/lobby/list")
	if result == null:
		error_received.emit("REQUEST_FAILED", "Failed to list lobbies")
		return

	var items = result.get("lobbies", [])
	logger.log_info("Received %d lobbies" % items.size())
	lobby_list_received.emit(items)


## Join an existing lobby by code or name
func join_lobby(code_or_name: String, player_data: Dictionary = {}) -> void:
	var body = {
		"peer_id": my_peer_id,
		"code": code_or_name.to_upper().strip_edges(),
		"player":
		player_data if not player_data.is_empty() else {"name": "Player"}
	}

	var result = await _http_post("/api/lobby/join", body)
	if result == null:
		error_received.emit("REQUEST_FAILED", "Failed to join lobby")
		return

	if not result.get("success", false):
		error_received.emit(
			result.get("error", "UNKNOWN"),
			result.get("message", "Failed to join lobby")
		)
		return

	current_lobby_code = result.get("code", "")
	var host_id = result.get("host_id", -1)
	is_host = (my_peer_id == host_id)

	logger.log_info(
		(
			"Joined lobby: %s (host=%d, me=%d)"
			% [current_lobby_code, host_id, my_peer_id]
		)
	)
	lobby_joined.emit(
		result.get("code", ""),
		result.get("name", ""),
		host_id,
		result.get("your_id"),
		result.get("players", [])
	)


## Leave the current lobby
func leave_lobby() -> void:
	if current_lobby_code == "":
		logger.log_warning("Not in a lobby")
		return

	logger.log_info(
		(
			"Sending leave_lobby request to server (peer_id=%d, lobby=%s)"
			% [my_peer_id, current_lobby_code]
		)
	)
	var body = {"peer_id": my_peer_id}
	var result = await _http_post("/api/lobby/leave", body)

	if result and result.get("success", false):
		var code = result.get("code", "")
		logger.log_info("Successfully left lobby: " + code)
		current_lobby_code = ""
		is_host = false
		lobby_left.emit(code)
	else:
		var err_msg = "Failed to leave lobby"
		if result:
			err_msg = result.get("message", err_msg)
		logger.log_error("Leave lobby failed: " + err_msg)
		error_received.emit("LEAVE_FAILED", err_msg)


## Broadcast a game packet to all peers in the lobby
func broadcast_packet(packet_base64: String, target_peer: int = -1) -> void:
	if current_lobby_code == "":
		logger.log_warning("Not in a lobby, cannot broadcast")
		return

	var body = {
		"peer_id": my_peer_id, "packet": packet_base64, "target": target_peer
	}

	# Fire and forget - don't await
	_http_post_no_wait("/api/lobby/broadcast", body)


## Send a ping to keep connection alive
func send_ping() -> void:
	# With SSE, the server sends heartbeats, but we can ping if needed
	pass


## Check if connected to the server
func is_connected_to_server() -> bool:
	return _is_connected


## Get the current lobby code
func get_lobby_code() -> String:
	return current_lobby_code


# =============================================================================
# HTTP Helper Methods
# =============================================================================


func _http_get(path: String) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	_pending_requests.append(http)

	var url = _server_url + path
	var err = http.request(url, [], HTTPClient.METHOD_GET)

	if err != OK:
		logger.log_error("HTTP GET failed: " + str(err))
		_cleanup_request(http)
		return {}

	var response = await http.request_completed
	_cleanup_request(http)

	var result_code = response[0]
	var response_code = response[1]
	var body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		logger.log_error("HTTP GET result error: " + str(result_code))
		return {}

	if response_code != 200:
		logger.log_error("HTTP GET response code: " + str(response_code))

	var json_str = body.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	return data if data else {}


func _http_post(path: String, body: Dictionary) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	_pending_requests.append(http)

	var url = _server_url + path
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if err != OK:
		logger.log_error("HTTP POST failed: " + str(err))
		_cleanup_request(http)
		return {}

	var response = await http.request_completed
	_cleanup_request(http)

	var result_code = response[0]
	var response_code = response[1]
	var response_body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		logger.log_error("HTTP POST result error: " + str(result_code))
		return {}

	if response_code >= 400:
		logger.log_warning("HTTP POST response code: " + str(response_code))

	var json_str = response_body.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	return data if data else {}


func _http_post_no_wait(path: String, body: Dictionary) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	_pending_requests.append(http)

	var url = _server_url + path
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		logger.log_error("HTTP POST (no-wait) failed: " + str(err))
		_cleanup_request(http)
		return

	# Connect cleanup to completion
	http.request_completed.connect(
		func(_result, _code, _headers, _body): _cleanup_request(http),
		CONNECT_ONE_SHOT
	)


func _cleanup_request(http: HTTPRequest) -> void:
	if http in _pending_requests:
		_pending_requests.erase(http)
	if is_instance_valid(http):
		http.queue_free()
