@tool
class_name FormatTab
extends RefCounted
## Output format tab class for log output customization

var tab_container: TabContainer
var parent_dock: Control
var format_settings: LoggerSettings.FormatSettings
var logger: Logger
var ui_builder: LoggerDock.UIBuilder
var preview_label: RichTextLabel
var debounce_timer: Timer
var apply_button: Button

# UI Controls for format options
var show_timestamp_check: CheckBox
var show_level_check: CheckBox
var show_tags_check: CheckBox
var show_context_check: CheckBox
var show_source_check: CheckBox

var layout_buttons: Array[Button] = []
var component_list: ItemList
var move_up_btn: Button
var move_down_btn: Button

var use_colors_check: CheckBox
var default_colors_check: Button
var custom_colors_check: Button
var color_pickers: Dictionary = {}

var path_mode_buttons: Array[Button] = []
var path_depth_spin: SpinBox

var timestamp_date_check: CheckBox
var timestamp_ms_check: CheckBox
var timestamp_24h_check: Button
var timestamp_12h_check: Button
var timestamp_local_check: Button
var timestamp_utc_check: Button

var context_multiline_check: CheckBox
var context_limit_check: CheckBox
var context_limit_spin: SpinBox

func _init(p_parent_dock: Control, p_logger: Logger, p_ui_builder: LoggerDock.UIBuilder, p_tab_container: TabContainer) -> void:
	parent_dock = p_parent_dock
	logger = p_logger
	ui_builder = p_ui_builder
	tab_container = p_tab_container

	# Get format settings from logger
	if logger.has("_format_settings"):
		format_settings = logger._format_settings
	else:
		format_settings = LoggerSettings.FormatSettings.new()
		logger.set("_format_settings", format_settings)

	# Create debounce timer
	debounce_timer = Timer.new()
	debounce_timer.one_shot = true
	debounce_timer.wait_time = 0.2
	parent_dock.add_child(debounce_timer)
	debounce_timer.timeout.connect(_on_preview_update)

	_setup_ui()
	_connect_signals()
	_update_ui_from_settings()

## Create the UI for the format tab
func _setup_ui() -> void:
	var tab = VBoxContainer.new()
	tab.name = "Output Format"
	tab_container.add_child(tab)

	# Add a ScrollContainer to handle overflow
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(main_container)

	# Basic Components Section
	var basic_section = ui_builder.create_section(main_container, "Basic Components")
	var basic_grid = GridContainer.new()
	basic_grid.columns = 3
	basic_section.add_child(basic_grid)

	show_timestamp_check = CheckBox.new()
	show_timestamp_check.text = "Show Timestamp"
	basic_grid.add_child(show_timestamp_check)

	show_level_check = CheckBox.new()
	show_level_check.text = "Show Log Level"
	basic_grid.add_child(show_level_check)

	show_tags_check = CheckBox.new()
	show_tags_check.text = "Show Tags"
	basic_grid.add_child(show_tags_check)

	show_context_check = CheckBox.new()
	show_context_check.text = "Show Context Data"
	basic_grid.add_child(show_context_check)

	show_source_check = CheckBox.new()
	show_source_check.text = "Show Source Information"
	basic_grid.add_child(show_source_check)

	# Layout Options Section
	var layout_section = ui_builder.create_section(main_container, "Layout Options")

	var layout_buttons_container = HBoxContainer.new()
	layout_section.add_child(layout_buttons_container)

	var layout_expanded_btn = Button.new()
	layout_expanded_btn.text = "Expanded (multiline)"
	layout_expanded_btn.toggle_mode = true
	layout_expanded_btn.button_pressed = true
	layout_expanded_btn.button_group = ButtonGroup.new()
	layout_buttons_container.add_child(layout_expanded_btn)

	var layout_compact_btn = Button.new()
	layout_compact_btn.text = "Compact (single line)"
	layout_compact_btn.toggle_mode = true
	layout_compact_btn.button_group = layout_expanded_btn.button_group
	layout_buttons_container.add_child(layout_compact_btn)

	var layout_custom_btn = Button.new()
	layout_custom_btn.text = "Custom (define order)"
	layout_custom_btn.toggle_mode = true
	layout_custom_btn.button_group = layout_expanded_btn.button_group
	layout_buttons_container.add_child(layout_custom_btn)

	layout_buttons = [layout_expanded_btn, layout_compact_btn, layout_custom_btn]

	# Component order list (only visible in custom mode)
	var component_order_container = VBoxContainer.new()
	component_order_container.name = "ComponentOrder"
	layout_section.add_child(component_order_container)

	var component_header = HBoxContainer.new()
	component_order_container.add_child(component_header)

	var component_label = Label.new()
	component_label.text = "Component Order:"
	component_header.add_child(component_label)

	var component_buttons = HBoxContainer.new()
	component_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_buttons.alignment = BoxContainer.ALIGNMENT_END
	component_header.add_child(component_buttons)

	move_up_btn = Button.new()
	move_up_btn.text = "Move Up"
	component_buttons.add_child(move_up_btn)

	move_down_btn = Button.new()
	move_down_btn.text = "Move Down"
	component_buttons.add_child(move_down_btn)

	component_list = ItemList.new()
	component_list.select_mode = ItemList.SELECT_SINGLE
	component_list.custom_minimum_size = Vector2(0, 120)
	component_order_container.add_child(component_list)

	# Initialize with default components
	component_list.add_item("Timestamp")
	component_list.add_item("Log Level")
	component_list.add_item("Tags")
	component_list.add_item("Message")
	component_list.add_item("Source Information")
	component_list.add_item("Context Data")

	# Color Settings Section
	var color_section = ui_builder.create_section(main_container, "Color Settings")

	use_colors_check = CheckBox.new()
	use_colors_check.text = "Enable Colored Output"
	color_section.add_child(use_colors_check)

	var color_type_container = HBoxContainer.new()
	color_section.add_child(color_type_container)

	default_colors_check = Button.new()
	default_colors_check.text = "Use Default Colors"
	default_colors_check.toggle_mode = true
	default_colors_check.button_pressed = true
	default_colors_check.button_group = ButtonGroup.new()
	color_type_container.add_child(default_colors_check)

	custom_colors_check = Button.new()
	custom_colors_check.text = "Use Custom Colors"
	custom_colors_check.toggle_mode = true
	custom_colors_check.button_group = default_colors_check.button_group
	color_type_container.add_child(custom_colors_check)

	# Color pickers container (only visible when custom colors selected)
	var color_pickers_container = GridContainer.new()
	color_pickers_container.name = "ColorPickers"
	color_pickers_container.columns = 3
	color_section.add_child(color_pickers_container)

	# Add color pickers for each log level and component
	_add_color_picker(color_pickers_container, "DEBUG", Color("#928374"))
	_add_color_picker(color_pickers_container, "INFO", Color("#83a598"))
	_add_color_picker(color_pickers_container, "WARNING", Color("#fabd2f"))
	_add_color_picker(color_pickers_container, "ERROR", Color("#fb4934"))
	_add_color_picker(color_pickers_container, "CRITICAL", Color("#fe8019"))
	_add_color_picker(color_pickers_container, "Timestamp", Color("#928374"))
	_add_color_picker(color_pickers_container, "Tags", Color("#8ec07c"))
	_add_color_picker(color_pickers_container, "Source", Color("#928374"))

	# Path Display Section
	var path_section = ui_builder.create_section(main_container, "Path Display")
	var path_buttons_container = HBoxContainer.new()
	path_section.add_child(path_buttons_container)

	var path_full_btn = Button.new()
	path_full_btn.text = "Full Path"
	path_full_btn.toggle_mode = true
	path_full_btn.button_group = ButtonGroup.new()
	path_buttons_container.add_child(path_full_btn)

	var path_filename_btn = Button.new()
	path_filename_btn.text = "Filename Only"
	path_filename_btn.toggle_mode = true
	path_filename_btn.button_pressed = true
	path_filename_btn.button_group = path_full_btn.button_group
	path_buttons_container.add_child(path_filename_btn)

	var path_short_btn = Button.new()
	path_short_btn.text = "Short Path"
	path_short_btn.toggle_mode = true
	path_short_btn.button_group = path_full_btn.button_group
	path_buttons_container.add_child(path_short_btn)

	var path_folders_btn = Button.new()
	path_folders_btn.text = "Limited Folders"
	path_folders_btn.toggle_mode = true
	path_folders_btn.button_group = path_full_btn.button_group
	path_buttons_container.add_child(path_folders_btn)

	path_mode_buttons = [path_full_btn, path_filename_btn, path_short_btn, path_folders_btn]

	var folder_depth_container = HBoxContainer.new()
	folder_depth_container.name = "FolderDepth"
	path_section.add_child(folder_depth_container)

	var folder_label = Label.new()
	folder_label.text = "Show Last"
	folder_depth_container.add_child(folder_label)

	path_depth_spin = SpinBox.new()
	path_depth_spin.min_value = 1
	path_depth_spin.max_value = 10
	path_depth_spin.value = 2
	path_depth_spin.step = 1
	folder_depth_container.add_child(path_depth_spin)

	var folders_label = Label.new()
	folders_label.text = "Folders"
	folder_depth_container.add_child(folders_label)

	# Timestamp Format Section
	var timestamp_section = ui_builder.create_section(main_container, "Timestamp Format")
	var timestamp_grid = GridContainer.new()
	timestamp_grid.columns = 2
	timestamp_section.add_child(timestamp_grid)

	timestamp_date_check = CheckBox.new()
	timestamp_date_check.text = "Include Date"
	timestamp_grid.add_child(timestamp_date_check)

	timestamp_ms_check = CheckBox.new()
	timestamp_ms_check.text = "Include Milliseconds"
	timestamp_grid.add_child(timestamp_ms_check)

	var time_format_container = HBoxContainer.new()
	timestamp_grid.add_child(time_format_container)

	timestamp_24h_check = Button.new()
	timestamp_24h_check.text = "24-hour Format"
	timestamp_24h_check.toggle_mode = true
	timestamp_24h_check.button_pressed = true
	timestamp_24h_check.button_group = ButtonGroup.new()
	time_format_container.add_child(timestamp_24h_check)

	timestamp_12h_check = Button.new()
	timestamp_12h_check.text = "12-hour Format"
	timestamp_12h_check.toggle_mode = true
	timestamp_12h_check.button_group = timestamp_24h_check.button_group
	time_format_container.add_child(timestamp_12h_check)

	var time_zone_container = HBoxContainer.new()
	timestamp_grid.add_child(time_zone_container)

	timestamp_local_check = Button.new()
	timestamp_local_check.text = "Local Time"
	timestamp_local_check.toggle_mode = true
	timestamp_local_check.button_pressed = true
	timestamp_local_check.button_group = ButtonGroup.new()
	time_zone_container.add_child(timestamp_local_check)

	timestamp_utc_check = Button.new()
	timestamp_utc_check.text = "UTC Time"
	timestamp_utc_check.toggle_mode = true
	timestamp_utc_check.button_group = timestamp_local_check.button_group
	time_zone_container.add_child(timestamp_utc_check)

	# Context Data Format Section
	var context_section = ui_builder.create_section(main_container, "Context Data Format")

	context_multiline_check = CheckBox.new()
	context_multiline_check.text = "Multiline (one property per line)"
	context_section.add_child(context_multiline_check)

	var context_limit_container = HBoxContainer.new()
	context_section.add_child(context_limit_container)

	context_limit_check = CheckBox.new()
	context_limit_check.text = "Limit to"
	context_limit_container.add_child(context_limit_check)

	context_limit_spin = SpinBox.new()
	context_limit_spin.min_value = 1
	context_limit_spin.max_value = 100
	context_limit_spin.value = 10
	context_limit_spin.step = 1
	context_limit_spin.editable = false
	context_limit_container.add_child(context_limit_spin)

	var properties_label = Label.new()
	properties_label.text = "properties"
	context_limit_container.add_child(properties_label)

	# Preview Section
	var preview_section = ui_builder.create_section(main_container, "Example Preview")

	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.custom_minimum_size = Vector2(0, 150)
	preview_label.fit_content = true
	preview_section.add_child(preview_label)

	# Apply button
	apply_button = Button.new()
	apply_button.text = "Apply Settings"
	apply_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.add_child(apply_button)

	# Set initial visibility
	component_order_container.visible = false
	color_pickers_container.visible = false
	folder_depth_container.visible = false

## Add a color picker for a named item
func _add_color_picker(container: GridContainer, name: String, default_color: Color) -> void:
	var label = Label.new()
	label.text = name + ":"
	container.add_child(label)

	var picker = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(40, 20)
	picker.color = default_color
	picker.edit_alpha = false
	container.add_child(picker)

	var hex_value = Label.new()
	hex_value.text = "#" + default_color.to_html(false)
	container.add_child(hex_value)

	# Store picker reference and connect signal
	color_pickers[name.to_lower()] = {
		"picker": picker,
		"label": hex_value
	}

	# Connect color changed signal
	picker.color_changed.connect(func(color: Color) -> void:
		hex_value.text = "#" + color.to_html(false)
		_schedule_preview_update()
	)

## Connect UI signals
func _connect_signals() -> void:
	# Basic component visibility
	show_timestamp_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.show_timestamp = pressed
		_schedule_preview_update()
	)

	show_level_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.show_level = pressed
		_schedule_preview_update()
	)

	show_tags_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.show_tags = pressed
		_schedule_preview_update()
	)

	show_context_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.show_context = pressed
		_schedule_preview_update()
	)

	show_source_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.show_source = pressed
		_schedule_preview_update()
	)

	# Layout mode buttons
	for i in range(layout_buttons.size()):
		layout_buttons[i].toggled.connect(func(pressed: bool) -> void:
			if pressed:
				format_settings.layout_mode = i
				# Show/hide component order list for custom mode
				var component_order = tab_container.get_current_tab_control().get_node("ComponentOrder")
				component_order.visible = (i == LoggerSettings.FormatSettings.LayoutMode.CUSTOM)
				_schedule_preview_update()
		)

	# Component order list
	component_list.item_selected.connect(func(index: int) -> void:
		move_up_btn.disabled = (index <= 0)
		move_down_btn.disabled = (index >= component_list.item_count - 1)
	)

	move_up_btn.pressed.connect(func() -> void:
		var selected_items = component_list.get_selected_items()
		if selected_items.is_empty():
			return

		var idx = selected_items[0]
		if idx > 0:
			# Swap items in the list and in the settings
			var temp = component_list.get_item_text(idx)
			component_list.set_item_text(idx, component_list.get_item_text(idx - 1))
			component_list.set_item_text(idx - 1, temp)
			component_list.select(idx - 1)

			# Update settings
			var comp_temp = format_settings.component_order[idx]
			format_settings.component_order[idx] = format_settings.component_order[idx - 1]
			format_settings.component_order[idx - 1] = comp_temp

			_schedule_preview_update()
	)

	move_down_btn.pressed.connect(func() -> void:
		var selected_items = component_list.get_selected_items()
		if selected_items.is_empty():
			return

		var idx = selected_items[0]
		if idx < component_list.item_count - 1:
			# Swap items in the list and in the settings
			var temp = component_list.get_item_text(idx)
			component_list.set_item_text(idx, component_list.get_item_text(idx + 1))
			component_list.set_item_text(idx + 1, temp)
			component_list.select(idx + 1)

			# Update settings
			var comp_temp = format_settings.component_order[idx]
			format_settings.component_order[idx] = format_settings.component_order[idx + 1]
			format_settings.component_order[idx + 1] = comp_temp

			_schedule_preview_update()
	)

	# Color settings
	use_colors_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.use_colors = pressed
		default_colors_check.disabled = !pressed
		custom_colors_check.disabled = !pressed
		_schedule_preview_update()
	)

	default_colors_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.use_default_colors = true
			# Hide custom color pickers
			var color_pickers = tab_container.get_current_tab_control().get_node("ColorPickers")
			color_pickers.visible = false
			_schedule_preview_update()
	)

	custom_colors_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.use_default_colors = false
			# Show custom color pickers
			var color_pickers = tab_container.get_current_tab_control().get_node("ColorPickers")
			color_pickers.visible = true
			_update_custom_colors()
			_schedule_preview_update()
	)

	# Path mode buttons
	for i in range(path_mode_buttons.size()):
		path_mode_buttons[i].toggled.connect(func(pressed: bool) -> void:
			if pressed:
				format_settings.path_mode = i
				# Show folder depth spinner only for LIMITED_FOLDERS mode
				var depth_container = tab_container.get_current_tab_control().get_node("FolderDepth")
				depth_container.visible = (i == LoggerSettings.FormatSettings.PathMode.LIMITED_FOLDERS)
				_schedule_preview_update()
		)

	path_depth_spin.value_changed.connect(func(value: float) -> void:
		format_settings.path_folder_depth = int(value)
		_schedule_preview_update()
	)

	# Timestamp settings
	timestamp_date_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.timestamp_show_date = pressed
		_schedule_preview_update()
	)

	timestamp_ms_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.timestamp_show_ms = pressed
		_schedule_preview_update()
	)

	timestamp_24h_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.timestamp_use_24h = true
			_schedule_preview_update()
	)

	timestamp_12h_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.timestamp_use_24h = false
			_schedule_preview_update()
	)

	timestamp_local_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.timestamp_use_local = true
			_schedule_preview_update()
	)

	timestamp_utc_check.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			format_settings.timestamp_use_local = false
			_schedule_preview_update()
	)

	# Context settings
	context_multiline_check.toggled.connect(func(pressed: bool) -> void:
		format_settings.context_multiline = pressed
		_schedule_preview_update()
	)

	context_limit_check.toggled.connect(func(pressed: bool) -> void:
		context_limit_spin.editable = pressed
		format_settings.context_limit = 0 if !pressed else int(context_limit_spin.value)
		_schedule_preview_update()
	)

	context_limit_spin.value_changed.connect(func(value: float) -> void:
		if context_limit_check.button_pressed:
			format_settings.context_limit = int(value)
			_schedule_preview_update()
	)

	# Apply button
	apply_button.pressed.connect(func() -> void:
		_save_format_settings()
	)

## Update UI controls from format settings
func _update_ui_from_settings() -> void:
	# Basic component visibility
	show_timestamp_check.button_pressed = format_settings.show_timestamp
	show_level_check.button_pressed = format_settings.show_level
	show_tags_check.button_pressed = format_settings.show_tags
	show_context_check.button_pressed = format_settings.show_context
	show_source_check.button_pressed = format_settings.show_source

	# Layout mode
	if format_settings.layout_mode >= 0 and format_settings.layout_mode < layout_buttons.size():
		layout_buttons[format_settings.layout_mode].button_pressed = true

		# Show/hide component order list
		var component_order = tab_container.get_current_tab_control().get_node("ComponentOrder")
		component_order.visible = (format_settings.layout_mode == LoggerSettings.FormatSettings.LayoutMode.CUSTOM)

		# Update component order list
		component_list.clear()
		for component in format_settings.component_order:
			var display_name = component.capitalize()
			component_list.add_item(display_name)

	# Color settings
	use_colors_check.button_pressed = format_settings.use_colors
	default_colors_check.disabled = !format_settings.use_colors
	custom_colors_check.disabled = !format_settings.use_colors

	if format_settings.use_default_colors:
		default_colors_check.button_pressed = true
	else:
		custom_colors_check.button_pressed = true

	# Show/hide color pickers
	var color_pickers_container = tab_container.get_current_tab_control().get_node("ColorPickers")
	color_pickers_container.visible = !format_settings.use_default_colors && format_settings.use_colors

	# Update color pickers
	_update_custom_colors()

	# Path mode
	if format_settings.path_mode >= 0 and format_settings.path_mode < path_mode_buttons.size():
		path_mode_buttons[format_settings.path_mode].button_pressed = true

		# Show folder depth spinner only for LIMITED_FOLDERS mode
		var depth_container = tab_container.get_current_tab_control().get_node("FolderDepth")
		depth_container.visible = (format_settings.path_mode == LoggerSettings.FormatSettings.PathMode.LIMITED_FOLDERS)

	path_depth_spin.value = format_settings.path_folder_depth

	# Timestamp settings
	timestamp_date_check.button_pressed = format_settings.timestamp_show_date
	timestamp_ms_check.button_pressed = format_settings.timestamp_show_ms
	timestamp_24h_check.button_pressed = format_settings.timestamp_use_24h
	timestamp_12h_check.button_pressed = !format_settings.timestamp_use_24h
	timestamp_local_check.button_pressed = format_settings.timestamp_use_local
	timestamp_utc_check.button_pressed = !format_settings.timestamp_use_local

	# Context settings
	context_multiline_check.button_pressed = format_settings.context_multiline
	context_limit_check.button_pressed = (format_settings.context_limit > 0)
	context_limit_spin.editable = context_limit_check.button_pressed
	context_limit_spin.value = format_settings.context_limit if format_settings.context_limit > 0 else 10

	# Update preview
	_update_preview()

## Update color pickers from settings
func _update_custom_colors() -> void:
	for key in format_settings.custom_colors:
		if key in color_pickers:
			var data = color_pickers[key]
			var picker = data.picker as ColorPickerButton
			var label = data.label as Label

			picker.color = format_settings.custom_colors[key]
			label.text = "#" + format_settings.custom_colors[key].to_html(false)

## Update custom colors from pickers
func _update_colors_from_pickers() -> void:
	for key in color_pickers:
		var data = color_pickers[key]
		var picker = data.picker as ColorPickerButton
		format_settings.custom_colors[key] = picker.color

## Schedule preview update with debounce
func _schedule_preview_update() -> void:
	debounce_timer.start()

func _on_preview_update() -> void:
	_update_preview()
	print_rich("[color=gray]Preview updated[/color]") # Optional debug message

## Update the preview with current settings
func _update_preview() -> void:
	# Get sample entry
	var entry = Logger.LogFormatter.generate_preview_entry()

	# Create temporary formatter with current settings
	var formatter = Logger.LogFormatter.new(
		Logger.LEVEL_COLORS,
		Logger.TIMESTAMP_COLOR,
		Logger.TAGS_COLOR,
		Logger.CONTEXT_KEY_COLOR,
		Logger.CONTEXT_VALUE_COLOR,
		Logger.REPLAY_COLOR,
		Logger.SOURCE_COLOR
	)

	formatter.apply_format_settings(format_settings)

	# Format the entry
	var formatted = formatter.format_entry(entry)

	# Set the formatted text
	preview_label.text = formatted

func _save_format_settings() -> void:
	# Update colors from pickers
	_update_colors_from_pickers()

	# Update the logger's formatter with our settings
	if logger and logger.has("_formatter"):
		logger._formatter.apply_format_settings(format_settings)

	# Save settings
	var result = LoggerSettings.save_format_settings(format_settings)

	if result == OK:
		print_rich("[color=green]Format settings saved successfully[/color]")
	else:
		push_error("Failed to save format settings: %d" % result)
