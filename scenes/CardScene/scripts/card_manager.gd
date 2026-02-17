extends Control
# @export var card_scene: PackedScene
@export_range(10, 200) var button_spacing: int = 10
@export_range(10, 200) var card_spacing: int = 10

var slots: Array = [] # Array to store slot references
var cards_array: Array[Card] = []
var sorted_cards_array: Array[Card] = []
var values: Array[int] = []
var sorted_all = []
var num_cards: int = Settings.cards_count
const CARD_WIDTH = 70
var move_count: int = 0
var is_animating = false
# Dirty hack to not add multiple var_tree entries
var _var_tree_mounted: bool = false
# Finish window management
var finish_window_open: bool = false
var finish_window_instance: Node = null

# TODO would be cool to add coloring/theme selection to main menu,
# so players can choose if they want rainbow or now



@export var timer_node: TimerController
@export var card_container: HBoxContainer
@export var slot_container: HBoxContainer
@export var swap_button_container: HBoxContainer
@export var sorted_cards_panel: PanelContainer
@export var show_sorted_button: Button
@export var sorted_cards_container: HBoxContainer
@export var scroll_container_node: ScrollContainer
@export var var_tree_node: VarTree
@export var buffer_zone_container: PanelContainer
@export var right_menu_buttons_container: VBoxContainer
@export var header_panel: PanelContainer

const card_scene: PackedScene = preload(ProjectFiles.Scenes.CARD_MAIN)
const swap_button_scene: PackedScene = preload(ProjectFiles.Scenes.SWAP_BTN)
const card_slot_scene: PackedScene = preload(ProjectFiles.Scenes.CARD_SLOT)
const finish_game_scene: PackedScene = preload(ProjectFiles.Scenes.FINISH_GAME_SCENE)

var var_tree: VarTree = null
@onready var logger := CustomLogger.get_logger(self )

class CardDebugData:
	var cards_in_slots: int = 0
	var cards_in_container: int = 0


var card_debug_info = CardDebugData.new()


func _ready():
	Settings.card_colors.map(func(color: Color): return color.lightened(0.1))
	# 1. Initial calculations and data generation
	if num_cards < 1:
		num_cards = 1 # Ensure at least 1 card
		push_warning("CardManager: num_cards was less than 1, set to 1. Check for settings!")

	values = generate_random_values()
	sorted_all = values.duplicate()
	sorted_all.sort()

	# 2. UI Adjustments and Node Population
	adjust_container_spacing()

	cards_array = generate_completed_card_array(values)
	sorted_cards_array = generate_completed_card_array(sorted_all, "SortedCard_")
	for card in sorted_cards_array:
		card.set_can_drag(false)
		card.set_card_size(Vector2(Constants.CARD_WIDTH, int(float(Constants.CARD_HEIGHT) / 2)))
	fill_card_container(cards_array, card_container)
	fill_card_container(sorted_cards_array, sorted_cards_container)
	# This also connects signals from slots
	slots = create_buffer_slots()

	# 4. Connect signals
	_connect_signals()

	# 5. Initial UI states
	if sorted_cards_panel != null:
		sorted_cards_panel.visible = false
	# Var tree mounting for debugging purposes
	var_tree = VarTreeHandler.handle_var_tree(var_tree_node, _setup_var_tree)


func _setup_var_tree(vt: VarTree) -> void:
	if _var_tree_mounted:
		return # Already mounted
	_var_tree_mounted = true
	vt.mount_var(
		self ,
		"Client number",
		{
			"font_color": Color.CYAN,
			"format_callback":
			func(_value: Variant) -> String: return str(Constants.get_game_debug_id())
		}
	)
	vt.mount_var(
		self ,
		"dbg_game_info/curr_dragged_card",
		{
			"font_color": Color.SEASHELL,
			"format_callback": func(_value: Variant) -> String: return (
			(str(DragState.currently_dragged_card.value) if DragState.currently_dragged_card != null else "None")
			if card_container
			else "0"
		)
		}
	)
	#TODO something shitty is happening here indentation level and formatter cannot fix it
	vt.mount_var(self ,
		"dbg_game_info/card_count",
		{
			"font_color": Color.SEASHELL,
			"format_callback":
			func(_value: Variant) -> String: return str(card_container.get_child_count()) if card_container else "0"
		}
	)
	vt.mount_var(
		self ,
		"dbg_game_info/card_slots",
		{
			"font_color": Color.SEASHELL,
			"format_callback":
			func(_value: Variant) -> String: return (
				str(
					slot_container.get_children().reduce(
						func(accum, slot): return accum + slot.get_child_count() - 2,
						0
					)
				)
				if slot_container
				else "0"
			)
		}
	)
	if Settings.is_multiplayer:
		vt.mount_var(
			self ,
			"dbg_game_mp/multiplayer",
			{
				"font_color": Color.AQUA,
				"format_callback": func(_value: Variant) -> String: return "ON"
			}
		)
		vt.mount_var(
			self ,
			"dbg_game_mp/IAmHost",
			{
				"font_color": Color.SEASHELL,
				"format_callback":
				func(_value: Variant) -> String: return str(ConnectionManager.am_i_host())
			}
		)
		vt.mount_var(
			self ,
			"dbg_game_mp/currentLobbyID",
			{
				"font_color": Color.SEASHELL,
				"format_callback":
					func(_value: Variant) -> String: return str(ConnectionManager.get_current_lobby_id())
			}
		)
		vt.mount_var(
			self ,
			"dbg_game_mp/Players count",
			{
				"font_color": Color.SEASHELL,
				"format_callback":
				func(_value: Variant) -> String: return str(ConnectionManager.get_player_list().size())
			}
		)


func _on_restart_game_button_pressed() -> void:
	timer_node.reset_timer()
	clear_container(card_container)
	clear_container(sorted_cards_container)
	cards_array = generate_completed_card_array(values)
	sorted_cards_array = generate_completed_card_array(sorted_all, "SortedCard_")
	for card in sorted_cards_array:
		card.set_can_drag(false)
		card.set_card_size(Vector2(Constants.CARD_WIDTH, int(float(Constants.CARD_HEIGHT) / 2)))
	fill_card_container(cards_array, card_container)
	fill_card_container(sorted_cards_array, sorted_cards_container)
	slots = create_buffer_slots()


func clear_container(_card_container: Node = null) -> void:
	if _card_container == null:
		push_error("CardManager: clear_container called with null _card_container.")
	# Clear existing children
	for child in _card_container.get_children():
		child.queue_free()


func fill_card_container(_card_instances_array: Array, _card_container: Node = null) -> void:
	if _card_container == null:
		push_error("CardManager: fill_card_container called with null _card_container.")
	# Add new card instances
	for card_instance in _card_instances_array:
		_card_container.add_child(card_instance)


func _connect_signals():
	# Connect to ScrollContainer's signal for card drops
	if scroll_container_node.has_signal("card_dropped_card_container"):
		# Ensure _on_card_placed_in_container can accept a Card argument if the signal sends one
		# Or use a dedicated handler like _on_card_dropped_from_scroll_container(card: Card)
		var error_code = scroll_container_node.connect(
			"card_dropped_card_container", Callable(self , "_on_card_placed_in_container")
		)
		if error_code != OK:
			printerr(
				(
					"CardManager: Failed to connect scroll_container_node.card_dropped_card_container. Error: %s"
					% error_code
				)
			)
	else:
		printerr(
			"CardManager: scroll_container_node does not have signal 'card_dropped_card_container'."
		)

	# Connect ShowSortedCardsButton
	if not show_sorted_button.is_connected(
		"pressed", Callable(self , "_on_show_sorted_cards_button_pressed")
	):
		show_sorted_button.connect(
			"pressed", Callable(self , "_on_show_sorted_cards_button_pressed")
		)
		_setup_button_glow_animation(show_sorted_button) # Setup glow after connecting
	else:
		logger.log_info("show_sorted_button.pressed already connected.")

	# Note: Signals from dynamically created slots are connected in create_buffer_slots()


func generate_random_values() -> Array[int]:
	var random_values_array: Array[int] = []

	# Generate new card values based on the selected range
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	if Settings.can_cards_be_repeated:
		for i in range(num_cards):
			random_values_array.append(rng.randi_range(1, Settings.card_value_range))
	else:
		# Generate unique numbers
		if num_cards > Settings.card_value_range:
			push_error(
				(
					"Cannot generate %d unique cards_array from a range of 1 to %d. Allowing repeats."
					% [num_cards, Settings.card_value_range]
				)
			)
			# Fallback to allowing repeats if unique generation is impossible
			for i in range(num_cards):
				random_values_array.append(rng.randi_range(1, Settings.card_value_range))
		else:
			var available_numbers: Array = []
			for i in range(1, Settings.card_value_range + 1):
				available_numbers.append(i)

			# Shuffle the list of available numbers
			available_numbers.shuffle()

			for i in range(num_cards):
				random_values_array.append(available_numbers[i]) # Take the first num_cards from the shuffled list
	return random_values_array


func calculate_max_cards():
	# Get screen width from constants
	var screen_width = Constants.SCREEN_WIDTH

	# Account for margins (e.g., 10% of screen width for padding)
	var usable_width = screen_width * 0.9

	# Get card width from constant or scene
	var total_card_width = CARD_WIDTH + card_spacing

	# Calculate max cards_array that can fit
	var max_cards = int(usable_width / total_card_width)

	# Ensure at least 2 cards_array (for sorting to make sense)
	return max(2, max_cards)


func adjust_container_spacing():
	# Calculate available width (80% of screen width for cards_array)
	var available_width = Constants.SCREEN_WIDTH * 0.8

	# Calculate total width taken by cards_array
	var total_card_width = num_cards * CARD_WIDTH

	# Compute maximum spacing allowed (ensuring it doesn't exceed a chosen cap, e.g., 100)
	var max_spacing = min(100, int((available_width - total_card_width) / (num_cards - 1)))

	# Ensure a minimum spacing of 10
	card_spacing = max(10, max_spacing / 2)
	# Apply spacing to the card container so that cards_array are properly separated
	card_container.add_theme_constant_override("separation", int(card_spacing * 0.8))
	# TODO CHECK ALL PATHS, WRITE A WRAPPER FUNCTION IF NEEDED
	sorted_cards_container.add_theme_constant_override("separation", int(card_spacing * 0.8))

	# TODO Manual spaccing for buttons, doing it via container is impossible beacause of the way it calculates the spacing
	# Place the cards_array in container, calculate the positions and place the swap buttons there
	button_spacing = (card_spacing * 2) + CARD_WIDTH - Constants.BUTTON_WIDTH
	swap_button_container.add_theme_constant_override("separation", button_spacing)

	# For the first button, set an offset so that its center lies directly in the gap between the first two cards_array.
	# This offset is half the difference between the card width and the button width.
	var first_button_offset: int = int((CARD_WIDTH - Constants.BUTTON_WIDTH) / 2.0)
	$SwapButtonPanel/CenterContainer.add_theme_constant_override("margin_left", first_button_offset)


func generate_completed_card_array(
	card_values: Array[int], name_prefix: String = "Card_"
) -> Array[Card]:
	# Step 1: Create card instances
	var cards: Array[Card] = []
	var card_scene_instance: Card = null
	for _i in card_values.size():
		card_scene_instance = card_scene.instantiate()
		card_scene_instance.set_card_scroll_container(scroll_container_node) # Set reference to scroll container for each card
		cards.append(card_scene_instance)


	# Step 2: Apply values and names
	for i in cards.size():
		cards[i].value = card_values[i]
		cards[i].name = "%s%d_Val_%d" % [name_prefix, i, card_values[i]]

	# Step 3: Apply colors
	cards.map(
		func(card):
			card.card_color = Settings.card_colors[card.value % Settings.card_colors.size()]
			return card
	)

	# Step 4: Set container refs
	cards.map(
		func(card):
			card.set_card_container_ref(card_container)
			return card
	)

	return cards


func create_buffer_slots(buffer_size: int = Settings.player_buffer_count) -> Array:
	# Clamp to valid range [1, num_cards]
	var actual_size = clampi(buffer_size, 1, num_cards)

	if buffer_size != actual_size:
		push_warning(
			(
				"CardManager: buffer_size (%d) was clamped to %d (valid range: 1-%d)"
				% [buffer_size, actual_size, num_cards]
			)
		)
		buffer_size = actual_size

	var _slots: Array = []

	# Clear any existing slots
	for child in slot_container.get_children():
		child.queue_free()

	# Create new _slots based on actual_size
	for i in range(actual_size):
		var slot: CardBuffer = card_slot_scene.instantiate()
		slot.slot_text = "Slot " + str(i + 1)
		slot.set_card_container(card_container)
		slot_container.add_child(slot)
		_slots.append(slot)

	# Connect signals from _slots to your manager
	for slot in _slots:
		if slot.has_signal("card_placed_in_slot"):
			slot.card_placed_in_slot.connect(_on_card_placed_in_slot)

	return _slots


func _on_card_placed_in_container(
	dropped_card: Card = null, was_in_buffer: bool = false, original_slot: Variant = null
):
	move_count += 1
	if not timer_node.timer_started:
		timer_node.start_timer()
	if check_sorting_order():
		# Just show a hint that they can finish
		ToastParty.show(
			{
				"text": "Cards are sorted! Press 'Finish Game' to complete! 🎉",
				"bgcolor": Color(0.2, 0.8, 0.2, 0.8),
				"color": Color(1, 1, 1, 1),
				"gravity": "bottom",
				"direction": "center",
				"text_size": 16,
				"use_font": true
			}
		)


func _on_card_placed_in_slot(card, slot):
	move_count += 1
	if not timer_node.timer_started:
		timer_node.start_timer()
	# Update the occupied_by property of the slot
	slot.occupied_by = card

	# Optional: Disable the card's dragging after placement
	if card.has_method("set_can_drag"):
		card.set_can_drag(true)

	if check_sorting_order():
		ToastParty.show(
			{
				"text": "Cards are sorted! Press 'Finish Game' to complete! 🎉",
				"bgcolor": Color(0.2, 0.8, 0.2, 0.8),
				"color": Color(1, 1, 1, 1),
				"gravity": "bottom",
				"direction": "center",
				"text_size": 16,
				"use_font": true
			}
		)


func _on_show_sorted_cards_button_pressed() -> void:
	var cards_are_sorted = check_sorting_order()

	if cards_are_sorted:
		# Cards are sorted - finish the game
		_finish_game()
	else:
		# Cards not sorted - show/hide the sorted reference
		_toggle_sorted_cards_panel()


func _finish_game() -> void:
	"""Called when player finishes the game (cards are sorted)"""
	# Prevent multiple windows - check both flag and instance validity
	if finish_window_open or (finish_window_instance and is_instance_valid(finish_window_instance)):
		logger.log_warning("Finish window already open, ignoring duplicate request")
		return

	# Mark window as open IMMEDIATELY to prevent race conditions
	finish_window_open = true

	# Disable the button to prevent multiple clicks
	if show_sorted_button:
		show_sorted_button.disabled = true

	# Stop the timer
	if timer_node:
		timer_node.stop_timer()
	else:
		logger.log_warning("timer_node is null in _finish_game()")

	# Get final time and move count
	var final_time_string = timer_node.getCurrentTimeAsString()
	var final_move_count = move_count

	logger.log_info("Game finished! Time: ", final_time_string, " Moves: ", final_move_count)

	# Show finish game scene
	_show_finish_game_scene(final_time_string, final_move_count)


func _show_finish_game_scene(
	time_string: String, moves: int, finishing_player_id: int = -1
) -> void:
	"""Load and display the finish game scene"""
	if not finish_game_scene:
		logger.log_error("CardManager: Failed to load FinishGameScene.tscn")
		_show_completion_toast(time_string, moves)
		return

	# Instantiate the scene
	var finish_instance = finish_game_scene.instantiate()

	# Store reference for cleanup
	finish_window_instance = finish_instance

	# Connect to window close signal
	if finish_instance.has_signal("window_closed"):
		finish_instance.window_closed.connect(_on_finish_window_closed)
	else:
		logger.log_warning("FinishGameScene missing window_closed signal")

	# Add to tree first so @onready variables are initialized
	get_tree().root.add_child(finish_instance)
	await get_tree().process_frame

	# Now call methods that depend on @onready variables
	finish_instance.set_game_stats(time_string, moves, finishing_player_id)
	finish_instance.set_time(time_string)
	finish_instance.set_moves(moves)


func _show_completion_toast(time_string: String, moves: int) -> void:
	"""Fallback: Show completion message as toast"""
	var text_to_show = "Cards sorted successfully in %s with %d moves! 👍" % [time_string, moves]
	ToastParty.show(
		{
			"text": text_to_show,
			"bgcolor": Color(0, 0, 0, 0.7),
			"color": Color(1, 1, 1, 1),
			"gravity": "top",
			"direction": "center",
			"text_size": 20,
			"use_font": true
		}
	)


func _toggle_sorted_cards_panel() -> void:
	"""Toggle the sorted cards reference panel"""
	var text_to_show = "Cards are NOT sorted! 😒"

	if not sorted_cards_panel.visible:
		ToastParty.show(
			{
				"text": text_to_show,
				"bgcolor": Color(0, 0, 0, 0.7),
				"color": Color(1, 1, 1, 1),
				"gravity": "top",
				"direction": "left",
				"text_size": 18,
				"use_font": true
			}
		)

	# Toggle visibility
	sorted_cards_panel.visible = not sorted_cards_panel.visible

	# Update button text
	if sorted_cards_panel.visible:
		show_sorted_button.text = "Hide Sorted Cards"
	else:
		show_sorted_button.text = "Finish Game!"


func _setup_button_glow_animation(button: Button):
	# Define base and glow colors
	var base_button_color: Color = Color.GRAY
	var glow_button_color: Color = Color.CHOCOLATE

	# Attempt to get the existing normal stylebox or create a new one
	var stylebox_normal: StyleBoxFlat = null

	# Check if the button already has a theme override for "normal" stylebox
	if button.has_theme_stylebox_override("normal"):
		var existing_override = button.get_theme_stylebox_override("normal")
		if existing_override is StyleBoxFlat:
			stylebox_normal = existing_override.duplicate(true) # Duplicate to avoid modifying shared resource
			base_button_color = stylebox_normal.bg_color # Use its current color as base
		else:
			# If it's not a StyleBoxFlat, we create a new one
			stylebox_normal = StyleBoxFlat.new()
			stylebox_normal.bg_color = base_button_color # Default base
	elif button.theme and button.theme.has_stylebox("normal", button.get_class()):
		var theme_stylebox = button.theme.get_stylebox("normal", button.get_class())
		if theme_stylebox is StyleBoxFlat:
			stylebox_normal = theme_stylebox.duplicate(true) # Duplicate from theme
			base_button_color = stylebox_normal.bg_color
		else:
			stylebox_normal = StyleBoxFlat.new()
			stylebox_normal.bg_color = base_button_color
	else:
		# If no stylebox found, create a new one
		stylebox_normal = StyleBoxFlat.new()
		stylebox_normal.bg_color = base_button_color

	# Apply the (potentially new or duplicated) stylebox to the button's normal state
	button.add_theme_stylebox_override("normal", stylebox_normal)

	# Ensure other states don't look too different or also get a basic stylebox if they have none
	# This part is optional and depends on your theme setup.
	# For simplicity, we'll only animate the 'normal' state's bg_color.
	# If you want hover/pressed states to also reflect the glow, you'd need to
	# create/duplicate and manage their styleboxes similarly.

	# Create a tween to animate the bg_color
	var tween = get_tree().create_tween() # Use get_tree().create_tween() for persistent tweens
	tween.set_loops() # Loop indefinitely

	# Animate from base_button_color to glow_button_color
	tween.tween_property(stylebox_normal, "bg_color", glow_button_color, 3)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Animate from glow_button_color back to base_button_color
	tween.tween_property(stylebox_normal, "bg_color", base_button_color, 3)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func animate_card_swap(card_a, card_b):
	# Kill any existing tweens on these cards_array
	var tweens_to_kill = []
	for node in [card_a, card_b]:
		for tween in node.get_children():
			if tween is Tween:
				tweens_to_kill.append(tween)

	for tween in tweens_to_kill:
		tween.kill()

	# Store original positions
	var pos_a = card_a.global_position
	var pos_b = card_b.global_position

	# Create a single tween for the entire animation
	var tween = create_tween()
	tween.set_parallel(true)

	# First step: Move cards_array up
	tween.tween_property(card_a, "position:y", card_a.position.y - 30, 0.2)
	tween.tween_property(card_b, "position:y", card_b.position.y - 30, 0.2)

	# Wait for up movement to complete
	tween.chain()

	# Second step: Move horizontally
	tween.tween_property(card_a, "global_position:x", pos_b.x, 0.3)
	tween.tween_property(card_b, "global_position:x", pos_a.x, 0.3)

	# Wait for horizontal movement
	tween.chain()

	# Third step: Move down
	tween.tween_property(card_a, "position:y", card_a.position.y, 0.2)
	tween.tween_property(card_b, "position:y", card_b.position.y, 0.2)

	return tween


func check_sorting_order() -> bool:
	var sorted_correctly = true
	if card_container.get_child_count() != num_cards:
		logger.log_info("Card count mismatch!")
		return false
	var cards_in_container: Array[Card] = []
	for child in card_container.get_children():
		if child is Card:
			cards_in_container.append(child as Card)
	# Check if the cards_array are sorted
	for i in range(1, cards_in_container.size()):
		var current_card = cards_in_container[i].value
		var previous_card = cards_in_container[i - 1].value
		if current_card < previous_card:
			logger.log_info(
				(
					"cards_array[%d] = %d < cards_array[%d] = %d"
					% [i, current_card, i - 1, previous_card]
				)
			)
			sorted_correctly = false
			break
	if not sorted_correctly:
		logger.log_warning("Cards not sorted correctly!")
	return sorted_correctly
	# Calculate the time taken


func _on_finish_window_closed():
	"""Handle finish window closing - reset state and re-enable button"""
	logger.log_info("Finish window closed, resetting state")

	finish_window_open = false
	finish_window_instance = null

	# Re-enable the finish button
	if show_sorted_button:
		show_sorted_button.disabled = false


func _exit_tree():
	"""Clean up finish window when scene exits"""
	if finish_window_instance and is_instance_valid(finish_window_instance):
		logger.log_info("Scene exiting, cleaning up finish window")
		finish_window_instance.queue_free()
		finish_window_instance = null


func check_player_buffer_contiguity() -> bool:
	# Build a list of all card values from your cards_array array
	# Get buffer values in order from slots
	var buffer_values = []
	for slot in slots:
		if slot.occupied_by == null:
			logger.log_info("Buffer not full")
			return false # Buffer not full
		buffer_values.append(slot.occupied_by.value)

	# Now check if buffer_values is a contiguous subsequence of sorted_all
	return SubarrayUtils.is_contiguous_subarray(sorted_all, buffer_values)
