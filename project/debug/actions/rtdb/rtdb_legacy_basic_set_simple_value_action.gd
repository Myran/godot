# Migrated from scene_debug.gd _test_rtdb_basic_set_simple_value
@tool
extends RTDBDebugAction

var _transaction_count: int = 0


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Basic Set Simple Value (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Sets a simple value in RTDB"


func execute() -> void:
	Log.debug("RTDB Test: Set Simple Value", {}, ["test"])
	_update_status("Running basic set simple value test...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = _last_error_result
		execution_completed.emit(false, error_result[1] if error_result.size() > 1 else null)
		return

	_transaction_count += 1
	var test_path: Array[Variant] = ["simple_value"]
	var test_data: Variant = "Basic Value " + str(_transaction_count)

	var result: Array = await execute_simple_operation(
		"set_value_async", test_path, test_data, "Basic Set Simple Value"
	)
	
	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
