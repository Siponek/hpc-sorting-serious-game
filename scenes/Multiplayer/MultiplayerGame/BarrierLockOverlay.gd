extends CanvasLayer

@onready
var status_label: Label = $OverlayRect/CenterContainer/VBoxContainer/StatusLabel


func show_overlay(main_thread_name: String):
	status_label.text = (
		"Main thread (" + main_thread_name + ") is processing..."
	)
	visible = true


func hide_overlay():
	visible = false
