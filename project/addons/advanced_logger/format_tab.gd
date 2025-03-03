@tool
class_name FormatTab
extends RefCounted
## Format tab for configuring log output display

# References to parent and container
var tab_container: TabContainer
var parent_dock: Control
var logger: Logger

# UI Controls
var show_timestamp_check: CheckBox
var show_tags_check: CheckBox
var use_colors_check: CheckBox
var preview_label: RichTextLabel
var apply_button: Button

func _init(p_parent_dock: Control, p_logger: Logger, p_tab_container: TabContainer) -> void:
	parent_dock = p_parent_dock
	logger = p_logger
	tab_container = p_tab_container

	_setup_ui()
	_connect_signals()
	_update_ui_from_logger()

# Create the UI for the format tab
func _setup_ui() -> void:
	if not tab_container:
		push_error("Tab container is null, cannot create format tab UI")
		return

	var tab: VBoxContainer = VBoxContainer.new()
	if not tab:
		push_error("Failed to create format tab container")
		return

	tab.name = "Format"
	tab_container.add_child(tab)

	# Add a ScrollContainer to handle overflow
	var scroll: ScrollContainer = ScrollContainer.new()
	if not scroll:
		push_error("Failed to create scroll container")
		return

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var main_container: VBoxContainer = VBoxContainer.new()
	if not main_container:
		push_error("Failed to create main container")
		return

	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(main_container)

	# Display Options Section
	var display_section: VBoxContainer = _create_section(main_container, "Display Options")
	if not display_section:
		push_error("Failed to create display section")
		return

	var display_grid: GridContainer = GridContainer.new()
	if not display_grid:
		push_error("Failed to create display grid")
		return

	display_grid.columns = 1
	display_section.add_child(display_grid)

	show_timestamp_check = CheckBox.new()
	if not show_timestamp_check:
		push_error("Failed to create timestamp checkbox")
		return

	show_timestamp_check.text = "Show Timestamp"
	display_grid.add_child(show_timestamp_check)

	show_tags_check = CheckBox.new()
	if not show_tags_check:
		push_error("Failed to create tags checkbox")
		return

	show_tags_check.text = "Show Tags"
	display_grid.add_child(show_tags_check)

	use_colors_check = CheckBox.new()
	if not use_colors_check:
		push_error("Failed to create colors checkbox")
		return

	use_colors_check.text = "Use Colors"
	display_grid.add_child(use_colors_check)

	# Preview Section
	var preview_section: VBoxContainer = _create_section(main_container, "Preview")
	if not preview_section:
		push_error("Failed to create preview section")
		return

	preview_label = RichTextLabel.new()
	if not preview_label:
		push_error("Failed to create preview label")
		return

	preview_label.bbcode_enabled = true
	preview_label.custom_minimum_size = Vector2(0, 150)
	preview_label.fit_content = true
	preview_section.add_child(preview_label)

	# Apply Button
	apply_button = Button.new()
	if not apply_button:
		push_error("Failed to create apply button")
		return

	apply_button.text = "Apply Settings"
	apply_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.add_child(apply_button)

# Create a section with title
func _create_section(parent: Container, title: String) -> VBoxContainer:
	if not parent or title.is_empty():
		push_error("Invalid parameters for create_section")
		return null

	var section: VBoxContainer = VBoxContainer.new()
	if not section:
		push_error("Failed to create section container")
		return null

	parent.add_child(section)

	var header: Label = Label.new()
	if not header:
		push_error("Failed to create section header")
		return section # Return the section even without header

	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	return section

# Connect UI signals
func _connect_signals() -> void:
	if not show_timestamp_check or not show_tags_check or not use_colors_check or not apply_button:
		push_error("Cannot connect signals: UI controls not initialized")
		return

	# Connect checkboxes
	show_timestamp_check.toggled.connect(_on_setting_changed)
	show_tags_check.toggled.connect(_on_setting_changed)
	use_colors_check.toggled.connect(_on_setting_changed)
	apply_button.pressed.connect(_apply_settings)

# Update the preview when settings change
func _on_setting_changed(_value: bool) -> void:
	if not preview_label:
		push_error("Preview label is null")
		return
	_update_preview()

# Update UI from logger settings
func _update_ui_from_logger() -> void:
	if not logger or not show_timestamp_check or not show_tags_check or not use_colors_check:
		push_error("Cannot update UI: logger or UI controls not initialized")
		return

	show_timestamp_check.button_pressed = logger._show_timestamp
	show_tags_check.button_pressed = logger._show_tags
	use_colors_check.button_pressed = logger._use_colors

	_update_preview()

# Apply settings to logger
func _apply_settings() -> void:
	if not logger or not parent_dock:
		push_error("Cannot apply settings: logger or parent dock not initialized")
		return

	if not show_timestamp_check or not show_tags_check or not use_colors_check:
		push_error("Cannot apply settings: UI controls not initialized")
		return

	logger.set_show_timestamp(show_timestamp_check.button_pressed)
	logger.set_show_tags(show_tags_check.button_pressed)
	logger.set_use_colors(use_colors_check.button_pressed)

	# Save settings
	var result: Error = LoggerSettings.save_settings(logger)
	if result != OK:
		push_error("Failed to save format settings: %d" % result)
		return

	print_rich("[color=green]Format settings applied and saved[/color]")

	# Notify that settings changed
	parent_dock.settings_changed.emit()

# Update the preview with current settings
func _update_preview() -> void:
	if not logger or not preview_label:
		push_error("Cannot update preview: logger or preview label not initialized")
		return

	if not show_timestamp_check or not show_tags_check or not use_colors_check:
		push_error("Cannot update preview: UI controls not initialized")
		return

	# Create temporary log entry for preview
	var sample_tags: Array[String] = ["tag1", "tag2"]
	var sample_source: Dictionary = {"file": "res://scripts/example.gd", "line": 42, "function": "do_something"}

	var entry: Logger.LogEntry = Logger.LogEntry.new(
		Logger.LogLevel.INFO,
		"This is a sample log message",
		sample_tags,
		sample_source
	)

	if not entry:
		push_error("Failed to create sample log entry")
		return

	# Temporarily set logger settings to match UI
	var original_show_timestamp: bool = logger._show_timestamp
	var original_show_tags: bool = logger._show_tags
	var original_use_colors: bool = logger._use_colors

	logger._show_timestamp = show_timestamp_check.button_pressed
	logger._show_tags = show_tags_check.button_pressed
	logger._use_colors = use_colors_check.button_pressed

	# Format the preview
	var formatted: String = logger._format_entry(entry)

	# Restore original settings
	logger._show_timestamp = original_show_timestamp
	logger._show_tags = original_show_tags
	logger._use_colors = original_use_colors

	# Set preview text
	preview_label.text = formatted
