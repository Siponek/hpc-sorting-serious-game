extends Control

# @export var card_scene: PackedScene
@export_range(1, 20) var num_cards: int = 10
@export_range(10, 200) var button_spacing: int = 10
@export_range(10, 200) var card_spacing: int = 10
@export var buffer_size: int = 5 # Number of buffer slots

var slots = [] # Array to store slot references
var cards = []
var values = []
const CARD_WIDTH = 70
var start_time: float
var move_count: int = 0

var is_animating = false # Flag to track animation state

const card_scene: PackedScene = preload("res://scenes/CardScene/CardMain.tscn")
const swap_button_scene: PackedScene = preload("res://scenes/CardScene/swapBtn.tscn")
const toast_notification_scene: PackedScene = preload("res://scenes/toast_notification.tscn")
const card_slot_scene: PackedScene = preload("res://scenes/CardScene/CardSlot.tscn")

@onready var button_container: HBoxContainer = $SwapButtonPanel/CenterContainer/SwapButtonContainer
@onready var card_container: HBoxContainer = $CardPanel/CenterContainer/CardContainer
@onready var slot_container = $BufferZonePanel/MarginContainer/VBoxContainer/SlotContainer

func _ready():
	var max_cards = calculate_max_cards()
	num_cards = min(num_cards, max_cards)
	if num_cards < 1:
		num_cards = 1
		push_warning("Screen too small - can only fit 1 card")
	
	randomize()
	for i in range(num_cards):
		values.append(randi() % 100)

	# Update layout in the editor
	adjust_container_spacing()
	create_cards()
	create_buffer_slots()
	start_time = Time.get_unix_time_from_system()

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
	var first_button_offset = (CARD_WIDTH - Constants.BUTTON_WIDTH) / 2
	$SwapButtonPanel/CenterContainer.add_theme_constant_override("margin_left", first_button_offset)
	
	print("Max spacing set to: " + str(max_spacing))
	print("Card spacing set to: " + str(card_spacing))
	print("Button spacing set to: " + str(button_spacing))
	print("Button container offset: " + str(first_button_offset))

func create_cards():
	for i in range(num_cards):
		var card_instance = card_scene.instantiate()
		card_instance.set_card_value(values[i])
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
		if slot.has_signal("card_placed"):
			slot.card_placed.connect(_on_card_placed_in_slot)

# Add this function to handle card placement in slots
func _on_card_placed_in_slot(card, slot):
	print("Card " + str(card.value) + " placed in slot " + slot.slot_text)
	
	# Update the occupied_by property of the slot
	slot.occupied_by = card
	
	# Check if all slots are filled and sorted properly
	check_buffer_sort_order()
	
	# Optional: Disable the card's dragging after placement
	if card.has_method("set_can_drag"):
		card.set_can_drag(false)
	
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
	
	# Check if the cards are sorted
	for i in range(1, cards.size()):
		if cards[i].value < cards[i - 1].value:
			sorted_correctly = false
			print("Cards not sorted correctly!")
			break
	
	if sorted_correctly:
		# Calculate the time taken
		var end_time = Time.get_unix_time_from_system()
		var time_taken = end_time - start_time
		
		# Format the time taken
		var minutes = int(time_taken / 60)
		var seconds = int(time_taken % 60)
		# var time_string = "%02d:%02d" % [minutes, seconds]
		var time_string = "30:30" % [minutes, seconds]
		
		# Create the toast notification text
		var toast_text = "Cards sorted successfully in %s with %d moves!" % [time_string, move_count]
		
		# Create the toast notification instance
		var toast = toast_notification_scene.instantiate()
		
		# Add the toast notification to the scene
		add_child(toast)
		
		# Set the toast notification text
		toast.popup(toast_text)
		
		print_rich("[color=green]Congratulations! Cards sorted correctly![/color]")

func check_buffer_sort_order():
	var all_slots_filled = true
	var cards_in_slots = []
	
	# Check if all slots are filled
	for slot in slots:
		if slot.occupied_by == null:
			all_slots_filled = false
			break
		cards_in_slots.append(slot.occupied_by)
	
	# If all slots are filled, check if cards are sorted
	if all_slots_filled:
		var sorted_correctly = true
		for i in range(1, cards_in_slots.size()):
			if cards_in_slots[i].value < cards_in_slots[i - 1].value:
				sorted_correctly = false
				break
		
		if sorted_correctly:
			# Show victory notification
			var toast = toast_notification_scene.instantiate()
			add_child(toast)
			toast.popup("Cards sorted correctly in the buffer zone!")
