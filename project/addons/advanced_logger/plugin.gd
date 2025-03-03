@tool
extends EditorPlugin
## Plugin initialization script for the Advanced Logger

const AUTOLOAD_NAME: String = "Log"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/logger.gd"

func _enter_tree() -> void:
	print("Advanced Logger: Initializing...")

	# Register as autoload singleton
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Print completion message using our centralized color palette
	print_rich("[color=#%s]Advanced Logger initialized[/color]" % LoggerColors.SUCCESS_HTML)

func _exit_tree() -> void:
	# Save settings before cleanup
	var logger = Engine.get_singleton(AUTOLOAD_NAME)
	if logger:
		var save_result = LoggerSettings.save_settings(logger)
		if save_result != OK:
			push_error("Failed to save logger settings")

	# Remove autoload
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
