extends Control

# @export var card_scene: PackedScene
@export_range(1, 20) var num_cards: int = 10
@export_range(50, 200) var card_spacing: int = 10

var cards = []
var values = []
const CARD_WIDTH = 100
var is_animating = false # Flag to track animation state

const card_scene: PackedScene = preload("res://scenes/CardScene/CardMain.tscn")
const swap_button_scene: PackedScene = preload("res://scenes/CardScene/swapBtn.tscn")

@onready var button_container: HBoxContainer = $SwapButtonPanel/CenterContainer/SwapButtonContainer
@onready var card_container: HBoxContainer = $CardPanel/CenterContainer/CardContainer

func _ready():
	# Calculate maximum cards that can fit on screen
	var max_cards = calculate_max_cards()
	
	# Cap the number of cards to what can fit on screen
	num_cards = min(num_cards, max_cards)
	
	if num_cards < 1:
		num_cards = 1
		push_warning("Screen too small - can only fit 1 card")
	
	# Generate random card values
	randomize()
	for i in range(num_cards):
		values.append(randi() % 100)
	
	# Adjust container separation based on available space
	adjust_container_spacing()
	
	# Create cards
	create_cards()
	
	# Create swap buttons between cards
	create_swap_buttons()
	
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
	# Calculate available width (80% of screen for cards)
	var available_width = Constants.SCREEN_WIDTH * 0.8
	
	# Calculate optimal spacing based on number of cards
	var total_card_width = num_cards * CARD_WIDTH
	var max_spacing = min(100, int((available_width - total_card_width) / (num_cards - 1)))
	
	# Choose a comfortable spacing that fits on screen
	card_spacing = max(10, max_spacing)
	
	# Apply spacing to card container
	card_container.add_theme_constant_override("separation", card_spacing)
	
	# Calculate button container spacing to align buttons with gaps between cards
	# For n cards, we need n-1 buttons positioned at the midpoints between cards
	var button_width = 40 # Approximate width of swap button
	
	# Match button spacing to card spacing + card width - button width
	# This positions button centers at the midpoints between card centers
	var button_spacing = card_spacing + CARD_WIDTH - button_width
	button_container.add_theme_constant_override("separation", button_spacing)
	
	# Adjust button container offset to align first button with gap between first two cards
	# Position the button container with an initial offset to align first button properly
	var first_button_offset = (CARD_WIDTH - button_width) / 2
	$SwapButtonPanel/CenterContainer.add_theme_constant_override("margin_left", first_button_offset)
	
	print("Card spacing set to: " + str(card_spacing))
	print("Button spacing set to: " + str(button_spacing))
	print("Button container offset: " + str(first_button_offset))

func create_cards():
	for i in range(num_cards):
		var card_instance = card_scene.instantiate()
		card_instance.set_card_value(values[i])
		# Let the container handle positioning
		card_container.add_child(card_instance)
		cards.append(card_instance)

func create_swap_buttons():
	# Create n-1 swap buttons (one between each pair of cards)
	for i in range(num_cards - 1):
		var swap_button = swap_button_scene.instantiate()
		# Connect button to swap function
		swap_button.pressed.connect(_on_swap_button_pressed.bind(i))
		# Add to container (let container handle positioning)
		button_container.add_child(swap_button)

func _on_swap_button_pressed(index):
	# Skip if already animating
	if is_animating:
		return
		
	# Set animating flag to prevent multiple animations
	is_animating = true
		
	# Swap cards at index and index+1
	await swap_cards(index, index + 1)
	
	# Check if sorting is complete
	check_sorting_order()

func swap_cards(index_a, index_b):
	# Disable all swap buttons during animation
	var buttons = button_container.get_children()
	for button in buttons: button.disabled = !button.disabled
	
	# Disable card interaction
	for card in cards:
		if card.has_method("set_can_drag"):
			card.set_can_drag(false)
	
	# Animate the swap
	var tween = animate_card_swap(cards[index_a], cards[index_b])
	
	# Wait for animation to complete
	await tween.finished
	
	# Swap cards in the array
	var temp_card = cards[index_a]
	cards[index_a] = cards[index_b]
	cards[index_b] = temp_card
	
	# Re-enable all buttons
	for button in buttons: button.disabled = !button.disabled
	
	# Re-enable card interaction
	for card in cards:
		if card.has_method("set_can_drag"):
			card.set_can_drag(true)
	
	# Reset animation flag
	is_animating = false
	
	print("Swapped cards: " + str(cards[index_b].value) + " and " + str(cards[index_a].value))

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
		print_rich("[color=green]Congratulations! Cards sorted correctly![/color]")