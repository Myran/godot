@tool
extends EditorPlugin
## Plugin initialization script for the Advanced Logger

const AUTOLOAD_NAME: String = "Log"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/logger.gd"

# Shared logger instance
var logger_instance: Logger
var logger_dock: LoggerDock

func _enter_tree() -> void:
	print("Advanced Logger: Initializing...")

	# Create logger instance
	logger_instance = Logger.new()

	# Load settings
	var load_result = LoggerSettings.load_settings(logger_instance)
	if load_result != OK:
		push_warning("Failed to load logger settings, using defaults")

	# Register as autoload singleton
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Replace the autoload's logger with our instance
	call_deferred("_register_shared_logger_instance")

	# Create and add dock UI
	logger_dock = LoggerDock.new(logger_instance)
	add_control_to_bottom_panel(logger_dock, "Logger")

	# Connect to settings changes signal
	logger_dock.settings_changed.connect(_on_settings_changed)

func _register_shared_logger_instance() -> void:
	# Get the autoload singleton
	var autoload_logger: Logger = Engine.get_singleton(AUTOLOAD_NAME) as Logger
	if not autoload_logger:
		push_error("Failed to get logger autoload")
		return

	# Copy settings from our instance to the autoload
	var level_result: Error = autoload_logger.set_level(logger_instance._current_level)
	if level_result != OK:
		push_warning("Failed to set log level on autoload logger")

	var buffer_result: Error = autoload_logger.set_buffer_size(logger_instance._buffer_size)
	if buffer_result != OK:
		push_warning("Failed to set buffer size on autoload logger")

	var window_result: Error = autoload_logger.set_retroactive_window(logger_instance._retroactive_window)
	if window_result != OK:
		push_warning("Failed to set retroactive window on autoload logger")

	autoload_logger.set_show_timestamp(logger_instance._show_timestamp)
	autoload_logger.set_show_tags(logger_instance._show_tags)
	autoload_logger.set_use_colors(logger_instance._use_colors)

	# Copy tags
	autoload_logger.clear_tags()
	autoload_logger.clear_ignored_tags()

	var active_tags: Array[String] = logger_instance.get_active_tags()
	for tag in active_tags:
		if tag is String and not tag.is_empty():
			var tag_result: Error = autoload_logger.add_tag(tag)
			if tag_result != OK:
				push_warning("Failed to add tag to autoload logger: %s" % tag)

	var ignored_tags: Array[String] = logger_instance.get_ignored_tags()
	for tag in ignored_tags:
		if tag is String and not tag.is_empty():
			var tag_result: Error = autoload_logger.add_ignored_tag(tag)
			if tag_result != OK:
				push_warning("Failed to add ignored tag to autoload logger: %s" % tag)

	print_rich("[color=green]Advanced Logger initialized[/color]")

func _exit_tree() -> void:
	# Save settings before cleanup
	if logger_instance:
		var save_result = LoggerSettings.save_settings(logger_instance)
		if save_result != OK:
			push_error("Failed to save logger settings")

	# Remove autoload
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

	# Remove dock
	if logger_dock:
		remove_control_from_bottom_panel(logger_dock)
		if logger_dock.settings_changed.is_connected(_on_settings_changed):
			logger_dock.settings_changed.disconnect(_on_settings_changed)
		logger_dock.queue_free()

	# Clean up
	logger_instance = null

func _on_settings_changed() -> void:
	# When settings change in UI, save them
	if logger_instance:
		LoggerSettings.save_settings(logger_instance)

		# Update the autoload instance if it exists
		var autoload_logger = Engine.get_singleton(AUTOLOAD_NAME)
		if autoload_logger:
			# Copy settings from our instance to the autoload
			autoload_logger.set_level(logger_instance._current_level)
			autoload_logger.set_buffer_size(logger_instance._buffer_size)
			autoload_logger.set_retroactive_window(logger_instance._retroactive_window)
			autoload_logger.set_show_timestamp(logger_instance._show_timestamp)
			autoload_logger.set_show_tags(logger_instance._show_tags)
			autoload_logger.set_use_colors(logger_instance._use_colors)

			# Clear and copy tags
			autoload_logger.clear_tags()
			autoload_logger.clear_ignored_tags()

			for tag in logger_instance.get_active_tags():
				autoload_logger.add_tag(tag)

			for tag in logger_instance.get_ignored_tags():
				autoload_logger.add_ignored_tag(tag)
