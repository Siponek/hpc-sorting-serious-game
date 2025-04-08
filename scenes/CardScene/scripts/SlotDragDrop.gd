extends Control
@export var slot_text: String = "Slot"
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label
var occupied_by = null
signal card_placed(card, slot)


func _on_card_placed_in_slot(card, slot):
	print("Card " + str(card.value) + " placed in slot " + slot.slot_text)
	
	# Update the occupied_by property of the slot
	slot.occupied_by = card
	
	
	# Optional: Disable the card's dragging after placement
	if card.has_method("set_can_drag"):
		card.set_can_drag(false)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept any card, whether the slot is empty or already occupied
	return data is Control and data.has_method("set_card_value")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("Slot " + slot_text + " _drop_data called with: " + str(data))
	if data is Control and data.has_method("set_card_value"):
		var incoming_card = data
		var source_slot = incoming_card.current_slot

		# If this slot already has a card, we need to swap
		if occupied_by != null:
			var current_card = occupied_by

			# Move our current card to the source slot
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

			# Update the occupied_by property of the source slot
			if source_slot != null:
				source_slot.occupied_by = current_card

		# Place the incoming card in this slot
		occupied_by = incoming_card
		incoming_card.global_position = global_position + Vector2(5, 5)
		incoming_card.place_in_slot(self)

		# Emit signal for card placement
		emit_signal("card_placed", incoming_card, self)
	
func clear_slot():
	occupied_by = null
func _ready() -> void:
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.text = slot_text