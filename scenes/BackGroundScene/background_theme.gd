extends CanvasLayer

@onready var color_rect = $ColorRect


func _ready():
	# Access constants from your singleton
	color_rect.size = Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
	# Ensure it's positioned at the origin
	color_rect.position = Vector2.ZERO
