extends Node

# Screen resolution constants
const SCREEN_WIDTH: int = 1151
const SCREEN_HEIGHT: int = 649

# UI element sizing constants
const BUTTON_WIDTH: int = 40
const BUTTON_HEIGHT: int = 50
const BUTTON_SPACING: int = 10
const CARD_WIDTH: int = 100
const CARD_HEIGHT: int = 150
const DEBUG_MODE: bool = true

var arguments = {}
const DEFAULT_MULTIPLAYER_PORT: int = 7777
var logger := Logger.get_logger_by_name("constants-init")
var _game_debug_id: String = ""  # Cache the parsed ID


func _ready():
	parse_game_debug_id()


func parse_game_debug_id() -> void:
	var temp = OS.get_cmdline_args()
	logger.log_info("Parsing game debug ID from arguments:", temp)
	for argument in temp:
		if argument.contains("="):
			var key_value = argument.split("=")
			arguments[key_value[0].trim_prefix("--")] = key_value[1]
		else:
			# Options without an argument will be present in the dictionary,
			# with the value set to an empty string.
			arguments[argument.trim_prefix("--")] = ""

	# Cache the game_debug_id
	if arguments.has("game_debug_id"):
		_game_debug_id = arguments["game_debug_id"]
	else:
		logger.log_warning("No game_debug_id found in arguments")


func get_game_debug_id() -> String:
	return _game_debug_id


func get_multiplayer_port() -> int:
	if arguments.has("port"):
		return int(arguments["port"])
	else:
		return DEFAULT_MULTIPLAYER_PORT
