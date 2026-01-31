extends Node

var player_buffer_count: int
var cards_count: int
var card_value_range: int
var can_cards_be_repeated: bool = false
var barrier_mode: int = 0  # 0 = "First to reach barrier", 1 = "Round-robin"
# FLags
var is_multiplayer: bool = false