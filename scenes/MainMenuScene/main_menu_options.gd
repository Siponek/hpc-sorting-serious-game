extends VBoxContainer

var dialog_open := false

var singleplayer_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.SINGLEPLAYER_OPTIONS)
var multiplayer_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.MULTIPLAYER_OPTIONS)
var game_options_dialog_scene: PackedScene = preload(ProjectFiles.Scenes.GAME_OPTIONS)

@export var var_tree_node: VarTree

var enter_tweens: Dictionary = {}
var exit_tweens: Dictionary = {}

const EDGE_MARGIN := 50.0
# const MOVE_DISTANCE := 15.0
const MOVE_DISTANCE := 45.0
const MIN_DISTANCE := 5.0

# Meta keys (avoid string typos everywhere)
const META_ORIGINAL_POSITION := "original_position"
const META_CURRENT_SIDE := "current_side"
const META_CURRENT_ROTATION := "current_rotation"
const META_ORIGINAL_CONTAINER_OFFSET := "original_container_offset"

enum CircularPathState {
	MOVING_RIGHT,
	MOVING_UP,
	MOVING_LEFT,
	MOVING_DOWN,
}

@onready var logger := CustomLogger.get_logger(self)


class ButtonMoveInfo:
	var distance_to_edge: float
	var move_dir: Vector2


func _ready() -> void:
	VarTreeHandler.handle_var_tree(var_tree_node, _setup_var_tree)
	var button_number: int = 0
	for child in get_children():
		if child is Button:
			var btn: Button = child
			_init_button(btn, button_number)
			button_number += 1

func _init_button(btn: Button, number: int) -> void:
	enter_tweens[btn] = null
	exit_tweens[btn] = null

	_connect_button_signals(btn)
	btn.scale = Vector2.ONE
	btn.set_meta(META_ORIGINAL_CONTAINER_OFFSET, btn.global_position - self.global_position)
	btn.set_meta(META_CURRENT_ROTATION, 0)
	btn.set_meta("button_number", number) # For debugging purposes

func _connect_button_signals(btn: Button) -> void:
	btn.mouse_entered.connect(func(): _on_button_mouse_entered(btn))
	btn.mouse_exited.connect(func(): _on_button_mouse_exited(btn))
	btn.button_down.connect(func(): _on_button_pressed(btn))
	btn.button_up.connect(func(): _on_button_released(btn))
	btn.gui_input.connect(func(event): _on_button_gui_input(event, btn))


func _kill_tween(dict: Dictionary, button: Button) -> void:
	if dict.has(button) and dict[button]:
		dict[button].kill()
		dict[button] = null

func _open_instantiated_dialog(dialog_instance: Window) -> void:
	if dialog_open:
		print("Dialog already open, cannot open another.")
		return

	dialog_open = true
	add_child(dialog_instance)

	# Setup window properties
	dialog_instance.close_requested.connect(func():
		dialog_instance.hide()
		dialog_instance.queue_free()
		dialog_open = false
	)

	# Show the window
	dialog_instance.popup_centered()

func _on_singleplayer_btn_pressed() -> void:
	_open_instantiated_dialog(singleplayer_options_dialog_scene.instantiate())

func _on_multiplayer_btn_pressed() -> void:
	_open_instantiated_dialog(multiplayer_options_dialog_scene.instantiate())

func _on_options_btn_pressed() -> void:
	_open_instantiated_dialog(game_options_dialog_scene.instantiate())

func _on_exit_btn_pressed() -> void:
	# Todo add confimation screen?
	logger.log_info("Exiting...")
	get_tree().quit()

func _ensure_hover_meta(button: Button) -> void:
	if not button.has_meta(META_ORIGINAL_POSITION):
		button.set_meta(META_ORIGINAL_POSITION, button.position)
	if not button.has_meta(META_CURRENT_SIDE):
		button.set_meta(META_CURRENT_SIDE, CircularPathState.MOVING_RIGHT)
	if not button.has_meta(META_CURRENT_ROTATION):
		button.set_meta(META_CURRENT_ROTATION, 0.0)

func _on_button_mouse_entered(button: Button) -> void:
	_kill_tween(enter_tweens, button)
	_kill_tween(exit_tweens, button)
	_ensure_hover_meta(button)

	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(button, "rotation_degrees", float(button.get_meta(META_CURRENT_ROTATION)) + 2.0, 0.2)

	var side: int = int(button.get_meta(META_CURRENT_SIDE))
	var move_info := _compute_distance_to_edge_and_move_dir(button, side, get_viewport_rect().size)
	var distance_to_turn := _compute_distance_to_turn(button, side)

	if _should_corner_turn(side, move_info.distance_to_edge, distance_to_turn, button):
		_apply_corner_turn(button, tween)
	else:
		_apply_move_tween(button, tween, move_info.move_dir)

	_apply_button_shadow(button)
	enter_tweens[button] = tween

func _compute_distance_to_turn(button: Button, side: int) -> float:
	var number_of_debug: int = button.get_meta("button_number")
	var distance := EDGE_MARGIN + (number_of_debug * button.size.y)
	if side in [CircularPathState.MOVING_UP, CircularPathState.MOVING_DOWN]:
		distance /= 4.0
	return distance

func _apply_move_tween(button: Button, tween: Tween, move_dir: Vector2) -> void:
	tween.tween_property(button, "position", move_dir * MOVE_DISTANCE, 1.0) \
		.as_relative().from_current().set_trans(Tween.TRANS_EXPO)

func _should_corner_turn(side: int, distance_to_edge: float, distance_to_turn: float, button: Button) -> bool:
	if side == CircularPathState.MOVING_LEFT:
		return distance_to_edge <= -button.size.x * 3 / 4
	return distance_to_edge < distance_to_turn

func _compute_distance_to_edge_and_move_dir(button: Button, side: int, screen_size: Vector2) -> ButtonMoveInfo:
	var screen_width: float = screen_size.x
	var screen_height: float = screen_size.y

	var button_right_edge = 0.0
	var distance_to_edge = 0.0
	var move_dir := Vector2.ZERO

	match side:
		CircularPathState.MOVING_RIGHT:
			button_right_edge = button.global_position.x + button.size.x
			distance_to_edge = screen_width - button_right_edge
			move_dir = Vector2.RIGHT

		CircularPathState.MOVING_UP:
			button_right_edge = (button.size.x * 3.0 / 4.0) - button.global_position.y
			if button_right_edge > 0:
				distance_to_edge = MIN_DISTANCE
			else:
				distance_to_edge = abs(button_right_edge)
			move_dir = Vector2.UP

		CircularPathState.MOVING_LEFT:
			button_right_edge = button.global_position.x - button.size.x
			distance_to_edge = button_right_edge
			move_dir = Vector2.LEFT

		CircularPathState.MOVING_DOWN:
			button_right_edge = (button.size.x * 3.0 / 4.0) - button.global_position.y
			button_right_edge = button.global_position.y + button.size.x
			if button_right_edge > screen_height:
				distance_to_edge = MIN_DISTANCE
			else:
				distance_to_edge = screen_height - button_right_edge
			move_dir = Vector2.DOWN

	var info = ButtonMoveInfo.new()
	info.distance_to_edge = distance_to_edge
	info.move_dir = move_dir
	return info

func _apply_corner_turn(button: Button, tween: Tween) -> void:
	var current_side: int = int(button.get_meta(META_CURRENT_SIDE))
	var current_canonical_rotation: float = float(button.get_meta(META_CURRENT_ROTATION, 0.0))
	var next_canonical_rotation: float = current_canonical_rotation

	# Same corner-rotation behavior you had
	match current_side:
		CircularPathState.MOVING_RIGHT:
			next_canonical_rotation = -90.0
		CircularPathState.MOVING_UP:
			next_canonical_rotation = -180.0
		CircularPathState.MOVING_LEFT:
			next_canonical_rotation = -270.0
		CircularPathState.MOVING_DOWN:
			next_canonical_rotation = -360.0

	tween.tween_property(button, "rotation_degrees", next_canonical_rotation, 0.3)

	# Same side increment logic
	button.set_meta(META_CURRENT_SIDE, (current_side + 1) % 4)
	button.set_meta(META_CURRENT_ROTATION, next_canonical_rotation)


func _apply_button_shadow(button: Button) -> void:
	if button.has_method("add_theme_constant_override"):
		button.add_theme_constant_override("shadow_offset_x", 3)
		button.add_theme_constant_override("shadow_offset_y", 3)
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))

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

func kill_tweens_from_dict(_tween_dictionary, button):
	if _tween_dictionary.has(button) and _tween_dictionary[button]:
		_tween_dictionary[button].kill()
		_tween_dictionary[button] = null

func _setup_var_tree(var_tree: VarTree) -> void:
	var_tree.visible = true
	var_tree.mount_var(self, "Debug ID", {
		"font_color": Color.WHITE_SMOKE,
		"format_callback": func(_value: Variant) -> String:
			return str(Constants.arguments.get("game_debug_id", "N/A"))
	})
	var_tree.mount_var(self, "clientID", {
		"font_color": Color.WHITE_SMOKE,
		"format_callback": func(_value: Variant) -> String:
			return str(ConnectionManager.get_my_client_id())
	})
	var_tree.mount_var(self, "IAmHost", {
		"font_color": Color.SEASHELL,
		"format_callback": func(_value: Variant) -> String:
			return str(ConnectionManager.am_i_host())
	})
	var_tree.mount_var(self, "currentLobbyID", {
		"font_color": Color.SEASHELL,
		"format_callback": func(_value: Variant) -> String:
			return str(ConnectionManager.get_current_lobby_id())
	})
	var_tree.mount_var(self, "Players count", {
		"font_color": Color.SEASHELL,
		"format_callback": func(_value: Variant) -> String:
			return str(ConnectionManager.get_player_list().size())
	})
	var_tree.mount_var(self, "IDs", {
		"font_color": Color.SEASHELL,
		"format_callback": func(_value: Variant) -> String:
			return str(ConnectionManager.get_player_list().get_client_ids())
	})
