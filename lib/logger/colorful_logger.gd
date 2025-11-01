class_name ColorfulLogger

enum LogLevel {INFO, WARNING, ERROR}
enum ClientColor {
	AQUA, HOT_PINK, YELLOW, CYAN,
	ORANGE, MAGENTA, LIME, GOLD,
	SKY_BLUE, CORAL, CHARTREUSE, SALMON,
	FUCHSIA, LIGHT_BLUE, LIGHT_CORAL, PINK
}
const LOG_LEVEL_COLORS: Dictionary[LogLevel, String] = {
	LogLevel.INFO: "green",
	LogLevel.WARNING: "yellow",
	LogLevel.ERROR: "red",
}
# Generate color order array from enum automatically
static func _generate_client_color_order() -> Array[ClientColor]:
	var result: Array[ClientColor] = []
	for color_name in ClientColor.keys():
		result.append(ClientColor[color_name])
	return result

# Generate color names dictionary from enum automatically
static func _generate_client_color_names() -> Dictionary[ClientColor, String]:
	var result: Dictionary[ClientColor, String] = {}
	for color_name in ClientColor.keys():
		var color_value = ClientColor[color_name]
		result[color_value] = color_name.to_lower()
	return result

static var CLIENT_COLOR_ORDER := _generate_client_color_order()
static var CLIENT_COLOR_NAMES := _generate_client_color_names()

var _client_name: String
var _client_color_enum: ClientColor
var _client_color: String
var _color_initialized: bool = false


func _init(p_client_name: String):
	_client_name = p_client_name
	# Don't pick color yet - wait until first log call


func _ensure_color_initialized() -> void:
	if _color_initialized:
		return

	_color_initialized = true

	# Now Constants is ready (called from log functions which run after _ready)
	var debug_id: String = Constants.get_game_debug_id()
	var count := CLIENT_COLOR_ORDER.size()

	if debug_id != "" and debug_id.is_valid_int():
		# Use debug_id for color (all loggers in same client get same color)
		var idx := int(debug_id) % count
		_client_color_enum = CLIENT_COLOR_ORDER[idx]
	else:
		# Fallback to name hash
		var idx: int = abs(_client_name.hash()) % count
		_client_color_enum = CLIENT_COLOR_ORDER[idx]

	_client_color = CLIENT_COLOR_NAMES[_client_color_enum]


# --- internals ---


func _timestamp() -> String:
	# e.g. "13:47:26.123"
	var ms := str(Time.get_ticks_msec() % 1000).pad_zeros(3)
	return "%s.%s" % [Time.get_datetime_string_from_system().substr(11, 8), ms]


func _callsite(depth: int = 2) -> Dictionary:
	# depth: 1 = _print_colored, 2 = log_*(), 3 = caller of log_*()
	var st := get_stack()
	if st.is_empty():
		return {"source": "res://unknown", "line": 0, "function": "<unknown>"}
	var idx: int = clamp(depth, 0, st.size() - 1)
	return st[idx]


func _print_colored(level: LogLevel, message: String) -> void:
	_ensure_color_initialized() # Initialize color on first use

	var level_color := LOG_LEVEL_COLORS[level]
	var level_text: String = LogLevel.keys()[level]
	var cs := _callsite(3) # Adjusted depth to get actual caller

	# Clickable location in editor output: res://file.gd:line
	var loc := (
		"%s:%d" % [cs.get("source", "res://unknown"), int(cs.get("line", 0))]
	)
	var func_name := str(cs.get("function", "<unknown>"))

	# Editor automatically detects res://...:line as clickable
	var meta := (
		"[color=#888](%s @ %s)[/color]" % [loc, func_name]
	)

	print_rich(
		(
			"[color=#aaa]%s[/color] [color=%s][%s][/color] [color=%s]%s:[/color] %s %s"
			% [
				_timestamp(),
				_client_color,
				_client_name,
				level_color,
				level_text,
				message,
				meta
			]
		)
	)


# --- public API ---

func log_info(message: String, arg1=null, arg2=null, arg3=null, arg4=null, arg5=null, arg6=null, arg7=null, arg8=null, arg9=null, arg10=null) -> void:
	var full_message = _format_message(message, [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10])
	_print_colored(LogLevel.INFO, full_message)


func log_warning(message: String, arg1=null, arg2=null, arg3=null, arg4=null, arg5=null, arg6=null, arg7=null, arg8=null, arg9=null, arg10=null) -> void:
	var full_message = _format_message(message, [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10])
	_print_colored(LogLevel.WARNING, full_message)


func log_error(message: String, arg1=null, arg2=null, arg3=null, arg4=null, arg5=null, arg6=null, arg7=null, arg8=null, arg9=null, arg10=null) -> void:
	var full_message = _format_message(message, [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10])
	_print_colored(LogLevel.ERROR, full_message)


func _format_message(base_message: String, args: Array) -> String:
	var parts = [base_message]
	for arg in args:
		if arg != null:
			parts.append(str(arg))
	return " ".join(parts)
