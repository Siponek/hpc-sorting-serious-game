extends PanelContainer

signal barrier_requested
signal release_requested

@onready
var status_label: Label = $%BarrierStatusLabel
@onready
var thread_status_container: VBoxContainer = $%ThreadStatusContainer
@onready
var barrier_button: Button = $%BarrierButton
@onready
var done_button: Button = $%DoneButton

var thread_status_labels: Dictionary = {} # player_id: Label


func _ready():
	barrier_button.pressed.connect(_on_barrier_button_pressed)
	done_button.pressed.connect(_on_done_button_pressed)


func _on_barrier_button_pressed():
	barrier_requested.emit()


func _on_done_button_pressed():
	release_requested.emit()


func update_status(text: String):
	status_label.text = "Status: " + text


# TODO need to make the labels one under another, and add a header for the waiting list
func add_thread_status(player_id: int, player_name: String):
	var label = Label.new()
	label.text = "Thread " + player_name + ": Running"
	thread_status_container.add_child(label)
	thread_status_labels[player_id] = label

# func set_waiting_threads(player_names: Array[String]):
# var label_text = "Waiting for: " + ", ".join(player_names)
# var label = Label.new()
# label.text = label_text
# thread_status_container.add_child(label)

func set_waiting_for_players(waiting_player_names: Array[String]):
	"""Display a grouped list of players we're waiting for"""
	clear_thread_statuses()

	if waiting_player_names.is_empty():
		return

	# Add header label
	var header_label = Label.new()
	header_label.text = "Waiting for:"
	header_label.add_theme_color_override("font_color", Color.YELLOW)
	thread_status_container.add_child(header_label)

	# Add each waiting player as a bullet point
	for player_name in waiting_player_names:
		var player_label = Label.new()
		player_label.text = "  - " + player_name
		thread_status_container.add_child(player_label)

func set_main_thread_active(main_thread_name: String, is_me: bool):
	"""Update label to show main thread is active"""
	clear_thread_statuses() # Clear old "Waiting for" labels
	var label = Label.new()
	if is_me:
		label.text = "You are the main thread - Processing buffers..."
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		label.text = "Main thread active: " + main_thread_name
		label.add_theme_color_override("font_color", Color.YELLOW)
	thread_status_container.add_child(label)


func set_thread_at_barrier(player_id: int, at_barrier: bool):
	if player_id in thread_status_labels:
		var label = thread_status_labels[player_id]
		if at_barrier:
			label.text = label.text.replace("Running", "At Barrier")
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.text = label.text.replace("At Barrier", "Running")
			label.remove_theme_color_override("font_color")


func clear_thread_statuses():
	for label in thread_status_labels.values():
		label.queue_free()
	thread_status_labels.clear()
	# Also clear all other children (like "Waiting for:" labels)
	for child in thread_status_container.get_children():
		child.queue_free()


func set_barrier_state(is_waiting: bool, is_main_thread: bool, is_active: bool):
	"""Update button visibility based on barrier state"""
	if is_active:
		barrier_button.visible = false
		done_button.visible = is_main_thread
		if is_main_thread:
			update_status("Main Thread Active")
		else:
			update_status("Blocked at Barrier")

	elif is_waiting:
		barrier_button.disabled = true
		barrier_button.text = "At Barrier..."
		done_button.visible = false
		update_status("Waiting for other threads")
	else:
		barrier_button.visible = true
		barrier_button.disabled = false
		barrier_button.text = "Reach Barrier"
		done_button.visible = false
		update_status("Running")


func reset_ui():
	clear_thread_statuses()
	update_status("Running")
	set_barrier_state(false, false, false)
