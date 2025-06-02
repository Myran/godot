# project/debug/actions/rtdb/rtdb_legacy_basic_get_simple_value_action.gd
@tool
class_name RTDBLegacyGetSimpleValueAction
extends RTDBDebugAction

func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Basic Get Simple Value (Legacy)"
	group = "Legacy Tests"
	description = "Migrated from scene_debug.gd - Gets a simple value from RTDB"

func execute_rtdb_action() -> void:
	Log.debug("RTDB Test: Get Simple Value", {}, ["test"])
	_update_status("Running basic get simple value test...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		execution_completed.emit(false, error_result[1] if error_result.size() > 1 else null)
		return

	var test_path: Array[Variant] = ["simple_value"]

	var result: Array = await execute_simple_operation(
		"get_value_async", test_path, null, "Basic Get Simple Value"
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)