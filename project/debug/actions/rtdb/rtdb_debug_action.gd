# project/debug/actions/rtdb/rtdb_debug_action.gd
@tool
class_name RTDBDebugAction
extends DebugAction
## Base class for all RTDB (Realtime Database) debug actions.
##
## This class provides common functionality for Firebase database operations,
## including connection management and error handling. All RTDB debug actions
## should extend this class instead of DebugAction directly.
##
## Example usage:
## [codeblock]
## extends RTDBDebugAction
##
## func execute() -> Array:
##     var db = get_firebase_database()
##     if not db:
##         return get_last_error_result()
##
##     # Your RTDB operation code here
##     var result = await execute_firebase_operation(db, "get_value_async", [path])
## [/codeblock]

var _last_error_result: Array = []

## Static counter for generating unique request IDs
static var _request_counter: int = 0


func _init() -> void:
	# Set category to RTDB by default, subclasses can override
	category = "RTDB"


## Generate a unique request ID using a simple counter
static func generate_request_id() -> int:
	_request_counter += 1
	if _request_counter > 999999:  # Prevent overflow
		_request_counter = 1
	return _request_counter


## Gets a Firebase Database instance with proper error handling.
## Returns null if the database cannot be instantiated, and sets appropriate error state.
func get_firebase_database() -> Object:
	# Check if Firebase class exists
	if not ClassDB.class_exists("FirebaseDatabase"):
		_update_status("FirebaseDatabase class not found.", true)
		_last_error_result = _failure("FirebaseDatabase C++ module not available.")
		return null

	# Instantiate the database
	var db: Object = ClassDB.instantiate("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status("Failed to instantiate FirebaseDatabase.", true)
		_last_error_result = _failure("Could not create FirebaseDatabase instance.")
		return null

	return db


## Returns the last error result from a failed get_firebase_database_for_target() call.
## This should be called immediately after get_firebase_database_for_target() returns null.
func get_last_error_result() -> Array:
	return _last_error_result


## Helper to create test paths with common debug prefix
func create_test_path(path_suffix: Array[Variant]) -> Array[Variant]:
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	return test_base_path + path_suffix


## Execute a Firebase operation and wait for its completion
## Uses FirebaseOperationManager for cleaner separation of concerns
func execute_firebase_operation(
	db: Object, operation: String, args: Array, timeout_sec: float = 10.0
) -> Dictionary:
	if not is_instance_valid(db):
		return {"success": false, "error": "Database instance invalid"}

	var op_manager := FirebaseOperationManager.new(db)
	return await op_manager.execute(operation, args, timeout_sec)


## Simplified template for common get/set/delete operations
func execute_simple_operation(
	operation: String,
	test_path: Array[Variant],
	test_data: Variant = null,
	operation_name: String = ""
) -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var display_name: String = operation_name if operation_name else operation
	_update_status("Executing %s..." % display_name)

	var args: Array = [test_path]
	if test_data != null:
		args.append(test_data)

	var result: Dictionary = await execute_firebase_operation(db, operation, args)

	if result.success:
		_update_status("%s completed successfully" % display_name)
		return _success(
			{
				"operation": operation,
				"path": test_path,
				"result": result.data,
				"timestamp": TimeUtils.now_ms()
			}
		)
	else:
		_update_status("%s failed: %s" % [display_name, result.error], true)
		return _failure(result.error)
