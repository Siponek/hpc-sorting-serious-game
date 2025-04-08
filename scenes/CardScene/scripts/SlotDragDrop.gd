extends Control
@export var slot_text: String = "Slot"
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label
var occupied_by = null
signal card_placed(card, slot)
# func _gui_input(event):
# 	if event is InputEventMouseButton:
# 		print("Slot " + slot_text + " got mouse button event: " + str(event.button_index) + " pressed: " + str(event.pressed))
# 	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
# 		print("Slot " + slot_text + " got mouse motion while dragging")
func _on_card_placed_in_slot(card, slot):
	print("Card " + str(card.value) + " placed in slot " + slot.slot_text)
	
	# Update the occupied_by property of the slot
	slot.occupied_by = card
	
	# Check if all slots are filled and sorted properly
	# check_buffer_sort_order()
	
	# Optional: Disable the card's dragging after placement
	if card.has_method("set_can_drag"):
		card.set_can_drag(false)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept any card, whether the slot is empty or already occupied
	return data is Control and data.has_method("set_card_value")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("Slot " + slot_text + " _drop_data called with: " + str(data))
	if data is Control and data.has_method("set_card_value"):
		var source_slot = data.current_slot
		
		# If this slot already has a card, we need to swap
		if occupied_by != null:
			var current_card = occupied_by
			
			# If the incoming card was in a slot, move our card there
			if source_slot != null:
				# Move our current card to the source slot
				current_card.global_position = source_slot.global_position + Vector2(5, 5)
				current_card.place_in_slot(source_slot)
				source_slot.occupied_by = current_card
			else:
				# If the incoming card wasn't in a slot, just release our card
				current_card.remove_from_slot()
				current_card.reset_position()
				current_card.set_can_drag(true)
			
		# Place the incoming card in this slot
		occupied_by = data
		data.global_position = global_position + Vector2(5, 5)
		data.place_in_slot(self)
		
		# Emit signal for card placement
		emit_signal("card_placed", data, self)
	
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