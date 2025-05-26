# Migrated from scene_debug.gd _test_rtdb_basic_set_simple_value
@tool
extends RTDBDebugAction

var _transaction_count: int = 0


func _init() -> void:
	action_name = "Basic Set Simple Value (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Sets a simple value in RTDB"


func execute() -> Array:
	Log.debug("RTDB Test: Set Simple Value", {}, ["test"])
	_update_status("Running basic set simple value test...")

	var db: Object = get_firebase_database()
	if not db:
		return _last_error_result

	_transaction_count += 1
	var test_path: Array[Variant] = ["simple_value"]
	var test_data: Variant = "Basic Value " + str(_transaction_count)

	return await execute_simple_operation(
		"set_value_async", test_path, test_data, "Basic Set Simple Value"
	)
