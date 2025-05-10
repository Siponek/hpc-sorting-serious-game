class_name Card
extends Control
const CARD_CONTINAER_PATH: String = "SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer"

var value: int = 0
var can_drag: bool = true
var is_dragging: bool = false
var current_slot = null
var container_relative_position: Vector2
var original_index: int = 0
var original_style: StyleBoxFlat

signal card_grabbed(card)
signal card_dropped(card, drop_position)

func _ready():
	container_relative_position = position
	# (Optional:) Save the card's container index
	if get_parent() != null:
		original_index = get_parent().get_child_count() - 1


## Set the value of the card and update the label
func set_card_value(new_value: int):
	value = new_value
	$Value.text = str(value)
# Add this function to your card.gd script
func set_can_drag(_value: bool):
	can_drag = _value
	# Optional: Change visual appearance to indicate draggability
	if _value:
		modulate.a = 1.0 # Full opacity
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate.a = 0.8 # Slightly transparent to indicate it can't be dragged
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _process(_delta):
	pass
	# if is_dragging:
		# global_position = get_global_mouse_position() - size / 2

# This function can be called from another script
func reset_position(_card_container_node: Node):
	# Reattach card back to the card container at its original index
	assert(_card_container_node != null, "Card container not found in the scene tree.")
	_card_container_node.add_child(self)
	# Reorder child to original index (if the container supports it)
	_card_container_node.move_child(self, original_index)
	position = container_relative_position

	$Panel.remove_theme_stylebox_override("panel") # Remove any custom style

func place_in_slot(slot):
	# TODO make this stylebox a ready resource so no initialization is needed
	# Create a stylebox with gradient instead of solid color
	var new_style = StyleBoxFlat.new()
	
	# Create a gradient from top to bottom
	new_style.bg_color = Color(0.4, 0.4, 0.4) # Base color
	
	# Add a vertical gradient
	new_style.set_border_width_all(0)
	new_style.shadow_size = 8
	
	# Enable gradient
	new_style.set_corner_radius_all(5) # Round corners
	new_style.border_blend = true
	
	
	# Apply the stylebox to the panel
	$Panel.add_theme_stylebox_override("panel", new_style)
	self.current_slot = slot

func remove_from_slot():
	original_style = $Panel.get_theme_stylebox("panel")
	# Create a stylebox for cards not in slots
	var new_style = StyleBoxFlat.new()
	
	# Either use a different gradient or a solid color
	new_style.bg_color = Color(0.5, 0.5, 0.5) # Gray background
	
	# You could also use a subtle gradient for non-slotted cards
	new_style.set_corner_radius_all(5) # Round corners
	
	$Panel.add_theme_stylebox_override("panel", new_style)
	self.current_slot = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag:
		print_debug("Card cannot be dragged")
		return null
	# print_debug("Card _get_drag_data called, current_slot: " + str(current_slot))

	set_drag_preview(create_drag_preview())
	# Save current container position data:
	if current_slot == null:
		container_relative_position = position
		original_index = get_index() # store current index in cardContainer
	# Detach card from current parent and reparent to drag layer (for example, the scene root)
	var drag_layer = get_tree().get_root()
	drag_layer.add_child(self)
	return self
	
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept any card, whether the slot is empty or already occupied
	print("Card _can_drop_data called with: " + str(data))
	return data is Card

func create_drag_preview():
	# Creates a simple preview (a copy of the card)
	var preview = self.duplicate()
	preview.set_z_index(1000) # Bring to front
	# Optional: Make preview slightly transparent
	preview.modulate = Color(1, 1, 1, 0.7)
	return preview