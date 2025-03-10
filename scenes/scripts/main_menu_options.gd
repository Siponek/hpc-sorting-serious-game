extends VBoxContainer


var button_handlers = {
	"StartBtn": "_on_StartBtn_pressed",
	"MultiplayerBtn": "_on_MultiplayerBtn_pressed",
	"OptionsBtn": "_on_OptionsBtn_pressed",
	"ExitBtn": "_on_ExitBtn_pressed"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	for btn in get_children():
		if btn is Button:
			# Set consistent button size
			btn.custom_minimum_size = Vector2(
				Constants.BUTTON_WIDTH, Constants.BUTTON_HEIGHT
			)
			
			# Connect signal based on dictionary mapping
			var btn_name = btn.name
			if button_handlers.has(btn_name):
				var handler = Callable(self, button_handlers[btn_name])
				btn.pressed.connect(handler)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_StartBtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/singleplayer-scene.tscn")

func _on_MultiplayerBtn_pressed() -> void:
	# Add your multiplayer handling code here
	print_rich("Multiplayer is not yet implemented.")
	pass

func _on_OptionsBtn_pressed() -> void:
	# Add your options menu handling code here
	print_rich("Options clicked.")
	pass

func _on_ExitBtn_pressed() -> void:
	print_rich("Exiting...")
	get_tree().quit()