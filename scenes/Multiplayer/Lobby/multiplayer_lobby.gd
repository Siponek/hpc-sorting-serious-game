extends Window

# var lobby_id: String = "" # This will now be primarily managed by ConnectionManager
var clients_ui_nodes: Dictionary = {} # To keep track of instantiated player UI elements
const player_in_lobby_scene: PackedScene = preload(ProjectFiles.Scenes.PLAYER_IN_LOBBY)
@onready var player_container: Node = $MarginContainer/VBoxContainer2/GridContainer # Ensure this path is correct
@onready var player_lobby_spawner: NodeInstantiator = $PlayerNodeInstantiator
# This function is called by multiplayer_options.gd when this scene is instantiated and shown.
# However, the lobby_id is now less critical here if ConnectionManager is the source of truth.

func _ready():
	# Connect to ConnectionManager signals
	ConnectionManager.player_joined_lobby.connect(_on_cm_player_joined)
	ConnectionManager.player_left_lobby.connect(_on_cm_player_left)
	ConnectionManager.player_list_updated.connect(_on_cm_player_list_updated)
	ConnectionManager.lobby_closed.connect(_on_cm_lobby_closed)

	# Initial population of the lobby
	# The lobby_id should be set by the scene that creates this one,
	# or this scene should fetch it from ConnectionManager.
	var current_lobby_id = ConnectionManager.get_current_lobby_id()
	if current_lobby_id.is_empty():
		push_error("MultiplayerLobby: Cannot initialize, ConnectionManager has no current lobby ID.")
		# Potentially close self or show an error
		# self.close_requested.emit()
		return
	self.set_lobby_id(current_lobby_id) # Set the lobby ID in the UI

	# Populate with existing players from ConnectionManager
	var initial_players = ConnectionManager.get_player_list()
	_update_player_list_ui(initial_players)

	if ConnectionManager.am_i_host():
		ToastParty.show({
			"text": "You are the host of this lobby! (ID: " + str(ConnectionManager.get_my_client_id()) + ")",
			"bgcolor": Color.GREEN, # ...
		})
		# Host specific UI elements can be enabled here
		# $StartGameButton.disabled = false
	else:
		ToastParty.show({
			"text": "Joined lobby: " + current_lobby_id + " (My ID: " + str(ConnectionManager.get_my_client_id()) + ")",
			"bgcolor": Color.DARK_GREEN, # ...
		})
		# $StartGameButton.disabled = true # Clients usually can't start the game

	# No direct GDSync.lobby_join or GDSync signal connections here anymore.
	# ConnectionManager handles joining when the lobby is created/joined.

func set_lobby_id(id: String) -> void:
	# lobby_id = id # Store if needed for display, but ConnectionManager.current_lobby_id is the authority
	$MarginContainer/VBoxContainer2/GridContainer/LabelLobbyID.text = "Lobby ID: " + id
	print("MultiplayerLobby: UI received lobby ID: ", id)

func _on_cm_player_joined(client_id: int):
	print("MultiplayerLobby: Player joined event from CM. ID: ", client_id)
	# This signal might be redundant if player_list_updated is comprehensive.
	# If player_list_updated always follows, you might only need to connect to that.
	# For now, let's assume we want a specific toast for a new joiner.
	var player_data = ConnectionManager.get_player_list().get(client_id, {"name": "New Player %d" % client_id})
	GDSync.call_func(ToastParty.show, [ {
		"text": player_data.get("name", "REMOTE: Player %d" % client_id) + " (" + str(client_id) + ") joined!",
		"bgcolor": Color.LIGHT_GREEN,
		"color": Color.BLACK
	}])
	ToastParty.show({
		"text": player_data.name + " (" + str(client_id) + ") joined!",
		"bgcolor": Color.LIGHT_GREEN,
		"color": Color.BLACK
	})
	# The list will be fully updated by _on_cm_player_list_updated if it's also emitted.
	# If not, you'd add the specific player UI here.
	# To avoid duplicate UI updates, it's often better to rely solely on player_list_updated.

func _on_cm_player_left(client_id: int):
	print("MultiplayerLobby: Player left event from CM. ID: ", client_id)
	# var player_data = ConnectionManager.get_player_list().get(client_id, {"name": "Player"}) # Get data before it's removed for the toast
	ToastParty.show({
		"text": "Player (" + str(client_id) + ") left.", # Ideally, get player name before they are removed from CM's list
		"bgcolor": Color.LIGHT_CORAL,
		"color": Color.BLACK
	})

func _on_cm_player_list_updated(players_map: Dictionary):
	print("MultiplayerLobby: Player list updated event from CM. Players: ", players_map.size())
	_update_player_list_ui(players_map)

func _update_player_list_ui(players_map: Dictionary):
	# Clear existing player UI elements
	for client_node in player_container.get_children():
		if client_node is PlayerInLobby:
			client_node.queue_free()
	clients_ui_nodes.clear()

	# Add/update UI elements for each player in the map
	for client_id in players_map:
		var player_data = players_map[client_id]
		# var client_ui_instance: PlayerInLobby = player_in_lobby_scene.instantiate()
		var client_ui_instance: PlayerInLobby = player_lobby_spawner.instantiate_node()
		GDSync.set_gdsync_owner(client_ui_instance, client_id) # Set GDSync owner for this instance
		# Call add_child to run _ready() and other lifecycle methods
		# player_container.add_child(client_ui_instance)
		GDSync.call_func(client_ui_instance.setup_player_display, [client_id, player_data])
		if ConnectionManager.is_currently_host:
			client_ui_instance.set_player_color(Color.AQUAMARINE) # Highlight host
		elif client_id == ConnectionManager.get_my_client_id():
			client_ui_instance.set_player_color(Color.LAWN_GREEN) # Highlight self

		clients_ui_nodes[client_id] = client_ui_instance
	
	var number_of_players: int = players_map.size()
	print("MultiplayerLobby: Number of players in UI: ", number_of_players)

func _on_cm_lobby_closed():
	print("MultiplayerLobby: Lobby closed event from CM.")
	ToastParty.show({
		"text": "The lobby has been closed.",
		"bgcolor": Color.GRAY
	})
	self.close_requested.emit() # Close this lobby window

func _on_leave_lobby_button_pressed() -> void:
	print("MultiplayerLobby: Requesting to leave lobby via ConnectionManager.")
	ConnectionManager.leave_current_lobby()
	# ConnectionManager will emit lobby_closed or player_left (for self)
	# which should trigger this window to close if appropriate.
	# No need to manually close here unless ConnectionManager doesn't handle self-leave causing lobby closure.
	# self.close_requested.emit() # This might be premature; wait for CM signals.

func _on_start_game_button_pressed() -> void:
	if ConnectionManager.am_i_host():
		print("MultiplayerLobby: Host is starting the game...")
		# 1. Tell ConnectionManager to notify other players (e.g., via a custom GDSync message or RPC)
		# ConnectionManager.broadcast_start_game_signal() 
		# 2. Transition to the game scene for all players
		# get_tree().change_scene_to_file("res://path_to_your_game_scene.tscn")
		ToastParty.show({"text": "Starting game... (Not implemented yet!)"})
	else:
		push_error("MultiplayerLobby: Client tried to press start game button!")