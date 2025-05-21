@tool
extends VBoxContainer

var button_handlers = {
	"StartBtn": "_on_StartBtn_pressed",
	"MultiplayerBtn": "_on_MultiplayerBtn_pressed",
	"OptionsBtn": "_on_OptionsBtn_pressed",
	"ExitBtn": "_on_ExitBtn_pressed"
}
# Dictionary to keep track of active tweens per button.
var enter_tweens = {}
var exit_tweens = {}
var dialog_open = false
var singleplayer_options_dialog_scene: Resource = preload("res://scenes/MainMenuScene/singleplayer_options.tscn")

func _ready():
	for btn in get_children():
		if btn is Button:
			# Initialize tweens for each button.
			enter_tweens[btn] = null
			exit_tweens[btn] = null
			# Connect main pressed signal based on dictionary mapping.

			var btn_name = btn.name
			if button_handlers.has(btn_name):
				btn.pressed.connect(Callable(self, button_handlers[btn_name]))
			
			# Connect animation signals using lambdas to capture the button.
			btn.mouse_entered.connect(func(): _on_button_mouse_entered(btn))
			btn.mouse_exited.connect(func(): _on_button_mouse_exited(btn))
			btn.button_down.connect(func(): _on_button_pressed(btn))
			btn.button_up.connect(func(): _on_button_released(btn))
			btn.gui_input.connect(func(event): _on_button_gui_input(event, btn))
			
			# Configure pivot and initial transform.
			btn.pivot_offset = btn.size / 2
			btn.scale = Vector2(1, 1)

# Replace kill_button_tween with these two functions
func kill_enter_tween(button):
	if enter_tweens.has(button) and enter_tweens[button]:
		enter_tweens[button].kill()
		enter_tweens[button] = null

func kill_exit_tween(button):
	if exit_tweens.has(button) and exit_tweens[button]:
		exit_tweens[button].kill()
		exit_tweens[button] = null

func _on_singleplayer_btn_pressed() -> void:
	if dialog_open:
		return
		
	dialog_open = true
	var singleplayer_options_dialog = singleplayer_options_dialog_scene.instantiate()
	add_child(singleplayer_options_dialog)
	
	# Setup window properties
	singleplayer_options_dialog.title = "Singleplayer Options"
	singleplayer_options_dialog.close_requested.connect(func():
		singleplayer_options_dialog.hide()
		singleplayer_options_dialog.queue_free()
		dialog_open=false
	)
	
	# Show the window
	singleplayer_options_dialog.popup_centered()

func _on_MultiplayerBtn_pressed() -> void:
	print_rich("Multiplayer is not yet implemented.")

func _on_OptionsBtn_pressed() -> void:
	print_rich("Options clicked.")

func _on_ExitBtn_pressed() -> void:
	print_rich("Exiting...")
	get_tree().quit()

func _on_button_mouse_entered(button: Button):
	# Kill any running enter tween for this button
	kill_enter_tween(button)
	# Also kill any exit tween for this button
	kill_exit_tween(button)
	# Store original position if not already saved
	if not button.has_meta("original_position"):
		button.set_meta("original_position", button.position)
	
	# Create a new tween for mouse enter effect.
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	# Scale, rotate and color change
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(button, "rotation_degrees", 2, 0.2)
	
	var screen_width = get_viewport_rect().size.x
	var button_right_edge = button.global_position.x + button.size.x
	var distance_to_edge = screen_width - button_right_edge

	# Mini game ;>
	if distance_to_edge > 10:
		# Move 10 pixels right
		tween.tween_property(button, "position", Vector2.RIGHT * 20, 1).as_relative().from_current().set_trans(Tween.TRANS_EXPO)

	# Add a subtle shadow if applicable.
	if button.has_method("add_theme_constant_override"):
		button.add_theme_constant_override("shadow_offset_x", 3)
		button.add_theme_constant_override("shadow_offset_y", 3)
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	
	enter_tweens[button] = tween

func _on_button_mouse_exited(button: Button):
	# kill_enter_tween(button)
	# Note the EASE_IN instead of EASE_OUT for natural reversal feel
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	# Same animations but with reversed timing
	tween.tween_property(button, "scale", Vector2(1, 1), 0.3)
	tween.tween_property(button, "rotation_degrees", 0, 0.3)
	

	exit_tweens[button] = tween

func _on_button_pressed(button: Button):
	# Create a tween for the button press effect.
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(button, "modulate", Color(0.9, 0.9, 0.9, 1.0), 0.1)
	
	
	# Add a brief flash effect.
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = button.size
	flash.position = Vector2.ZERO
	button.add_child(flash)
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)
	

func _on_button_released(button: Button):
	# Kill any existing tweens to avoid conflicts
	kill_enter_tween(button)
	kill_exit_tween(button)
	
	# Create a tween for the button release effect
	var tween = create_tween()
	
	# First step: Bounce out with elastic motion (larger than normal)
	tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	# Second step: Return to normal size with a slight delay
	tween.chain()
	tween.tween_interval(0.1) # Small delay for visual effect
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Optional: Restore normal color if you had changed it
	tween.parallel().tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func _on_button_gui_input(event: InputEvent, button: Button):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		kill_enter_tween(button)
		kill_exit_tween(button)
		# Reset position to original left position
		var left_position = Vector2(0, button.position.y)
			
		# Create animation tween
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(button, "position", left_position, 0.3)
		
		# Play a click sound (optional)
		# if $ClickSound: $ClickSound.play()
