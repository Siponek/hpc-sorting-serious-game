extends ScrollContainer
# This is a node that will control the behaviour of the card container.
# The reason why this is a scroll container instead card container (HBoxContainer) is because
# we want to be able to scroll through the cards when there are too many cards to fit on the screen
# and we want to be able to drag and drop cards between the slots. The dynamic container cannot be used for that
# Because we need clear indication where we can drag the cards to.
const CARD_CONTINAER_PATH: String = "SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer"
@onready var card_container: HBoxContainer = get_tree().get_root().get_node(CARD_CONTINAER_PATH)


# Checking if card can be dropped
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Card
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not (data is Card):
		return

	var incoming_card: Card = data
	var source_slot: CardBuffer = incoming_card.current_slot # The slot the incoming card *was* in, if any. Null if from container.
	print_debug("Source slot is %s" % [source_slot])
	# --- Handle the incoming card ---
	# Remove incoming_card from its previous parent (could be the drag layer or a buffer slot)
	if incoming_card.get_parent() != null:
		incoming_card.get_parent().remove_child(incoming_card)

	# Calculate target index based on drop position *before* adding the child
	var card_spacing = card_container.get_theme_constant("separation", "HBoxContainer")
	var effective_card_width = Constants.CARD_WIDTH + card_spacing
	var drop_x_in_container = at_position.x + scroll_horizontal
	# Ensure division by zero doesn't happen if effective_card_width is 0
	var target_index = 0
	if effective_card_width > 0:
		target_index = int(drop_x_in_container / effective_card_width)
	# Clamp index to valid range [0, current_child_count] (where it *will* be inserted)
	target_index = clamp(target_index, 0, card_container.get_child_count())


	if source_slot != null:
		# Case: Card came FROM a buffer slot, place it back in the container at the calculated target_index
		print_debug("Card %d returning from buffer slot %s to container at index %d" % [incoming_card.value, source_slot.slot_text, target_index])
		if source_slot.occupied_by == incoming_card: # Ensure the source slot knows it's empty
			source_slot.occupied_by = null
		incoming_card.remove_from_slot() # Reset style, current_slot = null

		# Add to container first, then move to the calculated target index
		card_container.add_child(incoming_card)
		card_container.move_child(incoming_card, target_index)
		incoming_card.set_can_drag(true)
		source_slot._update_panel_visibility()
		# Update the card's original_index to its new position
		# incoming_card.original_index = target_index # Do this in the final loop

	else:
		# Case: Card came FROM the container itself (swapping within container)
		print_debug("Card %d dropped within container, targeting index %d" % [incoming_card.value, target_index])

		var source_index = incoming_card.original_index # Where the card started

		print_debug("Source Index: %d, Target Index: %d" % [source_index, target_index])

		# Add the incoming card back temporarily to handle indices correctly
		card_container.add_child(incoming_card)

		# Find the card currently at the target index (if one exists AFTER adding incoming_card back)
		var target_card: Card = null
		# Adjust target index if it's beyond the source index after adding the child back
		var adjusted_target_index = target_index
		if target_index > source_index:
			adjusted_target_index -= 1 # Account for the placeholder incoming_card added earlier

		if adjusted_target_index < card_container.get_child_count():
			var node_at_target = card_container.get_child(adjusted_target_index)
			if node_at_target is Card and node_at_target != incoming_card:
				target_card = node_at_target

		# Perform the move/swap
		if target_card != null and target_card != incoming_card:
			# We are dropping onto another card - swap them
			print_debug("Swapping card %d (at %d) with card %d (at %d)" % [incoming_card.value, source_index, target_card.value, adjusted_target_index])
			# Move incoming card to target position (use the clamped target_index)
			card_container.move_child(incoming_card, target_index)

			# Move the card that was at the target position to the source position
			# Need to account for index shift if target_index < source_index
			var final_source_index = source_index
			card_container.move_child(target_card, final_source_index)
		else:
			# Dropping into an empty space or at the end
			print_debug("Moving card %d from %d to empty space at %d" % [incoming_card.value, source_index, target_index])
			card_container.move_child(incoming_card, target_index)

		# Ensure card is draggable and looks normal
		incoming_card.remove_from_slot() # Resets style just in case
		incoming_card.set_can_drag(true)

	# Update original_index for ALL children after any move/swap to ensure correctness
	for i in card_container.get_child_count():
		var child = card_container.get_child(i)
		if child is Card:
			child.original_index = i
			# Optional: Reset visual position if needed, though HBoxContainer should handle it
			# child.position = child.container_relative_position
	print_debug("Forcing redraw/update layout")
	# Optional: Force redraw/update layout if needed
	card_container.queue_redraw()