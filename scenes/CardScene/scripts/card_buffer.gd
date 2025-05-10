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
	return data is Card

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

# TODO unify the _drop data function in scroll_container and card_buffer
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Can only drop cards into control nodes
	if data is not Control: # or !data.has_method("set_card_value"):
		return

	var card_container_node = get_tree().get_root().get_node("SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer")
	var incoming_card: Card = data
	var source_slot: Control = incoming_card.current_slot # The slot the incoming card *was* in, if any. Null if from container.

	# --- Handle the card currently in THIS slot (if any) ---
	var old_card: Card = occupied_by # Card currently in this slot (can be null if empty)
	if old_card != null:
		# This slot is occupied. We need to move the old_card out.
		print_debug("Slot %s is occupied by card %d. Moving it out." % [slot_text, old_card.value])
		# Remove old_card from this slot's visual tree
		if old_card.get_parent() == self: # Or check against the specific Panel node if cards are added there
			self.remove_child(old_card)
		else:
			print_debug("Old card parent mismatch!") # Should ideally be a child of this slot control/panel

		occupied_by = null # This slot is now logically empty

		if source_slot != null and source_slot != self:
			# Case: Swapping between two different slots. Move old_card to the source_slot.
			print_debug("Swapping: Moving card %d from %s to %s" % [old_card.value, slot_text, source_slot.slot_text])
			# Ensure source_slot is ready to receive
			if source_slot.occupied_by == incoming_card: # Check if the source still thinks it holds the incoming card
				source_slot.occupied_by = null
			source_slot.add_child(old_card) # Add old_card to the source slot's visual tree
			old_card.place_in_slot(source_slot) # Update style and set current_slot
			source_slot.occupied_by = old_card # Update source slot's logical state
		else:
			# Case: Incoming card is from the main container (source_slot == null).
			# Send old_card back to the main container using its original position.
			print_debug("Returning card %d from %s to container at incoming index %d" % [old_card.value, slot_text, incoming_card.original_index])
			old_card.original_index = incoming_card.original_index # Update original index to the new position
			incoming_card.original_index = 0
			old_card.remove_from_slot() # Update style, set current_slot = null
			old_card.reset_position(card_container_node) # This re-adds to container at original_index and sets position
			old_card.set_can_drag(true) # Make sure it's draggable again

	# --- Handle the incoming card ---
	# Remove incoming_card from its previous parent (could be the drag layer or another slot's panel)
	if incoming_card.get_parent() != null:
		incoming_card.get_parent().remove_child(incoming_card)

	# Add incoming_card to this slot
	print_debug("Placing card %d into %s" % [incoming_card.value, slot_text])
	self.add_child(incoming_card) # Add to this slot's visual tree (assuming cards are direct children)
	occupied_by = incoming_card # Update logical state
	incoming_card.place_in_slot(self) # Update style and set current_slot

	# If the incoming card came from another slot, ensure that slot knows it's empty now
	# (This check prevents issues if the signal/logic flow is slightly off)
	if source_slot != null and source_slot != self and source_slot.occupied_by == incoming_card:
		print_debug("Clearing occupied_by for source slot %s" % source_slot.slot_text)
		source_slot.occupied_by = null

	# Emit the signal *after* all state changes are complete
	emit_signal("card_placed_in_slot", incoming_card, self)