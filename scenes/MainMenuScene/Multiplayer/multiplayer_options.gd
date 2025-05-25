extends Window

const multiplayer_lobby_scene: PackedScene = preload(ProjectFiles.Scenes.MULTIPLAYER_LOBBY_SCENE)
var lobby_id_to_join: String = "wololo"

func _ready() -> void:
	# Connect signals from conection manager
	ConnectionManager.lobby_created_successfully.connect(_on_connection_manager_lobby_created)
	ConnectionManager.lobby_creation_has_failed.connect(_on_connection_manager_lobby_creation_failed)
	ConnectionManager.joined_lobby_successfully.connect(_on_connection_manager_joined_lobby)
	ConnectionManager.failed_to_join_lobby.connect(_on_connection_manager_failed_to_join_lobby)
	# No longer connect directly to GDSync.lobby_created or GDSync.lobby_creation_failed here

func _on_host_game_button_pressed() -> void:
	var lobby_name_input = $MarginContainer/VBoxContainer/NameServerLineEdit.text # Get lobby name from UI
	if lobby_name_input.is_empty():
		lobby_name_input = lobby_id_to_join # Fallback or default
	ConnectionManager.ensure_multiplayer_started()
	ConnectionManager.start_hosting_lobby(
		lobby_id_to_join,
		# password = 
		"",
		# public = 
		true,
		# player_limit = 
		0,
		# tags = 
		# data = 
	)

func _on_connection_manager_lobby_created(lobby_id: String):
	print("MultiplayerOptions: Lobby created successfully via ConnectionManager! ID: ", lobby_id)
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
		push_error("MultiplayerOptions: Parent or _open_instantiated_dialog method not found.")
		# Fallback: just add and show if parent logic is complex
		get_tree().root.add_child(lobby_scene_instance)
		lobby_scene_instance.popup_centered()


	self.close_requested.emit() # Close the current window

func _on_connection_manager_lobby_creation_failed(lobby_name: String, error_code: int):
	# Use the error_code to display a user-friendly message
	# You can use your existing lobby_creation_failed logic here,
	# but call it with the parameters from ConnectionManager's signal.
	lobby_creation_failed(lobby_name, error_code) # Assuming this method shows a Toast or error message
	push_error("MultiplayerOptions: Lobby creation failed for '", lobby_name, "'. Error: ", error_code)
	# Show an error message to the user, e.g., using ToastParty
	ToastParty.show({
		"text": "Failed to create lobby: " + lobby_name + " (Error: " + str(error_code) + ")",
		"bgcolor": Color.RED,
		"color": Color.WHITE
	})


func _on_join_game_button_pressed() -> void:
	ToastParty.show({
		"text": "You are totally joining a game rn ☆*: .｡. o(≧▽≦)o .｡.:*☆", # Text (emojis can be used)
		"bgcolor": Color.KHAKI, # Background Color
		"color": Color.DARK_KHAKI, # Text Color
		"gravity": "top", # top or bottom
		"direction": "left", # left or center or right
		"text_size": 18, # [optional] Text (font) size // experimental (warning!)
		"use_font": true # [optional] Use custom ToastParty font // experimental (warning!)
	})
	var lobby_id_input = $PathToYourLobbyIDLineEdit.text # Get lobby ID from UI
	if lobby_id_input.is_empty():
		# Show error or use a default if appropriate
		ToastParty.show({"text": "Please enter a Lobby ID to join.", "bgcolor": Color.ORANGE_RED})
		return

	# ConnectionManager.ensure_multiplayer_started() # If needed
	ConnectionManager.join_existing_lobby(
		lobby_id_input
		# password = "" # Get from UI if password protected
	)
	ToastParty.show({
		"text": "Attempting to join lobby: " + lobby_id_input + "...",
		"bgcolor": Color.SKY_BLUE
	})

func _on_connection_manager_joined_lobby(lobby_id: String):
	print("MultiplayerOptions: Joined lobby successfully via ConnectionManager! ID: ", lobby_id)
	var lobby_scene_instance = multiplayer_lobby_scene.instantiate()
	# lobby_scene_instance.set_lobby_id(lobby_id) # Lobby scene can get this from ConnectionManager

	if get_parent() and get_parent().has_method("_open_instantiated_dialog"):
		get_parent().dialog_open = false
		get_parent()._open_instantiated_dialog(lobby_scene_instance)
	else:
		get_tree().root.add_child(lobby_scene_instance)
		lobby_scene_instance.popup_centered()
	
	self.close_requested.emit()

func _on_connection_manager_failed_to_join_lobby(lobby_id: String, error_code: int):
	push_error("MultiplayerOptions: Failed to join lobby '", lobby_id, "'. Error: ", error_code)
	# Show an error message to the user
	ToastParty.show({
		"text": "Failed to join lobby: " + lobby_id + " (Error: " + str(error_code) + ")",
		"bgcolor": Color.RED,
		"color": Color.WHITE
	})

# This local function can still be used for displaying errors from ConnectionManager
func lobby_creation_failed(lobby_name: String, error: int):
	# ... your existing error matching logic ...
	var error_message = "Lobby creation failed for " + lobby_name + ". "
	match (error):
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
			error_message += "A lobby with this name already exists."
		# ... other cases ...
		_:
			error_message += "Unknown error (" + str(error) + ")."
	push_error(error_message) # Log it
	# ToastParty.show(...) # Show to user (already handled in _on_connection_manager_lobby_creation_failed)
