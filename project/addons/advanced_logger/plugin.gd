@tool
extends EditorPlugin
## Plugin initialization script for the Advanced Logger

const AUTOLOAD_NAME: String = "Log"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/core/logger.gd"
const LOGGER_DOCK_PATH: String = "res://addons/advanced_logger/logger_dock.tscn"
const DOCK_POSITION: int = EditorPlugin.DOCK_SLOT_RIGHT_UL

var _dock: Control


func _enter_tree() -> void:
	# Register autoload singleton for runtime use
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Register project settings for test tag inclusion
	_register_project_settings()

	# Add the dock - it works independently via config
	var dock_scene: PackedScene = load(LOGGER_DOCK_PATH)
	if dock_scene:
		_dock = dock_scene.instantiate()
		add_control_to_dock(DOCK_POSITION, _dock)

		# Since the ConfigManager is not accessible here, we need to load it directly
		const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
		var config = ConfigManager.get_instance()

		if config.get_show_editor_debug():
			print_rich('dock: ',_dock)

		# Keep the initialization message visible always
		print_rich("[color=#%s]Advanced Logger initialized[/color]" % LoggerColors.SUCCESS_HTML)
	else:
		push_error("Failed to load logger dock scene")

## Register necessary project settings
func _register_project_settings() -> void:
	# Setting for including test tags
	if not ProjectSettings.has_setting("advanced_logger/include_test_tags"):
		ProjectSettings.set_setting("advanced_logger/include_test_tags", false)
		ProjectSettings.set_initial_value("advanced_logger/include_test_tags", false)
		ProjectSettings.add_property_info({
			"name": "advanced_logger/include_test_tags",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})

	ProjectSettings.save()


func _exit_tree() -> void:
	# Remove dock
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()

	# Remove autoload
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
