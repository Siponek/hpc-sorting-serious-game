extends Control

@export var slot_text: String = "Slot":
	set(value):
		slot_text = value
		# Assuming you have a Label child
		if has_node("Label"): $Label.text = value

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label
var occupied_by = null
signal card_placed_in_slot(card, slot)
signal card_removed(card, slot)

func _ready() -> void:
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.text = slot_text

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept any card, whether the slot is empty or already occupied
	print("Slot " + str(slot_text) + " _can_drop_data called")
	return data is Control and data.has_method("set_card_value")

func _get_drag_data(_position):
	if occupied_by:
		var card = occupied_by
		occupied_by = null
		# Remove card visually from the slot
		remove_child(card)
		# Set preview for the card being dragged
		card.set_drag_preview(card.create_drag_preview())
		emit_signal("card_removed", card, self)
		# Return the card node itself
		return card
	return null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Can only drop cards into control nodes
	if data is not Control: # or !data.has_method("set_card_value"):
		return

	var card_container_node = get_tree().get_root().get_node("SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer")
	var incoming_card: Control = data
	var source_slot: Control = incoming_card.current_slot
	print_debug("Card is coming from: " + str(source_slot))
	if source_slot == null: # .is_in_group("cardContainer"):
		# 1) If slot is empty, place card in it
		if occupied_by == null:
			print_debug("Card is coming from cardContainer -> source_slot == null, filling empty slot")
			incoming_card.get_parent().remove_child(incoming_card)
			incoming_card.set_z_index(100) # Bring to front
			self.add_child(incoming_card)
		# Slot is not empty, we need to swap cards
		else:
			print_debug("Card is coming from cardContainer -> source_slot == null, switching cards")
			self.occupied_by.get_parent().remove_child(self.occupied_by)
			self.occupied_by.current_slot = null
			# TODO to be returned to the cardContainer in proper place that 
			card_container_node.add_child(self.occupied_by)
			incoming_card.get_parent().remove_child(incoming_card)
			self.add_child(incoming_card)

		# incoming_card.place_in_slot(self)
		# occupied_by = incoming_card
		# emit_signal("card_placed_in_slot", incoming_card, self)
		# return
	# 2) If slot already has a card, swap it back out
	elif occupied_by != null:
		var old_card = occupied_by
		# if incoming came from another slot, send old_card there
		if source_slot != null and source_slot != self:
			print_debug("Card is coming ")
			old_card.get_parent().remove_child(old_card)
			source_slot.add_child(old_card)
			old_card.place_in_slot(source_slot)
			source_slot.occupied_by = old_card
		else:
			print_debug("Card is coming from another slot, but the source_slot is null")
			# incoming came from deck → send old_card back to deck
			old_card.remove_from_slot()
			old_card.reset_position()
			incoming_card.set_z_index(1) # Bring to front
			old_card.set_can_drag(true)

	# 3) Place incoming_card in this slot
	occupied_by = incoming_card
	incoming_card.place_in_slot(self)
	# print("Card was in slot: " + str(incoming_card.current_slot))
	emit_signal("card_placed_in_slot", incoming_card, self)
	# print("Card placed in slot: " + str(incoming_card.current_slot))