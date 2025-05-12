extends Window

func _ready():
	# Optional: set modal, center on parent, etc.
	popup_centered()
	self.size = $VBoxContainer.get_combined_minimum_size()


func _on_start_button_pressed() -> void:
	# Get values from the SpinBoxes
	var buffer_slots_count = $VBoxContainer/BufferSpinBox.value
	var cards_count = $VBoxContainer/CardCountSpinBox.value
	var card_range = $VBoxContainer/CardRangeSpinBox.value
	print("Settings -> Buffer slots: " + str(buffer_slots_count))
	print("Settings -> Number of cards: " + str(cards_count))
	print("Settings -> Card value range: " + str(card_range))
	# Save these options, for example in a global (autoload) settings singleton:
	Settings.player_buffer_count = int(buffer_slots_count)
	Settings.cards_count = int(cards_count)
	Settings.card_value_range = int(card_range)
	
	# Then switch to the singleplayer game scene
	SceneManager.goto_scene("res://scenes/singleplayer-scene.tscn")