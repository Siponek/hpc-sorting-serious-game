extends Window

@onready
var theme_option_button = $MarginContainer/VBoxContainer/ThemeSection/ThemeOptionButton
@onready
var theme_preview = $MarginContainer/VBoxContainer/ThemeSection/ThemePreview
@onready
var save_button = $MarginContainer/VBoxContainer/ButtonSection/SaveButton
@onready
var close_button = $MarginContainer/VBoxContainer/ButtonSection/CloseButton

var selected_theme = ThemeManager.current_theme


func _ready():
	# Connect signals
	close_button.pressed.connect(_on_close_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	theme_option_button.item_selected.connect(_on_theme_selected)

	# Set the dialog to close when clicking outside
	close_requested.connect(_on_close_button_pressed)

	# Populate theme dropdown with unlocked themes
	_populate_theme_dropdown()

	# Apply initial theme to preview
	_update_theme_preview()


func _populate_theme_dropdown():
	# Clear existing items
	theme_option_button.clear()

	# Add all themes, enabling only the unlocked ones
	for theme_id in ThemeManager.theme_names.keys():
		var theme_name = ThemeManager.get_theme_name(theme_id)
		var is_unlocked = ThemeManager.is_theme_unlocked(theme_id)

		theme_option_button.add_item(theme_name, theme_id)
		var item_index = theme_option_button.item_count - 1
		theme_option_button.set_item_disabled(item_index, !is_unlocked)

		# Select current theme
		if theme_id == ThemeManager.current_theme:
			theme_option_button.select(item_index)
			selected_theme = theme_id


func _on_theme_selected(index):
	var theme_id = theme_option_button.get_item_id(index)
	if ThemeManager.is_theme_unlocked(theme_id):
		selected_theme = theme_id
		_update_theme_preview()


func _update_theme_preview():
	# Apply the selected theme to the preview panel
	theme_preview.theme = ThemeManager.themes[selected_theme]


func _on_save_button_pressed():
	# Apply the selected theme
	if selected_theme != ThemeManager.current_theme:
		ThemeManager.switch_theme(selected_theme)

	# Close the dialog
	hide()
	queue_free()


func _on_close_button_pressed():
	# Close without saving
	hide()
	queue_free()
