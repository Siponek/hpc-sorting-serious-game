extends Window

@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var moves_label: Label = $VBoxContainer/MovesLabel
@onready var close_button: Button = $VBoxContainer/ExitToMainMenuButton
@onready var reset_game_button: Button = $VBoxContainer/ResetGameButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func set_game_stats(time_string: String, moves: int) -> void:
	"""Set the time and moves display"""
	if time_label:
		time_label.text = "Time: " + time_string
	if moves_label:
		moves_label.text = "Moves: " + str(moves)

func set_time(time_string: String) -> void:
	"""Set just the time"""
	if time_label:
		time_label.text = "Time: " + time_string

func set_moves(moves: int) -> void:
	"""Set just the moves"""
	if moves_label:
		moves_label.text = "Moves: " + str(moves)

func _on_close_button_pressed() -> void:
	"""Close the finish scene"""
	queue_free()
	SceneManager.goto_scene(ProjectFiles.Scenes.MENU_SCENE)