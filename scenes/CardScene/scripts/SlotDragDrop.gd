extends Control
@export var slot_text: String = "Slot"
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label
var occupied_by = null
signal card_placed(card, slot)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept any card, whether the slot is empty or already occupied
	return data is Control and data.has_method("set_card_value")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# print_debug("Slot " + slot_text + " _drop_data called with: " + str(data))
	if data is Control and data.has_method("set_card_value"):
		var incoming_card = data
		var source_slot = incoming_card.current_slot

		# If this slot already has a card, we need to swap
		if occupied_by != null:
			var current_card = occupied_by

			# Move our current card to the source slot
			if source_slot != null:
				# TODO make a system that will detach the nodes and connect them to other nodes
				# Current one only moves them with the global position
				# Move our current card to the source slot
				current_card.global_position = source_slot.global_position + Vector2(5, 5)
				current_card.place_in_slot(source_slot)
				current_card.z_index = source_slot.z_index + 100
				source_slot.occupied_by = current_card
			else:
				# If the incoming card wasn't in a slot, just release our card
				current_card.remove_from_slot()
				current_card.reset_position()
				current_card.set_can_drag(true)

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