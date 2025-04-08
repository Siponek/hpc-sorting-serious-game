extends Control


func _ready() -> void:
	var button_width = Constants.BUTTON_WIDTH
	var button_height = Constants.BUTTON_HEIGHT # Half the normal button height
	self.custom_minimum_size = Vector2(button_width, button_height)