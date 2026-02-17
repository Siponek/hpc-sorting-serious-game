extends "res://scenes/CardScene/scripts/card_manager.gd"
class_name MultiplayerCardManager


## Inner class for card state transport protocol
class CardState:
	var value: int
	var index: int
	var original_index: int
	var in_container: bool
	var in_buffer: bool
	var buffer_owner: int

	func _init(
		p_value: int,
		p_index: int = -1,
		p_original_index: int = -1,
		p_in_container: bool = true,
		p_in_buffer: bool = false,
		p_buffer_owner: int = -1
	) -> void:
		value = p_value
		index = p_index
		original_index = p_original_index
		in_container = p_in_container
		in_buffer = p_in_buffer
		buffer_owner = p_buffer_owner

	func to_dict() -> Dictionary:
		return {
			"value": value,
			"index": index,
			"original_index": original_index,
			"in_container": in_container,
			"in_buffer": in_buffer,
			"buffer_owner": buffer_owner
		}

	static func from_dict(data: Dictionary) -> CardState:
		return CardState.new(
			data.get("value", 0),
			data.get("index", -1),
			data.get("original_index", -1),
			data.get("in_container", true),
			data.get("in_buffer", false),
			data.get("buffer_owner", -1)
		)


# Multiplayer-specific variables
var is_host: bool = false
var my_client_id: int = -1
var game_state_synced: bool = false
@onready var buffer_size = Settings.player_buffer_count
# Track which cards are in OTHER players' buffers
var cards_in_other_buffers: Dictionary = {} # card_value: player_id

# Barrier synchronization feature
var barrier_manager: BarrierManager
@export var barrier_control_panel: PanelContainer
@export var barrier_lock_overlay: CanvasLayer
@export var all_buffers_view: PanelContainer
var interaction_locked: bool = false


### Toggle elements elements that should not be visible when overlay is active
func _toggle_visibility_of_the_rest_for_overlay(_visible: bool):
	logger.log_info("Toggling visibility of non-overlay elements: ", _visible)
	right_menu_buttons_container.visible = _visible
	header_panel.visible = _visible
	buffer_zone_container.visible = _visible


# TODO The cards order is not syncing properly, checkout before cloude update
# To see if the syncing mechanism makes sense.
# Perhaps we need to add signal on moving cards and then update the game state on every move?
func _ready():
	is_host = ConnectionManager.am_i_host()
	my_client_id = ConnectionManager.get_my_client_id()
	logger.log_info(
		"Starting initialization. Host: ", is_host, " Client ID: ", my_client_id
	)

	# Add to group for interaction lock check
	add_to_group("card_manager")

	# Initialize barrier manager
	barrier_manager = BarrierManager.new()
	barrier_manager.set_barrier_mode(Settings.barrier_mode)
	barrier_manager.barrier_state_changed.connect(_on_barrier_state_changed)
	# Connect barrier control panel signals
	barrier_control_panel.barrier_requested.connect(_on_barrier_requested)
	barrier_control_panel.release_requested.connect(
		_on_release_barrier_requested
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
	if VarTreeHandler.should_enable_var_tree():
		VarTreeHandler.handle_var_tree(var_tree_node, _setup_var_tree)


### Client: Set up structure without generating cards
func _initialize_client_structure():
	logger.log_info("Client initializing structure")

	Settings.card_colors.map(func(color: Color): return color.lightened(0.1))

	if num_cards < 1:
		num_cards = 1

	values = []
	sorted_all = []
	cards_array.clear()
	sorted_cards_array.clear()

	adjust_container_spacing()
	slots = create_buffer_slots()

	_connect_signals()

	sorted_cards_panel.visible = false

	logger.log_info("Client structure ready, waiting for game state")


func _connect_signals():
	super._connect_signals()
	# Connect buffer view card drop signal for barrier mode
	if (
		scroll_container_node
		and scroll_container_node.has_signal("buffer_view_card_dropped")
	):
		scroll_container_node.buffer_view_card_dropped.connect(
			_on_buffer_view_card_dropped
		)


func setup_multiplayer_sync():
	# Expose functions for remote calls
	GDSync.expose_func(self.sync_complete_game_state)
	GDSync.expose_func(self.sync_card_moved)
	GDSync.expose_func(self.sync_card_entered_buffer)
	GDSync.expose_func(self.sync_card_left_buffer)
	GDSync.expose_func(self.sync_timer_state)
	GDSync.expose_func(self.sync_game_finished)
	# Host function that clients can call to request current state
	GDSync.expose_func(self.send_current_state_to)

	# Barrier synchronization functions
	GDSync.expose_func(self.barrier_thread_reached)
	GDSync.expose_func(self.barrier_activate)
	GDSync.expose_func(self.barrier_card_picked)
	GDSync.expose_func(self.barrier_release)

	logger.log_info("Sync functions exposed")


### Host: Send complete initial game state to all clients
func broadcast_initial_game_state():
	if not is_host:
		return

	logger.log_info("Broadcasting initial game state")

	var card_states: Array[Dictionary] = []
	for i in range(cards_array.size()):
		var card = cards_array[i]
		var state = CardState.new(card.value, i, card.original_index)
		card_states.append(state.to_dict())

	GDSync.call_func(
		self.sync_complete_game_state,
		[card_states, values, sorted_all, num_cards, buffer_size]
	)

	logger.log_info("Initial state broadcasted")


### Client: Request current game state from host
func request_game_state_from_host():
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
			var state = CardState.new(child.value, i, child.original_index)
			card_states.append(state.to_dict())

	# Cards in MY buffer
	for slot_idx in range(slots.size()):
		var slot = slots[slot_idx]
		if slot.occupied_by and slot.occupied_by is Card:
			var card = slot.occupied_by
			var state = CardState.new(
				card.value, -1, card.original_index, false, true, my_client_id
			)
			card_states.append(state.to_dict())

	# Cards in OTHER players' buffers
	for card_value in cards_in_other_buffers:
		var owner_id = cards_in_other_buffers[card_value]
		var state = CardState.new(card_value, -1, -1, false, true, owner_id)
		card_states.append(state.to_dict())

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
		card_instance.set_card_scroll_container(scroll_container_node) # Set reference to scroll container for each card
		card_instance.set_card_value(value)
		card_instance.set_card_container_ref(card_container)
		card_instance.name = "Card_Val_" + str(value)

		var new_card_style = StyleBoxFlat.new()
		new_card_style.bg_color = Settings.card_colors[value % Settings.card_colors.size()]
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

	logger.log_debug("Card ", card_value, " moved to index ", to_index)


func sync_card_entered_buffer(card_value: int, entering_player_id: int):
	"""Notify all players that a card entered someone's buffer"""
	logger.log_debug(
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
		logger.log_debug(
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
		logger.log_debug(
			"Added card ", card_value, " back to container at index ", to_index
		)

	# Reset card state
	card.remove_from_slot()
	card.set_can_drag(true)
	card.visible = true

	_update_all_card_indices()

	logger.log_debug("Card ", card_value, " now visible at index ", to_index)


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

	logger.log_debug(
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
		logger.log_debug(
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
		logger.log_debug(
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


#region Barrier Synchronization Functions


func _on_barrier_requested():
	"""Called when local thread (player) clicks barrier button"""
	logger.log_info(
		"Barrier requested by player ",
		my_client_id,
		" - current state: ",
		barrier_manager.current_state
	)

	# Block only during active barrier processing
	if (
		barrier_manager.current_state
		== BarrierManager.BarrierState.BARRIER_ACTIVE
	):
		logger.log_info("Blocked: barrier is active")
		return
	# Block if this player already reached the barrier
	if barrier_manager.has_thread_reached_barrier(my_client_id):
		logger.log_info("Blocked: player already at barrier")
		return

	logger.log_info(
		"Broadcasting barrier_thread_reached for player ", my_client_id
	)
	GDSync.call_func(self.barrier_thread_reached, [my_client_id])
	# Also update local state (GDSync.call_func only broadcasts to others, not to self)
	barrier_thread_reached(my_client_id)


func barrier_thread_reached(thread_id: int):
	"""Received by all when a thread reaches the barrier"""
	logger.log_info(
		"barrier_thread_reached: thread ",
		thread_id,
		" (I am ",
		my_client_id,
		")"
	)
	var all_thread_ids = ConnectionManager.get_player_list().get_client_ids()
	logger.log_info(
		"All thread IDs: ",
		all_thread_ids,
		" - current state: ",
		barrier_manager.current_state
	)

	if barrier_manager.current_state == BarrierManager.BarrierState.RUNNING:
		# First thread at barrier - start waiting
		logger.log_info("First thread at barrier - entering waiting state")
		barrier_manager.enter_waiting_state(thread_id, all_thread_ids)
		logger.log_info(
			"Main thread assigned: ", barrier_manager.main_thread_id
		)
	else:
		# Already waiting - mark this thread as at barrier
		logger.log_info(
			"Thread ", thread_id, " joining barrier (already waiting)"
		)
		barrier_manager.mark_thread_at_barrier(thread_id)

# If this is ME reaching the barrier, disable my button
	if thread_id == my_client_id:
		logger.log_info("Disabling my barrier button")
		barrier_control_panel.set_barrier_state(true, false, false)

	# Update the waiting list for all players whenever any thread reaches the barrier
	_update_barrier_ui_waiting()
	# Check if all threads at barrier
	logger.log_info("Threads at barrier: ", barrier_manager.threads_at_barrier)

	if barrier_manager.all_threads_at_barrier(all_thread_ids):
		logger.log_info("All threads at barrier! Initiating processing...")
		_initiate_barrier_processing()


func _initiate_barrier_processing():
	"""Host initiates barrier processing after all threads arrive"""
	logger.log_info("_initiate_barrier_processing called - is_host: ", is_host)
	if not is_host:
		logger.log_info("Not host, skipping barrier processing initiation")
		return

	# Collect all buffer snapshots
	var snapshots: Array = []

	# Add own buffer snapshot
	var my_snapshot = _get_my_buffer_snapshot()
	snapshots.append(my_snapshot)
	logger.log_info("My buffer snapshot: ", my_snapshot)

	# For other threads' buffers, use cards_in_other_buffers tracking
	var buffers_by_owner: Dictionary = {}
	for card_value in cards_in_other_buffers:
		var owner_id = cards_in_other_buffers[card_value]
		if owner_id not in buffers_by_owner:
			buffers_by_owner[owner_id] = []
		buffers_by_owner[owner_id].append(card_value)

	for owner_id in buffers_by_owner:
		snapshots.append(
			{"owner_id": owner_id, "card_values": buffers_by_owner[owner_id]}
		)

	logger.log_info("All snapshots: ", snapshots)
	logger.log_info(
		"Broadcasting barrier_activate with main_thread: ",
		barrier_manager.main_thread_id
	)
	GDSync.call_func(
		self.barrier_activate, [barrier_manager.main_thread_id, snapshots]
	)
	# Also update local state (GDSync.call_func only broadcasts to others, not to self)
	barrier_activate(barrier_manager.main_thread_id, snapshots)


func barrier_activate(main_thread_id: int, buffer_snapshots: Array):
	"""All threads receive this when barrier activates"""
	logger.log_info(
		"barrier_activate received - main_thread: ",
		main_thread_id,
		", I am: ",
		my_client_id
	)
	logger.log_info("Buffer snapshots: ", buffer_snapshots)
	barrier_manager.main_thread_id = main_thread_id
	barrier_manager.activate_barrier()

	# Update UI to show which thread is the main thread
	var main_thread_name = _get_player_name(main_thread_id)
	var is_me = my_client_id == main_thread_id
	barrier_control_panel.set_main_thread_active(main_thread_name, is_me)

	if my_client_id == main_thread_id:
		logger.log_info("I am the main thread - entering main thread mode")
		_enter_main_thread_mode(buffer_snapshots)
	else:
		logger.log_info("I am NOT the main thread - entering blocked mode")
		_enter_blocked_mode()


func _enter_main_thread_mode(buffer_snapshots: Array):
	"""Main thread enters processing mode - can access all buffers"""
	logger.log_info("Entering main thread mode")
	interaction_locked = false

	all_buffers_view.clear_buffers()
	for snap_dict in buffer_snapshots:
		var thread_name = _get_player_name(snap_dict.owner_id)
		logger.log_info(
			"Adding buffer for thread ",
			snap_dict.owner_id,
			" (",
			thread_name,
			"): ",
			snap_dict.card_values
		)
		all_buffers_view.add_thread_buffer(
			snap_dict.owner_id, thread_name, snap_dict.card_values
		)
	_toggle_visibility_of_the_rest_for_overlay(false)
	all_buffers_view.show_view()
	barrier_control_panel.set_barrier_state(false, true, true)


func _enter_blocked_mode():
	"""Non-main threads enter blocked mode - cannot move cards"""
	logger.log_info("Entering blocked mode - interaction_locked = true")
	interaction_locked = true

	var main_thread_name = _get_player_name(barrier_manager.main_thread_id)
	logger.log_info("Showing lock overlay for main thread: ", main_thread_name)
	barrier_lock_overlay.show_overlay(main_thread_name)
	barrier_control_panel.set_barrier_state(false, false, true)


func _on_buffer_view_card_dropped(
	card_value: int, from_thread_id: int, target_index: int
):
	"""Main thread dropped a card from AllBuffersView to main container"""
	logger.log_info(
		"Buffer view card dropped: value=",
		card_value,
		" from_thread=",
		from_thread_id,
		" target_index=",
		target_index
	)
	if not barrier_manager.is_main_thread(my_client_id):
		logger.log_warning("Not main thread, ignoring buffer view card drop")
		return

	logger.log_info(
		"Broadcasting barrier_card_picked: value=",
		card_value,
		" target_index=",
		target_index
	)

	GDSync.call_func(
		self.barrier_card_picked, [card_value, from_thread_id, target_index]
	)
	# Also update local state (GDSync.call_func only broadcasts to others, not to self)
	barrier_card_picked(card_value, from_thread_id, target_index)


func _on_buffer_card_selected(card_value: int, from_thread_id: int):
	"""Main thread selected a card from another thread's buffer (click fallback)"""
	logger.log_info(
		"Card selected from buffer: value=",
		card_value,
		" from_thread=",
		from_thread_id
	)
	if not barrier_manager.is_main_thread(my_client_id):
		logger.log_warning("Not main thread, ignoring card selection")
		return

	# Get the target index (end of main container)
	var target_index = card_container.get_child_count()
	logger.log_info(
		"Broadcasting barrier_card_picked: value=",
		card_value,
		" target_index=",
		target_index
	)

	GDSync.call_func(
		self.barrier_card_picked, [card_value, from_thread_id, target_index]
	)
	# Also update local state (GDSync.call_func only broadcasts to others, not to self)
	barrier_card_picked(card_value, from_thread_id, target_index)


func barrier_card_picked(
	card_value: int, from_thread_id: int, target_index: int
):
	"""Sync card pick from buffer to main container"""
	logger.log_info(
		"barrier_card_picked: value=",
		card_value,
		" from=",
		from_thread_id,
		" to_index=",
		target_index
	)

	# Step 1: Update tracking dictionary
	if card_value in cards_in_other_buffers:
		cards_in_other_buffers.erase(card_value)
		logger.log_info("Removed card from cards_in_other_buffers tracking")

	# Step 2: Update AllBuffersView UI for main thread
	if all_buffers_view and all_buffers_view.visible:
		all_buffers_view.remove_card_from_buffer(card_value, from_thread_id)

	# Step 3: Transfer card from buffer to main container
	_transfer_card_to_container(card_value, from_thread_id, target_index)


func _on_release_barrier_requested():
	"""Main thread finished - release the barrier"""
	logger.log_info("Release barrier requested")
	if not barrier_manager.is_main_thread(my_client_id):
		logger.log_warning("Not main thread, ignoring release request")
		return
	logger.log_info("Broadcasting barrier_release")
	GDSync.call_func(self.barrier_release, [])
	# Also update local state (GDSync.call_func only broadcasts to others, not to self)
	barrier_release()


func barrier_release():
	"""All threads: barrier released, return to running state"""
	logger.log_info("barrier_release received - releasing barrier")
	barrier_manager.release_barrier()
	_exit_barrier_mode()


func _exit_barrier_mode():
	"""Clean up barrier UI and return to running state"""
	logger.log_info("Exiting barrier mode - interaction_locked = false")
	interaction_locked = false
	barrier_lock_overlay.visible = false

	all_buffers_view.hide_view()
	_toggle_visibility_of_the_rest_for_overlay(true)

	barrier_control_panel.reset_ui()


func _update_barrier_ui_waiting():
	"""Update UI when first thread reaches barrier"""
	barrier_control_panel.update_status("Waiting at barrier...")

	# Only disable button if THIS player has reached the barrier
	var my_reached = barrier_manager.has_thread_reached_barrier(my_client_id)
	barrier_control_panel.set_barrier_state(my_reached, false, false)

	# Collect players who haven't reached the barrier yet
	var players = ConnectionManager.get_player_list()
	var waiting_player_names: Array[String] = []
	for player in players.get_all_players():
		if not barrier_manager.has_thread_reached_barrier(player.client_id):
			waiting_player_names.append(player.name)

	# Display the grouped waiting list
	barrier_control_panel.set_waiting_for_players(waiting_player_names)


func _on_barrier_state_changed(new_state: BarrierManager.BarrierState):
	"""Handle barrier state changes"""
	match new_state:
		BarrierManager.BarrierState.RUNNING:
			barrier_control_panel.update_status("Running")
		BarrierManager.BarrierState.WAITING_AT_BARRIER:
			barrier_control_panel.update_status("Waiting at barrier...")
		BarrierManager.BarrierState.BARRIER_ACTIVE:
			barrier_control_panel.update_status("Barrier active")


func _get_my_buffer_snapshot() -> Dictionary:
	"""Get current state of local thread's buffer"""
	var card_values: Array = []

	for slot in slots:
		if slot.occupied_by and slot.occupied_by is Card:
			card_values.append(slot.occupied_by.value)

	return {"owner_id": my_client_id, "card_values": card_values}


func _get_player_name(player_id: int) -> String:
	"""Get player/thread name by ID"""
	var players = ConnectionManager.get_player_list()
	for player in players.get_all_players():
		if player.client_id == player_id:
			return player.name
	return "Thread " + str(player_id)


#endregion

#region Card State Management Helpers
## These functions handle card state transitions during barrier operations.
## The flow when main thread picks a card from another player's buffer:
##   1. _detach_card_from_slot() - Owner removes card from their buffer slot
##   2. _get_or_create_card() - Find existing card or create new instance
##   3. _reset_card_for_container() - Reset visual state to standard dimensions
##   4. _place_card_in_container() - Add card to main container at position


func _detach_card_from_slot(card_value: int) -> void:
	"""
	Detach a card from this player's buffer slot without destroying it.
	The card remains in cards_array and will be reparented to the main container.
	Called only on the buffer owner's client.
	"""
	for slot in slots:
		if slot.occupied_by and slot.occupied_by is Card:
			if slot.occupied_by.value == card_value:
				var card = slot.occupied_by
				# Clear slot reference
				slot.occupied_by = null
				slot._update_panel_visibility()
				# Clear card's slot reference
				card.current_slot = null
				# Orphan the card (remove from scene tree but don't destroy)
				if card.get_parent():
					card.get_parent().remove_child(card)
				logger.log_debug(
					"Detached card ", card_value, " from buffer slot"
				)
				break


func _get_or_create_card(card_value: int) -> Card:
	"""
	Get an existing card from cards_array or create a new instance.
	New cards are added to cards_array for tracking.
	"""
	var card = _find_card_by_value(card_value)
	if card != null:
		return card

	# Card doesn't exist - create new instance
	card = card_scene.instantiate()
	card.set_card_scroll_container(scroll_container_node) # Set reference to scroll container for each card
	card.set_card_value(card_value)
	card.set_card_container_ref(card_container)
	card.name = "Card_Val_" + str(card_value)

	var new_card_style = StyleBoxFlat.new()
	new_card_style.bg_color = Settings.card_colors[card_value % Settings.card_colors.size()]
	card.set_base_style(new_card_style)

	cards_array.append(card)
	logger.log_debug("Created new card instance for value ", card_value)
	return card


func _reset_card_for_container(card: Card) -> void:
	"""
	Reset a card's visual state to standard dimensions for the main container.
	This ensures cards coming from buffer views (mini size) are restored.
	"""
	card.set_card_size(Vector2(Constants.CARD_WIDTH, Constants.CARD_HEIGHT))
	card.set_can_drag(true)
	card.visible = true
	card.current_slot = null


func _place_card_in_container(card: Card, index: int) -> void:
	"""
	Place a card in the main container at the specified index.
	Handles orphaning from previous parent and index bounds.
	"""
	if card.get_parent():
		card.get_parent().remove_child(card)

	card_container.add_child(card)
	var clamped_index = min(index, card_container.get_child_count() - 1)
	card_container.move_child(card, clamped_index)
	_update_all_card_indices()


func _transfer_card_to_container(
	card_value: int, from_thread_id: int, target_index: int
) -> void:
	"""
	High-level function to transfer a card from a buffer to the main container.
	Handles the complete flow: detach (if owner) -> get/create -> reset -> place.
	"""
	# If this is MY buffer, detach the card from the slot
	if from_thread_id == my_client_id:
		logger.log_info("Detaching card ", card_value, " from my buffer")
		_detach_card_from_slot(card_value)

	# Get or create the card instance
	var card = _get_or_create_card(card_value)

	# Reset to standard container state
	_reset_card_for_container(card)

	# Place in container
	_place_card_in_container(card, target_index)
	logger.log_info(
		"Card ", card_value, " placed in container at index ", target_index
	)

#endregion
