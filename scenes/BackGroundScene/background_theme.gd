extends Control

@onready var color_rect = $ColorRect


func _ready():
	# Wait for scene tree to be fully initialized
	await get_tree().process_frame

	# Force initial resize
	_resize_background()

	# Connect to viewport size changes for window resizing
	get_viewport().size_changed.connect(_resize_background)


func _resize_background():
	# Get current viewport size
	var viewport_size = get_viewport().get_visible_rect().size

	# Resize the background control to match
	size = viewport_size

	# The ColorRect child will automatically fill due to its anchors
	# But we can also explicitly set it if needed
	color_rect.size = viewport_size
