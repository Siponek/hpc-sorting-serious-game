extends Window

func _ready():
	# Optional: set modal, center on parent, etc.
	popup_centered()
	self.size = $VBoxContainer.get_combined_minimum_size()


func _on_start_button_pressed() -> void:
	# Get values from the SpinBoxes
	var buffer_slots = $VBoxContainer/BufferSpinBox.value
	var num_cards = $VBoxContainer/CardCountSpinBox.value
	var card_range = $VBoxContainer/CardRangeSpinBox.value
	print("Settings -> Buffer slots: " + str(buffer_slots))
	print("Settings -> Number of cards: " + str(num_cards))
	print("Settings -> Card value range: " + str(card_range))
	# Save these options, for example in a global (autoload) settings singleton:
	Settings.player_buffer = int(buffer_slots)
	Settings.num_cards = int(num_cards)
	Settings.card_value_range = int(card_range)
	
	# Then switch to the singleplayer game scene
	SceneManager.goto_scene("res://scenes/singleplayer-scene.tscn")