class_name PlayerInLobby
extends Control

var client_id: int = -1 # Default ID, should be set when the player joins the lobby

@onready var player_name_label: Label = $Panel/Label
@onready var kick_button: Button = $Panel/Button


func set_player_name(_name: String) -> void:
	if not _name or _name.is_empty():
		_name = "Player " + str(client_id) # Fallback name if none provided
	if !player_name_label:
		print("PlayerInLobby: player_name_label is not found. Ensure the scene structure is correct.")
		print("Chidlren of PlayerInLobby: ", get_children(), " | PlayerNameLabel: ", $Panel.get_node_or_null("Label"))
		return
	player_name_label.text = _name

func set_client_id(id: int) -> void:
	client_id = id
	# Set the button's metadata to the client ID for later reference
	kick_button.set_meta("client_id", id)

func _on_kick_button_pressed() -> void:
	pass
	# if client_id != -1:
	# 	print("Requesting to kick player with ID: ", client_id)
	# 	# Emit a signal or call a method in ConnectionManager to kick this player
	# 	ConnectionManager.kick_player(client_id)
	# else:
	# 	print("Kick button pressed, but client ID is not set.")