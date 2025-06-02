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
	print("=== RTDBDebugAction.execute() CALLED ===")
	print("Action name: ", action_name)
	
	# Track test execution if we're in test context
	if DebugAction.current_test_id != "":
		DebugAction.test_action_count += 1

	print("=== About to call execute_rtdb_action() ===")
	# Call the actual implementation
	execute_rtdb_action()
	print("=== execute_rtdb_action() returned ===")


# Default execute implementation - subclasses should override this
func execute_rtdb_action() -> void:
	push_error("execute_rtdb_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_rtdb_action() not implemented", true)
	execution_completed.emit(false, {"error": "Not implemented"})


# Get Firebase backend instance through data source
func get_firebase_database():
	if not Engine.has_singleton("data_source"):
		Log.error(
			"DataSource singleton not available for RTDB operations", {}, ["debug", "rtdb", "error"]
		)
		return null

	var data_source = Engine.get_singleton("data_source")
	if not data_source:
		Log.error("DataSource singleton is null", {}, ["debug", "rtdb", "error"])
		return null

	# Access the backend directly
	# Access the backend directly
	var backend = data_source._backend
	if backend:
		if backend.get_class() == "FirebaseBackend":
			Log.debug(
				"Found Firebase backend for RTDB operations",
				{"backend_type": backend.get_class()},
				["debug", "rtdb"]
			)
			return backend
		else:
			Log.warning(
				"Backend is not Firebase type",
				{"backend_type": backend.get_class()},
				["debug", "rtdb", "warning"]
			)
			return null
	else:
		Log.error("Backend is null in DataSource", {}, ["debug", "rtdb", "error"])
		return null


# Helper method for RTDB operations using Firebase backend
func execute_simple_operation(
	method: String, path_variants: Array, value: Variant, operation_name: String
) -> Array:
	print("=== execute_simple_operation CALLED ===")
	print("Method: ", method)
	print("Operation: ", operation_name)
	
	Log.debug(
		"Executing RTDB operation",
		{
			"method": method,
			"path": path_variants,
			"operation": operation_name,
			"has_value": value != null
		},
		["debug", "rtdb"]
	)

	var firebase_backend = get_firebase_database()
	if not firebase_backend:
		var error_msg = "Firebase backend not available for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		execution_completed.emit(false, {"error": error_msg})
		return [false, {"error": error_msg}]

	if not firebase_backend.is_available():
		var error_msg = "Firebase backend not initialized for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		execution_completed.emit(false, {"error": error_msg})
		return [false, {"error": error_msg}]

	var result: Variant
	_update_status("Executing " + operation_name + "...")

	# Use the Firebase backend methods directly
	match method:
		"get_value_async":
			# Convert path to proper format
			var key = path_variants[-1] if path_variants.size() > 0 else ""
			var path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.get_data(path, key)

		"set_value_async":
			# Convert path to proper format
			var key = path_variants[-1] if path_variants.size() > 0 else ""
			var path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.set_data(path, key, value)

		"remove_value_async":
			# Convert path to proper format
			var key = path_variants[-1] if path_variants.size() > 0 else ""
			var path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.delete_data(path, key)

		_:
			var error_msg = "Unsupported RTDB method: " + method
			Log.error(error_msg, {"method": method}, ["debug", "rtdb", "error"])
			_update_status("ERROR: " + error_msg, true)
			execution_completed.emit(false, {"error": error_msg})
			return [false, {"error": error_msg}]

	# Handle result
	if result != null:
		Log.info(
			"RTDB operation completed successfully",
			{"operation": operation_name, "method": method, "result_type": typeof(result)},
			["debug", "rtdb", "success"]
		)
		_update_status(operation_name + " completed successfully")
		execution_completed.emit(true, {"result": result})
		return [true, {"result": result}]
	else:
		Log.warning(
			"RTDB operation returned null",
			{"operation": operation_name, "method": method},
			["debug", "rtdb", "warning"]
		)
		_update_status(operation_name + " completed (null result)")
		execution_completed.emit(true, {"result": null})
		return [true, {"result": null}]


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
