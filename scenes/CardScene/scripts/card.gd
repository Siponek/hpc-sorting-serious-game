extends Control

var value: int = 0
var original_position: Vector2
var can_drag: bool = true
var is_dragging: bool = false
var current_slot = null
# I want a gradiend color for the card


signal card_grabbed(card)
signal card_dropped(card, drop_position)

func _ready():
	original_position = position


## Set the value of the card and update the label
func set_card_value(new_value: int):
	value = new_value
	$Value.text = str(value)
# Add this function to your card.gd script
func set_can_drag(value: bool):
	can_drag = value
	# Optional: Change visual appearance to indicate draggability
	if value:
		modulate.a = 1.0 # Full opacity
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate.a = 0.8 # Slightly transparent to indicate it can't be dragged
		mouse_default_cursor_shape = Control.CURSOR_ARROW
# Use the built-in _gui_input method instead of a separate handler
func _gui_input(event: InputEvent) -> void:
	pass
	if can_drag:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					print("Card grabbed: " + str(value))
					is_dragging = true
					emit_signal("card_grabbed", self)
				else:
					print("Card dropped: " + str(value))
					is_dragging = false
					emit_signal("card_dropped", self, global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Card _unhandled_input")
	elif event is InputEventMouseMotion:
		# print("Mouse motion")
		pass

func _process(_delta):
	pass
	# if is_dragging:
		# global_position = get_global_mouse_position() - size / 2

func reset_position():
	position = original_position
	# if get_parent():
    #     position = Vector2.ZERO  # Or whatever default position should be

func place_in_slot(slot):
	# Create a stylebox with gradient instead of solid color
	var new_style = StyleBoxFlat.new()
	
	# Create a gradient from top to bottom
	new_style.bg_color = Color(0.4, 0.7, 0.3) # Base color
	
	# Add a vertical gradient
	new_style.set_border_width_all(0)
	new_style.shadow_color = Color(0.2, 0.5, 0.1, 0.6) # Darker shade of the base color
	new_style.shadow_size = 8
	
	# Enable gradient
	new_style.set_corner_radius_all(5) # Round corners
	new_style.border_blend = true
	
	
	# Apply the stylebox to the panel
	$Panel.add_theme_stylebox_override("panel", new_style)
	current_slot = slot

func remove_from_slot():
	# Create a stylebox for cards not in slots
	var new_style = StyleBoxFlat.new()
	
	# Either use a different gradient or a solid color
	new_style.bg_color = Color(0.5, 0.5, 0.5) # Gray background
	
	# You could also use a subtle gradient for non-slotted cards
	new_style.set_corner_radius_all(5) # Round corners
	
	$Panel.add_theme_stylebox_override("panel", new_style)
	current_slot = null

# Returns the data to pass from an object when you click and drag away from
# this object. Also calls `set_drag_preview()` to show the mouse dragging
# something so the user knows that the operation is working.
func _get_drag_data(_at_position: Vector2) -> Variant:
	# print("Card _get_drag_data")
	if can_drag:
		# Create a preview for the drag operation
		var preview = duplicate()
		preview.modulate.a = 0.5
		preview.set_card_value(value)
		preview.set_script(null)
		set_drag_preview(preview)
		# If card is in a slot, remove it when starting to drag
		if current_slot != null:
			if current_slot.has_method("clear_slot"):
				current_slot.clear_slot()
			remove_from_slot()
			# Also notify the slot that it's now empty
		
		return self
	return null
