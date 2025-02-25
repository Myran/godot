@tool
class_name LoggerDock
extends Control

# Single signal to notify of any settings change
signal settings_changed

@export var logger: Logger
@export var run_tests: bool = true

# UI elements stored as direct references
var tag_input: LineEdit
var tag_list: ItemList
var level_option: OptionButton
var buffer_size_spin: SpinBox
var retro_spin: SpinBox
var run_tests_check: CheckBox
var buffer_apply_button: Button
var retro_apply_button: Button
var add_tag_button: Button
var remove_tag_button: Button
var clear_tags_button: Button
var run_tests_button: Button

# Initialization
func _init(logger_instance: Logger) -> void:
	if not logger_instance:
		push_error("Logger dock created with null logger instance")
		return

	logger = logger_instance
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	if not logger:
		push_error("Logger dock has no logger instance")
		return

	_setup_ui()
	_connect_signals()
	_update_ui_from_logger()

# UI Setup with direct references
func _setup_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# Test section
	var test_section := VBoxContainer.new()
	layout.add_child(test_section)

	var test_header := Label.new()
	test_header.text = "Self-Test Settings"
	test_header.add_theme_font_size_override("font_size", 16)
	test_section.add_child(test_header)

	var test_container := HBoxContainer.new()
	test_section.add_child(test_container)

	run_tests_check = CheckBox.new()
	run_tests_check.text = "Run Self-Tests on Project Start"
	run_tests_check.tooltip_text = "If enabled, Logger will automatically run self-tests when the project starts"
	run_tests_check.button_pressed = run_tests
	test_container.add_child(run_tests_check)

	run_tests_button = Button.new()
	run_tests_button.text = "Run Tests Now"
	run_tests_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	test_container.add_child(run_tests_button)

	var separator := HSeparator.new()
	layout.add_child(separator)

	# Logger settings
	var settings_container := GridContainer.new()
	settings_container.columns = 2
	layout.add_child(settings_container)

	# Log level
	var level_label := Label.new()
	level_label.text = "Log Level:"
	settings_container.add_child(level_label)

	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_log_level_options(level_option)
	settings_container.add_child(level_option)

	# Buffer size
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

	buffer_apply_button = Button.new()
	buffer_apply_button.text = "Apply"
	buffer_container.add_child(buffer_apply_button)

	# Retroactive window
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

	retro_apply_button = Button.new()
	retro_apply_button.text = "Apply"
	retro_container.add_child(retro_apply_button)

	# Tag management
	var tag_separator := HSeparator.new()
	layout.add_child(tag_separator)

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

	add_tag_button = Button.new()
	add_tag_button.text = "Add Tag"
	tag_header.add_child(add_tag_button)

	remove_tag_button = Button.new()
	remove_tag_button.text = "Remove Selected"
	tag_header.add_child(remove_tag_button)

	clear_tags_button = Button.new()
	clear_tags_button.text = "Clear All"
	tag_header.add_child(clear_tags_button)

	tag_list = ItemList.new()
	tag_list.select_mode = ItemList.SELECT_MULTI
	tag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_container.add_child(tag_list)

# Connect signals using direct references
func _connect_signals() -> void:
	if not _verify_ui_elements():
		push_error("Required UI elements not properly initialized")
		return

	# Connect all UI element signals using simple lambdas
	level_option.item_selected.connect(func(idx): _on_level_changed(idx))
	run_tests_check.toggled.connect(func(en): _on_run_tests_toggled(en))
	tag_input.text_submitted.connect(func(txt): _on_tag_submitted(txt))

	buffer_apply_button.pressed.connect(func(): _on_buffer_size_applied(buffer_size_spin.value))
	retro_apply_button.pressed.connect(func(): _on_retro_window_applied(retro_spin.value))
	add_tag_button.pressed.connect(func(): _on_add_tag_pressed())
	remove_tag_button.pressed.connect(func(): _on_remove_selected_tags())
	clear_tags_button.pressed.connect(func(): _on_clear_tags_pressed())
	run_tests_button.pressed.connect(func(): _on_run_tests_now_pressed())

# Verify all UI elements are properly initialized
func _verify_ui_elements() -> bool:
	return level_option != null && \
		buffer_size_spin != null && \
		retro_spin != null && \
		tag_input != null && \
		tag_list != null && \
		run_tests_check != null && \
		buffer_apply_button != null && \
		retro_apply_button != null && \
		add_tag_button != null && \
		remove_tag_button != null && \
		clear_tags_button != null && \
		run_tests_button != null

func _setup_log_level_options(option_button: OptionButton) -> void:
	if not option_button:
		return

	option_button.add_item("DEBUG", Logger.LogLevel.DEBUG)
	option_button.add_item("INFO", Logger.LogLevel.INFO)
	option_button.add_item("WARNING", Logger.LogLevel.WARNING)
	option_button.add_item("ERROR", Logger.LogLevel.ERROR)
	option_button.add_item("CRITICAL", Logger.LogLevel.CRITICAL)

# Update UI from logger state
func _update_ui_from_logger() -> void:
	if not logger or not _verify_ui_elements():
		push_error("Cannot update UI from logger: invalid state")
		return

	level_option.select(logger._current_level)
	buffer_size_spin.value = logger._buffer.buffer.size()
	retro_spin.value = logger._config.retroactive_time_window

	tag_list.clear()
	for tag in logger._active_tags:
		tag_list.add_item(tag)

# Public methods
func set_log_level(level: int) -> bool:
	if not logger or not level_option:
		push_error("Cannot set log level: logger or UI not initialized")
		return false

	if level < Logger.LogLevel.DEBUG or level > Logger.LogLevel.CRITICAL:
		push_error("Invalid log level: %d" % level)
		return false

	level_option.select(level)
	var result = logger.set_level(level)
	if result == OK:
		print_rich("[color=green]Log level set to: %s[/color]" % Logger.LogLevel.keys()[level])
		return true
	else:
		push_error("Failed to set log level: %d" % result)
		return false

func set_buffer_size(size: int) -> bool:
	if not logger or not buffer_size_spin:
		push_error("Cannot set buffer size: logger or UI not initialized")
		return false

	if size < Logger.LoggerConfig.MIN_BUFFER_SIZE or size > Logger.LoggerConfig.MAX_BUFFER_SIZE:
		push_error("Invalid buffer size: %d" % size)
		return false

	buffer_size_spin.value = size
	var result = logger.set_buffer_size(size)
	if result == OK:
		print_rich("[color=green]Buffer size set to: %d[/color]" % size)
		return true
	else:
		push_error("Failed to set buffer size: %d" % result)
		return false

func set_retro_window(seconds: int) -> bool:
	if not logger or not retro_spin:
		push_error("Cannot set retroactive window: logger or UI not initialized")
		return false

	if seconds < Logger.LoggerConfig.MIN_TIME_WINDOW or seconds > Logger.LoggerConfig.MAX_TIME_WINDOW:
		push_error("Invalid retroactive window: %d" % seconds)
		return false

	retro_spin.value = seconds
	var result = logger.set_retroactive_window(seconds)
	if result == OK:
		print_rich("[color=green]Retroactive window set to: %d seconds[/color]" % seconds)
		return true
	else:
		push_error("Failed to set retroactive window: %d" % result)
		return false

func add_tag(tag: String) -> bool:
	if not logger or not tag_list:
		push_error("Cannot add tag: logger or UI not initialized")
		return false

	if tag.is_empty():
		push_warning("Cannot add empty tag")
		return false

	tag = tag.strip_edges()
	if tag.is_empty():
		return false

	if logger.add_tag(tag) == OK:
		if not _tag_exists_in_list(tag):
			tag_list.add_item(tag)
		return true
	else:
		push_error("Failed to add tag: %s" % tag)
		return false

func should_run_tests() -> bool:
	return run_tests

# Event handlers
func _on_level_changed(index: int) -> void:
	if not level_option or not logger:
		push_error("Level changed but logger or UI not initialized")
		return

	var level := level_option.get_item_id(index)
	if logger.set_level(level) == OK:
		print_rich("[color=green]Log level changed to: %s[/color]" % Logger.LogLevel.keys()[level])
		settings_changed.emit()
	else:
		push_error("Failed to change log level to: %s" % Logger.LogLevel.keys()[level])
		# Revert UI to match logger state
		_update_ui_from_logger()

func _on_buffer_size_applied(size: float) -> void:
	var value := int(size)
	if value < Logger.LoggerConfig.MIN_BUFFER_SIZE or value > Logger.LoggerConfig.MAX_BUFFER_SIZE:
		push_warning("Buffer size must be between %d and %d" %
			[Logger.LoggerConfig.MIN_BUFFER_SIZE, Logger.LoggerConfig.MAX_BUFFER_SIZE])
		_update_ui_from_logger() # Revert UI
		return

	if logger and logger.set_buffer_size(value) == OK:
		print_rich("[color=green]Buffer size changed to: %d[/color]" % value)
		settings_changed.emit()
	else:
		push_error("Failed to change buffer size")
		_update_ui_from_logger() # Revert UI

func _on_retro_window_applied(seconds: float) -> void:
	var value := int(seconds)
	if value < Logger.LoggerConfig.MIN_TIME_WINDOW or value > Logger.LoggerConfig.MAX_TIME_WINDOW:
		push_warning("Retroactive window must be between %d and %d seconds" %
			[Logger.LoggerConfig.MIN_TIME_WINDOW, Logger.LoggerConfig.MAX_TIME_WINDOW])
		_update_ui_from_logger() # Revert UI
		return

	if logger and logger.set_retroactive_window(value) == OK:
		print_rich("[color=green]Retroactive window changed to: %d seconds[/color]" % value)
		settings_changed.emit()
	else:
		push_error("Failed to change retroactive window")
		_update_ui_from_logger() # Revert UI

func _on_run_tests_toggled(enabled: bool) -> void:
	run_tests = enabled
	print_rich("[color=%s]Logger self-tests will %s on next project start[/color]" %
		["green" if enabled else "yellow", "run" if enabled else "NOT run"])
	settings_changed.emit()

func _on_run_tests_now_pressed() -> void:
	if not logger:
		push_error("Cannot run tests: logger not initialized")
		return

	print_rich("[color=green]Running Logger self-tests manually...[/color]")
	print("(Plain text) Running Logger self-tests manually...")

	# Force the logger to DEBUG level temporarily to show all messages
	var original_level = logger._current_level
	logger.set_level(Logger.LogLevel.DEBUG)

	# Force the logger to be enabled
	logger._enabled = true

	# Enable testing mode if available
	if logger.has_method("enable_testing_mode"):
		logger.enable_testing_mode()

	# Make sure the Log singleton is using our logger instance
	var autoload_logger = Engine.get_singleton("Log")
	if autoload_logger:
		# Make sure settings are properly transferred
		LoggerSettings.apply_logger_to_logger(logger, autoload_logger)

		# Force the autoload logger to be enabled with DEBUG level
		autoload_logger._enabled = true
		autoload_logger._current_level = Logger.LogLevel.DEBUG

		# Enable testing mode on autoload logger if available
		if autoload_logger.has_method("enable_testing_mode"):
			autoload_logger.enable_testing_mode()

		print("Autoload logger enabled for testing")
	else:
		print("Log singleton not available - using local logger for tests")
		# If Log singleton isn't available, we can still use our local logger
		# This workaround is for when running tests within the editor
		Engine.register_singleton("Log", logger)
		print("Temporarily registered local logger as Log singleton")

	# Run tests directly without creating a new instance
	print("Attempting to run logger tests directly...")

	# Direct test execution
	print_rich("\n[color=green]=== Starting Log.Self-Test (Manual) ===\n[/color]")

	# Basic test logs using local logger directly
	logger.debug("Manual test: Debug level message")
	logger.info("Manual test: Info level message")
	logger.warning("Manual test: Warning level message")

	# Test context data
	logger.info(
		"Manual test: Context data example",
		{"number": 42, "text": "Hello", "vector": Vector2(100, 200)}
	)

	# Test tag system
	logger.add_tag("manual-test")
	logger.info("Manual test: Tagged message", {"test_id": 1}, ["manual-test"])

	# Test error with retroactive display
	logger.debug("Manual test: This should appear in retroactive display")
	logger.error(
		"Manual test: Error message with retroactive display",
		{"error_code": 404, "details": "Testing error handling"}
	)

	# Test tag removal & cleanup
	logger.remove_tag("manual-test")
	logger.clear_tags()

	print_rich("\n[color=green]=== Manual Test Complete ===\n[/color]")

	# Now try loading and running the test script
	var TestScript = load("res://addons/advanced_logger/logger_test.gd")
	if TestScript:
		print("Logger test script loaded successfully")
		var test_script = TestScript.new()

		# Set a flag to skip the initialization check
		test_script._logger_ready = true
		# Disable initialization attempts
		test_script._initialization_attempts = 0
		# Make sure tests will run
		test_script._should_run_tests = true
		test_script._max_attempts = 0

		add_child(test_script)

		# Connect to the tests_completed signal
		test_script.tests_completed.connect(func():
			print("Logger test script completed execution")
			test_script.queue_free()
		)

		# Run tests directly
		test_script.run_tests()

		print("Logger test script execution initiated")
	else:
		push_error("Failed to load logger_test.gd - running fallback tests only")

	# Remove temporary singleton if we added it
	if Engine.has_singleton("Log") and not autoload_logger:
		Engine.unregister_singleton("Log")
		print("Removed temporary Log singleton")

	# Cleanup after a delay regardless of test script execution
	get_tree().create_timer(2.0).timeout.connect(func():
		# Disable testing mode if available
		if logger.has_method("disable_testing_mode"):
			logger.disable_testing_mode()

		# Also check the autoload logger
		if autoload_logger and autoload_logger.has_method("disable_testing_mode"):
			autoload_logger.disable_testing_mode()

		# Restore original log level
		logger.set_level(original_level)
		# Also ensure we clear tags after test
		logger.clear_tags()

		print_rich("[color=green]Test run complete, settings restored.[/color]")
		print("(Plain text) Test run complete, settings restored.")
	)

func _on_tag_submitted(new_tag: String) -> void:
	_add_tag(new_tag)

func _on_add_tag_pressed() -> void:
	if tag_input:
		_add_tag(tag_input.text)
		tag_input.text = ""

func _add_tag(tag: String) -> void:
	if not logger or not tag_list:
		push_error("Cannot add tag: logger or UI not initialized")
		return

	tag = tag.strip_edges()
	if tag.is_empty():
		return

	if logger.add_tag(tag) == OK:
		if not _tag_exists_in_list(tag):
			tag_list.add_item(tag)
			settings_changed.emit()
		if tag_input:
			tag_input.text = ""
	else:
		push_error("Failed to add tag: %s" % tag)

func _tag_exists_in_list(tag: String) -> bool:
	if not tag_list:
		return false
	for i in range(tag_list.item_count):
		if tag_list.get_item_text(i) == tag:
			return true
	return false

func _on_remove_selected_tags() -> void:
	if not tag_list or not logger:
		push_error("Cannot remove tags: logger or UI not initialized")
		return

	var selected := tag_list.get_selected_items()
	if selected.is_empty():
		return

	var any_removed = false
	for i in range(selected.size() - 1, -1, -1):
		var idx := selected[i]
		var tag := tag_list.get_item_text(idx)
		logger.remove_tag(tag)
		tag_list.remove_item(idx)
		any_removed = true

	if any_removed:
		settings_changed.emit()

func _on_clear_tags_pressed() -> void:
	if not tag_list or not logger:
		push_error("Cannot clear tags: logger or UI not initialized")
		return

	if tag_list.item_count > 0:
		logger.clear_tags()
		tag_list.clear()
		settings_changed.emit()
