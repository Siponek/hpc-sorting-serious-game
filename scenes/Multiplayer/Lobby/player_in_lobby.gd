@tool
class_name PlayerInLobby
extends Panel
const player_name_label_path: NodePath = "MarginContainer/HBoxContainer/PlayerNameLabel"
const kick_button_path: NodePath = "MarginContainer/HBoxContainer/KickPlayerButton"
# Root node properties that will sync automatically
@export var display_name: String = "Player":
	set(value):
		display_name = value
		if player_name_label:
			player_name_label.text = value

@export var display_color: Color = Color.WHITE:
	set(value):
		display_color = value
		self.modulate = value

@export var display_client_id: int = -1:
	set(value):
		display_client_id = value
		client_id = value
		if kick_button:
			kick_button.set_meta("client_id", value)
@onready var player_name_label: Label = get_node_or_null(player_name_label_path)
@onready var kick_button: Button = get_node_or_null(kick_button_path)
@onready var logger = Logger.get_logger(self)
var client_id: int = -1


func _ready() -> void:
	if Engine.is_editor_hint():
		player_name_label.name = "PlayerNameLabel"  # Ensure the label has the correct name in editor

	# unsafe :D
	# GDSync.expose_func(self.setup_player_display)
	# GDSync.expose_func(self.set_player_name)
	# GDSync.expose_func(self.set_client_id)
	# GDSync.expose_func(self.set_player_color)
	client_id = ConnectionManager.get_my_client_id()


# func _multiplayer_ready():
# 	logger.log_info("Multiplayer ready for client ID: ", client_id)


func setup_player_display(id: int, data: Dictionary) -> void:
	logger.log_info(
		"Setting up player display for ID: ", id, " with data: ", data
	)
	# Set root node properties - these will sync automatically
	self.set_client_id(id)
	self.set_player_name(data.get("name", "Player " + str(id)))
	if data.has("color"):
		self.display_color = data.get("color")
	if GDSync.is_gdsync_owner(self) or data.get("is_host", false):
		kick_button.visible = false
	else:
		kick_button.visible = true


func set_player_name(_name: String) -> void:
	if not _name or _name.is_empty():
		_name = "Player " + str(client_id)  # Fallback name if none provided
	if !player_name_label:
		push_error(
			"PlayerInLobby: player_name_label is not found. Ensure the scene structure is correct."
		)
		return
	self.display_name = _name


func set_client_id(id: int) -> void:
	self.display_client_id = id
	# Set the button's metadata to the client ID for later reference
	kick_button.set_meta("client_id", id)


func set_player_color(color: Color) -> void:
	self.display_color = color


func print_please():
	logger.log_info(
		"Please call me with a client ID to set up the player display."
	)
	print("Current client ID: ", client_id)


func determine_and_set_color(
	actual_host_id: int, remote_client_id: int
) -> void:
	var color: Color = Color.WHITE
	if remote_client_id == actual_host_id:
		color = Color.AQUAMARINE  # Host color
	elif GDSync.is_gdsync_owner(self):
		color = Color.LAWN_GREEN  # My own color
	else:
		color = Color.GRAY  # Default color for other players
	set_player_color(color)


func _on_kick_player_button_pressed() -> void:
	ToastParty.show(
		{
			"text": "Kick button pressed for player ID: " + str(client_id),
			"bgcolor": Color.RED,
			"color": Color.WHITE
		}
	)
