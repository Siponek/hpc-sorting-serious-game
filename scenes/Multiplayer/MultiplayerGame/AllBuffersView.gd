extends PanelContainer

const ThreadBufferPanel = preload(
	"res://scenes/Multiplayer/MultiplayerGame/ThreadBufferPanel.tscn"
)

@onready
var buffers_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/BuffersContainer

var buffer_panels: Dictionary = {}  # player_id: ThreadBufferPanel


func add_thread_buffer(player_id: int, player_name: String, card_values: Array):
	var panel = ThreadBufferPanel.instantiate()
	buffers_container.add_child(panel)
	panel.setup(player_id, player_name, card_values)
	buffer_panels[player_id] = panel


func remove_card_from_buffer(card_value: int, player_id: int):
	if player_id in buffer_panels:
		buffer_panels[player_id].remove_card(card_value)


func clear_buffers():
	for panel in buffer_panels.values():
		panel.queue_free()
	buffer_panels.clear()


func show_view():
	visible = true


func hide_view():
	visible = false
	clear_buffers()
