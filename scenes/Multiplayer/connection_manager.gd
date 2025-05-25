extends Node

# --- Signals ---
signal connected_to_multiplayer
signal connection_to_multiplayer_failed(error_code)
signal lobby_created_successfully(lobby_id)
signal lobby_creation_has_failed(lobby_name, error_code)
signal joined_lobby_successfully(lobby_id)
signal failed_to_join_lobby(lobby_id, error_code)
signal player_joined_lobby(client_id) # Consider passing player data too
signal player_left_lobby(client_id)
signal player_list_updated(players_map) # Emits the current map of players
signal lobby_closed

# --- State Variables ---
var current_lobby_id: String = ""
var connected_clients: Dictionary = {} # Store client_id: client_data
var is_currently_host: bool = false
var local_client_id: int = -1

func _ready():
	# Connect to GDSync signals here
	GDSync.connected.connect(_on_gdsync_connected)
	GDSync.connection_failed.connect(_on_gdsync_connection_failed)
	GDSync.lobby_created.connect(_on_gdsync_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_gdsync_lobby_creation_failed)
	GDSync.client_joined.connect(_on_gdsync_client_joined)
	GDSync.client_left.connect(_on_gdsync_client_left)
	GDSync.lobby_joined.connect(_on_gdsync_lobby_joined) # If GDSync has this
	GDSync.lobby_join_failed.connect(_on_gdsync_lobby_join_failed) # If GDSync has this
	# You might want to initialize local multiplayer if it's always needed
	# GDSync.start_local_multiplayer() 
	# Or provide a method for UI to call this.

# --- Public API Methods ---
func start_hosting_lobby(lobby_name: String, password: String = "", is_public: bool = true, player_limit: int = 0):
	if not GDSync.is_active(): # Or similar check if GDSync needs prior connection
		GDSync.start_local_multiplayer() # Or connect to a master server if not local
		# You might need to wait for GDSync.connected signal before creating lobby
	
	print("ConnectionManager: Attempting to create lobby: ", lobby_name)
	GDSync.lobby_create(lobby_name, password, is_public, player_limit)

func join_existing_lobby(lobby_id_to_join: String, password: String = ""):
	if not GDSync.is_active():
		GDSync.start_local_multiplayer()
		# Potentially wait for connection
		
	print("ConnectionManager: Attempting to join lobby: ", lobby_id_to_join)
	GDSync.lobby_join(lobby_id_to_join, password)

func leave_current_lobby():
	if current_lobby_id != "":
		print("ConnectionManager: Leaving lobby: ", current_lobby_id)
		GDSync.lobby_leave()
		if is_currently_host and GDSync.lobby_get_player_count() <= 1: # Check if you are the last one
			GDSync.lobby_close() # This might trigger _on_gdsync_lobby_closed
		_reset_lobby_state()
	else:
		print("ConnectionManager: Not in a lobby to leave.")

func get_player_list() -> Dictionary:
	return connected_clients.duplicate(true)

func get_current_lobby_id() -> String:
	return current_lobby_id

func am_i_host() -> bool:
	return is_currently_host
	
func get_my_client_id() -> int:
	return local_client_id

# --- GDSync Signal Handlers (Internal) ---
func _on_gdsync_connected():
	local_client_id = GDSync.get_client_id()
	print("ConnectionManager: Connected to multiplayer. Client ID: ", local_client_id)
	emit_signal("connected_to_multiplayer")

func _on_gdsync_connection_failed(error: int):
	push_error("ConnectionManager: Connection failed. Error: ", error)
	match (error):
		ENUMS.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
			push_error("The public or private key you entered were invalid.")
		ENUMS.CONNECTION_FAILED.TIMEOUT:
			push_error("Unable to connect, please check your internet connection.")

	emit_signal("connection_to_multiplayer_failed", error)

func _on_gdsync_lobby_created(lobby_id: String):
	print("ConnectionManager: Lobby created successfully. ID: ", lobby_id)
	current_lobby_id = lobby_id
	is_currently_host = true # Crucial for host logic
	# Add self to client list immediately as host
	if local_client_id != -1: # Ensure we have our ID
		connected_clients[local_client_id] = {"name": "HostPlayer"} # Add more data as needed
		emit_signal("player_list_updated", connected_clients)
		emit_signal("player_joined_lobby", local_client_id) # Notify UI about self
	emit_signal("lobby_created_successfully", lobby_id)

func _on_gdsync_lobby_creation_failed(lobby_name: String, error: int):
	push_error("ConnectionManager: Lobby creation failed for '", lobby_name, "'. Error: ", error)
	emit_signal("lobby_creation_has_failed", lobby_name, error)

func _on_gdsync_lobby_joined(lobby_id: String, _client_id: int): # GDSync might pass client_id here too
	# This signal might be for when *anyone* joins a lobby you are in, or when *you* successfully join.
	# Clarify GDSync's behavior for this signal.
	# If it's for when *you* join:
	if _client_id == local_client_id:
		print("ConnectionManager: Successfully joined lobby: ", lobby_id)
		current_lobby_id = lobby_id
		is_currently_host = GDSync.is_host() # Update host status
		# You might need to request the current player list from the host or GDSync
		# For now, assume client_joined will populate it.
		emit_signal("joined_lobby_successfully", lobby_id)
	# If it's a generic "someone joined the lobby I'm in", it might be redundant with client_joined

func _on_gdsync_lobby_join_failed(lobby_id: String, error: int):
	match (error):
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
			push_error("A lobby with the name " + lobby_id + " already exists.")
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_SHORT:
			push_error(lobby_id + " is too short.")
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_LONG:
			push_error(lobby_id + " is too long.")
		ENUMS.LOBBY_CREATION_ERROR.PASSWORD_TOO_LONG:
			push_error("The password for " + lobby_id + " is too long.")
		ENUMS.LOBBY_CREATION_ERROR.TAGS_TOO_LARGE:
			push_error("The tags have exceeded the 2048 byte limit.")
		ENUMS.LOBBY_CREATION_ERROR.DATA_TOO_LARGE:
			push_error("The data have exceeded the 2048 byte limit.")
		ENUMS.LOBBY_CREATION_ERROR.ON_COOLDOWN:
			push_error("Please wait a few seconds before creating another lobby.")
	emit_signal("failed_to_join_lobby", lobby_id, error)

func _on_gdsync_client_joined(client_id: int):
	if client_id == local_client_id and is_currently_host:
		# Host already added self in _on_gdsync_lobby_created
		# Or, if this is the primary way to know you've "joined" your own lobby as host:
		if not connected_clients.has(client_id):
			print("ConnectionManager: Host (self) officially noted in lobby. ID: ", client_id)
			connected_clients[client_id] = {"name": "Player " + str(client_id)} # Get actual player data
			emit_signal("player_list_updated", connected_clients)
			emit_signal("player_joined_lobby", client_id)
		return

	if not connected_clients.has(client_id):
		print("ConnectionManager: Client joined lobby. ID: ", client_id)
		# You'll likely want to get player data associated with this client_id
		# GDSync.player_get_data(client_id, "player_name") or similar
		connected_clients[client_id] = {"name": "Player " + str(client_id)} # Placeholder
		emit_signal("player_list_updated", connected_clients)
		emit_signal("player_joined_lobby", client_id)
	else:
		print("ConnectionManager: Client ", client_id, " re-announced or already present.")


func _on_gdsync_client_left(client_id: int):
	if connected_clients.has(client_id):
		print("ConnectionManager: Client left lobby. ID: ", client_id)
		connected_clients.erase(client_id)
		emit_signal("player_list_updated", connected_clients)
		emit_signal("player_left_lobby", client_id)
		
		if client_id == local_client_id: # If I left
			_reset_lobby_state()


func _on_gdsync_lobby_closed():
	print("ConnectionManager: Lobby has been closed.")
	_reset_lobby_state()
	emit_signal("lobby_closed")

func _reset_lobby_state():
	current_lobby_id = ""
	connected_clients.clear()
	is_currently_host = false
	# Don't reset local_client_id unless disconnected from GDSync entirely
	emit_signal("player_list_updated", connected_clients) # Notify UI of empty list

# --- Helper to start local multiplayer if not already connected ---
# This might be useful before attempting lobby operations
func ensure_multiplayer_started():
	if not GDSync.is_active(): # Or appropriate check for GDSync
		GDSync.start_local_multiplayer()
		# You might need to yield here for the 'connected' signal
		# await GDSync.connected 
		# This can be tricky if called from _ready or _init before tree is fully set up.
		# A state machine or boolean flag might be better.
		print("ConnectionManager: Started local multiplayer.")
	else:
		print("ConnectionManager: Local multiplayer already started or connected.")
