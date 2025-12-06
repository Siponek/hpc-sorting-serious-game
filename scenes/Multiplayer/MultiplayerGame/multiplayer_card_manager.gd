extends "res://scenes/CardScene/scripts/card_manager.gd"
class_name MultiplayerCardManager

# Multiplayer-specific variables
var is_host: bool = false
var my_client_id: int = -1
var game_state_synced: bool = false
@onready var buffer_size = Settings.player_buffer_count
# Track which cards are in OTHER players' buffers
var cards_in_other_buffers: Dictionary = {} # card_value: player_id


# TODO The cards order is not syncing properly, checkout before cloude update
# To see if the syncing mechanism makes sense.
# Perhaps we need to add signal on moving cards and then update the game state on every move?
func _ready():
	is_host = ConnectionManager.am_i_host()
	my_client_id = ConnectionManager.get_my_client_id()

	logger.log_info(
		"Starting initialization. Host: ", is_host, " Client ID: ", my_client_id
	)

	setup_multiplayer_sync()

	if is_host:
		super._ready()
		await get_tree().process_frame
		broadcast_initial_game_state()
		game_state_synced = true
		logger.log_info("Host ready with ", cards_array.size(), " cards")
	else:
		_initialize_client_structure()
		await get_tree().create_timer(0.5).timeout
		request_game_state_from_host()
	if OS.has_feature("debug"):
		mount_var_tree_variables()


func _initialize_client_structure():
	"""Client: Set up structure without generating cards"""
	logger.log_info("Client initializing structure")

	card_colors.map(func(color: Color): return color.lightened(0.1))

	if num_cards < 1:
		num_cards = 1

	values = []
	sorted_all = []
	cards_array.clear()
	sorted_cards_array.clear()

	adjust_container_spacing()
	slots = create_buffer_slots()

	if not _validate_node_references():
		push_error("MultiplayerCardManager: Critical node references missing")
		return

	_connect_signals()

	if sorted_cards_panel:
		sorted_cards_panel.visible = false

	logger.log_info("Client structure ready, waiting for game state")


func setup_multiplayer_sync():
	# Expose functions for remote calls
	GDSync.expose_func(self.sync_complete_game_state)
	GDSync.expose_func(self.sync_card_moved)
	GDSync.expose_func(self.sync_card_entered_buffer)
	GDSync.expose_func(self.sync_card_left_buffer)
	GDSync.expose_func(self.sync_timer_state)
	GDSync.expose_func(self.sync_game_finished)

	logger.log_info("Sync functions exposed")


func broadcast_initial_game_state():
	"""Host: Send complete initial game state to all clients"""
	if not is_host:
		return

	logger.log_info("Broadcasting initial game state")

	var card_states: Array[Dictionary] = []
	for i in range(cards_array.size()):
		var card = cards_array[i]
		card_states.append(
			{
				"value": card.value,
				"index": i,
				"original_index": card.original_index,
				"in_container": true,
				"in_buffer": false,
				"buffer_owner": - 1
			}
		)

	GDSync.call_func(
		self.sync_complete_game_state,
		[card_states, values, sorted_all, num_cards, buffer_size]
	)

	logger.log_info("Initial state broadcasted")


func request_game_state_from_host():
	"""Client: Request current game state from host"""
	logger.log_info("Requesting game state from host")

	if is_host:
		return

	var host_id = ConnectionManager.get_lobby_host_id()
	GDSync.call_func_on(host_id, self.send_current_state_to, [my_client_id])


func send_current_state_to(requesting_client_id: int):
	"""Host: Send current game state to specific client"""
	if not is_host:
		return

	logger.log_info("Sending state to client ", requesting_client_id)

	var card_states: Array[Dictionary] = []

	# Cards in main container
	for i in range(card_container.get_child_count()):
		var child = card_container.get_child(i)
		if child is Card:
			card_states.append(
				{
					"value": child.value,
					"index": i,
					"original_index": child.original_index,
					"in_container": true,
					"in_buffer": false,
					"buffer_owner": - 1
				}
			)

	# Cards in MY buffer
	for slot_idx in range(slots.size()):
		var slot = slots[slot_idx]
		if slot.occupied_by and slot.occupied_by is Card:
			var card = slot.occupied_by
			card_states.append(
				{
					"value": card.value,
					"index": - 1,
					"original_index": card.original_index,
					"in_container": false,
					"in_buffer": true,
					"buffer_owner": my_client_id
				}
			)

	# Cards in OTHER players' buffers
	for card_value in cards_in_other_buffers:
		var owner_id = cards_in_other_buffers[card_value]
		card_states.append(
			{
				"value": card_value,
				"index": - 1,
				"original_index": - 1,
				"in_container": false,
				"in_buffer": true,
				"buffer_owner": owner_id
			}
		)

	GDSync.call_func_on(
		requesting_client_id,
		self.sync_complete_game_state,
		[card_states, values, sorted_all, num_cards, buffer_size]
	)


func sync_complete_game_state(
	card_states: Array,
	game_values: Array,
	sorted_values: Array,
	card_count: int,
	buf_size: int
):
	"""Client: Receive and apply complete game state"""
	if is_host:
		return

	logger.log_info(
		"Syncing complete game state with ", card_states.size(), " cards"
	)

	values = game_values
	sorted_all = sorted_values
	num_cards = card_count
	buffer_size = buf_size

	# Clear existing cards
	for child in card_container.get_children():
		if child is Card:
			child.queue_free()

	cards_array.clear()
	cards_in_other_buffers.clear()

	# Recreate ALL cards
	var all_card_values: Array[int] = []
	for state in card_states:
		all_card_values.append(state.value)

	all_card_values.sort()

	var card_lookup: Dictionary = {}

	for value in all_card_values:
		var card_instance: Card = card_scene.instantiate()
		card_instance.set_card_value(value)
		card_instance.set_card_container_ref(card_container)
		card_instance.name = "Card_Val_" + str(value)

		var new_card_style = StyleBoxFlat.new()
		new_card_style.bg_color = card_colors[value % card_colors.size()]
		card_instance.set_base_style(new_card_style)

		card_lookup[value] = card_instance
		cards_array.append(card_instance)

	# Place cards according to their state
	for state in card_states:
		var card = card_lookup[state.value]
		card.original_index = state.original_index

		if state.in_container:
			card_container.add_child(card)
			if state.index >= 0:
				card_container.move_child(card, state.index)
		elif state.in_buffer:
			var buffer_owner = state.buffer_owner

			if buffer_owner == my_client_id:
				logger.log_info("Card ", state.value, " is in my buffer")
			else:
				cards_in_other_buffers[state.value] = buffer_owner
				logger.log_info(
					"Card ",
					state.value,
					" is in player ",
					buffer_owner,
					"'s buffer"
				)

	# Create sorted reference display
	sorted_cards_array = generate_completed_card_array(
		sorted_all, "SortedCard_"
	)
	for card in sorted_cards_array:
		card.set_can_drag(false)
		card.set_card_size(
			Vector2(Constants.CARD_WIDTH, int(float(Constants.CARD_HEIGHT) / 2))
		)

	for child in sorted_cards_container.get_children():
		child.queue_free()

	fill_card_container(sorted_cards_array, sorted_cards_container)

	game_state_synced = true
	logger.log_info(
		"Game state synced - ",
		cards_array.size(),
		" total cards, ",
		card_container.get_child_count(),
		" in container, ",
		cards_in_other_buffers.size(),
		" in other players' buffers"
	)


func sync_card_moved(
	card_value: int, from_index: int, to_index: int, moving_client_id: int
):
	"""Sync card movement in main container"""
	if moving_client_id == my_client_id:
		return

	logger.log_info(
		"Syncing card ", card_value, " move from ", from_index, " to ", to_index
	)

	var card: Card = _find_card_by_value(card_value)
	if not card:
		push_error("MultiplayerCardManager: Card ", card_value, " not found!")
		return

	# Ensure card is in container
	if card.get_parent() != card_container:
		# Card might be orphaned, re-add it
		if card.get_parent():
			card.get_parent().remove_child(card)
		card_container.add_child(card)
		logger.log_info("Re-added card ", card_value, " to container")

	# Move to correct position
	card_container.move_child(card, to_index)

	# Make sure card is visible and draggable
	card.visible = true
	card.set_can_drag(true)
	card.remove_from_slot() # Reset any slot styling

	_update_all_card_indices()

	logger.log_info("Card ", card_value, " moved to index ", to_index)


func sync_card_entered_buffer(card_value: int, entering_player_id: int):
	"""Notify all players that a card entered someone's buffer"""
	logger.log_info(
		"Card ", card_value, " entered player ", entering_player_id, "'s buffer"
	)

	if entering_player_id == my_client_id:
		return

	var card: Card = _find_card_by_value(card_value)
	if not card:
		push_error("MultiplayerCardManager: Card ", card_value, " not found!")
		return

	# Remove from container if it's there
	if card.get_parent() == card_container:
		card_container.remove_child(card)
		logger.log_info(
			"Removed card ", card_value, " from container (entered buffer)"
		)

	# Track it
	cards_in_other_buffers[card_value] = entering_player_id

	logger.log_info(
		"Card ",
		card_value,
		" now hidden (in player ",
		entering_player_id,
		"'s buffer)"
	)


func sync_card_left_buffer(
	card_value: int, leaving_player_id: int, to_index: int
):
	"""Notify all players that a card left someone's buffer"""
	logger.log_info(
		"Card ",
		card_value,
		" left player ",
		leaving_player_id,
		"'s buffer to index ",
		to_index
	)

	if leaving_player_id == my_client_id:
		# It's my card leaving my buffer, I handle it locally
		return

	# Remove from tracking
	if card_value in cards_in_other_buffers:
		cards_in_other_buffers.erase(card_value)
		logger.log_info("Removed card ", card_value, " from tracking")

	# Find the card
	var card: Card = _find_card_by_value(card_value)
	if not card:
		push_error(
			"MultiplayerCardManager: Card ",
			card_value,
			" not found for buffer exit!"
		)
		return

	# Make sure it's not already in container
	if card.get_parent() == card_container:
		logger.log_info(
			"Card ", card_value, " already in container, just moving"
		)
		card_container.move_child(card, to_index)
	else:
		# Add back to container
		if card.get_parent():
			card.get_parent().remove_child(card)

		card_container.add_child(card)
		card_container.move_child(card, to_index)
		logger.log_info(
			"Added card ", card_value, " back to container at index ", to_index
		)

	# Reset card state
	card.remove_from_slot()
	card.set_can_drag(true)
	card.visible = true

	_update_all_card_indices()

	logger.log_info("Card ", card_value, " now visible at index ", to_index)


func _find_card_by_value(value: int) -> Card:
	"""Find a card by its value"""
	for card in cards_array:
		if card.value == value:
			return card
	return null


func _update_all_card_indices():
	"""Update original_index for all cards in container"""
	for i in range(card_container.get_child_count()):
		var child = card_container.get_child(i)
		if child is Card:
			child.original_index = i


func _on_card_placed_in_container(
	dropped_card: Card = null,
	was_in_buffer: bool = false,
	original_slot: Variant = null
):
	if not game_state_synced:
		logger.log_warning("Skipping sync - game state not ready")
		super._on_card_placed_in_container()
		return

	if not dropped_card:
		logger.log_info("No dragged card in DragState")
		super._on_card_placed_in_container()
		return

	var moved_card = dropped_card

	# Check if this is the first move (timer not started yet)
	var should_start_timer = not timer_node.timer_started

	# IMPORTANT: Check slot status BEFORE scroll_container processes the drop
	# Store this before the card's state changes
	super._on_card_placed_in_container()

	# If timer just started, broadcast to all clients
	if should_start_timer and timer_node.timer_started:
		logger.log_info(
			"First move detected, broadcasting timer start to all clients"
		)
		GDSync.call_func(self.sync_timer_state, ["start"])

	# Wait a frame to ensure card is properly placed
	await get_tree().process_frame

	var new_index = moved_card.get_index()

	logger.log_info(
		"Card ",
		moved_card.value,
		" placed. Current slot: ",
		was_in_buffer,
		" Index: ",
		new_index
	)

	# Check if this card was in my buffer

	if was_in_buffer:
		# Card is leaving MY buffer and going to container
		logger.log_info(
			"Broadcasting card ",
			moved_card.value,
			" leaving my buffer to index ",
			new_index
		)
		# Clear the slot's occupied_by reference
		if original_slot and original_slot.occupied_by == moved_card:
			original_slot.occupied_by = null
			original_slot._update_panel_visibility()
		GDSync.call_func(
			self.sync_card_left_buffer,
			[moved_card.value, my_client_id, new_index]
		)
	else:
		# Card is just moving within container
		logger.log_info(
			"Broadcasting card ",
			moved_card.value,
			" moved from ",
			moved_card.original_index,
			" to ",
			new_index
		)
		GDSync.call_func(
			self.sync_card_moved,
			[
				moved_card.value,
				moved_card.original_index,
				new_index,
				my_client_id
			]
		)


# Override parent's buffer placement handler
func _on_card_placed_in_slot(card, slot):
	# Check if this is the first move (timer not started yet)
	var should_start_timer = not timer_node.timer_started

	# Call parent logic first
	super._on_card_placed_in_slot(card, slot)

	# If timer just started, broadcast to all clients
	if should_start_timer and timer_node.timer_started:
		(
			logger
			.log_info(
				"First move detected (slot), broadcasting timer start to all clients"
			)
		)
		GDSync.call_func(self.sync_timer_state, ["start"])

	if not game_state_synced:
		logger.log_info("Skipping buffer sync - game state not ready")
		return

	var slot_index = slots.find(slot)

	logger.log_info(
		"Broadcasting card ",
		card.value,
		" entered my buffer at slot ",
		slot_index
	)

	# Notify everyone that this card entered MY buffer
	GDSync.call_func(self.sync_card_entered_buffer, [card.value, my_client_id])


func sync_timer_state(action: String):
	if action == "start" and timer_node and not timer_node.timer_started:
		timer_node.start_timer()
	elif action == "stop" and timer_node:
		timer_node.stop_timer()
	elif action == "reset" and timer_node:
		timer_node.reset_timer()


# Override parent's _finish_game to add multiplayer synchronization
func _finish_game() -> void:
	"""Override: Called when player finishes the game (cards are sorted)"""
	# Prevent multiple windows - inherited from parent
	if (
		finish_window_open
		or (
			finish_window_instance and is_instance_valid(finish_window_instance)
		)
	):
		logger.log_warning(
			"Finish window already open, ignoring duplicate request"
		)
		return

	# Mark window as open IMMEDIATELY to prevent race conditions
	finish_window_open = true

	# Disable the button to prevent multiple clicks
	if show_sorted_button:
		show_sorted_button.disabled = true

	# Stop MY timer
	if timer_node:
		timer_node.stop_timer()
	else:
		logger.log_warning("timer_node is null in _finish_game()")

	# Get final time and move count
	var final_time_string = (
		timer_node.getCurrentTimeAsString() if timer_node else "N/A"
	)
	var final_move_count = move_count

	logger.log_info(
		"Game finished! Time: ", final_time_string, " Moves: ", final_move_count
	)

	# Broadcast to ALL clients that game is finished
	GDSync.call_func(
		self.sync_game_finished,
		[my_client_id, final_time_string, final_move_count]
	)

	# Show MY finish screen (will also show to others via sync)
	_show_finish_game_scene(final_time_string, final_move_count, my_client_id)


func sync_game_finished(
	finishing_player_id: int, time_string: String, moves: int
):
	"""All clients receive this when ANY player finishes"""
	logger.log_info(
		"Player ",
		finishing_player_id,
		" finished the game! Time: ",
		time_string,
		" Moves: ",
		moves
	)

	# Stop everyone's timer
	if timer_node and timer_node.timer_started:
		timer_node.stop_timer()
		logger.log_info("Timer stopped for all players")

	# Show finish screen with the winning player's stats
	_show_finish_game_scene(time_string, moves, finishing_player_id)
