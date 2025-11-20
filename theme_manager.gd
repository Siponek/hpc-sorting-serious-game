extends Node

signal theme_changed(theme_name)

# Available themes
enum ThemeType {
	DEFAULT,
	DARK,
	NEON,
	PASTEL,
	MONOCHROME
}

# Preload all theme resources
var themes = {
	ThemeType.DEFAULT: preload(ProjectFiles.Resources.MENU_THEME),
	ThemeType.DARK: preload(ProjectFiles.Resources.DARK_THEME),
}

# Theme names for UI
var theme_names = {
	ThemeType.DEFAULT: "Default",
	ThemeType.DARK: "Dark Mode",
}

# Current active theme
var current_theme: ThemeType = ThemeType.DEFAULT:
	set(value):
		if current_theme != value:
			current_theme = value
			theme_changed.emit(theme_names[current_theme])
			save_theme_preference()

# Track which themes the player has unlocked
var unlocked_themes = {
	ThemeType.DEFAULT: true, # Default theme is always unlocked
	ThemeType.DARK: false,
}

func _ready():
	load_theme_preference()

# Get the current theme resource
func get_theme() -> Theme:
	return themes[current_theme]

# Get a user-friendly name for a theme
func get_theme_name(theme_enum: ThemeType) -> String:
	return theme_names[theme_enum]

# Unlock a new theme and notify the player
func unlock_theme(theme: ThemeType) -> bool:
	if unlocked_themes.has(theme) and not unlocked_themes[theme]:
		unlocked_themes[theme] = true
		save_unlocked_themes()
		return true
	return false # Already unlocked or invalid theme

# Switch to a different theme
func switch_theme(theme: ThemeType) -> bool:
	if unlocked_themes.has(theme) and unlocked_themes[theme]:
		current_theme = theme
		return true
	return false # Not unlocked or invalid theme

# Check if a theme is unlocked
func is_theme_unlocked(theme: ThemeType) -> bool:
	return unlocked_themes.has(theme) and unlocked_themes[theme]

# Get a list of all unlocked themes
func get_unlocked_themes() -> Array:
	var result = []
	for theme in unlocked_themes.keys():
		if unlocked_themes[theme]:
			result.append(theme)
	return result

# Save the current theme preference
func save_theme_preference():
	var config = ConfigFile.new()
	config.set_value("theme", "current_theme", current_theme)
	config.save("user://theme_settings.cfg")

# Save the unlocked themes
func save_unlocked_themes():
	var config = ConfigFile.new()
	for theme in unlocked_themes.keys():
		config.set_value("unlocked_themes", str(theme), unlocked_themes[theme])
	config.save("user://theme_unlocks.cfg")

# Load the saved theme preference
func load_theme_preference():
	var config = ConfigFile.new()
	var err = config.load("user://theme_settings.cfg")
	if err == OK:
		current_theme = config.get_value("theme", "current_theme", ThemeType.DEFAULT)

	# Load unlocked themes
	err = config.load("user://theme_unlocks.cfg")
	if err == OK:
		for theme in unlocked_themes.keys():
			unlocked_themes[theme] = config.get_value("unlocked_themes", str(theme), theme == ThemeType.DEFAULT)
