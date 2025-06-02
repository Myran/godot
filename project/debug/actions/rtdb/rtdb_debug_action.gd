# project/debug/actions/rtdb/rtdb_debug_action.gd
@tool
class_name RTDBDebugAction
extends DebugAction

func _init() -> void:
	# Set category to RTDB by default, subclasses can override
	category = "RTDB"


# Handle test tracking when action completes
func _on_execution_completed(success: bool, result: Variant) -> void:
	if DebugAction.current_test_id != "":
		if success:
			DebugAction.test_success_count += 1
			Log.info(
				"DEBUG_TEST_SUCCESS",
				{
					"test_id": DebugAction.current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"duration_ms": 0  # Could be enhanced with timing
				},
				["debug", "test", "success"]
			)
		else:
			DebugAction.test_failure_count += 1
			Log.error(
				"DEBUG_TEST_FAILURE",
				{
					"test_id": DebugAction.current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"error": str(result),
					"duration_ms": 0  # Could be enhanced with timing
				},
				["debug", "test", "failure"]
			)


# Enhanced execute method with test tracking
func execute() -> void:
	# Track test execution if we're in test context
	if DebugAction.current_test_id != "":
		DebugAction.test_action_count += 1

	# Call the actual implementation
	execute_rtdb_action()


# Default execute implementation - subclasses should override this
func execute_rtdb_action() -> void:
	push_error("execute_rtdb_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_rtdb_action() not implemented", true)
	execution_completed.emit(false, {"error": "Not implemented"})


# Helper methods for RTDB operations - to be implemented by subclasses or base class
func execute_simple_operation(method: String, path_variants: Array, value: Variant, operation_name: String) -> Array:
	push_error("execute_simple_operation() not implemented in base RTDBDebugAction")
	return [false, {"error": "execute_simple_operation not implemented"}]


func get_firebase_database():
	push_error("get_firebase_database() not implemented in base RTDBDebugAction")
	return null


func get_last_error_result() -> Array:
	return [false, {"error": "get_last_error_result not implemented"}]


func create_test_path(path_suffix: Array = []) -> Array[Variant]:
	var base_path: Array[Variant] = ["debug_tests", "rtdb", str(Time.get_unix_time_from_system())]
	base_path.append_array(path_suffix)
	return base_path


func execute_firebase_operation(db: Object, operation: String, args: Array) -> Dictionary:
	push_error("execute_firebase_operation() not implemented in base RTDBDebugAction")
	return {"success": false, "error": "execute_firebase_operation not implemented"}


# Static request ID generator for Firebase operations
static var _next_request_id: int = 1

static func generate_request_id() -> int:
	_next_request_id += 1
	return _next_request_id