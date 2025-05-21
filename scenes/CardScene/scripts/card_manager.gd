extends Control

# @export var card_scene: PackedScene
@export_range(10, 200) var button_spacing: int = 10
@export_range(10, 200) var card_spacing: int = 10

var slots: Array = [] # Array to store slot references
var cards_array: Array[Card] = []
var sorted_cards_array: Array[Card] = []
var values: Array[int] = []
var sorted_all = []
var buffer_size: int = Settings.player_buffer_count
var num_cards: int = Settings.cards_count
const CARD_WIDTH = 70
var move_count: int = 0
var timer_started: bool = false
var is_animating = false

# TODO would be cool to add coloring/theme selection to main menu,
# so players can choose if they want rainbow or now
	
var card_colors: Array[Color] = [
	Color.STEEL_BLUE,
	Color.SEA_GREEN,
	Color.GOLDENROD,
	Color.SLATE_BLUE,
	Color.INDIAN_RED,
	Color.DARK_KHAKI,
	Color.FIREBRICK,
	Color.DARK_CYAN,
	Color.DARK_MAGENTA,
	Color.OLIVE_DRAB,
	Color.PURPLE,
	Color.TEAL,
	Color.CHOCOLATE,
	Color.CRIMSON,
	Color.DARK_ORCHID
]


const ToastNotificationScript: Script = preload("res://scenes/CardScene/scripts/toast_notification.gd") # Preload the script
const card_scene: PackedScene = preload("res://scenes/CardScene/CardMain.tscn")
const swap_button_scene: PackedScene = preload("res://scenes/CardScene/swapBtn.tscn")
const toast_notification_scene: PackedScene = preload("res://scenes/toast_notification.tscn")
const card_slot_scene: PackedScene = preload("res://scenes/CardScene/CardSlot.tscn")

@onready var show_sorted_button: Button = get_node("./../RightSideButtonsContainer/ShowSortedCardsButton")
@onready var button_container: HBoxContainer = $SwapButtonPanel/CenterContainer/SwapButtonContainer
@onready var card_container: HBoxContainer = $CardPanel/ScrollContainer/MarginContainer/CardContainer
@onready var slot_container: HBoxContainer = $BufferZonePanel/MarginContainer/VBoxContainer/SlotContainer
@onready var timer_node: PanelContainer = get_node("./../TopBar/TimerPanel")
@onready var sorted_cards_container: HBoxContainer = get_node("./../SortedCardsPanel/ScrollContainer/MarginContainer/HBoxContainer")
@onready var sorted_cards_panel: PanelContainer = get_node("./../SortedCardsPanel")
@onready var scroll_container_node: ScrollContainer = $CardPanel/ScrollContainer

func _ready():
	card_colors.map(func(color: Color): return color.lightened(0.1))
	# 1. Initial calculations and data generation
	if num_cards < 1:
		num_cards = 1 # Ensure at least 1 card
		push_warning("CardManager: num_cards was less than 1, set to 1.")
		
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
	slots = create_buffer_slots() # This also connects signals from slots

	# 3. Validate critical node references
	if not _validate_node_references():
		push_error("CardManager: Critical node references are missing. Aborting further setup.")
		return # Stop further execution if essential nodes are missing

	# 4. Connect signals
	_connect_signals()

	# 5. Initial UI states
	if sorted_cards_panel != null: # sorted_cards_panel is checked in _validate_node_references
		sorted_cards_panel.visible = false
	
func fill_card_container(_card_instances_array: Array, _card_container: Node = null) -> void:
	if _card_container == null:
		push_error("CardManager: fill_card_container called with null _card_container.")
	# Clear existing children
	for child in _card_container.get_children():
		child.queue_free()
	
	# Add new card instances
	for card_instance in _card_instances_array:
		_card_container.add_child(card_instance)

func _validate_node_references() -> bool:
	var all_valid = true
	if not scroll_container_node:
		printerr("CardManager: scroll_container_node not found. Path: $CardPanel/ScrollContainer")
		all_valid = false
	if not card_container:
		printerr("CardManager: card_container not found. Path: $CardPanel/ScrollContainer/MarginContainer/CardContainer")
		all_valid = false
	if not slot_container:
		printerr("CardManager: slot_container not found. Path: $BufferZonePanel/MarginContainer/VBoxContainer/SlotContainer")
		all_valid = false
	if not timer_node:
		printerr("CardManager: timer_node not found. Path: ./../TopBar/TimerPanel")
		all_valid = false
	if not sorted_cards_container:
		printerr("CardManager: sorted_cards_container not found. Path: ./../SortedCardsPanel/ScrollContainer/MarginContainer/HBoxContainer")
		all_valid = false
	if not sorted_cards_panel:
		printerr("CardManager: sorted_cards_panel not found. Path: ./../SortedCardsPanel")
		all_valid = false
	if not show_sorted_button:
		printerr("CardManager: show_sorted_button not found. Path: ./../RightSideButtonsContainer/ShowSortedCardsButton")
		all_valid = false
	if not button_container:
		printerr("CardManager: button_container (for swap buttons) not found. Path: $SwapButtonPanel/CenterContainer/SwapButtonContainer")
		all_valid = false
		
	return all_valid

func _connect_signals():
	# Connect to ScrollContainer's signal for card drops
	if scroll_container_node: # Already validated in _validate_node_references
		if scroll_container_node.has_signal("card_dropped_card_container"):
			# Ensure _on_card_placed_in_container can accept a Card argument if the signal sends one
			# Or use a dedicated handler like _on_card_dropped_from_scroll_container(card: Card)
			var error_code = scroll_container_node.connect("card_dropped_card_container", Callable(self, "_on_card_placed_in_container"))
			if error_code == OK:
				print_debug("CardManager: Connected scroll_container_node.card_dropped_card_container to _on_card_placed_in_container.")
			else:
				printerr("CardManager: Failed to connect scroll_container_node.card_dropped_card_container. Error: %s" % error_code)
		else:
			printerr("CardManager: scroll_container_node does not have signal 'card_dropped_card_container'.")
	
	# Connect ShowSortedCardsButton
	if show_sorted_button: # Already validated
		if not show_sorted_button.is_connected("pressed", Callable(self, "_on_show_sorted_cards_button_pressed")):
			show_sorted_button.connect("pressed", Callable(self, "_on_show_sorted_cards_button_pressed"))
			_setup_button_glow_animation(show_sorted_button) # Setup glow after connecting
			print_debug("CardManager: Connected show_sorted_button.pressed to _on_show_sorted_cards_button_pressed.")
		else:
			print_debug("CardManager: show_sorted_button.pressed already connected.")
	
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
			push_error("Cannot generate %d unique cards_array from a range of 1 to %d. Allowing repeats." % [num_cards, Settings.card_value_range])
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
	card_container.add_theme_constant_override("separation", card_spacing * 0.8)
	sorted_cards_container.add_theme_constant_override("separation", card_spacing * 0.8)

	# TODO Manual spaccing for buttons, doing it via container is impossible beacause of the way it calculates the spacing
	# Place the cards_array in container, calculate the positions and place the swap buttons there
	button_spacing = (card_spacing * 2) + CARD_WIDTH - Constants.BUTTON_WIDTH
	button_container.add_theme_constant_override("separation", button_spacing)
	
	# For the first button, set an offset so that its center lies directly in the gap between the first two cards_array.
	# This offset is half the difference between the card width and the button width.
	var first_button_offset: int = int((CARD_WIDTH - Constants.BUTTON_WIDTH) / 2.0)
	$SwapButtonPanel/CenterContainer.add_theme_constant_override("margin_left", first_button_offset)
	
	print_debug("Max spacing set to: " + str(max_spacing))
	print_debug("Card spacing set to: " + str(card_spacing))
	print_debug("Button spacing set to: " + str(button_spacing))
	print_debug("Button container offset: " + str(first_button_offset))

func generate_completed_card_array(_values_for_cards: Array[int], _name_prefix: String = "Card_") -> Array[Card]:
	var array_to_be_filled: Array[Card] = []


	for i in range(num_cards):
		var card_instance = card_scene.instantiate()
		card_instance.set_card_value(_values_for_cards[i])
		card_instance.name = _name_prefix + str(i) + "_Val_" + str(_values_for_cards[i])
		var new_card_style = StyleBoxFlat.new()
		new_card_style.bg_color = card_colors[card_instance.value % card_colors.size()]
		card_instance.set_base_style(new_card_style)
		# Add card to the container
		# Save the initial relative position and the child index
		card_instance.container_relative_position = card_instance.position
		card_instance.original_index = card_instance.get_index()
		
		array_to_be_filled.append(card_instance)
	return array_to_be_filled

func create_buffer_slots() -> Array:
	var _slots: Array = []
	# Clear any existing slots
	for child in slot_container.get_children():
		child.queue_free()
	
	# Create new _slots based on buffer_size
	for i in range(buffer_size):
		var slot = card_slot_scene.instantiate()
		slot.slot_text = "Slot " + str(i + 1)
		slot_container.add_child(slot)
		_slots.append(slot)
	
	# You might want to connect signals from _slots to your manager
	for slot in _slots:
		# Optional: Connect any custom signals from your slot script
		if slot.has_signal("card_placed_in_slot"):
			slot.card_placed_in_slot.connect(_on_card_placed_in_slot)
	return _slots

func _on_card_placed_in_container():
	move_count += 1
	if not timer_started:
		timer_node.start_timer()
		timer_started = true
	if check_sorting_order():
		var text_to_show = "Cards are sorted! 👍"
		ToastParty.show({
			"text": text_to_show, # Text (emojis can be used)
			"bgcolor": Color(0, 0, 0, 0.7), # Background Color
			"color": Color(1, 1, 1, 1), # Text Color
			"gravity": "top", # top or bottom
			"direction": "left", # left or center or right
			"text_size": 18, # [optional] Text (font) size // experimental (warning!)
			"use_font": true # [optional] Use custom ToastParty font // experimental (warning!)
		})

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
	
	if check_sorting_order():
		var text_to_show = "Cards are sorted! 👍"
		ToastParty.show({
			"text": text_to_show, # Text (emojis can be used)
			"bgcolor": Color(0, 0, 0, 0.7), # Background Color
			"color": Color(1, 1, 1, 1), # Text Color
			"gravity": "top", # top or bottom
			"direction": "left", # left or center or right
			"text_size": 18, # [optional] Text (font) size // experimental (warning!)
			"use_font": true # [optional] Use custom ToastParty font // experimental (warning!)
		})

func _on_show_sorted_cards_button_pressed() -> void:
	var text_to_show = "Cards are sorted! 👍"
	if !check_sorting_order():
		text_to_show = "Cards are NOT sorted! 😒"
	ToastParty.show({
		"text": text_to_show, # Text (emojis can be used)
		"bgcolor": Color(0, 0, 0, 0.7), # Background Color
		"color": Color(1, 1, 1, 1), # Text Color
		"gravity": "top", # top or bottom
		"direction": "left", # left or center or right
		"text_size": 18, # [optional] Text (font) size // experimental (warning!)
		"use_font": true # [optional] Use custom ToastParty font // experimental (warning!)
	})
	# Toggle visibility
	sorted_cards_panel.visible = not sorted_cards_panel.visible

	if sorted_cards_panel.visible:
		show_sorted_button.text = "Hide Sorted Cards" # Update button text

	else:
		show_sorted_button.text = "Show Sorted Cards" # Reset button text

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
	
	print_debug("CardManager: Button color pulse animation setup complete for button: ", button.name)


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
		print_debug("Card count mismatch!")
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
			print_debug("cards_array[%d] = %d < cards_array[%d] = %d" % [i, current_card, i - 1, previous_card])
			sorted_correctly = false
			break
	if not sorted_correctly:
		print("Cards not sorted correctly!")
	return sorted_correctly
	# Calculate the time taken


func check_player_buffer_contiguity() -> bool:
	# Build a list of all card values from your cards_array array
	# Get buffer values in order from slots
	var buffer_values = []
	for slot in slots:
		if slot.occupied_by == null:
			print_debug("Buffer not full")
			return false # Buffer not full
		buffer_values.append(slot.occupied_by.value)
	
	# Now check if buffer_values is a contiguous subsequence of sorted_all
	return SubarrayUtils.is_contiguous_subarray(sorted_all, buffer_values)
