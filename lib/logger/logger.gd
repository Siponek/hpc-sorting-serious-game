extends Node

var _loggers: Dictionary = {}


# Get logger with automatic name detection from calling script
func get_logger(caller: Object = null) -> ColorfulLogger:
	var _name: String

	if caller != null and caller.get_script() != null:
		# Extract _name from the caller's script path
		var script_path = caller.get_script().resource_path
		var base_name = script_path.get_file().get_basename()

		# Try to append game_debug_id if Constants is ready
		var debug_id = Constants.get_game_debug_id()
		if debug_id != "":
			_name = "%s-Client%s" % [base_name, debug_id]
		else:
			_name = base_name
	else:
		# Fallback to generic _name
		_name = "Unknown"

	if not _loggers.has(_name):
		_loggers[_name] = ColorfulLogger.new(_name)

	return _loggers[_name]


# Alternative: explicit _name override
func get_logger_by_name(_name: String) -> ColorfulLogger:
	if not _loggers.has(_name):
		_loggers[_name] = ColorfulLogger.new(_name)
	return _loggers[_name]


# Update logger name after game_debug_id is parsed
func update_logger_name(old_logger: ColorfulLogger, new_name: String) -> ColorfulLogger:
	var old_name = old_logger._client_name
	if _loggers.has(old_name):
		_loggers.erase(old_name)

	if not _loggers.has(new_name):
		_loggers[new_name] = ColorfulLogger.new(new_name)

	return _loggers[new_name]
