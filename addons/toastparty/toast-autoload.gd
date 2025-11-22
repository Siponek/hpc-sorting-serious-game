extends Node
const label_resource = preload("toast_label/toast_label.tscn")

var label_top_left = []
var label_top_right = []
var label_bottom_left = []
var label_bottom_right = []

var label_top_center = []
var label_bottom_center = []

# parent node
var canvas_layer: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("ToastPartyLayer")
	canvas_layer.layer = 1000
	add_child(canvas_layer)

	# TODO: We need Debounce function
	# Connect signal resize to _on_resize
	# get_tree().get_root().connect("size_changed", _on_resize, 1)

func _find_active_window() -> Window:
	"""Find the topmost visible Window in the scene tree"""
	var root = get_tree().root
	var children = root.get_children()

	if children.size() == 0:
		return null

	# The topmost (most recently added) node is the last child
	var topmost_child = children[-1]

	# Search within this topmost node for a Window
	return _search_for_window_recursive(topmost_child)

func _search_for_window_recursive(node: Node) -> Window:
	"""Recursively search for a visible Window node"""
	# Check if this node is a visible Window
	if node is Window and node.visible:
		return node

	# Search children recursively
	for child in node.get_children():
		var window = _search_for_window_recursive(child)
		if window:
			return window

	return null

func _get_or_create_window_canvas(window: Window) -> CanvasLayer:
	"""Get or create a CanvasLayer for toasts inside a Window"""
	var canvas = window.get_node_or_null("ToastPartyWindowLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "ToastPartyWindowLayer"
		canvas.layer = 100 # High layer to appear above Window content
		window.add_child(canvas)
	return canvas

func _add_new_label(config):
	# Create a new label
	var label = label_resource.instantiate()

	# Check if there's an active Window - if so, add toast to it
	var active_window = _find_active_window()

	if active_window:
		# Add to Window's internal canvas layer
		var window_canvas = _get_or_create_window_canvas(active_window)
		window_canvas.add_child(label)
	else:
		# Add to main canvas layer (regular scenes)
		canvas_layer.add_child(label)

	label.connect("remove_label", remove_label_from_array)

	if config.direction == "left":
		if config.gravity == "top":
			label_top_left.insert(0, label)
		else:
			label_bottom_left.insert(0, label)
	elif config.direction == "center":
		if config.gravity == "top":
			label_top_center.insert(0, label)
		else:
			label_bottom_center.insert(0, label)
	else:
		if config.gravity == "top":
			label_top_right.insert(0, label)
		else:
			label_bottom_right.insert(0, label)

	# Configuration of the label
	label.init(config)

	# Move all labels to new positions when a new label is added
	move_positions(config.direction, config.gravity)

func move_positions(direction, gravity):
	if direction == "left" and gravity == "bottom":
		_move_label_array(label_bottom_left)
	elif direction == "left" and gravity == "top":
		_move_label_array(label_top_left)
	elif direction == "right" and gravity == "bottom":
		_move_label_array(label_bottom_right)
	elif direction == "right" and gravity == "top":
		_move_label_array(label_top_right)
	elif direction == "center" and gravity == "bottom":
		_move_label_array(label_bottom_center)
	elif direction == "center" and gravity == "top":
		_move_label_array(label_top_center)

func _move_label_array(label_array: Array):
	"""Move labels in array, cleaning up freed ones"""
	var labels_to_remove = []

	for index in label_array.size():
		var _label = label_array[index]

		# Check if label is still valid (not freed)
		if is_instance_valid(_label):
			_label.move_to(index)
		else:
			# Mark for removal
			labels_to_remove.append(_label)

	# Clean up freed labels from array
	for freed_label in labels_to_remove:
		label_array.erase(freed_label)


func remove_label_from_array(label):
	# Check if label is still valid before accessing properties
	if not is_instance_valid(label):
		# Label already freed, try to remove from all arrays
		_cleanup_freed_labels()
		return

	if label.direction == "left":
		if label.gravity == "top":
			label_top_left.erase(label)
		else:
			label_bottom_left.erase(label)
	elif label.direction == "center":
		if label.gravity == "top":
			label_top_center.erase(label)
		else:
			label_bottom_center.erase(label)
	else:
		if label.gravity == "top":
			label_top_right.erase(label)
		else:
			label_bottom_right.erase(label)

func _cleanup_freed_labels():
	"""Remove all freed labels from tracking arrays"""
	_clean_array(label_top_left)
	_clean_array(label_top_right)
	_clean_array(label_top_center)
	_clean_array(label_bottom_left)
	_clean_array(label_bottom_right)
	_clean_array(label_bottom_center)

func _clean_array(label_array: Array):
	"""Remove freed labels from a specific array"""
	var labels_to_remove = []
	for label in label_array:
		if not is_instance_valid(label):
			labels_to_remove.append(label)

	for freed_label in labels_to_remove:
		label_array.erase(freed_label)

## Event resize
func _on_resize():
	var toast_labels = label_top_left + label_top_right + label_bottom_left + label_bottom_right + label_top_center + label_bottom_center
	for _label in toast_labels:
		_label.update_x_position()

func clean_config(config):
	if not config.has("text"):
		config.text = "🥑 toast party! 🥑"

	if not config.has("direction"):
		config.direction = "right"

	if not config.has("gravity"):
		config.gravity = "top"

	if not config.has("bgcolor"):
		config.bgcolor = Color(0, 0, 0, 0.7)

	if not config.has("color"):
		config.color = Color(1, 1, 1, 1)

	return config

func show(config={}):
	var _config_cleaned = clean_config(config)
	_add_new_label(_config_cleaned)
