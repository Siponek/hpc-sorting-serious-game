class_name CardBuffer
extends VBoxContainer

@export var slot_text: String = "Slot":
	set(value):
		slot_text = value
		if has_node("Label") and is_inside_tree(): # Check if node is ready
			$Panel/CenterContainer/Label.text = value # Path to label inside Panel
@export var card_container: HBoxContainer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/CenterContainer/Label # Assuming this is the label showing slot_text
@onready var logger = CustomLogger.get_logger(self )
var occupied_by: Card = null # Explicitly type if possible
signal card_placed_in_slot(card: Card, slot: CardBuffer)
signal card_removed(card: Card, slot: CardBuffer)


func set_card_container(_node: HBoxContainer):
	assert(_node != null)
	card_container = _node

 
func _ready() -> void:
	if card_container == null:
		push_error(
			"CardBuffer: card_container was not set. This is a setup error."
		)
		get_tree().quit() # or: set_process(false); set_physics_process(false); return
		return
	# panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER # This might be okay depending on desired panel behavior
	label.text = slot_text
	_update_panel_visibility() # Set initial state


func set_occupied_by(card: Card) -> void:
	self.occupied_by = card
	_update_panel_visibility() # Update visibility based on new state


func _update_panel_visibility():
	if occupied_by != null:
		# Hide panel (and its child label) when card is present
		panel.visible = false
	else:
		# Show panel (and its child label) when slot is empty
		panel.visible = true
	# print("Panel visibility updated: %s" % [panel.visible])


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# print("Checking if data can be dropped in slot %s" % [slot_text])
	return data is Card


###? Not necessary since buffer slots are not drag targets
func _get_drag_data(_position):
	pass
	if occupied_by:
		var card_to_drag: Card = occupied_by
		self.set_occupied_by(null) # Set this slot to empty

		# The card is expected to be a child of this VBoxContainer if it's 'occupied_by' this slot.
		if card_to_drag.get_parent() == self:
			remove_child(card_to_drag) # Visually remove from this slot for dragging

		card_to_drag.set_drag_preview(card_to_drag.create_drag_preview())

		_update_panel_visibility() # Update visibility as slot is now empty
		emit_signal("card_removed", card_to_drag, self )
		return card_to_drag
	return null


# TODO unify the _drop data function in scroll_container and card_buffer
# TODO this should be managed by parent, card buffer should just send signals
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Can only drop cards into control nodes
	if data is not Card:
		return

	var incoming_card: Card = data
	var source_slot: CardBuffer = incoming_card.current_slot # The slot the incoming card *was* in, if any. Null if from container.

	# --- Handle the card currently in THIS slot (if any) ---
	var old_card: Card = occupied_by # Card currently in this slot (can be null if empty)
	if old_card != null:
		# This slot is occupied. We need to move the old_card out.
		logger.log_debug(
			(
				"Slot %s is occupied by card %d. Moving it out."
				% [slot_text, old_card.value]
			)
		)
		# Remove old_card from this slot's visual tree
		if old_card.get_parent() == self: # Or check against the specific Panel node if cards are added there
			self.remove_child(old_card)
		else:
			logger.log_debug("Old card parent mismatch!") # Should ideally be a child of this slot control/panel
		self.set_occupied_by(null) # Set this slot to empty

		if source_slot != null and source_slot != self:
			# Case: Swapping between two different slots. Move old_card to the source_slot.
			logger.log_debug(
				(
					"Swapping: Moving card %d from %s to %s"
					% [old_card.value, slot_text, source_slot.slot_text]
				)
			)
			# Ensure source_slot is ready to receive
			if source_slot.occupied_by == incoming_card: # Check if the source still thinks it holds the incoming card
				source_slot.set_occupied_by(null)
			source_slot.add_child(old_card) # Add old_card to the source slot's visual tree
			old_card.place_in_slot(source_slot) # Update style and set current_slot
			source_slot.set_occupied_by(old_card) # Set the source slot's logical state
			if source_slot.has_method("_update_panel_visibility"):
				source_slot._update_panel_visibility()
		else:
			# Case: Incoming card is from the main container (source_slot == null).
			# Send old_card back to the main container using its original position.
			(
				logger
				.log_debug(
					(
						"Returning card %d from %s to container at incoming index %d"
						% [
							old_card.value,
							slot_text,
							incoming_card.original_index
						]
					)
				)
			)
			old_card.original_index = incoming_card.original_index # Update original index to the new position
			incoming_card.original_index = 0
			old_card.remove_from_slot() # Update style, set current_slot = null
			old_card.reset_position(card_container) # This re-adds to container at original_index and sets position
			old_card.set_can_drag(true) # Make sure it's draggable again

	# --- Handle the incoming card ---
	# Remove incoming_card from its previous parent (could be the drag layer or another slot's panel)
	if incoming_card.get_parent() != null:
		incoming_card.get_parent().remove_child(incoming_card)

	# Add incoming_card to this slot
	logger.log_debug(
		"Placing card %d into %s" % [incoming_card.value, slot_text]
	)
	self.add_child(incoming_card) # Add to this slot's visual tree (assuming cards are direct children)
	self.set_occupied_by(incoming_card) # Set this slot's logical state
	incoming_card.place_in_slot(self ) # Update style and set current_slot

	# If incoming card came from another slot, ensure that slot knows it's empty
	# and updates its panel visibility if it's not the one that received old_card.
	if (
		source_slot != null
		and source_slot != self
		and source_slot.occupied_by == incoming_card
	):
		# This case might be redundant if swap logic is complete
		source_slot.set_occupied_by(null)
		if source_slot.has_method("_update_panel_visibility"):
			source_slot._update_panel_visibility()
	_update_panel_visibility() # Update this slot's panel visibility
	# Emit the signal *after* all state changes are complete
	emit_signal("card_placed_in_slot", incoming_card, self )
	DragState.currently_dragged_card = null
	DragState.card_dragged_from_main_container = false
	if old_card != null and old_card.current_slot != null:
		old_card.is_potential_swap_highlight = false
		old_card._apply_current_style()
	if incoming_card != null:
		incoming_card.is_potential_swap_highlight = false
		incoming_card._apply_current_style()
