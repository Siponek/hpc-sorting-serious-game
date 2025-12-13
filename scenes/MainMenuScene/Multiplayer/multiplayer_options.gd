extends Window

const multiplayer_lobby_scene: PackedScene = preload(
	ProjectFiles.Scenes.MULTIPLAYER_LOBBY_SCENE
)
var lobby_id_to_join: String = "wololo"
var selected_lobby_id_from_list: String = "" # To store ID from ItemList
@onready var logger = CustomLogger.get_logger(self)
@onready
var lobby_start_name_input: LineEdit = $MarginContainer/HBoxContainer/ActionOptionsVBoxContainer/NameServerLineEdit # Get lobby name from UI
@onready
var lobby_join_id_input: LineEdit = $MarginContainer/HBoxContainer/ActionOptionsVBoxContainer/MarginContainer/VBoxContainer/CodeFieldLineEdit
@onready
var lobby_list_ui: ItemList = $MarginContainer/HBoxContainer/LobbyListVBoxContainer/MarginContainer/LobbyList
@onready
var host_game_button: Button = $MarginContainer/HBoxContainer/ActionOptionsVBoxContainer/HostGameButton
@onready
var refresh_lobbies_button: Button = $MarginContainer/HBoxContainer/LobbyListVBoxContainer/RefreshLobbiesButton
@onready
var join_game_button: Button = $MarginContainer/HBoxContainer/ActionOptionsVBoxContainer/MarginContainer/VBoxContainer/JoinGameButton


func _on_about_to_popup() -> void:
	ConnectionManager.ensure_multiplayer_started() # Ensure GDSync is active before showing the dialog


func _ready() -> void:
	# Connect signals from conection manager
	ConnectionManager.lobby_created_successfully.connect(
		_on_connection_manager_lobby_created
	)
	ConnectionManager.lobby_creation_has_failed.connect(
		_on_connection_manager_lobby_creation_failed
	)
	ConnectionManager.joined_lobby_successfully.connect(
		_on_connection_manager_joined_lobby
	)
	ConnectionManager.failed_to_join_lobby.connect(
		_on_connection_manager_failed_to_join_lobby
	)
	ConnectionManager.discovered_lobbies_updated.connect(
		_on_connection_manager_lobbies_updated
	)
	lobby_start_name_input.text_changed.connect(
		func(text: String) -> void:
			# Enable host button if lobby name is not empty
			host_game_button.disabled=text.is_empty()
	)
	lobby_join_id_input.text_changed.connect(
		func(text: String) -> void:
			join_game_button.disabled=(
				text.is_empty() and selected_lobby_id_from_list.is_empty()
			)
	)
	# Get the latest lobbies
	lobby_list_ui.clear() # Clear old list
	ConnectionManager.get_discovered_lobbies()
	join_game_button.disabled = true # Disable join button until we have a lobby ID
	lobby_start_name_input.text = lobby_id_to_join # Set default lobby name input


func _on_host_game_button_pressed() -> void:
	var lobby_name_input = lobby_start_name_input.text
	if lobby_name_input.is_empty():
		lobby_name_input = lobby_id_to_join # Fallback or default
	# ConnectionManager.ensure_multiplayer_started()
	(
		ConnectionManager
		.start_hosting_lobby(
			lobby_name_input,
			# password =
			"",
			# public =
			true,
			# player_limit =
			0,
			# tags =
			# data =
		)
	)


func _on_connection_manager_lobby_created(lobby_id: String):
	logger.log_info(
		"Lobby created successfully via ConnectionManager! ID: ", lobby_id
	)
	var lobby_scene_instance = multiplayer_lobby_scene.instantiate()
	# It's important that the lobby_scene itself knows how to get its ID
	# or that ConnectionManager provides it when the lobby scene is shown.
	# For now, we assume the lobby scene will fetch details from ConnectionManager.
	# lobby_scene_instance.set_lobby_id(lobby_id) # The lobby scene can get this from ConnectionManager.get_current_lobby_id()

	if get_parent() and get_parent().has_method("_open_instantiated_dialog"):
		get_parent().dialog_open = false # Manage this flag carefully
		get_parent()._open_instantiated_dialog(lobby_scene_instance)
		# lobby_scene_instance.show() # _open_instantiated_dialog should handle showing
	else:
		push_error(
			"MultiplayerOptions: Parent or _open_instantiated_dialog method not found."
		)
		# Fallback: just add and show if parent logic is complex
		get_parent().add_child(lobby_scene_instance)
		lobby_scene_instance.popup_centered()
	self.close_requested.emit()
	# Note: Host should NOT call join_existing_lobby - they're already in the lobby after creation


func _on_connection_manager_lobby_creation_failed(
	lobby_name: String, error_message: String
):
	# Use the error_code to display a user-friendly message
	# You can use your existing lobby_creation_failed logic here,
	# but call it with the parameters from ConnectionManager's signal.
	lobby_creation_failed(lobby_name, error_message) # Assuming this method shows a Toast or error message


func _on_join_game_button_pressed() -> void:
	var lobby_id_to_attempt_join: String = ""

	if not selected_lobby_id_from_list.is_empty():
		lobby_id_to_attempt_join = selected_lobby_id_from_list
		ToastParty.show(
			{
				"text": "Joining selected lobby: " + lobby_id_to_attempt_join,
				"bgcolor": Color.PALE_GREEN
			}
		)
	elif not lobby_join_id_input.text.is_empty():
		lobby_id_to_attempt_join = lobby_join_id_input.text
		ToastParty.show(
			{
				"text": "Joining lobby by code: " + lobby_id_to_attempt_join,
				"bgcolor": Color.PALE_TURQUOISE
			}
		)
	else:
		ToastParty.show(
			{
				"text": "Please select a lobby or enter a code to join.",
				"bgcolor": Color.ORANGE_RED
			}
		)
		return

	# ConnectionManager.ensure_multiplayer_started() # Ensure GDSync is active
	ConnectionManager.join_existing_lobby(lobby_id_to_attempt_join)


func _on_connection_manager_joined_lobby(lobby_id: String):
	logger.log_info(
		"JOINED lobby successfully via ConnectionManager! ID: ", lobby_id
	)
	var lobby_scene_instance = multiplayer_lobby_scene.instantiate()
	if get_parent() and get_parent().has_method("_open_instantiated_dialog"):
		get_parent().dialog_open = false
		get_parent()._open_instantiated_dialog(lobby_scene_instance)
	else:
		get_tree().root.add_child(lobby_scene_instance)
		lobby_scene_instance.popup_centered()

	self.close_requested.emit()


func _on_refresh_lobbies_button_pressed() -> void:
	ToastParty.show(
		{"text": "Refreshing lobby list...", "bgcolor": Color.LIGHT_BLUE}
	)
	ConnectionManager.find_lobbies()
	lobby_list_ui.clear() # Clear old list while waiting for new one
	selected_lobby_id_from_list = "" # Reset selection
	join_game_button.disabled = true # Disable join until new selection or code entry


func _on_connection_manager_lobbies_updated(lobbies: Array):
	ToastParty.show(
		{
			"text": "Lobby list updated with %d lobbies." % lobbies.size(),
			"bgcolor": Color.LIGHT_GREEN
		}
	)
	lobby_list_ui.clear()
	selected_lobby_id_from_list = "" # Reset selection
	join_game_button.disabled = true # Disable join until new selection or code entry

	if lobbies.is_empty():
		lobby_list_ui.add_item("No lobbies found.")
		lobby_list_ui.set_item_disabled(0, true)
		return

	for lobby_data in lobbies:
		# GDSync lobby_find usually returns a list of dictionaries.
		# Each dictionary contains details about a lobby.
		# Common keys might be "id", "name", "player_count", "max_players".
		# Adjust these based on what GDSync actually provides.
		var lobby_name = lobby_data.get("Name", "Unnamed Lobby")
		var player_count = lobby_data.get("PlayerCount", 0)
		var max_players = lobby_data.get("PlayerLimit", 0)

		var display_text = (
			"%s (%s/%s)"
			% [
				lobby_name,
				player_count,
				max_players if max_players > 0 else "-"
			]
		)
		var item_idx = lobby_list_ui.add_item(display_text, null, true)
		lobby_list_ui.set_item_metadata(item_idx, lobby_name) # Store the actual ID


func _on_lobby_list_item_selected(index: int):
	if lobby_list_ui.is_item_disabled(index):
		selected_lobby_id_from_list = ""
		join_game_button.disabled = true
		logger.log_info("Selected item is disabled, cannot join.")
		return

	selected_lobby_id_from_list = lobby_list_ui.get_item_metadata(index)
	lobby_join_id_input.text = "" # Clear code field if a list item is selected
	logger.log_info(
		"Selected lobby ID from list: ", selected_lobby_id_from_list
	)
	join_game_button.disabled = selected_lobby_id_from_list.is_empty()


func _on_connection_manager_failed_to_join_lobby(
	_lobby_name: String, error_message: String
):
	ToastParty.show(
		{"text": error_message, "bgcolor": Color.RED, "color": Color.WHITE}
	)
	logger.log_error(
		"Failed to join lobby via ConnectionManager: ", error_message
	)


func lobby_creation_failed(lobby_name: String, error: String):
	ToastParty.show(
		{
			"text":
			"Failed to create lobby: " + lobby_name + ". Error: " + error,
			"bgcolor": Color.DARK_RED,
			"color": Color.WHITE
		}
	)
