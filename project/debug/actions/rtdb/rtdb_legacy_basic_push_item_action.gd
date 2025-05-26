# Migrated from scene_debug.gd _test_rtdb_basic_push_item
@tool
extends RTDBDebugAction

var _transaction_count: int = 0


func _init() -> void:
	action_name = "Basic Push Item (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Pushes an item to RTDB"


func execute() -> Array:
	Log.debug("RTDB Test: Push Item", {}, ["test"])
	_update_status("Running basic push item test...")

	var db: Object = get_firebase_database()
	if not db:
		return _last_error_result

	_transaction_count += 1
	var push_data: Dictionary = {
		"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()
	}
	var test_path: Array[Variant] = ["pushed_items"]

	return await execute_simple_operation(
		"push_and_update_async", test_path, push_data, "Basic Push Item"
	)
