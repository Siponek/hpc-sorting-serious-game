extends PanelContainer

const CardScene: PackedScene = preload(
	ProjectFiles.Scenes.CARD_MAIN
)

@onready var thread_label: Label = $VBoxContainer/ThreadLabel
@onready
var card_container: HBoxContainer = $VBoxContainer/ScrollContainer/CardContainer

var owner_thread_id: int = -1
var card_instances: Dictionary = {}  # card_value: Card
var scroll_container_ref: ScrollContainer = null
@onready var logger = CustomLogger.get_logger(self)


func setup(
	player_id: int,
	player_name: String,
	card_values: Array,
	scroll_container: ScrollContainer = null
):
	owner_thread_id = player_id
	scroll_container_ref = scroll_container
	thread_label.text = player_name + "'s Buffer"

	for value in card_values:
		add_card(value)


func add_card(card_value: int):
	var card: Card = CardScene.instantiate()
	if scroll_container_ref != null:
		card.set_card_scroll_container(scroll_container_ref)
	else:
		(
			logger
			. log_warning(
				"ThreadBufferPanel: No scroll container reference provided for card, dragging may not work properly."
			)
		)
	card.set_card_value(card_value)
	card.buffer_view_source_id = owner_thread_id
	card.set_can_drag(true)

	# Set card size (mini card)
	card.custom_minimum_size = Vector2(60, 80)

	# Set color
	var style = StyleBoxFlat.new()
	style.bg_color = Settings.card_colors[
		card_value % Settings.card_colors.size()
	]
	card.set_base_style(style)

	card_container.add_child(card)
	card_instances[card_value] = card


func remove_card(card_value: int):
	if card_value in card_instances:
		card_instances[card_value].queue_free()
		card_instances.erase(card_value)


func get_card_count() -> int:
	return card_instances.size()
