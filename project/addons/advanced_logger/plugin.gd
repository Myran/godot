@tool
extends EditorPlugin
## Plugin initialization script for the Advanced Logger

const AUTOLOAD_NAME: String = "Log"
const LOGGER_SCRIPT_PATH: String = "res://addons/advanced_logger/logger.gd"
const LOGGER_DOCK_PATH: String = "res://addons/advanced_logger/logger_dock.tscn"
const DOCK_POSITION: int = EditorPlugin.DOCK_SLOT_RIGHT_UL

var _dock: Control


func _enter_tree() -> void:
	# Register autoload singleton for runtime use
	add_autoload_singleton(AUTOLOAD_NAME, LOGGER_SCRIPT_PATH)

	# Add the dock - it works independently via config
	var dock_scene: PackedScene = load(LOGGER_DOCK_PATH)
	if dock_scene:
		_dock = dock_scene.instantiate()
		add_control_to_dock(DOCK_POSITION, _dock)
		print_rich('dock: ',_dock)
		print_rich("[color=#%s]Advanced Logger initialized[/color]" % LoggerColors.SUCCESS_HTML)
	else:
		push_error("Failed to load logger dock scene")


func _exit_tree() -> void:
	# Remove dock
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()

	# Remove autoload
	if Engine.has_singleton(AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
