extends Node

var current_scene: Node = null

func _ready():
	var root = get_tree().root
	# Using a negative index counts from the end, so this gets the last child node of `root`.
	current_scene = root.get_child(root.get_child_count() - 1)

func goto_scene(res_path):
	# This function will usually be called from a signal callback,
	# or some other function in the current scene.
	# Deleting the current scene at this point is
	# a bad idea, because it may still be executing code.
	# This will result in a crash or unexpected behavior.
	# The solution is to defer the load to a later time, when
	# we can be sure that no code from the current scene is running:
	#Check if the res_path is valid
	if not ResourceLoader.exists(res_path):
		ToastParty.show({
			"text": "Error: Scene path does not exist: " + res_path, # Text (emojis can be used)
			"bgcolor": Color(0, 0, 0, 0.7), # Background Color
			"color": Color(1, 1, 1, 1), # Text Color
			"gravity": "top", # top or bottom
			"direction": "left", # left or center or right
			"text_size": 18, # [optional] Text (font) size // experimental (warning!)
			"use_font": true # [optional] Use custom ToastParty font // experimental (warning!)
		})
		print("Error: Scene path does not exist: " + res_path)
		return
	_deferred_goto_scene.call_deferred(res_path)


func _deferred_goto_scene(res_path):
	# It is now safe to remove the current scene.
	current_scene.free()

	# Load the new scene.
	var s = ResourceLoader.load(res_path)

	# Instance the new scene.
	current_scene = s.instantiate()
	_on_scene_changed(current_scene)
	# Add it to the active scene, as child of root.
	get_tree().root.add_child(current_scene)

	# Optionally, to make it compatible with the SceneTree.change_scene_to_file() API.
	get_tree().current_scene = current_scene

func _on_scene_changed(new_scene):
	# Apply theme to the new scene
	new_scene.theme = ThemeManager.get_theme()