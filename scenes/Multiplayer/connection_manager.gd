extends Node

# --- Signals ---
signal connected_to_multiplayer
signal connection_to_multiplayer_failed(error_code)
signal lobby_created_successfully(lobby_name)
signal lobby_creation_has_failed(lobby_name, error_str)
signal joined_lobby_successfully(lobby_name)
signal failed_to_join_lobby(lobby_name, error_code)
signal player_joined_lobby(client_id)
signal player_left_lobby(client_id)
signal player_list_updated(players_map) # Emits the current map of players
signal lobby_closed
signal discovered_lobbies_updated(lobbies_list)

# --- State Variables ---
var current_lobby_name_id: String = ""
###  Store client_id: client_data
var connected_clients: Dictionary = {}
var is_currently_host: bool = false
var local_client_id: int = -1
var actual_lobby_host_id: int = -1
### To store found lobbies
var discovered_lobbies: Array = []

func _ready():
	# Connect to GDSync signals here
	GDSync.connected.connect(_on_gdsync_connected)
	GDSync.connection_failed.connect(_on_gdsync_connection_failed)
	GDSync.lobby_created.connect(_on_gdsync_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_gdsync_lobby_creation_failed)
	GDSync.client_joined.connect(_on_gdsync_client_joined)
	GDSync.client_left.connect(_on_gdsync_client_left)
	GDSync.lobby_joined.connect(_on_gdsync_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_gdsync_lobby_join_failed)
	GDSync.lobbies_received.connect(_on_gdsync_lobby_list_updated)

	#Exposing GDSync to clients, so things can be called from host on clients
	GDSync.expose_func(ToastParty.show)
	GDSync.expose_var(self, "actual_lobby_host_id")
# --- Public API Methods ---
func start_hosting_lobby(lobby_name: String, _password: String = "", _is_public: bool = true, _player_limit: int = 0):
	# print("ConnectionManager: Attempting to create lobby: ", lobby_name)
	# GDSync.lobby_create(lobby_name, passw password, is_public, player_limit)
	GDSync.lobby_create(lobby_name)


func ensure_multiplayer_started():
	if not GDSync.is_active(): # Or appropriate check for GDSync
		GDSync.start_local_multiplayer()
		print("ConnectionManager: Started local multiplayer.")
	else:
		print("ConnectionManager: Local multiplayer already started or connected.")

func find_lobbies():
	# print("ConnectionManager: Requesting lobby list from GDSync.")
	#Assing return array or just empty array if the result is null
	GDSync.get_public_lobbies()
	# GDSync will emit 'lobby_list_updated' when results are available
func get_discovered_lobbies() -> Array:
	return discovered_lobbies.duplicate()

func get_lobby_host_id() -> int:
	return actual_lobby_host_id

func join_existing_lobby(lobby_id_to_join: String, password: String = ""):
	# print("ConnectionManager: Attempting to join lobby: ", lobby_id_to_join)
	GDSync.lobby_join(lobby_id_to_join, password)

func leave_current_lobby():
	if current_lobby_name_id != "":
		# print("ConnectionManager: Leaving lobby: ", current_lobby_name_id)
		GDSync.lobby_leave()
		if GDSync.lobby_get_player_count() < 1: # Check if you are the last one
			GDSync.lobby_close() # This might trigger _on_gdsync_lobby_closed
		emit_signal("lobby_closed")
		_reset_lobby_state()
	else:
		print("ConnectionManager: Not in a lobby to leave.")

func get_player_list() -> Dictionary:
	return connected_clients.duplicate(true)

func get_current_lobby_id() -> String:
	return current_lobby_name_id

func am_i_host() -> bool:
	return is_currently_host

func get_my_client_id() -> int:
	return local_client_id

# --- GDSync Signal Handlers (Internal) ---
func _on_gdsync_connected():
	local_client_id = GDSync.get_client_id()
	# print("ConnectionManager: Connected to multiplayer. Client ID: ", local_client_id)
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
	# print("ConnectionManager: Lobby created successfully. ID: ", lobby_id)
	current_lobby_name_id = lobby_id
	is_currently_host = true
	local_client_id = GDSync.get_client_id()
	actual_lobby_host_id = local_client_id
	emit_signal("lobby_created_successfully", lobby_id)

func _on_gdsync_lobby_creation_failed(lobby_name: String, error: int):
	push_error("ConnectionManager: Lobby creation failed for '", lobby_name, "'. Error: ", error)
	var error_message: String = "Lobby creation failed for " + lobby_name + ". "
	match (error):
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
			error_message += "A lobby with this name already exists. Joining instead."
			ConnectionManager.join_existing_lobby(lobby_name) # Attempt to join the existing lobby
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_SHORT: error_message += "Name is too short."
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_LONG: error_message += "Name is too long."
		ENUMS.LOBBY_CREATION_ERROR.PASSWORD_TOO_LONG: error_message += "Password is too long."
		ENUMS.LOBBY_CREATION_ERROR.TAGS_TOO_LARGE: error_message += "Tags exceed the 2048 byte limit."
		ENUMS.LOBBY_CREATION_ERROR.DATA_TOO_LARGE: error_message += "Data exceeds the 2048 byte limit."
		ENUMS.LOBBY_CREATION_ERROR.ON_COOLDOWN: error_message += "Please wait a few seconds before creating another lobby."
		ENUMS.LOBBY_CREATION_ERROR.LOCAL_PORT_ERROR: error_message += "Local port error. Ensure your network settings are correct."
		# ... other GDSync specific error codes ...
		_: error_message += "Unknown error (" + str(error) + ")."
	emit_signal("lobby_creation_has_failed", lobby_name, error_message)

func _on_gdsync_lobby_joined(lobby_name_id: String): # GDSync might pass client_id here too
	# print("ConnectionManager: Successfully joined lobby: ", lobby_name_id)
	current_lobby_name_id = lobby_name_id
	is_currently_host = GDSync.is_host() # Update host status
	emit_signal("joined_lobby_successfully", lobby_name_id)

func _on_gdsync_lobby_join_failed(lobby_name: String, error_code: int):
	var error_message = "Failed to join lobby: " + lobby_name + ". "
	# Show an error message to the user
	match (error_code):
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST:
			error_message += "The lobby does not exist or has been closed."
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_CLOSED:
			error_message += "The lobby is closed or no longer available."
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_FULL:
			error_message += "The lobby is full. Please try another one."
		ENUMS.LOBBY_JOIN_ERROR.INCORRECT_PASSWORD:
			error_message += "Incorrect password for the lobby."
		ENUMS.LOBBY_JOIN_ERROR.DUPLICATE_USERNAME:
			error_message += "You are already in this lobby with the same username. Please change your name."
		# ... other GDSync specific error codes ...
		_: error_message += "Unknown error (" + str(error_code) + ")."
	emit_signal("failed_to_join_lobby", lobby_name, error_message)

func _on_gdsync_client_joined(client_id: int):
	if client_id == local_client_id and is_currently_host:
		if not connected_clients.has(client_id):
			# print("ConnectionManager: Host (self) officially noted in lobby. ID: ", client_id)
			connected_clients[client_id] = {"name": "Player " + str(client_id)
			}
			emit_signal("player_list_updated", connected_clients)
			emit_signal("player_joined_lobby", client_id)
		else:
			ToastParty.show({
				"text": "Error, You are already in the lobby as host!",
				"bgcolor": Color.ROSY_BROWN,
			})
			# print("ConnectionManager: Host (self) re-announced or already present in lobby. ID: ", client_id)
		return


	if not connected_clients.has(client_id):
		print("ConnectionManager: Client joined lobby. ID: ", client_id)
		connected_clients[client_id] = {"name": "Player " + str(client_id)
		}
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

		if client_id == local_client_id:
			_reset_lobby_state()


func _on_gdsync_lobby_closed():
	print("ConnectionManager: Lobby has been closed.")
	_reset_lobby_state()
	emit_signal("lobby_closed")

func _on_gdsync_lobby_list_updated(lobbies: Array):
	print("ConnectionManager: Received lobby list update. Count: ", lobbies.size())
	discovered_lobbies = lobbies
	emit_signal("discovered_lobbies_updated", discovered_lobbies)

func _reset_lobby_state():
	current_lobby_name_id = ""
	connected_clients.clear()
	is_currently_host = false
	# Notify UI of empty list
	emit_signal("player_list_updated", connected_clients)
