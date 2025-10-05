extends ScrollContainer
# This is a node that will control the behaviour of the card container.
# The reason why this is a scroll container instead card container (HBoxContainer) is because
# we want to be able to scroll through the cards when there are too many cards to fit on the screen
# and we want to be able to drag and drop cards between the slots. The dynamic container cannot be used for that
# Because we need clear indication where we can drag the cards to.
var CARD_CONTAINER_PATH: String

const DROP_PLACEHOLDER_SCENE: PackedScene = preload("res://scenes/CardScene/DropIndicator.tscn")
var current_drop_placeholder: Control = null
### Tracks if a card is being dragged over this container
var is_dragging_card_over_self: bool = false
### Stores the actual card node if dragged from this container
var dragged_card_from_container_node: Card = null

signal card_dropped_card_container()
var card_container: HBoxContainer

func _ready():
	#TODO make this somehow detached so multiplayer doesnt have to pick this way, or al least single source of truth
	if Settings.is_multiplayer:
		CARD_CONTAINER_PATH = "MultiPlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer"
	else:
		CARD_CONTAINER_PATH = "SinglePlayerScene/VBoxContainer/CardPanel/ScrollContainer/MarginContainer/CardContainer"
	if DROP_PLACEHOLDER_SCENE:
		current_drop_placeholder = DROP_PLACEHOLDER_SCENE.instantiate()
		# Keep it out of the tree initially, or add and hide:
		# add_child(current_drop_placeholder) # Optional: add to scroll container itself, not card_container
		current_drop_placeholder.visible = false
	card_container = get_tree().get_root().get_node(CARD_CONTAINER_PATH)
	if card_container == null:
		push_error("ScrollContainer: Card container not found at path: " + CARD_CONTAINER_PATH)
		return

### Checking if card can be dropped
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Card

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not (data is Card):
		return

	var incoming_card_data: Card = data # This is the data from _get_drag_data, which is the card itself
	var card_to_place: Card = null
	var final_insert_index: int = -1
	# --- Handle the incoming card ---
	# Determine which card node to actually place
	if dragged_card_from_container_node != null and incoming_card_data == dragged_card_from_container_node:
		# This means the card originated from this container and was hidden
		card_to_place = dragged_card_from_container_node
		card_to_place.visible = true # Make it visible again
	else:
		# Card came from a buffer slot or another source
		card_to_place = incoming_card_data


	# Remove incoming_card_data from its previous parent if it's still in one (e.g. buffer slot)
	if card_to_place.get_parent() != null:
		card_to_place.get_parent().remove_child(card_to_place)

	var source_slot: CardBuffer = card_to_place.current_slot # Get current_slot before clearing it

	# --- Determine insertion index ---
	if is_dragging_card_over_self and current_drop_placeholder != null and current_drop_placeholder.is_inside_tree() and current_drop_placeholder.visible:
		final_insert_index = current_drop_placeholder.get_index()
		current_drop_placeholder.get_parent().remove_child(current_drop_placeholder) # Remove placeholder
	else:
		# Fallback: Calculate target index based on drop position (e.g., if placeholder wasn't active or card from buffer)
		var card_spacing = card_container.get_theme_constant("separation", "HBoxContainer")
		var effective_card_width = Constants.CARD_WIDTH + card_spacing
		var drop_x_in_container = at_position.x + scroll_horizontal
		if effective_card_width > 0:
			final_insert_index = int((drop_x_in_container + effective_card_width / 2.0) / effective_card_width)
		else:
			final_insert_index = 0

		var num_actual_cards_at_drop = 0
		for i in card_container.get_child_count():
			if card_container.get_child(i) is Card:
				num_actual_cards_at_drop += 1
		final_insert_index = clamp(final_insert_index, 0, num_actual_cards_at_drop)

	# --- Handle card placement/swapping ---
	if source_slot != null: # Card came FROM a buffer slot
		print_debug("Card %d returning from buffer slot %s to container at index %d" % [card_to_place.value, source_slot.slot_text, final_insert_index])
		if source_slot.occupied_by == card_to_place:
			source_slot.occupied_by = null # CardBuffer will call _update_panel_visibility
			source_slot._update_panel_visibility() # Explicitly call if not handled by setter
		card_to_place.remove_from_slot() # Resets style, current_slot = null

		card_container.add_child(card_to_place)
		card_container.move_child(card_to_place, final_insert_index)
		card_to_place.set_can_drag(true)
	else: # Card came FROM the container itself (swapping or reordering)
		print_debug("Card %d dropped within container, targeting index %d" % [card_to_place.value, final_insert_index])
		var source_index = card_to_place.original_index # Where the card started (if not hidden) or where it was if hidden

		# If card_to_place was the dragged_card_from_container_node, it was already removed.
		# Otherwise, it's an incoming_card that wasn't part of this container before this drop.

		# Check if there's a card at the target destination to swap with
		var target_card_at_destination: Card = null
		if final_insert_index < card_container.get_child_count():
			var node_at_target = card_container.get_child(final_insert_index)
			if node_at_target is Card and node_at_target != card_to_place: # Ensure it's not the placeholder
				target_card_at_destination = node_at_target

		card_container.add_child(card_to_place) # Add the card first

		if target_card_at_destination != null: # Swapping with an existing card
			print_debug("Swapping card %d with card %d (at index %d)" % [card_to_place.value, target_card_at_destination.value, final_insert_index])
			# card_to_place is added, target_card_at_destination is at final_insert_index (or final_insert_index+1 if card_to_place was added before it)
			# The HBoxContainer will shift things. We need to place card_to_place at final_insert_index,
			# and the card that *was* there needs to go to the original spot of card_to_place.
			# This part of the logic from your previous version was more direct for swaps.
			# For now, let's simplify: insert card_to_place. HBoxContainer shifts others.
			card_container.move_child(card_to_place, final_insert_index)
		else: # Moving to an empty slot or end
			card_container.move_child(card_to_place, final_insert_index)

		card_to_place.remove_from_slot() # Resets style just in case
		card_to_place.set_can_drag(true)

	# --- Finalize ---
	# Update original_index for ALL children
	for i in card_container.get_child_count():
		var child = card_container.get_child(i)
		if child is Card:
			child.original_index = i
			child.is_potential_swap_highlight = false # Reset swap highlight
			child._apply_current_style()

	card_container.queue_redraw()

	# Reset DragState and local drag tracking
	DragState.currently_dragged_card = null
	DragState.card_dragged_from_main_container = false
	dragged_card_from_container_node = null
	is_dragging_card_over_self = false
	emit_signal(card_dropped_card_container.get_name())

func _prepare_card_drag_from_container(card_node: Card):
	if card_node != null:
		dragged_card_from_container_node = card_node
		# Instead of removing, just hide. This simplifies index management for placeholder.
		# If removed, placeholder index calculation becomes more complex.
		card_node.visible = true

func _process(_delta: float) -> void:
	# Check if a card is being dragged and if it originated from the main container
	if DragState.currently_dragged_card == null:
		if current_drop_placeholder != null and current_drop_placeholder.is_inside_tree():
			current_drop_placeholder.get_parent().remove_child(current_drop_placeholder)
		is_dragging_card_over_self = false
		return

	var global_mouse_pos: Vector2 = get_global_mouse_position()
	var container_global_rect: Rect2 = card_container.get_global_rect()

	if container_global_rect.has_point(global_mouse_pos) and DragState.currently_dragged_card != null:
		is_dragging_card_over_self = true

		var mouse_pos_relative_to_scroll_container_viewport: Vector2 = get_local_mouse_position()
		var local_mouse_pos_x_in_card_container: float = mouse_pos_relative_to_scroll_container_viewport.x + scroll_horizontal

		var card_spacing: float = card_container.get_theme_constant("separation", "HBoxContainer")
		var effective_card_width: float = Constants.CARD_WIDTH + card_spacing

		var num_actual_cards: int = 0
		for i in card_container.get_child_count():
			var child = card_container.get_child(i)
			# Exclude the placeholder itself and the card being dragged (which is hidden)
			if child is Card and child.visible:
				num_actual_cards += 1
			elif child == current_drop_placeholder:
				pass # Don't count placeholder if it's already there for num_actual_cards

		var potential_insert_index: int = 0
		if effective_card_width > 0:
			# Add half of effective_card_width to mouse_pos.x to make insertion point appear "between" cards
			# when mouse is over the latter half of a card's space.
			potential_insert_index = int((local_mouse_pos_x_in_card_container + effective_card_width / 2.0) / effective_card_width)

		potential_insert_index = clamp(potential_insert_index, 0, num_actual_cards)


		if not current_drop_placeholder.is_inside_tree():
			card_container.add_child(current_drop_placeholder)

		# Ensure placeholder is not considered in its own positioning calculation for move_child
		var current_placeholder_idx = -1
		if current_drop_placeholder.is_inside_tree() and current_drop_placeholder.get_parent() == card_container:
			current_placeholder_idx = current_drop_placeholder.get_index()

		if current_placeholder_idx != potential_insert_index:
			card_container.move_child(current_drop_placeholder, potential_insert_index)

		current_drop_placeholder.visible = true
	else:
		if is_dragging_card_over_self: # Mouse just exited
			if current_drop_placeholder != null and current_drop_placeholder.is_inside_tree():
				current_drop_placeholder.get_parent().remove_child(current_drop_placeholder)
		is_dragging_card_over_self = false
