# Migrated from scene_debug.gd _test_rtdb_basic_get_simple_value
extends RTDBDebugAction


func _init():
	action_name = "Basic Get Simple Value (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Gets a simple value from RTDB"


func execute() -> Array:
	Log.debug("RTDB Test: Get Simple Value", {}, ["test"])
	_update_status("Running basic get simple value test...")

	var db = get_firebase_database()
	if not db:
		return _last_error_result

	var test_path: Array[Variant] = ["simple_value"]

	return await execute_simple_operation(
		"get_value_async", test_path, null, "Basic Get Simple Value"
	)
