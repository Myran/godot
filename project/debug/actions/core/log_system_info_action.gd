# project/debug/actions/core/log_system_info_action.gd
@tool
class_name LogSystemInfoAction
extends DebugAction


func _init() -> void:
	action_name = "Log System Information"
	category = "System"
	group = "Diagnostics"
	description = "Logs basic system information and environment variables."


func execute() -> Array:
	_update_status("Collecting system information...")

	var info: Dictionary = {
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"godot_version": Engine.get_version_info(),
		"debug_build": OS.is_debug_build(),
		"processor_count": OS.get_processor_count(),
		"device_model": OS.get_model_name(),
		"memory_static_usage": OS.get_static_memory_usage(),
		"executable_path": OS.get_executable_path(),
		"time": Time.get_datetime_string_from_system()
	}

	var formatted_info: String = ""
	for key: String in info.keys():
		formatted_info += key + ": " + str(info[key]) + "\n"

	Log.info("System info collected by debug action", info, ["debug", "system"])
	_update_status("System Information:\n" + formatted_info)

	return _success(info)
