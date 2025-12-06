extends Node

## LocalServerWebPatch.gd
## WebRTC-based replacement for GD-Sync's LocalServer.gd
## Uses PackRTC for signaling and WebRTC peer connections on web platform

var GDSync
var connection_controller
var request_processor
var session_controller
var logger

# Lobby state (mirrors original LocalServer.gd)
var local_lobby_name: String = ""
var local_lobby_password: String = ""
var local_lobby_public: bool = false
var local_lobby_open: bool = true
var local_lobby_player_limit: int = 0

var local_lobby_data: Dictionary = {}
var local_lobby_tags: Dictionary = {}
var local_owner_cache: Dictionary = {}

var found_lobbies: Dictionary = {}

var peer_client_table: Dictionary = {}
var lobby_client_table: Dictionary = {}

# WebRTC specific
var rtc_session: PRSession = null
var is_host: bool = false
var _is_initialized: bool = false


# Client class (mirrors original)
class Client:
	extends RefCounted
	var valid: bool = false
	var client_id: int = -1
	var peer_id: int = -1
	var username: String
	var player_data: Dictionary = {}

	var requests_RUDP: Array = []
	var requests_UDP: Array = []
	var lobby_targets: Array = []

	func construct_lobby_targets(clients: Dictionary) -> void:
		lobby_targets = clients.values()
		lobby_targets.erase(self)

	func collect_player_data() -> Dictionary:
		var data: Dictionary = player_data.duplicate()
		data["ID"] = client_id
		data["Username"] = username
		return data


func _ready() -> void:
	print("[LocalServerWebPatch] _ready() called!")

	GDSync = get_node("/root/GDSync")
	name = "LocalServer"
	connection_controller = GDSync._connection_controller
	request_processor = GDSync._request_processor
	session_controller = GDSync._session_controller
	logger = GDSync._logger

	# Configure PackRTC
	PackRTC.game_channel = "gdsync-hpc-sorting"
	PackRTC.use_mesh = true
	PackRTC.enable_debug = OS.has_feature("editor")

	set_process(false)
	print("[LocalServerWebPatch] Initialized successfully!")
	logger.write_log(
		"LocalServerWebPatch initialized for web platform.", "[LocalServer-Web]"
	)


func reset_multiplayer() -> void:
	logger.write_log("Closing web multiplayer.", "[LocalServer-Web]")

	if rtc_session:
		rtc_session.queue_free()
		rtc_session = null

	set_process(false)
	found_lobbies.clear()
	clear_lobby_data()
	_is_initialized = false


func clear_lobby_data() -> void:
	logger.write_log("Clear lobby data.", "[LocalServer-Web]")
	local_lobby_name = ""
	local_lobby_password = ""

	local_lobby_data.clear()
	local_lobby_tags.clear()
	local_owner_cache.clear()
	peer_client_table.clear()
	lobby_client_table.clear()
	is_host = false


func start_local_peer() -> bool:
	print("[LocalServerWebPatch] start_local_peer() called - returning true for WebRTC mode")
	logger.write_log(
		"Web platform: WebRTC mode - no UDP binding needed.",
		"[LocalServer-Web]"
	)
	# On web, we don't need to bind UDP ports
	# Return true to indicate successful initialization
	# Actual WebRTC connection happens when creating/joining lobby
	_is_initialized = true
	return true


func create_local_lobby(
	lobby_name: String,
	password: String = "",
	public: bool = true,
	player_limit: int = 0,
	tags: Dictionary = {},
	data: Dictionary = {}
) -> void:
	logger.write_log("Creating web lobby: " + lobby_name, "[LocalServer-Web]")

	# Validate lobby parameters
	if lobby_name.length() < 3:
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_SHORT
		)
		return
	if lobby_name.length() > 32:
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_LONG
		)
		return
	if password.length() > 16:
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.PASSWORD_TOO_LONG
		)
		return
	if var_to_bytes(tags).size() > 2048:
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.TAGS_TOO_LARGE
		)
		return
	if var_to_bytes(data).size() > 2048:
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.DATA_TOO_LARGE
		)
		return

	# Use PackRTC to host
	PackRTC.game_channel = "gdsync-" + lobby_name.to_lower().replace(" ", "-")
	var session = await PackRTC.host()

	if session is PRSession:
		rtc_session = session
		is_host = true

		# Store lobby state
		local_lobby_name = lobby_name
		local_lobby_password = password
		local_lobby_public = public
		local_lobby_player_limit = player_limit
		local_lobby_tags = tags
		local_lobby_data = data

		# Add to found lobbies
		var lobby_dict: Dictionary = get_lobby_dictionary()
		lobby_dict["Code"] = PackRTC.game_code
		found_lobbies[local_lobby_name] = lobby_dict

		# Wait for WebRTC peer to be ready
		logger.write_log(
			"Waiting for WebRTC peer to be ready...", "[LocalServer-Web]"
		)
		await session.peer_ready

		# Set up multiplayer
		multiplayer.multiplayer_peer = session.rtc_peer

		# Connect peer signals
		session.rtc_peer.peer_connected.connect(_on_peer_connected)
		session.rtc_peer.peer_disconnected.connect(_on_peer_disconnected)

		set_process(true)
		logger.write_log(
			"Web lobby created. Code: " + PackRTC.game_code, "[LocalServer-Web]"
		)
		GDSync.lobby_created.emit.call_deferred(lobby_name)
	else:
		logger.write_error(
			"Failed to create web lobby: " + str(session), "[LocalServer-Web]"
		)
		GDSync.lobby_creation_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_CREATION_ERROR.LOCAL_PORT_ERROR
		)


func join_lobby(lobby_name: String, password: String) -> void:
	logger.write_log("Joining web lobby: " + lobby_name, "[LocalServer-Web]")

	# For web, lobby_name is actually the room code
	var code = lobby_name

	# Use PackRTC to join
	var session = await PackRTC.join(code)

	if session is PRSession:
		rtc_session = session
		is_host = false
		local_lobby_name = lobby_name
		local_lobby_password = password

		# Wait for WebRTC peer to be ready
		logger.write_log(
			"Waiting for WebRTC peer to be ready...", "[LocalServer-Web]"
		)
		await session.peer_ready

		# Set up multiplayer
		multiplayer.multiplayer_peer = session.rtc_peer

		# Connect peer signals
		session.rtc_peer.peer_connected.connect(_on_peer_connected)
		session.rtc_peer.peer_disconnected.connect(_on_peer_disconnected)

		connection_controller.in_local_lobby = true
		set_process(true)

		logger.write_log("Joined web lobby successfully.", "[LocalServer-Web]")
		GDSync.lobby_joined.emit.call_deferred(lobby_name)
	else:
		logger.write_error(
			"Failed to join web lobby: " + str(session), "[LocalServer-Web]"
		)
		GDSync.lobby_join_failed.emit.call_deferred(
			lobby_name, ENUMS.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST
		)


func get_public_lobbies() -> void:
	# On web, we can't scan for lobbies like UDP broadcast
	# Return the locally known lobbies
	var lobbies: Array = []
	for lobby_data in found_lobbies.values():
		if lobby_data.get("Public", false):
			lobbies.append(lobby_data)

	logger.write_log(
		"Returning " + str(lobbies.size()) + " known lobbies.",
		"[LocalServer-Web]"
	)
	GDSync.lobbies_received.emit.call_deferred(lobbies)


func get_public_lobby(lobby_name: String) -> void:
	for lobby_data in found_lobbies.values():
		if (
			lobby_data.get("Public", false)
			and lobby_data.get("Name", "") == lobby_name
		):
			GDSync.lobby_received.emit.call_deferred(lobby_data)
			return

	GDSync.lobby_received.emit.call_deferred({})


func is_local_server() -> bool:
	return local_lobby_name != "" and is_host


func _on_peer_connected(id: int) -> void:
	logger.write_log("WebRTC peer connected: " + str(id), "[LocalServer-Web]")

	var client: Client = Client.new()
	client.peer_id = id
	client.client_id = id
	client.valid = true
	peer_client_table[id] = client
	lobby_client_table[id] = client

	# Rebuild lobby targets for all clients
	for client_id in lobby_client_table:
		lobby_client_table[client_id].construct_lobby_targets(
			lobby_client_table
		)

	# Emit client joined
	GDSync.client_joined.emit.call_deferred(id)


func _on_peer_disconnected(id: int) -> void:
	logger.write_log(
		"WebRTC peer disconnected: " + str(id), "[LocalServer-Web]"
	)

	if lobby_client_table.has(id):
		lobby_client_table.erase(id)
	if peer_client_table.has(id):
		peer_client_table.erase(id)

	# Rebuild lobby targets
	for client_id in lobby_client_table:
		lobby_client_table[client_id].construct_lobby_targets(
			lobby_client_table
		)

	# Emit client left
	GDSync.client_left.emit.call_deferred(id)


func _process(_delta: float) -> void:
	if not rtc_session or not rtc_session.rtc_peer:
		return

	# Poll the WebRTC peer
	rtc_session.rtc_peer.poll()


# Stub functions to maintain API compatibility
func perform_local_scan() -> void:
	# Not needed for WebRTC - signaling server handles discovery
	pass


func get_lobby_dictionary(with_data: bool = false) -> Dictionary:
	var dict: Dictionary = {
		"Name": local_lobby_name,
		"PlayerCount": lobby_client_table.size() + 1,  # +1 for host
		"PlayerLimit": local_lobby_player_limit,
		"Public": local_lobby_public,
		"Open": local_lobby_open,
		"Tags": local_lobby_tags,
		"HasPassword": local_lobby_password != "",
		"Host": GDSync.player_get_data(GDSync.get_client_id(), "Username", ""),
		"Code": PackRTC.game_code if PackRTC.game_code else ""
	}

	if with_data:
		dict["Data"] = local_lobby_data

	return dict
