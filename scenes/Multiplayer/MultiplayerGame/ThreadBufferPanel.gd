extends PanelContainer

const CardScene: PackedScene = preload(ProjectFiles.Scenes.CARD_MAIN)

@onready var thread_label: Label = $VBoxContainer/ThreadLabel
@onready
var card_container: HBoxContainer = $VBoxContainer/ScrollContainer/CardContainer

var owner_thread_id: int = -1
var card_instances: Dictionary = {}  # card_value: Card

# Card colors for visual consistency
var card_colors: Array[Color] = [
	Color("#FF6B6B"),
	Color("#4ECDC4"),
	Color("#45B7D1"),
	Color("#96CEB4"),
	Color("#FFEAA7"),
	Color("#DDA0DD"),
	Color("#98D8C8"),
	Color("#F7DC6F"),
	Color("#BB8FCE"),
	Color("#85C1E9"),
	Color("#F8B500"),
	Color("#00CED1"),
	Color("#FF7F50"),
	Color("#9ACD32"),
	Color("#FF69B4"),
	Color("#20B2AA")
]


func setup(player_id: int, player_name: String, card_values: Array):
	owner_thread_id = player_id
	thread_label.text = player_name + "'s Buffer"

	for value in card_values:
		add_card(value)


func add_card(card_value: int):
	var card: Card = CardScene.instantiate()
	card.set_card_value(card_value)
	card.buffer_view_source_id = owner_thread_id
	card.set_can_drag(true)

	# Set card size (mini card)
	card.custom_minimum_size = Vector2(60, 80)

	# Set color
	var style = StyleBoxFlat.new()
	style.bg_color = card_colors[card_value % card_colors.size()]
	card.set_base_style(style)

	card_container.add_child(card)
	card_instances[card_value] = card


func remove_card(card_value: int):
	if card_value in card_instances:
		card_instances[card_value].queue_free()
		card_instances.erase(card_value)


func get_card_count() -> int:
	return card_instances.size()
