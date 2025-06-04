# project/debug/actions/registrations/system_actions.gd
# System-level debug actions for infrastructure and platform utilities

class_name SystemActions


static func register_all(registry: DebugActionRegistry) -> void:
	_register_memory_actions(registry)
	_register_debug_system_actions(registry)
	_register_connectivity_actions(registry)

	Log.info("System debug actions registered", {}, ["debug", "system"])


static func _register_memory_actions(registry: DebugActionRegistry) -> void:
	# System memory utilities
	registry.register_action(
		(
			DebugAction
			. create("Force Low Memory Warning", _force_low_memory)
			. set_category("System")
			. set_group("Memory")
			. set_description("Simulates low memory condition for testing memory management")
		)
	)


static func _register_debug_system_actions(registry: DebugActionRegistry) -> void:
	# Registry introspection utilities
	registry.register_action(
		(
			DebugAction
			. create("Show Registry Stats", func() -> bool: return _show_registry_stats(registry))
			. set_category("System")
			. set_group("Debug")
			. set_description("Display debug action registry statistics")
		)
	)

	# Registry introspection utilities
	registry.register_action(
		(
			DebugAction
			. create("Quit Application", func() -> bool: return _quit_application())
			. set_category("System")
			. set_group("Debug")
			. set_description("Quit Application")
		)
	)


#static func _quit() -> void:
#DebugManager.action(DebugManager.DebugEventType.EVENT_QUIT)


static func _register_connectivity_actions(registry: DebugActionRegistry) -> void:
	# RTDB Status check - always available
	registry.register_action(
		(
			DebugAction
			. create("RTDB Status", _rtdb_status_check)
			. set_category("RTDB")
			. set_group("Utilities")
			. set_description("Check RTDB availability and connection status")
		)
	)


# System action implementations
static func _force_low_memory() -> bool:
	# Simulate low memory condition
	Log.warning("Simulating low memory condition for testing", {}, ["debug", "system", "memory"])

	if OS.has_method("low_processor_usage_mode"):
		var old_mode: bool = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode = old_mode

	Log.info("Low memory simulation completed", {}, ["debug", "system", "memory"])
	return true


static func _show_registry_stats(registry: DebugActionRegistry) -> bool:
	# Display debug action registry statistics
	var stats: Dictionary = {
		"total_actions": registry.get_all_actions().size(),
		"total_categories": registry.get_categories().size(),
		"categories": {}
	}

	for category: String in registry.get_categories():
		var category_stats: Dictionary = {
			"groups": registry.get_groups_for_category(category).size(),
			"ungrouped_actions": registry.get_ungrouped_actions(category).size(),
			"total_actions": 0
		}

		for group: String in registry.get_groups_for_category(category):
			category_stats.total_actions += registry.get_actions_for_group(category, group).size()
		category_stats.total_actions += category_stats.ungrouped_actions

		stats.categories[category] = category_stats

	Log.info("Debug Action Registry Statistics", stats, ["debug", "registry", "stats"])
	return true


static func _quit_application() -> bool:
	# Quit the application
	DebugManager.action(DebugManager.DebugEventType.EVENT_QUIT)
	return true


static func _rtdb_status_check() -> bool:
	# Check RTDB status and availability
	var status: Dictionary = {
		"firebase_database_available": ClassDB.class_exists("FirebaseDatabase"),
		"firebase_auth_available": ClassDB.class_exists("FirebaseAuth"),
		"platform": OS.get_name(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("RTDB Status Check", status, ["debug", "rtdb", "status"])
	return true
