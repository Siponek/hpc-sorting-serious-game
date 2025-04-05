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
			# Connect signal based on dictionary mapping
			var btn_name = btn.name
			if button_handlers.has(btn_name):
				var handler = Callable(self, button_handlers[btn_name])
				btn.pressed.connect(handler)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_StartBtn_pressed() -> void:
	var singleplayer_options_dialog = preload("res://scenes/MainMenuScene/singleplayer_options.tscn").instantiate()
	add_child(singleplayer_options_dialog)
	singleplayer_options_dialog.popup_centered()
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

func _on_button_mouse_entered(button):
	# Scale up slightly
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	
	# Add glow effect
	button.modulate = Color(1.2, 1.2, 1.2)

func _on_button_mouse_exited(button):
	# Return to normal
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	button.modulate = Color(1.0, 1.0, 1.0)

func _on_button_pressed(button):
	# Scale down slightly when pressed
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)

func _on_button_released(button):
	# Return to hover state if still hovering
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05)