extends "res://scenes/CardScene/scripts/card_manager.gd"
class_name MultiplayerCardManager

# Multiplayer-specific variables
var is_host: bool = false
var my_client_id: int = -1
var game_state_synced: bool = false

func _ready():
	# Get multiplayer info first
	is_host = ConnectionManager.am_i_host()
	my_client_id = ConnectionManager.get_my_client_id()

	# Call parent ready
	super._ready()

	# Setup multiplayer-specific functionality
	setup_multiplayer_sync()

	# Only host initializes the game state
	if is_host:
		await get_tree().process_frame # Wait for all nodes to be ready
		broadcast_game_state_to_clients()
	else:
		request_game_state_from_host()

func setup_multiplayer_sync():
	# Expose functions for remote calls
	GDSync.expose_func(self.sync_card_positions)
	GDSync.expose_func(self.sync_card_moved)
	GDSync.expose_func(self.sync_game_state)
	GDSync.expose_func(self.sync_timer_state)

	print("MultiplayerCardManager: Sync functions exposed for client ", my_client_id)

func request_game_state_from_host():
	print("MultiplayerCardManager: Client requesting game state from host")
	# Clear any default cards that might have been generated
	clear_container(card_container)

	# Request current game state from host
	if is_host:
		return # Don't request from ourselves

	var host_id = ConnectionManager.get_lobby_host_id()
	GDSync.call_func_on(host_id, self.send_game_state_to_client, [my_client_id])

func send_game_state_to_client(requesting_client_id: int):
	if not is_host:
		return

	print("MultiplayerCardManager: Sending game state to client ", requesting_client_id)

	# Prepare card data
	var card_data = []
	for i in range(card_container.get_child_count()):
		var card = card_container.get_child(i)
		if card is Card:
			card_data.append({
				"value": card.value,
				"index": i,
				"position": card.position,
				"original_index": card.original_index
			})

	# Send game state to the specific client
	GDSync.call_func_on(requesting_client_id, self.sync_game_state, [card_data, values, sorted_all])

func broadcast_game_state_to_clients() -> void:
	print("MultiplayerCardManager: Broadcasting game state to all clients")

	# Prepare card data
	var card_data = []
	for i in range(card_container.get_child_count()):
		var card = card_container.get_child(i)
		if card is Card:
			card_data.append({
				"value": card.value,
				"index": i,
				"position": card.position,
				"original_index": card.original_index
			})

	# Broadcast to all clients
	GDSync.call_func(self.sync_game_state, [card_data, values, sorted_all])

func sync_game_state(card_data: Array, game_values: Array, sorted_values: Array):
	if is_host:
		return # Host doesn't need to sync from itself

	print("MultiplayerCardManager: Syncing game state with ", card_data.size(), " cards")

	# Store the values
	values = game_values
	sorted_all = sorted_values
	num_cards = values.size()

	# Clear existing cards
	clear_container(card_container)
	clear_container(sorted_cards_container)

	# Recreate cards from synced data
	cards_array.clear()
	for data in card_data:
		var card_instance = card_scene.instantiate()
		card_instance.set_card_value(data.value)
		card_instance.name = "Card_" + str(data.index) + "_Val_" + str(data.value)
		card_instance.original_index = data.original_index

		# Set card style
		var new_card_style = StyleBoxFlat.new()
		new_card_style.bg_color = card_colors[card_instance.value % card_colors.size()]
		card_instance.set_base_style(new_card_style)

		cards_array.append(card_instance)
		card_container.add_child(card_instance)

	# Create sorted cards display
	sorted_cards_array = generate_completed_card_array(sorted_all, "SortedCard_")
	for card in sorted_cards_array:
		card.set_can_drag(false)
		card.set_card_size(Vector2(Constants.CARD_WIDTH, int(float(Constants.CARD_HEIGHT) / 2)))
	fill_card_container(sorted_cards_array, sorted_cards_container)

	# Create buffer slots
	slots = create_buffer_slots()

	game_state_synced = true
	print("MultiplayerCardManager: Game state synchronized successfully")

func sync_card_moved(card_value: int, from_index: int, to_index: int, moving_client_id: int):
	if moving_client_id == my_client_id:
		return # Don't sync our own moves

	print("MultiplayerCardManager: Syncing card move from client ", moving_client_id,
		  " - Card ", card_value, " from ", from_index, " to ", to_index)

	# Find the card by value
	var card_to_move = null
	for card in card_container.get_children():
		if card is Card and card.value == card_value:
			card_to_move = card
			break

	if card_to_move:
		# Move the card to the new position
		card_container.move_child(card_to_move, to_index)
		# Update original indices for all cards
		for i in card_container.get_child_count():
			var child = card_container.get_child(i)
			if child is Card:
				child.original_index = i

func sync_card_positions(positions_data: Array):
	if is_host:
		return # Host doesn't sync positions from clients

	for data in positions_data:
		var card = find_card_by_value(data.value)
		if card:
			card.position = data.position

func find_card_by_value(value: int) -> Card:
	for card in card_container.get_children():
		if card is Card and card.value == value:
			return card
	return null

# Override the card movement detection
func _on_card_placed_in_container():
	super._on_card_placed_in_container()

	# If we're the one who moved the card, broadcast the change
	if game_state_synced and DragState.currently_dragged_card:
		var moved_card = DragState.currently_dragged_card
		var new_index = moved_card.get_index()

		if is_host or true: # For now, allow all players to broadcast moves
			GDSync.call_func(self.sync_card_moved, [
				moved_card.value,
				moved_card.original_index,
				new_index,
				my_client_id
			])

# Override timer start to sync across clients
func start_timer_sync():
	if is_host:
		GDSync.call_func(self.sync_timer_state, ["start"])

func sync_timer_state(action: String):
	if action == "start" and not timer_node.timer_started:
		timer_node.start_timer()
	elif action == "stop":
		timer_node.stop_timer()
	elif action == "reset":
		timer_node.reset_timer()
