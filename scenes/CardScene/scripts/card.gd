extends Control

var value: int = 0
var original_position: Vector2
var can_drag: bool = true
var is_dragging: bool = false
var current_slot = null

signal card_grabbed(card)
signal card_dropped(card, drop_position)

func _ready():
	original_position = position


## Set the value of the card and update the label
func set_card_value(new_value: int):
	value = new_value
	$Value.text = str(value)

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

func place_in_slot(slot):
	var new_style = StyleBoxFlat.new()
	
	# Set the color (you can adjust this to the color you want)
	new_style.bg_color = Color(0.4, 0.7, 0.3) # A green color to indicate "placed"
	$Panel.add_theme_stylebox_override("panel", new_style)
	current_slot = slot

func remove_from_slot():
	var new_style = StyleBoxFlat.new()
	
	# Set the color (you can adjust this to the color you want)
	new_style.bg_color = Color(0.5, 0.5, 0.5) # A green color to indicate "placed"
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
