# project/debug/actions/rtdb/rtdb_legacy_basic_push_item_action.gd
@tool
class_name RTDBLegacyPushItemAction
extends RTDBDebugAction

var _transaction_count: int = 0


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Basic Push Item (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Pushes an item to RTDB"


func execute_rtdb_action() -> bool:
	Log.debug("RTDB Test: Push Item", {}, ["test"])
	_update_status("Running basic push item test...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		execution_completed.emit(false, error_result[1] if error_result.size() > 1 else null)
		return false

	_transaction_count += 1
	var push_data: Dictionary = {
		"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()
	}
	var test_path: Array[Variant] = ["pushed_items"]

	var success: bool = await execute_simple_operation(
		"push_value_async", test_path, push_data, "Basic Push Item"
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# Just return the success status for test tracking
	return success
