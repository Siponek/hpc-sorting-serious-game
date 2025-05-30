@tool
class_name PlayerInLobby
extends Panel
const player_name_label_path: NodePath = "MarginContainer/HBoxContainer/PlayerNameLabel"
const kick_button_path: NodePath = "MarginContainer/HBoxContainer/KickPlayerButton"
@export var player_name: String = "Player":
	set(value):
		player_name = value
		self.set_player_name(player_name) # Update the label text when the name is set

@export var player_color: Color = Color.WHITE:
	set(value):
		player_color = value
		self.modulate = player_color # Apply to the Panel itself

@export var player_id: int = -1 # This is likely the GDSync client_id, set by setup_player_display
# var client_id: int = -1 # Redundant if player_id serves the same purpose and is set correctly

@onready var player_name_label: Label = get_node_or_null(player_name_label_path)
@onready var kick_button: Button = get_node_or_null(kick_button_path)
var client_id: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		player_name_label.name = "PlayerNameLabel" # Ensure the label has the correct name in editor

		# Apply initial exported values if nodes are found
		
	GDSync.expose_func(setup_player_display) # Expose the setup function to GDSync
	GDSync.expose_func(set_player_name) # Expose the set player name function to GDSync
	GDSync.expose_func(set_client_id) # Expose the set client ID function to GDSync
	GDSync.expose_func(set_player_color) # Expose the set player color function to GDSync
	client_id = ConnectionManager.get_my_client_id()
	player_name_label.text = player_name
	$Panel.modulate = player_color

func set_player_name(_name: String) -> void:
	if not _name or _name.is_empty():
		_name = "Player " + str(client_id) # Fallback name if none provided
	if !player_name_label:
		push_error("PlayerInLobby: player_name_label is not found. Ensure the scene structure is correct.")
		return
	player_name_label.text = _name

func set_client_id(id: int) -> void:
	client_id = id
	# Set the button's metadata to the client ID for later reference
	kick_button.set_meta("client_id", id)

func set_player_color(color: Color) -> void:
	# Assuming you want to set the background color of the player panel
	if not $Panel:
		push_error("PlayerInLobby: Panel node not found.")
		return
	$Panel.modulate = color

func setup_player_display(id: int, data: Dictionary) -> void:
	set_client_id(id)
	set_player_name(data.get("name", "Player " + str(id)))
	if data.has("color"):
		set_player_color(data.get("color"))
	
	# Show/hide kick button based on whether this is the local player or if the current user is host
	if GDSync.is_gdsync_owner(self):
		# if client_id != ConnectionManager.get_my_client_id():
			# kick_button.visible = true
		# else:
			kick_button.visible = false

func _on_kick_player_button_pressed() -> void:
	ToastParty.show({
		"text": "Kick button pressed for player ID: " + str(client_id),
		"bgcolor": Color.RED,
		"color": Color.WHITE
	})
	# if client_id != -1:
	# 	print("Requesting to kick player with ID: ", client_id)
	# 	# Emit a signal or call a method in ConnectionManager to kick this player
	# 	ConnectionManager.kick_player(client_id)
	# else:
	# 	print("Kick button pressed, but client ID is not set.")
