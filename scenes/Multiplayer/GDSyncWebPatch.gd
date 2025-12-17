extends Node

## GDSyncWebPatch.gd
## Autoload that patches GD-Sync to use WebRTC on web platform
## This script must be loaded AFTER GDSync in project.godot autoloads

var logger: ColorfulLogger
var _patch_applied: bool = false

# Use the new signaling-based LocalServer
const web_local_server_script = preload(
	ProjectFiles.Scripts.LOCAL_SERVER_SIGNALING
)


func _ready() -> void:
	logger = CustomLogger.get_logger(self)

	# Only apply patch for web exports
	if not OS.has_feature("web"):
		return

	_apply_web_patch()


func _apply_web_patch() -> void:
	var gdsync = get_node_or_null("/root/GDSync")
	if not gdsync:
		logger.log_error("GDSync autoload not found! Cannot apply web patch.")
		return

	# Get the original LocalServer node
	var original_local_server = gdsync.get_node_or_null("LocalServer")
	if not original_local_server:
		logger.log_error(
			"GDSync LocalServer not found! Cannot apply web patch."
		)
		return

	# Disable and rename the original LocalServer
	original_local_server.name = "LocalServer_Original_Disabled"
	original_local_server.set_process(false)
	original_local_server.set_physics_process(false)

	# Create and add the web-compatible LocalServer
	var web_local_server = web_local_server_script.new()
	web_local_server.name = "LocalServer"
	gdsync.add_child(web_local_server)

	# Update GDSync's reference to use the new LocalServer
	gdsync._local_server = web_local_server

	# Also update ConnectionController's reference if it exists
	if (
		gdsync._connection_controller
		and "local_server" in gdsync._connection_controller
	):
		gdsync._connection_controller.local_server = web_local_server

	_patch_applied = true
	logger.log_info(
		"GD-Sync WebRTC patch applied for web platform (using SignalingClient)."
	)
