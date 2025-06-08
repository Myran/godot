# project/debug/actions/rtdb/rtdb_set_simple_value_action.gd
class_name RTDBSetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Set Simple Value"


# Override the new pattern instead of the legacy one
func _execute_action_logic(params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	var test_value: String = params.get("value_to_set", "Test Value: " + str(TimeUtils.now_ms()))
	
	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return DebugActionResult.new_failure(
			"Firebase backend not available",
			"BACKEND_UNAVAILABLE",
			DebugActionResult.ErrorCategory.SYSTEM,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)
	
	if not firebase_backend.is_available():
		return DebugActionResult.new_failure(
			"Firebase backend not initialized",
			"BACKEND_NOT_INITIALIZED",
			DebugActionResult.ErrorCategory.SYSTEM,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)
	
	# Use Firebase backend directly - it returns DebugActionResult-compatible data
	var path_variants: Array = RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE)
	var key: String = path_variants[-1] if path_variants.size() > 0 else ""
	var path: Array = path_variants.slice(0, -1) if path_variants.size() > 1 else []
	
	var result_success: bool = await firebase_backend.set_data(path, key, test_value)
	var duration_ms: int = Time.get_ticks_msec() - start_time
	
	if result_success:
		return DebugActionResult.new_success(
			{"value_set": test_value, "path": path_variants},
			duration_ms,
			action_name,
			{"test_type": "simple_value", "backend": "firebase"}
		)
	else:
		return DebugActionResult.new_failure(
			"Set operation failed",
			"SET_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			{"attempted_value": test_value, "path": path_variants},
			duration_ms,
			action_name
		)


# Keep legacy method for compatibility but mark it as deprecated
func execute_rtdb_action() -> bool:
	# This will be removed once all actions migrate to new pattern
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
