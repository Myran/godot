# Migrated from scene_debug.gd _test_rtdb_basic_push_item
@tool
extends RTDBDebugAction

var _transaction_count: int = 0


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Basic Push Item (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Pushes an item to RTDB"


func execute() -> void:
	Log.debug("RTDB Test: Push Item", {}, ["test"])
	_update_status("Running basic push item test...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = _last_error_result
		execution_completed.emit(false, error_result[1] if error_result.size() > 1 else null)
		return

	_transaction_count += 1
	var push_data: Dictionary = {
		"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()
	}
	var test_path: Array[Variant] = ["pushed_items"]

	var result: Array = await execute_simple_operation(
		"push_and_update_async", test_path, push_data, "Basic Push Item"
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
