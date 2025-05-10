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

#Styling
var managed_base_style: StyleBoxFlat
var managed_hover_style: StyleBoxFlat
var managed_swap_highlight_style: StyleBoxFlat
var is_mouse_hovering: bool = false
var is_potential_swap_highlight: bool = false

signal card_grabbed(card)
signal card_dropped(card, drop_position)

@onready var panel_node: Panel = $Panel # Assuming your card's visual panel is named "Panel"

func _ready():
	container_relative_position = position
	# (Optional:) Save the card's container index
	if get_parent() != null:
		original_index = get_parent().get_child_count() - 1
	# Ensure styles are initialized
	if not managed_base_style:
		var current_theme_style = panel_node.get_theme_stylebox("panel")
		if current_theme_style is StyleBoxFlat:
			managed_base_style = current_theme_style.duplicate()
		else:
			managed_base_style = StyleBoxFlat.new()
			managed_base_style.bg_color = Color.DARK_GRAY # Default fallback
			managed_base_style.set_corner_radius_all(5)
	_generate_hover_style()
	_generate_swap_highlight_style()
	_apply_current_style()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Call this from CardManager to set the card's specific color/style
func set_base_style(new_style: StyleBoxFlat):
	managed_base_style = new_style.duplicate()
	_generate_hover_style()
	_apply_current_style() # Apply the new base style immediately

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

# This function can be called from another script
func reset_position(_card_container_node: Node):
	assert(_card_container_node != null, "Card container not found in the scene tree.")
	if get_parent() != _card_container_node: # Avoid re-adding if already there
		if get_parent():
			get_parent().remove_child(self)
		_card_container_node.add_child(self)
	
	_card_container_node.move_child(self, original_index)
	position = container_relative_position
	current_slot = null
	is_mouse_hovering = false # Reset hover state
	_apply_current_style() # Restore its managed style

func place_in_slot(slot):
	self.current_slot = slot
	is_mouse_hovering = false # Reset hover state
	_apply_current_style() # Restore its managed style when placed in a slot

func remove_from_slot():
	# Apply a generic style when removed from a slot (e.g., moved to drag preview or temporarily)
	var temp_style = StyleBoxFlat.new()
	temp_style.bg_color = Color(0.5, 0.5, 0.5, 0.7) # Semi-transparent Gray
	temp_style.set_corner_radius_all(5)
	if is_instance_valid(panel_node):
		panel_node.add_theme_stylebox_override("panel", temp_style)
	self.current_slot = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag:
		print_debug("Card cannot be dragged")
		return null
	# print_debug("Card _get_drag_data called, current_slot: " + str(current_slot))
	DragState.currently_dragged_card = self
	DragState.card_dragged_from_main_container = (current_slot == null)
	set_drag_preview(create_drag_preview())
	# Save current container position data:
	if current_slot == null: # Dragged from main container
		original_index = get_index()
		# Notify scroll_container to hide this card and store it
		var scroll_container_node = get_tree().get_root().get_node_or_null("SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer")
		if scroll_container_node != null and scroll_container_node.has_method("_prepare_card_drag_from_container"):
			scroll_container_node._prepare_card_drag_from_container(self)
		else: # Fallback if direct call isn't set up: just hide
			self.visible = false
	return self
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		is_potential_swap_highlight = false
		is_mouse_hovering = false # Reset this too
		_apply_current_style()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Card):
		return false # Can only drop cards

	if current_slot != null:
		# If this card is in a slot (CardBuffer), it means we are trying to drop onto an occupied slot.
		# The slot itself (CardBuffer) should decide if it can handle this (e.g., for a swap).
		# We assume the CardBuffer's _can_drop_data is appropriate.
		if current_slot.has_method("_can_drop_data"):
			return current_slot._can_drop_data(_at_position, data) # Delegate to CardBuffer
		else:
			return true # Fallback: if CardBuffer doesn't have the method, assume true
	else:
		# If this card is NOT in a slot (e.g., it's in the main ScrollContainer),
		# it should not be a direct drop target itself. The ScrollContainer handles drops.
		return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Propagate the drop to the current slot if it exists
	if current_slot != null:
		# If this card is in a slot (CardBuffer), and it received a drop,
		# it means another card is being dropped onto the slot this card occupies.
		# Delegate the actual drop handling to the CardBuffer.
		# The CardBuffer's _drop_data method will use 'data' as the incoming card
		# and 'self.occupied_by' (within CardBuffer's context) as the card already in the slot.
		if current_slot.has_method("_drop_data"):
			current_slot._drop_data(_at_position, data) # Delegate to CardBuffer
		else:
			print_debug("Card %s in slot %s, but slot has no _drop_data method." % [self.name, current_slot.name])
	else:
		# This should not typically happen if _can_drop_data returned false for cards not in slots.
		print_debug("Card %s _drop_data called, but card is not in a slot." % self.name)


func create_drag_preview():
	# Creates a simple preview (a copy of the card)
	var preview = self.duplicate()
	# preview.set_z_index(1000) # Bring to front
	if is_instance_valid(preview.panel_node) and managed_base_style:
		preview.panel_node.add_theme_stylebox_override("panel", managed_base_style.duplicate())
	
	# Optional: Make preview slightly transparent
	preview.modulate = Color(1, 1, 1, 0.7)
	return preview

func _generate_hover_style():
	if managed_base_style:
		managed_hover_style = managed_base_style.duplicate()
		# Example hover effect: brighten and add a border
		managed_hover_style.bg_color = managed_base_style.bg_color.lightened(0.2)
		managed_hover_style.border_width_left = 2
		managed_hover_style.border_width_top = 2
		managed_hover_style.border_width_right = 2
		managed_hover_style.border_width_bottom = 2
		managed_hover_style.border_color = Color.DIM_GRAY
	else:
		# Fallback if base style isn't set somehow
		managed_hover_style = StyleBoxFlat.new()
		managed_hover_style.bg_color = Color.LIGHT_GOLDENROD
		managed_hover_style.set_corner_radius_all(5)

func _generate_swap_highlight_style():
	if managed_base_style:
		managed_swap_highlight_style = managed_base_style.duplicate()
		managed_swap_highlight_style.border_width_left = 5
		managed_swap_highlight_style.border_width_top = 5
		managed_swap_highlight_style.border_width_right = 5
		managed_swap_highlight_style.border_width_bottom = 5
		managed_swap_highlight_style.border_color = Color.BEIGE
	else: # Fallback
		managed_swap_highlight_style = StyleBoxFlat.new()
		managed_swap_highlight_style.set_corner_radius_all(5)
		managed_swap_highlight_style.border_width_left = 3
		managed_swap_highlight_style.border_width_top = 3
		managed_swap_highlight_style.border_width_right = 3
		managed_swap_highlight_style.border_width_bottom = 3
		managed_swap_highlight_style.border_color = Color.GREEN_YELLOW
		managed_swap_highlight_style.bg_color = Color(0.8, 0.9, 0.8, 0.1) # Optional subtle bg tint

func _apply_current_style():
	if not is_instance_valid(panel_node): return

	if is_potential_swap_highlight and managed_swap_highlight_style:
		panel_node.add_theme_stylebox_override("panel", managed_swap_highlight_style)
	elif is_mouse_hovering and managed_hover_style:
		panel_node.add_theme_stylebox_override("panel", managed_hover_style)
	elif managed_base_style:
		panel_node.add_theme_stylebox_override("panel", managed_base_style)
	else:
		panel_node.remove_theme_stylebox_override("panel")


func _on_mouse_entered():
	is_mouse_hovering = true
	if DragState.currently_dragged_card != null and \
		DragState.currently_dragged_card != self:
		# Only highlight if this card is also in main container
		is_potential_swap_highlight = true
	_apply_current_style()

func _on_mouse_exited():
	is_mouse_hovering = false
	is_potential_swap_highlight = false # Always reset on exit
	_apply_current_style()