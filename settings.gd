extends Node

var player_buffer_count: int
var cards_count: int
var card_value_range: int
var can_cards_be_repeated: bool = false
### 0 = "First to reach barrier", 1 = "Round-robin". Round robin is deprecated..
var barrier_mode: int = 0
# FLags
var is_multiplayer: bool = false

# TODO move this to a separate file with constants or something
var card_colors: Array[Color] = [
	Color.STEEL_BLUE,
	Color.SEA_GREEN,
	Color.GOLDENROD,
	Color.SLATE_BLUE,
	Color.INDIAN_RED,
	Color.DARK_KHAKI,
	Color.FIREBRICK,
	Color.DARK_CYAN,
	Color.DARK_MAGENTA,
	Color.OLIVE_DRAB,
	Color.PURPLE,
	Color.TEAL,
	Color.CHOCOLATE,
	Color.CRIMSON,
	Color.DARK_ORCHID
]
