extends Control
@export var slot_text: String = "Slot"
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label
var occupied_by = null

# func _gui_input(event):
# 	if event is InputEventMouseButton:
# 		print("Slot " + slot_text + " got mouse button event: " + str(event.button_index) + " pressed: " + str(event.pressed))
# 	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
# 		print("Slot " + slot_text + " got mouse motion while dragging")

# Debug drag and drop events
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	print("Slot " + slot_text + " _can_drop_data called with: " + str(data))
	return data is Control and data.has_method("set_card_value") and occupied_by == null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("Slot " + slot_text + " _drop_data called with: " + str(data))
	if data is Control and data.has_method("set_card_value"):
		# Store reference to the card occupying this slot
		occupied_by = data
		
		# Center the card in the slot
		data.modulate.a = 1.0
		data.position = global_position - data.size / 2
		# small offest
		data.global_position = global_position + Vector2(5, 5)
		data.place_in_slot(self)
		
		print("Card with value " + str(data.value) + " placed in slot " + slot_text)
		
		# Tell the card manager to check if sorting is complete
		var card_manager = get_node("/root/SinglePlayerScene/CardManager")
		if card_manager and card_manager.has_method("check_sorting_order"):
			card_manager.check_sorting_order()
	
func clear_slot():
	occupied_by = null
func _ready() -> void:
	# Set the Control node's minimum size (this is the root node)
	# original_position = position
	# Set Z index to ensure it doesn't block slots when dragging
	# z_index = 10  # Higher value means it renders on top
	# Also set the panel's minimum size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.text = slot_text