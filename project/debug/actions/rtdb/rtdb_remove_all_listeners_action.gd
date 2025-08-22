class_name RTDBRemoveAllListenersAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.listeners.remove_all"
	group = "Listeners"
	description = "Removes active RTDB listeners to clean up test state."


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		return false

	_update_status("Removing RTDB listeners...")

	var test_paths: Array[Array] = [
		create_test_path(["child_events"]),  # Used by child listener actions
		create_test_path(["single_value"]),  # Used by single value listener
		create_test_path(["test_data"]),  # Common test path
		create_test_path([])  # Base debug test path
	]

	var removed_count: int = 0
	for path: Array in test_paths:
		db.stop_listening(path)
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

	return true
