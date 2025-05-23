extends VBoxContainer

var dialog_open = false
var singleplayer_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.SINGLEPLAYER_OPTIONS)
var multiplayer_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.MULTIPLAYER_OPTIONS)
var game_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.GAME_OPTIONS)

# Dictionary to keep track of active tweens per button.
var enter_tweens = {}
var exit_tweens = {}
const EDGE_MARGIN = 50.0 # Margin from screen edges for button movement
const MOVE_DISTANCE = 100.0
enum CircularPathState {
	# NONE,
	MOVING_RIGHT,
	# READY_TO_MOVE_UP,
	MOVING_UP,
	# READY_TO_MOVE_LEFT,
	MOVING_LEFT,
	# READY_TO_MOVE_DOWN,
	MOVING_DOWN,
	# READY_TO_LOOP_RIGHT # State before starting the loop by moving right again
}
func _ready():
	var cumulative_pivot_y_offset = 0.0 # Accumulator for the Y pivot offset
	for btn: Button in get_children():
		if btn is Button:
			# Initialize tweens for each button.
			enter_tweens[btn] = null
			exit_tweens[btn] = null
			# Connect animation signals using lambdas to capture the button.
			btn.mouse_entered.connect(func(): _on_button_mouse_entered(btn))
			btn.mouse_exited.connect(func(): _on_button_mouse_exited(btn))
			btn.button_down.connect(func(): _on_button_pressed(btn))
			btn.button_up.connect(func(): _on_button_released(btn))
			btn.gui_input.connect(func(event): _on_button_gui_input(event, btn))
			
			btn.pivot_offset = Vector2(int(btn.size.x / 2) + cumulative_pivot_y_offset + int(btn.size.y / 2), int(btn.size.y / 2))
			# Add the current button's full height to the accumulator for the next button.
			cumulative_pivot_y_offset -= btn.size.y
			btn.scale = Vector2(1, 1)
			# We need to store original position and rotation for the button but with regards to the 
			btn.set_meta("original_container_offset", btn.global_position - self.global_position)
			btn.set_meta("current_rotation", 0)
func kill_tweens_from_dict(_tween_dictionary, button):
	if _tween_dictionary.has(button) and _tween_dictionary[button]:
		_tween_dictionary[button].kill()
		_tween_dictionary[button] = null

func _open_dialog_scene(scene_resource: PackedScene) -> void:
	if dialog_open:
		print("Dialog already open, cannot open another.")
		return
		
	dialog_open = true
	var dialog_instance = scene_resource.instantiate()
	add_child(dialog_instance)
	
	# Setup window properties
	dialog_instance.close_requested.connect(func():
		dialog_instance.hide()
		dialog_instance.queue_free()
		dialog_open=false
	)
	
	# Show the window
	dialog_instance.popup_centered()

func _on_singleplayer_btn_pressed() -> void:
	_open_dialog_scene(singleplayer_options_dialog_scene)

func _on_multiplayer_btn_pressed() -> void:
	_open_dialog_scene(multiplayer_options_dialog_scene)

func _on_options_btn_pressed() -> void:
	_open_dialog_scene(game_options_dialog_scene)

func _on_exit_btn_pressed() -> void:
	# Todo add confimation screen?
	print_rich("Exiting...")
	get_tree().quit()

func _on_button_mouse_entered(button: Button):
	# Kill any running enter tween for this button
	kill_tweens_from_dict(enter_tweens, button)
	# Also kill any exit tween for this button
	kill_tweens_from_dict(exit_tweens, button)
	# Store original position if not already saved
	if not button.has_meta("original_position"):
		button.set_meta("original_position", button.position)
	if not button.has_meta("current_side"):
		button.set_meta("current_side", CircularPathState.MOVING_RIGHT)
	# Create a new tween for mouse enter effect.
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	# Scale, rotate and color change
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(button, "rotation_degrees", button.get_meta("current_rotation") + 2, 0.2)
	
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	var button_right_edge
	var distance_to_edge
	var current_side_vector_move
	var min_distance = 5.0 # Minimum distance to use when button passes an edge
    
	match button.get_meta("current_side"):
		CircularPathState.MOVING_RIGHT:
			button_right_edge = button.global_position.x + button.size.x
			distance_to_edge = screen_width - button_right_edge
			current_side_vector_move = Vector2.RIGHT
		CircularPathState.MOVING_UP:
			button_right_edge = (button.size.x * 3 / 4) - button.global_position.y
			if button_right_edge > 0:
				distance_to_edge = min_distance
			else:
				distance_to_edge = abs(button_right_edge)
			current_side_vector_move = Vector2.UP
		CircularPathState.MOVING_LEFT:
			# The button is rotated at this point
			button_right_edge = button.global_position.x - button.size.x
			distance_to_edge = button_right_edge
			current_side_vector_move = Vector2.LEFT
		CircularPathState.MOVING_DOWN:
			button_right_edge = (button.size.x * 3 / 4) - button.global_position.y
			button_right_edge = button.global_position.y + button.size.x
			if button_right_edge > screen_height:
				distance_to_edge = min_distance
			else:
				distance_to_edge = screen_height - button_right_edge
			current_side_vector_move = Vector2.DOWN
	
	
	# Mini game ;>
	if distance_to_edge >= EDGE_MARGIN:
		# Move 10 pixels right
		tween.tween_property(button, "position", current_side_vector_move * MOVE_DISTANCE, 1).as_relative().from_current().set_trans(Tween.TRANS_EXPO)
	else:
		var current_side = button.get_meta("current_side")
		var current_canonical_rotation = button.get_meta("current_rotation", 0.0)
		var next_canonical_rotation = current_canonical_rotation
		match current_side:
			CircularPathState.MOVING_RIGHT:
				next_canonical_rotation -= 90
			CircularPathState.MOVING_UP:
				next_canonical_rotation = -180
			CircularPathState.MOVING_LEFT:
				next_canonical_rotation = -270
			CircularPathState.MOVING_DOWN:
				next_canonical_rotation = -360
		# var next_canonical_rotation = fposmod(current_canonical_rotation - 90.0, 360.0)
		tween.tween_property(button, "rotation_degrees", next_canonical_rotation, 0.3)
		# Move to next side (wrap around after 3)
		button.set_meta("current_side", (current_side + 1) % 4)
		button.set_meta("current_rotation", next_canonical_rotation)

	# Add a subtle shadow if applicable.
	if button.has_method("add_theme_constant_override"):
		button.add_theme_constant_override("shadow_offset_x", 3)
		button.add_theme_constant_override("shadow_offset_y", 3)
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	
	enter_tweens[button] = tween

func _on_button_mouse_exited(button: Button):
	# Note the EASE_IN instead of EASE_OUT for natural reversal feel
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	# Same animations but with reversed timing
	tween.tween_property(button, "scale", Vector2(1, 1), 0.3)
	var current_meta_rotation = button.get_meta("current_rotation")
	if current_meta_rotation == -360:
		kill_tweens_from_dict(enter_tweens, button)
		kill_tweens_from_dict(exit_tweens, button)
		button.set_meta("current_rotation", 0)
		# Rotate the button to zero degrees instantly.
		# This line itself is an instant change. No tween is applied to rotation here.
		button.rotation_degrees = 0
	else:
		# Tween rotation back to its canonical resting state (without the +2 wobble from mouse enter)
		tween.tween_property(button, "rotation_degrees", current_meta_rotation, 0.3)

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
	kill_tweens_from_dict(enter_tweens, button)
	kill_tweens_from_dict(exit_tweens, button)
	
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
		kill_tweens_from_dict(enter_tweens, button)
		kill_tweens_from_dict(exit_tweens, button)
		# Reset position to original left position
		button.set_meta("current_side", CircularPathState.MOVING_RIGHT)
		button.set_meta("current_rotation", 0)
		var left_position = button.get_meta("original_position")
		# Create animation tween
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(button, "position", left_position, 0.3)
		tween.tween_property(button, "rotation", 0, 0.3)
		
		# Play a click sound (optional)
		# if $ClickSound: $ClickSound.play()