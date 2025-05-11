extends Control

# var SubarrayUtils = preload("res://res/algorithms/SubarrayUtils.gd")

# @export var card_scene: PackedScene
@export_range(10, 200) var button_spacing: int = 10
@export_range(10, 200) var card_spacing: int = 10

var slots = [] # Array to store slot references
var cards = []
var values = []
var sorted_all = []
var buffer_size: int = Settings.player_buffer
var num_cards: int = Settings.num_cards
const CARD_WIDTH = 70
var move_count: int = 0
var timer_started: bool = false
var is_animating = false # Flag to track animation state
# TODO would be cool to add coloring/theme selection to main menu,
# so players can choose if they want rainbow or now
var card_colors = [
	Color.STEEL_BLUE.lightened(0.1),
	Color.SEA_GREEN.lightened(0.1),
	Color.GOLDENROD.lightened(0.1),
	Color.SLATE_BLUE.lightened(0.1),
	Color.INDIAN_RED.lightened(0.1),
	Color.DARK_KHAKI.lightened(0.1)
]


const card_scene: PackedScene = preload("res://scenes/CardScene/CardMain.tscn")
const swap_button_scene: PackedScene = preload("res://scenes/CardScene/swapBtn.tscn")
const toast_notification_scene: PackedScene = preload("res://scenes/toast_notification.tscn")
const card_slot_scene: PackedScene = preload("res://scenes/CardScene/CardSlot.tscn")

@onready var button_container: HBoxContainer = $SwapButtonPanel/CenterContainer/SwapButtonContainer
@onready var card_container: HBoxContainer = $CardPanel/ScrollContainer/MarginContainer/CardContainer
@onready var slot_container: HBoxContainer = $BufferZonePanel/MarginContainer/VBoxContainer/SlotContainer
@onready var timer_node: PanelContainer = get_node("./../TopBar/TimerPanel")
@onready var mini_buffer_container: HBoxContainer = get_node("./../SortedCardsBufferPanel/HBoxContainer")
@onready var scroll_container_node: ScrollContainer = $CardPanel/ScrollContainer

func _ready():
	var max_cards = calculate_max_cards()
	print("Max cards: " + str(max_cards), "Num cards: " + str(num_cards))
	# num_cards = min(num_cards, max_cards)
	if num_cards < 1:
		num_cards = 1
		push_warning("Screen too small - can only fit 1 card")
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(num_cards):
		values.append(rng.randi_range(1, Settings.card_value_range))
	sorted_all = values.duplicate()
	sorted_all.sort() # ascending order
	# Update layout in the editor
	adjust_container_spacing()
	create_cards()
	create_buffer_slots()
	if scroll_container_node != null:
		# Ensure the signal exists on scroll_container_node
		if scroll_container_node.has_signal("card_dropped_card_container"):
			# Connect to a method in CardManager that accepts a Card argument.
			# Let's assume you have or create a method like _on_card_dropped_from_scroll_container
			var error_code = scroll_container_node.connect("card_dropped_card_container", self._on_card_placed_in_container)
			if error_code == OK:
				print_debug("CardManager: Successfully connected scroll_container's card_dropped_card_container to _on_card_dropped_from_scroll_container.")
			else:
				printerr("CardManager: Failed to connect scroll_container's signal. Error code: %s" % error_code)
		else:
			printerr("CardManager: ScrollContainer node does not have signal 'card_dropped_card_container'.")
	else:
		printerr("CardManager: ScrollContainer node not found. Check path: $CardPanel/ScrollContainer")
	
	# wait 1 frame for scaling down
	await get_tree().process_frame
	# To make the contents smaller
	mini_buffer_container.scale = Vector2(0.5, 0.5)
	if scroll_container_node != null:
		if scroll_container_node.has_signal("card_dropped_card_container"):
			scroll_container_node.card_dropped_card_container.connect(check_sorting_order)
			print_debug("CardManager: Connected to card_dropped_card_container signal from ScrollContainer.")
		else:
			printerr("CardManager: ScrollContainer node does not have signal 'card_dropped_card_container'.")
	else:
		printerr("CardManager: ScrollContainer node not found at path: CardPanel/ScrollContainer")


func calculate_max_cards():
	# Get screen width from constants
	var screen_width = Constants.SCREEN_WIDTH
	
	# Account for margins (e.g., 10% of screen width for padding)
	var usable_width = screen_width * 0.9
	
	# Get card width from constant or scene
	var total_card_width = CARD_WIDTH + card_spacing
	
	# Calculate max cards that can fit
	var max_cards = int(usable_width / total_card_width)
	
	# Ensure at least 2 cards (for sorting to make sense)
	return max(2, max_cards)

func adjust_container_spacing():
	# Calculate available width (80% of screen width for cards)
	var available_width = Constants.SCREEN_WIDTH * 0.8
	
	# Calculate total width taken by cards
	var total_card_width = num_cards * CARD_WIDTH
	
	# Compute maximum spacing allowed (ensuring it doesn't exceed a chosen cap, e.g., 100)
	var max_spacing = min(100, int((available_width - total_card_width) / (num_cards - 1)))
	
	# Ensure a minimum spacing of 10
	card_spacing = max(10, max_spacing / 2)
	# Apply spacing to the card container so that cards are properly separated
	card_container.add_theme_constant_override("separation", card_spacing * 0.8)

	# TODO Manual spaccing for buttons, doing it via container is impossible beacause of the way it calculates the spacing
	# Place the cards in container, calculate the positions and place the swap buttons there
	button_spacing = (card_spacing * 2) + CARD_WIDTH - Constants.BUTTON_WIDTH
	button_container.add_theme_constant_override("separation", button_spacing)
	
	# For the first button, set an offset so that its center lies directly in the gap between the first two cards.
	# This offset is half the difference between the card width and the button width.
	var first_button_offset: int = int((CARD_WIDTH - Constants.BUTTON_WIDTH) / 2.0)
	$SwapButtonPanel/CenterContainer.add_theme_constant_override("margin_left", first_button_offset)
	
	print_debug("Max spacing set to: " + str(max_spacing))
	print_debug("Card spacing set to: " + str(card_spacing))
	print_debug("Button spacing set to: " + str(button_spacing))
	print_debug("Button container offset: " + str(first_button_offset))

func create_cards():
	for card_node in cards:
		if is_instance_valid(card_node):
			card_node.queue_free()
	cards.clear()
	for child in card_container.get_children():
		child.queue_free()

	for i in range(num_cards):
		var card_instance = card_scene.instantiate()
		card_instance.set_card_value(values[i])
		card_instance.name = "Card_" + str(i) + "_Val_" + str(values[i])
		var new_card_style = StyleBoxFlat.new()
		new_card_style.bg_color = card_colors[i % card_colors.size()]
		card_instance.set_base_style(new_card_style)
		# Add card to the container
		card_container.add_child(card_instance)
		# Save the initial relative position and the child index
		card_instance.container_relative_position = card_instance.position
		card_instance.original_index = card_instance.get_index()
		
		cards.append(card_instance)

func create_buffer_slots():
	# Clear any existing slots
	for child in slot_container.get_children():
		child.queue_free()
	
	slots.clear()
	
	# Create new slots based on buffer_size
	for i in range(buffer_size):
		var slot = card_slot_scene.instantiate()
		slot.slot_text = "Slot " + str(i + 1)
		slot_container.add_child(slot)
		slots.append(slot)
	
	# You might want to connect signals from slots to your manager
	for slot in slots:
		# Optional: Connect any custom signals from your slot script
		if slot.has_signal("card_placed_in_slot"):
			slot.card_placed_in_slot.connect(_on_card_placed_in_slot)

func _on_card_placed_in_container():
	move_count += 1
	if not timer_started:
		timer_node.start_timer()
		timer_started = true

func _on_card_placed_in_slot(card, slot):
	move_count += 1
	if not timer_started:
		timer_node.start_timer()
		timer_started = true
	# Update the occupied_by property of the slot
	slot.occupied_by = card

	# Optional: Disable the card's dragging after placement
	if card.has_method("set_can_drag"):
		card.set_can_drag(true)
	
	# Optional: Play a sound effect
	# if $PlacementSound:
	#     $PlacementSound.play()

func animate_card_swap(card_a, card_b):
	# Kill any existing tweens on these cards
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
	
	# First step: Move cards up
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
	
func check_sorting_order():
	var sorted_correctly = true
	if card_container.get_child_count() != num_cards:
		print_debug("Card count mismatch!")
		return false
	var cards_in_container: Array[Card] = []
	for child in card_container.get_children():
		if child is Card:
			cards_in_container.append(child as Card)
	# Check if the cards are sorted
	for i in range(1, cards_in_container.size()):
		var current_card = cards_in_container[i].value
		var previous_card = cards_in_container[i - 1].value
		if current_card < previous_card:
			print_debug("cards[%d] = %d < cards[%d] = %d" % [i, current_card, i - 1, previous_card])
			sorted_correctly = false
			break
	if not sorted_correctly:
		print("Cards not sorted correctly!")
		return
	# Calculate the time taken
	var timer_node_time: int = timer_node.getCurrentTime()
	
	# Format the time taken
	var seconds = int(timer_node_time) % 60
	var minutes = int(float(timer_node_time) / 60)
	var time_string = "%02d:%02d" % [minutes, seconds]
	
	# Create the toast notification text
	var toast_text = "Cards sorted successfully in %s with %d moves!" % [time_string, move_count]
	
	# Create the toast notification instance
	var toast = toast_notification_scene.instantiate()
	
	# Add the toast notification to the scene
	add_child(toast)
	
	# Set the toast notification text
	toast.popup(toast_text)
	
	print_rich("[color=green]Congratulations! Cards sorted correctly![/color]")

func check_player_buffer_contiguity() -> bool:
	# Build a list of all card values from your cards array
	# Get buffer values in order from slots
	var buffer_values = []
	for slot in slots:
		if slot.occupied_by == null:
			print_debug("Buffer not full")
			return false # Buffer not full
		buffer_values.append(slot.occupied_by.value)
	
	# Now check if buffer_values is a contiguous subsequence of sorted_all
	return SubarrayUtils.is_contiguous_subarray(sorted_all, buffer_values)
