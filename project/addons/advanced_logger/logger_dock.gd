@tool
class_name LoggerDock
extends Control

signal tag_added(tag: String)
signal tag_removed(tag: String)
signal log_level_changed(level: int)
signal buffer_size_changed(size: int)
signal retro_window_changed(seconds: int)
signal run_tests_changed(enabled: bool)
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
@export var logger: Logger
@export var run_tests: bool = true

var tag_input: LineEdit
var tag_list: ItemList
var level_option: OptionButton
var buffer_size_spin: SpinBox
var retro_spin: SpinBox
var run_tests_check: CheckBox




func _init(logger_instance: Logger) -> void:
	logger = logger_instance
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_setup_ui()
	_connect_signals()


func _setup_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# Add test control at the top
	var test_container := HBoxContainer.new()
	layout.add_child(test_container)

	run_tests_check = CheckBox.new()
	run_tests_check.text = "Run Tests on Start"
	run_tests_check.button_pressed = run_tests
	test_container.add_child(run_tests_check)

	var separator := HSeparator.new()
	layout.add_child(separator)

	# Settings container
	var settings_container := GridContainer.new()
	settings_container.columns = 2
	layout.add_child(settings_container)

	# Log level control
	var level_label := Label.new()
	level_label.text = "Log Level:"
	settings_container.add_child(level_label)

	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_log_level_options(level_option)
	settings_container.add_child(level_option)

	# Buffer size control
	var buffer_label := Label.new()
	buffer_label.text = "Buffer Size:"
	settings_container.add_child(buffer_label)

	var buffer_container := HBoxContainer.new()
	settings_container.add_child(buffer_container)

	buffer_size_spin = SpinBox.new()
	buffer_size_spin.min_value = Logger.LoggerConfig.MIN_BUFFER_SIZE as float
	buffer_size_spin.max_value = Logger.LoggerConfig.MAX_BUFFER_SIZE as float
	buffer_size_spin.value = 1000.0
	buffer_size_spin.step = 100.0
	buffer_size_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffer_container.add_child(buffer_size_spin)

	var buffer_apply := Button.new()
	buffer_apply.text = "Apply"
	buffer_container.add_child(buffer_apply)

	# Retroactive window control
	var retro_label := Label.new()
	retro_label.text = "Retroactive Window (s):"
	settings_container.add_child(retro_label)

	var retro_container := HBoxContainer.new()
	settings_container.add_child(retro_container)

	retro_spin = SpinBox.new()
	retro_spin.min_value = Logger.LoggerConfig.MIN_TIME_WINDOW as float
	retro_spin.max_value = Logger.LoggerConfig.MAX_TIME_WINDOW as float
	retro_spin.value = 300.0
	retro_spin.step = 10.0
	retro_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retro_container.add_child(retro_spin)

	var retro_apply := Button.new()
	retro_apply.text = "Apply"
	retro_container.add_child(retro_apply)

	# Add separator
	var tag_separator := HSeparator.new()
	layout.add_child(tag_separator)

	# Tag management
	var tag_container := VBoxContainer.new()
	layout.add_child(tag_container)

	var tag_header := HBoxContainer.new()
	tag_container.add_child(tag_header)

	var tag_label := Label.new()
	tag_label.text = "Tags:"
	tag_header.add_child(tag_label)

	tag_input = LineEdit.new()
	tag_input.placeholder_text = "Enter tag name"
	tag_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_header.add_child(tag_input)

	var add_button := Button.new()
	add_button.text = "Add Tag"
	tag_header.add_child(add_button)

	var remove_button := Button.new()
	remove_button.text = "Remove Selected"
	tag_header.add_child(remove_button)

	var clear_button := Button.new()
	clear_button.text = "Clear All"
	tag_header.add_child(clear_button)

	tag_list = ItemList.new()
	tag_list.select_mode = ItemList.SELECT_MULTI
	tag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_container.add_child(tag_list)


func _setup_log_level_options(option_button: OptionButton) -> void:
	option_button.add_item("DEBUG", Logger.LogLevel.DEBUG)
	option_button.add_item("INFO", Logger.LogLevel.INFO)
	option_button.add_item("WARNING", Logger.LogLevel.WARNING)
	option_button.add_item("ERROR", Logger.LogLevel.ERROR)
	option_button.add_item("CRITICAL", Logger.LogLevel.CRITICAL)


func _connect_signals() -> void:
	if not level_option or not tag_input or not tag_list or not run_tests_check:
		push_error("Required UI elements not initialized")
		return

	level_option.item_selected.connect(_on_level_changed)
	tag_input.text_submitted.connect(_on_tag_submitted)
	tag_list.item_selected.connect(_on_tag_selected)
	run_tests_check.toggled.connect(_on_run_tests_toggled)

	# Get settings controls and connect with validation
	var buffer_container := (
		get_node_or_null("VBoxContainer/GridContainer/HBoxContainer") as HBoxContainer
	)
	var retro_container := (
		get_node_or_null("VBoxContainer/GridContainer/HBoxContainer2") as HBoxContainer
	)

	if buffer_container and retro_container:
		var buffer_apply := buffer_container.get_node("Button") as Button
		var retro_apply := retro_container.get_node("Button") as Button

		if buffer_apply and retro_apply:
			buffer_apply.pressed.connect(
				func() -> void: _validate_and_apply_buffer_size(buffer_size_spin.value)
			)
			retro_apply.pressed.connect(
				func() -> void: _validate_and_apply_retro_window(retro_spin.value)
			)

	# Get tag management buttons
	var add_button := get_node_or_null("VBoxContainer/VBoxContainer/HBoxContainer/Button") as Button
	var remove_button := (
		get_node_or_null("VBoxContainer/VBoxContainer/HBoxContainer/Button2") as Button
	)
	var clear_button := (
		get_node_or_null("VBoxContainer/VBoxContainer/HBoxContainer/Button3") as Button
	)

	if add_button and remove_button and clear_button:
		add_button.pressed.connect(_on_add_tag_pressed)
		remove_button.pressed.connect(_on_remove_selected_tags)
		clear_button.pressed.connect(_on_clear_tags_pressed)

	# Connect signals to auto-save
	logger_dock.log_level_changed.connect(_save_settings)
	logger_dock.buffer_size_changed.connect(_save_settings)
	logger_dock.retro_window_changed.connect(_save_settings)
	logger_dock.tag_added.connect(_save_settings)
	logger_dock.tag_removed.connect(_save_settings)


# Public methods
func set_log_level(level: int) -> void:
	if level >= Logger.LogLevel.DEBUG and level <= Logger.LogLevel.CRITICAL:
		level_option.select(level)
		logger._current_level = level  # Directly set the level
		var result := logger.set_level(level)
		if result == OK:
			log_level_changed.emit(level)
			print("Log level set to: %s" % Logger.LogLevel.keys()[level])


func set_buffer_size(size: int) -> void:
	if size >= Logger.LoggerConfig.MIN_BUFFER_SIZE and size <= Logger.LoggerConfig.MAX_BUFFER_SIZE:
		buffer_size_spin.value = size as float
		_validate_and_apply_buffer_size(size as float)


func set_retro_window(seconds: int) -> void:
	if (
		seconds >= Logger.LoggerConfig.MIN_TIME_WINDOW
		and seconds <= Logger.LoggerConfig.MAX_TIME_WINDOW
	):
		retro_spin.value = seconds as float
		_validate_and_apply_retro_window(seconds as float)


func add_tag(tag: String) -> void:
	if not tag.is_empty():
		_add_tag(tag)


func should_run_tests() -> bool:
	return run_tests


# Validation methods
func _validate_and_apply_buffer_size(size: float) -> void:
	var value := int(size)
	if value < Logger.LoggerConfig.MIN_BUFFER_SIZE or value > Logger.LoggerConfig.MAX_BUFFER_SIZE:
		push_warning(
			(
				"Buffer size must be between %d and %d"
				% [Logger.LoggerConfig.MIN_BUFFER_SIZE, Logger.LoggerConfig.MAX_BUFFER_SIZE]
			)
		)
		return

	var result := logger.set_buffer_size(value)
	if result == OK:
		print("Logger buffer size changed to: %d" % value)
		buffer_size_changed.emit(value)
	else:
		push_warning("Failed to change buffer size")


func _validate_and_apply_retro_window(seconds: float) -> void:
	var value := int(seconds)
	if value < Logger.LoggerConfig.MIN_TIME_WINDOW or value > Logger.LoggerConfig.MAX_TIME_WINDOW:
		push_warning(
			(
				"Retroactive window must be between %d and %d seconds"
				% [Logger.LoggerConfig.MIN_TIME_WINDOW, Logger.LoggerConfig.MAX_TIME_WINDOW]
			)
		)
		return

	var result := logger.set_retroactive_window(value)
	if result == OK:
		print("Logger retroactive window changed to: %d seconds" % value)
		retro_window_changed.emit(value)
	else:
		push_warning("Failed to change retroactive window")


# Event handlers
func _on_level_changed(index: int) -> void:
	if not level_option:
		print('level option not available!')
		return
	var level := level_option.get_item_id(index)
	var result := logger.set_level(level)
	if result == OK:
		log_level_changed.emit(level)
	else:
		push_warning("Failed to change log level")


func _on_tag_submitted(new_tag: String) -> void:
	_add_tag(new_tag)


func _on_add_tag_pressed() -> void:
	if tag_input:
		_add_tag(tag_input.text)
		tag_input.text = ""


func _add_tag(tag: String) -> void:
	tag = tag.strip_edges()
	if tag.is_empty() or not tag_list:
		return

	if logger.add_tag(tag) == OK:
		if not _tag_exists_in_list(tag):
			tag_list.add_item(tag)
			tag_added.emit(tag)
		tag_input.text = ""


func _tag_exists_in_list(tag: String) -> bool:
	if not tag_list:
		return false
	for i in range(tag_list.item_count):
		if tag_list.get_item_text(i) == tag:
			return true
	return false


func _on_tag_selected(_index: int) -> void:
	# Placeholder for future tag selection handling
	pass


func _on_remove_selected_tags() -> void:
	if not tag_list:
		return
	var selected := tag_list.get_selected_items()
	for i in range(selected.size() - 1, -1, -1):
		var idx := selected[i]
		var tag := tag_list.get_item_text(idx)
		logger.remove_tag(tag)
		tag_list.remove_item(idx)
		tag_removed.emit(tag)


func _on_clear_tags_pressed() -> void:
	if not tag_list or not logger:
		return
	logger.clear_tags()
	tag_list.clear()


func _on_run_tests_toggled(enabled: bool) -> void:
	run_tests = enabled
	run_tests_changed.emit(enabled)
