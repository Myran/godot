# project/debug/actions/rtdb/rtdb_remove_all_listeners_action.gd
@tool
class_name RTDBRemoveAllListenersAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Remove All Listeners"
	group = "Listeners"
	description = "Removes active RTDB listeners to clean up test state."


func execute() -> Array:
	var db = get_firebase_database()
	if not db:
		return get_last_error_result()

	_update_status("Removing RTDB listeners...")

	# The C++ Firebase module only supports one active child listener at a time
	# We'll remove listeners from common test paths used by debug actions
	var test_paths: Array[Array] = [
		create_test_path(["child_events"]),  # Used by child listener actions
		create_test_path(["single_value"]),  # Used by single value listener
		create_test_path(["test_data"]),  # Common test path
		create_test_path([])  # Base debug test path
	]

	var removed_count: int = 0
	for path in test_paths:
		# The C++ module's remove_listener_at_path() doesn't return a value
		# It removes the listener if one exists at that path
		db.remove_listener_at_path(path)
		removed_count += 1

		Log.debug(
			"Attempted to remove listener at path", {"path": path}, ["rtdb", "listeners", "cleanup"]
		)

	_update_status("Attempted to remove listeners from %d common test paths" % removed_count)

	Log.info(
		"RTDBRemoveAllListenersAction executed successfully",
		{"operation": "remove_listeners_at_paths", "paths_attempted": removed_count},
		["test", "rtdb", "listeners"]
	)

	return _success(
		{
			"operation": "remove_listeners_at_paths",
			"paths_attempted": removed_count,
			"timestamp": Time.get_ticks_msec(),
			"status": "cleanup_attempted"
		}
	)
