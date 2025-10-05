extends Window

var clients_ui_nodes: Dictionary = {} # To keep track of instantiated player UI elements
const label_lobby_name_path: NodePath = "MarginContainer/VBoxContainer2/GridContainer/LabelLobbyID"
const start_game_button_path: NodePath = "MarginContainer/VBoxContainer2/HBoxContainer/StartGameButton"
@onready var player_container: Node = $MarginContainer/VBoxContainer2/VScrollBar/GridContainerPlayerInLobby # Ensure this path is correct
@onready var player_lobby_spawner: NodeInstantiator = $NodeInstantiator
@onready var options_buffer_slots_count = $MarginContainer/VBoxContainer2/HBoxContainerCardOptions/BufferSpinBox.value
@onready var options_cards_count = $MarginContainer/VBoxContainer2/HBoxContainerCardOptions/CardCountSpinBox.value
@onready var options_card_range = $MarginContainer/VBoxContainer2/HBoxContainerCardOptions/CardRangeSpinBox.value
@onready var options_container = $MarginContainer/VBoxContainer2/HBoxContainerCardOptions


func _ready():
	var start_game_button: Button = self.get_node(start_game_button_path)
	if player_lobby_spawner.scene == null:
		push_error("MultiplayerLobby: PlayerInLobby scene is not loaded in NodeInstantiator!")
		ToastParty.show({
			"text": "Error: PlayerInLobby scene is not loaded in NodeInstantiator!",
			"bgcolor": Color.RED,

		})
		return
	# Connect to ConnectionManager signals
	if ConnectionManager.am_i_host():
		ConnectionManager.player_joined_lobby.connect(_on_cm_player_joined)
		ConnectionManager.player_left_lobby.connect(_on_cm_player_left)
		ConnectionManager.player_list_updated.connect(_on_cm_player_list_updated)
		ConnectionManager.lobby_closed.connect(_on_cm_lobby_closed)


	GDSync.expose_func(self.clear_player_list_ui)
	GDSync.expose_func(self.transition_to_multiplayer_game)
	# Initial population of the lobby
	# The lobby_id should be set by the scene that creates this one,
	# or this scene should fetch it from ConnectionManager.
	var current_lobby_id = ConnectionManager.get_current_lobby_id()
	if current_lobby_id.is_empty():
		push_error("MultiplayerLobby: Cannot initialize, ConnectionManager has no current lobby ID.")
		return
	self.set_lobby_id(current_lobby_id) # Set the lobby ID in the UI
	self.clear_player_list_ui()

	if ConnectionManager.am_i_host():
		ToastParty.show({
			"text": "You are the host of this lobby! (ID: " + str(ConnectionManager.get_my_client_id()) + ")",
			"bgcolor": Color.GREEN, # ...
		})
	else:
		ToastParty.show({
			"text": "Joined lobby: " + current_lobby_id + " (My ID: " + str(ConnectionManager.get_my_client_id()) + ")",
			"bgcolor": Color.DARK_GREEN, # ...
		})
		start_game_button.visible = false
		# TODO make changes to spixboxes update on player side too
		# make every field in options_container non-editable for clients
		# we can make the clients change their settings later ;>
		for child in options_container.get_children():
			if child is SpinBox:
				child.editable = false

func set_lobby_id(id: String) -> void:
	self.get_node(label_lobby_name_path).text = "Lobby ID: " + id
	print("MultiplayerLobby: UI received lobby ID: ", id)

func clear_player_list_ui() -> void:
	# Clear the player list UI
	for client_node in player_container.get_children():
		if client_node is PlayerInLobby:
			client_node.queue_free()
	clients_ui_nodes.clear()

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

func _on_cm_player_left(client_id: int):
	print("MultiplayerLobby: Player left event from CM. ID: ", client_id)
	ToastParty.show({
		"text": "Player (" + str(client_id) + ") left.", # Ideally, get player name before they are removed from CM's list
		"bgcolor": Color.LIGHT_CORAL,
		"color": Color.BLACK
	})

func _on_cm_player_list_updated(players_map: Dictionary):
	# print("MultiplayerLobby: Player list updated event from CM. Players: ", players_map.size())
	self.clear_player_list_ui()
	GDSync.call_func(clear_player_list_ui, [])
	if ConnectionManager.am_i_host():
		update_player_list_ui(players_map)

### Clear existing player UI elements and update with new data for each player in the lobby as Host
func update_player_list_ui(players_map: Dictionary):
	var actual_host_id = ConnectionManager.get_lobby_host_id()
	for client_id: int in players_map:
		var player_data = players_map[client_id]
		var client_ui_instance: PlayerInLobby = player_lobby_spawner.instantiate_node()
		await get_tree().process_frame
		if not client_ui_instance:
			push_error("MultiplayerLobby: Failed to instantiate PlayerInLobby for client ID: " + str(client_id))
			continue
		client_ui_instance.set_client_id(client_id)
		clients_ui_nodes[client_id] = client_ui_instance
		GDSync.set_gdsync_owner(client_ui_instance, client_id)
		# TODO this is creating error somethere
		# GDSync.call_func_on(
		# 	client_id, GDSync.set_gdsync_owner, [client_ui_instance, client_id]
		# )
		# Setup locally first (for the host view)
		client_ui_instance.setup_player_display(client_id, player_data)
		client_ui_instance.determine_and_set_color(actual_host_id, client_id)
		await get_tree().process_frame
		# if client_id != actual_host_id:
		# 	print("Its me mario: " + str(client_id))
		# 	GDSync.call_func_on(client_id, print, ["Its me Mario" + str(client_id) + "! "])
		# 	GDSync.call_func_on(client_id, client_ui_instance.setup_player_display, [client_id, player_data])
		# 	GDSync.call_func_on(client_id, client_ui_instance.determine_and_set_color, [actual_host_id, client_id])
		# else:
		# 	# When I want to set the host as green on everybody screen
		# 	GDSync.call_func(client_ui_instance.setup_player_display, [client_id, player_data])
		GDSync.call_func(client_ui_instance.setup_player_display, [client_id, player_data])
		GDSync.call_func(client_ui_instance.determine_and_set_color, [actual_host_id, client_id])

		await get_tree().process_frame


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
	self.close_requested.emit()

func _on_start_game_button_pressed() -> void:
	if ConnectionManager.am_i_host():
		print("MultiplayerLobby: Host is starting the game...")

		# Show preparation message
		GDSync.call_func(ToastParty.show, [ {
			"text": "Host is starting the game...",
			"bgcolor": Color.BLUE
		}])
		GDSync.call_func(prepare_for_game_transition, [])

		# Short delay to ensure all clients see the message
		await get_tree().create_timer(1.0).timeout
		#TODO make this somehow configurable for both singleplayer and multiplayer

		print("Settings -> Buffer slots: " + str(options_buffer_slots_count))
		print("Settings -> Number of cards: " + str(options_cards_count))
		print("Settings -> Card value range: " + str(options_card_range))
		# Save these options, for example in a global (autoload) settings singleton:
		Settings.player_buffer_count = int(options_buffer_slots_count)
		Settings.cards_count = int(options_cards_count)
		Settings.card_value_range = int(options_card_range)

		# Transition all players to the multiplayer game scene
		GDSync.call_func(transition_to_multiplayer_game, [])

		# Transition ourselves
		transition_to_multiplayer_game()
	else:
		push_error("MultiplayerLobby: Client tried to press start game button!")

func prepare_for_game_transition() -> void:
	# Prepare data, show loading indicator, etc.
	ToastParty.show({"text": "Preparing game...", "bgcolor": Color.BLUE})

func transition_to_multiplayer_game():
	print("MultiplayerLobby: Transitioning to multiplayer game scene")
	# add some flag or env variable to indicate multiplayer mode
	Settings.is_multiplayer = true
	SceneManager.goto_scene(ProjectFiles.Scenes.MULTIPLAYER_GAME_SCENE)
