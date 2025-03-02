@tool
extends EditorPlugin

const AUTOLOAD_NAME: String = "Log"
const TEST_AUTOLOAD_NAME: String = "LogTest"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/logger.gd"
const LOGGER_TEST_SCRIPT_PATH: String = "res://addons/advanced_logger/logger_test.gd"

# Single Logger instance that will be shared
var logger_instance: Logger
var logger_dock: LoggerDock

func _enter_tree() -> void:
	print("Advanced Logger: Initializing...")

	# Create a single logger instance first
	logger_instance = Logger.new()

	# Initialize the logger with settings
	var load_result = LoggerSettings.load_settings(logger_instance)
	if load_result != OK:
		push_error("Failed to load logger settings")

	# Register it as an autoload singleton by name
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Replace the autoload's logger with our instance
	# This must happen after the autoload is registered
	call_deferred("_register_shared_logger_instance")

	# Create dock UI with the same logger instance
	logger_dock = preload("res://addons/advanced_logger/logger_dock.gd").new(logger_instance)
	add_control_to_bottom_panel(logger_dock, "Logger")

	# Listen for settings changes from the dock
	logger_dock.settings_changed.connect(_on_settings_changed)

func _register_shared_logger_instance() -> void:
	# Get the autoload singleton
	var autoload_logger = Engine.get_singleton(AUTOLOAD_NAME)
	if autoload_logger:
		# Replace its internal data with our logger instance's data
		LoggerSettings.apply_logger_to_logger(logger_instance, autoload_logger)

		# Ensure the formatter is properly initialized with format settings
		if autoload_logger.has("_formatter") and autoload_logger.has("_format_settings"):
			autoload_logger._formatter.apply_format_settings(autoload_logger._format_settings)

		print_rich("[color=green]Advanced Logger initialized (DEBUG: %s, Buffer: %d entries)[/color]" %
			[Logger.LogLevel.keys()[logger_instance._current_level],
			logger_instance._buffer.buffer.size()])

		# Now check if tests should run
		if LoggerSettings.should_run_tests():
			_setup_test_script()
		else:
			print("Logger self-tests disabled (can be enabled in Logger panel)")

func _setup_test_script() -> void:
	# Add test script as autoload
	add_autoload_singleton(TEST_AUTOLOAD_NAME, LOGGER_TEST_SCRIPT_PATH)
	print("Logger test script registered")

func _exit_tree() -> void:
	# Save settings before cleanup
	if logger_instance:
		var run_tests = logger_dock.should_run_tests() if logger_dock else true

		# Make sure format settings are saved if format tab exists
		if logger_dock and logger_dock.format_tab and logger_dock.format_tab.has_method("_save_format_settings"):
			logger_dock.format_tab._save_format_settings()

		var save_result = LoggerSettings.save_settings(logger_instance, run_tests)
		if save_result != OK:
			push_error("Failed to save logger settings")

	# Clean up autoloads - use Engine.has_singleton to check if autoload exists
	if Engine.has_singleton(TEST_AUTOLOAD_NAME):
		remove_autoload_singleton(TEST_AUTOLOAD_NAME)
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

	# Clean up dock UI
	if logger_dock:
		remove_control_from_bottom_panel(logger_dock)
		if logger_dock.settings_changed.is_connected(_on_settings_changed):
			logger_dock.settings_changed.disconnect(_on_settings_changed)
		logger_dock.queue_free()

	# Free resources
	logger_instance = null

func _on_settings_changed() -> void:
	# When settings change in the UI, save them
	if logger_instance:
		var run_tests = logger_dock.should_run_tests() if logger_dock else true
		var save_result = LoggerSettings.save_settings(logger_instance, run_tests)
		if save_result != OK:
			push_error("Failed to save logger settings")
			return

		# Update the autoload if it exists (should be the same instance anyway)
		var autoload_logger = Engine.get_singleton(AUTOLOAD_NAME)
		if autoload_logger:
			# This is redundant if they share data, but ensures they stay in sync
			LoggerSettings.apply_logger_to_logger(logger_instance, autoload_logger)

			# Make sure format settings are applied to the formatter
			if autoload_logger.has("_formatter") and autoload_logger.has("_format_settings"):
				autoload_logger._formatter.apply_format_settings(autoload_logger._format_settings)

			print_rich("[color=green]Logger: Settings saved and applied[/color]")
			print("Logger: Settings saved and applied")
