extends Node

## GDSyncWebPatch.gd
## Autoload that patches GD-Sync to use WebRTC on web platform
## This script must be loaded AFTER GDSync in project.godot autoloads

var logger: ColorfulLogger
var _patch_applied: bool = false


func _init() -> void:
	# Use print for early debugging before logger is available
	print("[GDSyncWebPatch] _init called - OS.has_feature('web') = ", OS.has_feature("web"))


func _ready() -> void:
	logger = Logger.get_logger(self)

	print("[GDSyncWebPatch] _ready called")

	# Only apply patch for web exports
	if not OS.has_feature("web"):
		print("[GDSyncWebPatch] Not a web platform - skipping patch")
		logger.log_info("Not a web platform - GD-Sync patch not needed.")
		return

	print("[GDSyncWebPatch] Web platform detected - will apply patch immediately")
	logger.log_info("Web platform detected - applying GD-Sync WebRTC patch...")

	# Apply patch IMMEDIATELY - don't wait for process frames
	# This is critical because ConnectionManager might call ensure_multiplayer_started() right away
	_apply_web_patch()


func _apply_web_patch() -> void:
	print("[GDSyncWebPatch] _apply_web_patch() starting...")

	var gdsync = get_node_or_null("/root/GDSync")
	if not gdsync:
		print("[GDSyncWebPatch] ERROR: GDSync autoload not found!")
		logger.log_error("GDSync autoload not found! Cannot apply web patch.")
		return

	print("[GDSyncWebPatch] Found GDSync node")

	# Get the original LocalServer node
	var original_local_server = gdsync.get_node_or_null("LocalServer")
	if not original_local_server:
		print("[GDSyncWebPatch] ERROR: LocalServer not found in GDSync!")
		logger.log_error(
			"GDSync LocalServer not found! Cannot apply web patch."
		)
		return

	print("[GDSyncWebPatch] Found original LocalServer: ", original_local_server)

	# Disable and rename the original LocalServer
	original_local_server.name = "LocalServer_Original_Disabled"
	original_local_server.set_process(false)
	original_local_server.set_physics_process(false)
	print("[GDSyncWebPatch] Disabled original LocalServer")

	# Create and add the web-compatible LocalServer
	var web_local_server = (
		preload("res://scenes/Multiplayer/LocalServerWebPatch.gd").new()
	)
	web_local_server.name = "LocalServer"
	gdsync.add_child(web_local_server)
	print("[GDSyncWebPatch] Added new WebRTC LocalServer")

	# Update GDSync's reference to use the new LocalServer
	gdsync._local_server = web_local_server
	print("[GDSyncWebPatch] Updated gdsync._local_server reference")

	# Also update ConnectionController's reference
	if gdsync._connection_controller:
		print("[GDSyncWebPatch] Found ConnectionController, checking for local_server property...")
		if "local_server" in gdsync._connection_controller:
			gdsync._connection_controller.local_server = web_local_server
			print("[GDSyncWebPatch] Updated connection_controller.local_server reference")
		else:
			print("[GDSyncWebPatch] ConnectionController doesn't have local_server property")
	else:
		print("[GDSyncWebPatch] No ConnectionController found")

	_patch_applied = true
	print("[GDSyncWebPatch] PATCH APPLIED SUCCESSFULLY!")
	logger.log_info("GD-Sync WebRTC patch applied successfully!")
	logger.log_info("Multiplayer will use PackRTC WebRTC signaling on web.")
