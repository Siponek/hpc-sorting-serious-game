extends CanvasLayer

# Signal emitted when window is closed
signal window_closed

@onready var window: Window = $FinishGameWindow
@onready var title_label: Label = $FinishGameWindow/VBoxContainer/TitleLabel
@onready var time_label: Label = $FinishGameWindow/VBoxContainer/TimeLabel
@onready var moves_label: Label = $FinishGameWindow/VBoxContainer/MovesLabel
@onready var reset_button: Button = $FinishGameWindow/VBoxContainer/ResetGameButton
@onready var exit_button: Button = $FinishGameWindow/VBoxContainer/ExitToMainMenuButton
@onready var confetti_particles: GPUParticles2D = $ConfettiParticles
@onready var logger := CustomLogger.get_logger(self)

var finishing_player_id: int = -1

func _ready():
	# Connect button signals
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)

	# Trigger confetti
	if confetti_particles:
		confetti_particles.emitting = true
		confetti_particles.restart()

	# Connect window close requested signal
	if window:
		window.close_requested.connect(_on_close_requested)
		# Show the window
		window.popup_centered()

func set_game_stats(time_string: String, moves: int, player_id: int = -1) -> void:
	"""Primary method to set both time and moves stats"""
	finishing_player_id = player_id

	if time_label:
		time_label.text = "Time: " + time_string
	else:
		logger.log_warning("time_label is null")

	if moves_label:
		moves_label.text = "Moves: " + str(moves)
	else:
		logger.log_warning("moves_label is null")

	# Update title based on who finished
	_update_title_for_player(player_id)

func set_time(time_string: String) -> void:
	"""Fallback method to set only time"""
	if time_label:
		time_label.text = "Time: " + time_string

func set_moves(moves: int) -> void:
	"""Fallback method to set only moves"""
	if moves_label:
		moves_label.text = "Moves: " + str(moves)

func _update_title_for_player(player_id: int) -> void:
	"""Update title based on who finished the game"""
	if not title_label:
		return

	if not Settings.is_multiplayer or player_id < 0:
		# Singleplayer or no specific player
		title_label.text = "Congratulations!\nWhat a success!"
		return

	title_label.text = "Game Finished!
	Player " + str(player_id) + "\n" + "clicked finish game!\nCongratulations!"

func _on_reset_button_pressed() -> void:
	"""Reset the game"""
	logger.log_info("Reset button pressed")

	# Emit signal before closing
	window_closed.emit()

	# Find the card manager in the scene tree
	var card_manager = _find_card_manager()

	if card_manager and card_manager.has_method("_on_restart_game_button_pressed"):
		card_manager._on_restart_game_button_pressed()
		logger.log_info("Game reset triggered")
	else:
		logger.log_error("Could not find card_manager or restart method")

	# Close the finish window
	queue_free()

func _on_exit_button_pressed() -> void:
	"""Exit to main menu"""
	logger.log_info("Exit to main menu pressed")

	# Emit signal before closing
	window_closed.emit()

	# If multiplayer, handle cleanup
	if Settings.is_multiplayer:
		ConnectionManager.leave_current_lobby()
	# Navigate to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenuScene/menu_scene.tscn")

	# Close the finish window
	queue_free()

func _on_close_requested() -> void:
	"""Handle window close button"""
	# Emit signal before closing
	window_closed.emit()
	queue_free()

func _find_card_manager() -> Node:
	"""Find the card_manager in the scene tree"""
	# The card manager should be in the main game scene
	# Try common paths
	var root = get_tree().root

	# Search for nodes with card_manager in their script
	for child in root.get_children():
		var card_manager = _search_for_card_manager(child)
		if card_manager:
			return card_manager

	return null

func _search_for_card_manager(node: Node) -> Node:
	"""Recursively search for card_manager node"""
	# Check if this node has the card manager script or methods we need
	if node.has_method("_on_restart_game_button_pressed") and node.has_method("check_sorting_order"):
		return node

	# Search children
	for child in node.get_children():
		var result = _search_for_card_manager(child)
		if result:
			return result

	return null
