extends Node2D

@export var card_scene: PackedScene
@export var slot_scene: PackedScene
@export_range(1, 20) var num_cards: int = 10
@export_range(100, 200) var card_spacing: int = 120
@export var slot_spacing: int = 120

var cards = []
var slots = []
var values = []

func _ready():
	# Generate random card values
	randomize()
	for i in range(num_cards):
		values.append(randi() % 100)

	# Create slots
	create_slots()

	# Create cards
	create_cards()

func create_slots():
	var slot_container = $CenterContainer/PanelContainer/SlotContainer

	for i in range(num_cards):
		var slot: Control = slot_scene.instantiate()

		slot.slot_text = str(i + 1)
		slot.position.x = i * card_spacing
		slot_container.add_child(slot)
		slots.append(slot)
	await get_tree().process_frame

func create_cards():
	var card_container = $CardContainer

	for i in range(num_cards):
		var card_instance: Control = card_scene.instantiate()
		card_instance.set_card_value(values[i])
		card_instance.position.x = i * card_spacing

		# Connect signals
		card_instance.card_grabbed.connect(_on_card_grabbed)
		card_instance.card_dropped.connect(_on_card_dropped)

		card_container.add_child(card_instance)
		cards.append(card_instance)

func _on_card_grabbed(card):
	# Bring card to front
	card.get_parent().move_child(card, -1)

func _on_card_dropped(card, drop_position):
	var found_slot = false

	# Check if card is over a slot
	for slot in slots:
		var slot_global_rect = Rect2(slot.global_position, slot.size)

		if slot_global_rect.has_point(drop_position):
			# Check if slot is empty
			var slot_empty = true
			for other_card in cards:
				if other_card != card and other_card.current_slot == slot:
					slot_empty = false
					break

			if slot_empty:
				card.position = slot.position + Vector2(5, 5) # Small offset
				card.place_in_slot(slot)
				found_slot = true
				check_sorting_order()
				break

	if not found_slot:
		card.remove_from_slot()
		card.reset_position()

func check_sorting_order():
	# Check if all cards are in slots and in correct order
	var all_cards_in_slots = true
	var sorted_correctly = true

	var slot_values = []

	for slot in slots:
		var found = false
		for card in cards:
			if card.current_slot == slot:
				slot_values.append(card.value)
				found = true
				break

		if not found:
			all_cards_in_slots = false
			break

	if all_cards_in_slots:
		# Check if sorted
		for i in range(1, slot_values.size()):
			if slot_values[i] < slot_values[i - 1]:
				sorted_correctly = false
				break

		if sorted_correctly:
			print_rich("[color=green]Congratulations! Cards sorted correctly![/color]")
