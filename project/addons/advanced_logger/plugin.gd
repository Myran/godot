@tool
extends EditorPlugin
## Plugin initialization script for the Advanced Logger

const AUTOLOAD_NAME: String = "Log"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/core/logger.gd"
const LOGGER_DOCK_PATH: String = "res://addons/advanced_logger/logger_dock.tscn"
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const EXPORT_PLUGIN_PATH: String = "res://addons/advanced_logger/advanced_logger_export_plugin.gd"
const IOS_LOADER_PATH: String = "res://addons/advanced_logger/ios_loader.gd"
const IOS_LOADER_NAME: String = "LoggerIOSLoader"
const DOCK_POSITION: int = EditorPlugin.DOCK_SLOT_RIGHT_UL

var _dock: Control
var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	# Register autoload singleton for runtime use
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Add iOS Loader autoload if available
	if FileAccess.file_exists(IOS_LOADER_PATH):
		add_autoload_singleton(IOS_LOADER_NAME, IOS_LOADER_PATH)
		print_rich("[color=#%s]Advanced Logger: iOS Loader registered[/color]" % LoggerColors.INFO_HTML)

	# Register export plugin
	_export_plugin = load(EXPORT_PLUGIN_PATH).new()
	add_export_plugin(_export_plugin)

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

	# Ensure the config file is always exported
	if not ProjectSettings.has_setting("advanced_logger/export_config_file"):
		ProjectSettings.set_setting("advanced_logger/export_config_file", true)
		ProjectSettings.set_initial_value("advanced_logger/export_config_file", true)
		ProjectSettings.add_property_info({
			"name": "advanced_logger/export_config_file",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Always export the logger config file"
		})

	ProjectSettings.save()


func _exit_tree() -> void:
	# Clean up ConfigManager first before removing anything else
	_cleanup_config_manager()

	# Remove dock
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	# Remove export plugin
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null

	# Remove autoloads
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

	if Engine.has_singleton(IOS_LOADER_NAME):
		remove_autoload_singleton(IOS_LOADER_NAME)

## Notification handler for plugin cleanup
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Make sure we clean up when the plugin is about to be destroyed
		_cleanup_config_manager()

## Helper function to clean up ConfigManager
func _cleanup_config_manager() -> void:
	# We need to be very careful about cleaning up the singleton
	const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

	# Get and cleanup instance first
	var instance = ConfigManager.get_instance()
	if instance:
		# Clean up the instance internals
		instance.cleanup_instance()

	# Then clean up the static singleton
	ConfigManager.cleanup()

	# Force garbage collection if needed
	if OS.is_debug_build():
		print("Advanced Logger: Cleaned up ConfigManager singleton")
