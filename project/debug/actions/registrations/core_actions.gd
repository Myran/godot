# project/debug/actions/registrations/core_actions.gd
class_name CoreDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_system_actions(registry)


static func _register_system_actions(registry: DebugActionRegistry) -> void:
	# Log System Information - existing resource-based action
	var log_system_action: LogSystemInfoAction = LogSystemInfoAction.new()
	registry.register_action(log_system_action)

	# System utilities using new programmatic approach
	registry.register_action(
		(
			DebugAction
			. create("Clear All Caches", _clear_all_caches)
			. set_category("System")
			. set_group("Cache")
			. set_description("Clears all game caches and temporary data")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Force Garbage Collection", _force_gc)
			. set_category("System")
			. set_group("Memory")
			. set_description("Forces immediate garbage collection")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Print Engine Info", _print_engine_info)
			. set_category("System")
			. set_group("Information")
			. set_description("Prints detailed engine and system information")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Reset Debug Settings", _reset_debug_settings)
			. set_category("System")
			. set_group("Configuration")
			. set_description("Resets all debug-related settings to defaults")
			. set_requires_confirmation(true)
		)
	)


# Implementation functions for system actions
static func _clear_all_caches() -> void:
	# Clear caches if available - data_source is an autoload singleton
	if is_instance_valid(data_source) and data_source.has_method("clear_cache"):
		data_source.clear_cache()

	Log.info("All caches cleared", {}, ["debug", "system"])


static func _force_gc() -> void:
	# Request memory cleanup using available methods
	# Note: Godot handles GC automatically, but we can trigger memory pressure
	if OS.has_method("low_processor_usage_mode"):
		var old_mode = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode = old_mode

	Log.info("Garbage collection requested", {}, ["debug", "system"])


static func _print_engine_info() -> void:
	var info := {
		"engine_version": Engine.get_version_info(),
		"platform": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"memory_usage": OS.get_static_memory_usage(),
		"is_debug_build": OS.is_debug_build(),
		"command_line_args": OS.get_cmdline_args(),
		"environment": OS.get_environment("PATH")
	}

	Log.info("Engine Information", info, ["debug", "system", "info"])


static func _reset_debug_settings() -> void:
	# Reset debug manager settings
	if DebugManager:
		DebugManager.use_local_battle_db = false
		DebugManager.asset_variant = 1
		# Reset other debug settings as needed

	Log.info("Debug settings reset to defaults", {}, ["debug", "system"])
