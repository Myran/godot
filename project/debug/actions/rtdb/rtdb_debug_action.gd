# project/debug/actions/rtdb/rtdb_debug_action.gd
@tool
class_name RTDBDebugAction
extends DebugAction


func _init() -> void:
	# Set category to RTDB by default, subclasses can override
	category = "RTDB"

	# Set the action callable to execute_rtdb_action
	# This ensures the base class execute() method handles all test tracking
	action_callable = Callable(self, "execute_rtdb_action")


# Default execute implementation - subclasses should override this
# Returns bool to indicate success/failure for test tracking
func execute_rtdb_action() -> bool:
	push_error("execute_rtdb_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_rtdb_action() not implemented", true)
	return false  # Return false to indicate failure


# Get Firebase backend instance through data source
func get_firebase_database() -> Object:
	# In Godot 4, autoloads are directly accessible by name
	if not data_source:
		Log.error(
			"DataSource singleton not available for RTDB operations", {}, ["debug", "rtdb", "error"]
		)
		return null

	# Check if DataSource is initialized
	if not data_source.is_initialized():
		Log.error(
			"DataSource not yet initialized for RTDB operations", {}, ["debug", "rtdb", "error"]
		)
		return null

	# Access the backend directly
	var backend: Variant = data_source._backend
	if backend:
		# Check if backend is FirebaseBackend using 'is' operator
		if backend is FirebaseBackend:
			Log.debug(
				"Found Firebase backend for RTDB operations",
				{
					"backend_type":
					backend.get_script().get_path() if backend.get_script() else "unknown"
				},
				["debug", "rtdb"]
			)
			return backend
		else:
			Log.warning(
				"Backend is not Firebase type",
				{
					"backend_type":
					backend.get_script().get_path() if backend.get_script() else backend.get_class()
				},
				["debug", "rtdb", "warning"]
			)
			return null
	else:
		Log.error("Backend is null in DataSource", {}, ["debug", "rtdb", "error"])
		return null


# Helper method for RTDB operations using Firebase backend
# Returns true/false for the base class test tracking
func execute_simple_operation(
	method: String, path_variants: Array, value: Variant, operation_name: String
) -> bool:
	var start_time_ms: int = Time.get_ticks_msec()
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

	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		var error_msg: String = "Firebase backend not available for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		return false

	if not firebase_backend.is_available():
		var error_msg: String = "Firebase backend not initialized for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		return false

	var result: Variant
	_update_status("Executing " + operation_name + "...")

	# Use the Firebase backend methods directly
	match method:
		"get_value_async":
			# Convert path to proper format
			var key: String = path_variants[-1] if path_variants.size() > 0 else ""
			var path: Array = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.get_data(path, key)

		"set_value_async":
			# Convert path to proper format
			var key: String = path_variants[-1] if path_variants.size() > 0 else ""
			var path: Array = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.set_data(path, key, value)

		"remove_value_async":
			# Convert path to proper format
			var key: String = path_variants[-1] if path_variants.size() > 0 else ""
			var path: Array = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.remove_data(path, key)

		"push_value_async":
			# Push data to Firebase, returns the generated push key
			result = await firebase_backend.push_data(path_variants, value)

		_:
			var duration_ms: int = Time.get_ticks_msec() - start_time_ms
			var error_msg: String = "Unsupported RTDB method: " + method
			Log.error(
				error_msg,
				{
					"method": method,
					"duration_ms": duration_ms,
					"available_methods":
					["get_value_async", "set_value_async", "remove_value_async", "push_value_async"]
				},
				["debug", "rtdb", "error"]
			)
			_update_status("ERROR: " + error_msg + " (" + str(duration_ms) + "ms)", true)
			return false

	# Handle result with performance tracking
	var duration_ms: int = Time.get_ticks_msec() - start_time_ms

	if result != null:
		Log.info(
			"RTDB operation completed successfully",
			{
				"operation": operation_name,
				"method": method,
				"result_type": typeof(result),
				"duration_ms": duration_ms,
				"performance":
				"GOOD" if duration_ms < 500 else ("SLOW" if duration_ms < 2000 else "VERY_SLOW")
			},
			["debug", "rtdb", "success"]
		)
		_update_status(operation_name + " completed successfully (" + str(duration_ms) + "ms)")
		return true
	else:
		Log.warning(
			"RTDB operation returned null",
			{"operation": operation_name, "method": method, "duration_ms": duration_ms},
			["debug", "rtdb", "warning"]
		)
		_update_status(operation_name + " completed (null result, " + str(duration_ms) + "ms)")
		return true


func get_last_error_result() -> Array:
	return [false, {"error": "get_last_error_result not implemented"}]


func create_test_path(path_suffix: Array = []) -> Array[Variant]:
	var base_path: Array[Variant] = ["debug_tests", "rtdb", str(Time.get_unix_time_from_system())]
	base_path.append_array(path_suffix)
	return base_path


func execute_firebase_operation(_db: Object, _operation: String, _args: Array) -> Dictionary:
	push_error("execute_firebase_operation() not implemented in base RTDBDebugAction")
	return {"success": false, "error": "execute_firebase_operation not implemented"}


# Static request ID generator for Firebase operations
static var _next_request_id: int = 1


static func generate_request_id() -> int:
	_next_request_id += 1
	return _next_request_id
