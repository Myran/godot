# project/debug/actions/rtdb/rtdb_batch_operations_action.gd
@tool
class_name RTDBBatchOperationsAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Batch Operations"
	group = "Advanced"
	description = "Performs multiple RTDB operations in sequence to test batch processing."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.BATCH_OPS)

	_update_status("Starting batch operations test at path '%s'..." % str(full_path))

	var batch_operations: Array[Dictionary] = []
	var base_timestamp: int = TimeUtils.now_ms()

# Define multiple operations to perform in batch
	var operations_to_perform: Array[Dictionary] = [
		{
			"type": "set",
			"path": full_path + ["batch_item_1"],
			"data": {"name": "First Batch Item", "value": 100, "timestamp": base_timestamp}
		},
		{
			"type": "set",
			"path": full_path + ["batch_item_2"],
			"data": {"name": "Second Batch Item", "value": 200, "timestamp": base_timestamp + 1}
		},
		{
			"type": "set",
			"path": full_path + ["batch_item_3"],
			"data": {"name": "Third Batch Item", "value": 300, "timestamp": base_timestamp + 2}
		},
		{
			"type": "update",
			"path": full_path + ["batch_item_1"],
			"data": {"updated": true, "update_timestamp": base_timestamp + 10}
		},
		{"type": "get", "path": full_path + ["batch_item_2"], "data": null}
	]

# Execute batch operations
	for i: int in range(operations_to_perform.size()):
		var operation: Dictionary = operations_to_perform[i]
		var operation_result: Dictionary = await _execute_single_operation(db, operation, i)
		batch_operations.append(operation_result)

		# Brief delay between operations
		await Engine.get_main_loop().create_timer(0.1).timeout

# Count successful operations
	var successful_operations: int = 0
	var failed_operations: int = 0

	for result: Dictionary in batch_operations:
		var success_variant: Variant = result.get("success")
		var success_bool: bool = success_variant
		if success_bool:
			successful_operations += 1
		else:
			failed_operations += 1

	var batch_success: bool = failed_operations == 0
	var status_msg: String = (
		"Batch operations completed: %d successful, %d failed out of %d total"
		% [successful_operations, failed_operations, batch_operations.size()]
	)
	_update_status(status_msg, not batch_success)

	Log.debug(
		"RTDBBatchOperationsAction executed",
		{
			"path": full_path,
			"operation": "batch_operations",
			"success": batch_success,
			"total_operations": batch_operations.size(),
			"successful_operations": successful_operations,
			"failed_operations": failed_operations,
			"operations": batch_operations
		},
		["test", "rtdb", "advanced"]
	)

	return _success(
		{
			"operation": "batch_operations",
			"path": full_path,
			"success": batch_success,
			"total_operations": batch_operations.size(),
			"successful_operations": successful_operations,
			"failed_operations": failed_operations,
			"operations": batch_operations,
			"timestamp": TimeUtils.now_ms()
		}
	)


func _execute_single_operation(
	db: Object, operation: Dictionary, operation_index: int
) -> Dictionary:
	var operation_type_variant: Variant = operation.get("type")
	var operation_type: String = str(operation_type_variant)
	var operation_path_variant: Variant = operation.get("path")
	var operation_path: Array[Variant] = operation_path_variant
	var operation_data: Variant = operation.get("data")
	var op_manager: FirebaseOperationManager = FirebaseOperationManager.new(db)

	match operation_type:
		"set":
			var result: Dictionary = await op_manager.execute(
				"set_value_async", [operation_path, operation_data]
			)
			var result_success: Variant = result.get("success")
			var success_bool: bool = result_success
			var has_error: bool = result.has("error")
			var error_message: String = str(result.get("error")) if has_error else ""
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": success_bool,
				"data_sent": operation_data,
				"error": error_message
			}

		"update":
			# Use set for now as C++ module may not have update_value_async
			var result: Dictionary = await op_manager.execute(
				"set_value_async", [operation_path, operation_data]
			)
			var result_success: Variant = result.get("success")
			var success_bool: bool = result_success
			var has_error: bool = result.has("error")
			var error_message: String = str(result.get("error")) if has_error else ""
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": success_bool,
				"data_updated": operation_data,
				"error": error_message
			}

		"get":
			var result: Dictionary = await op_manager.execute("get_value_async", [operation_path])
			var result_success: Variant = result.get("success")
			var success_bool: bool = result_success
			var has_data: bool = result.has("data")
			var data_received: Variant = result.get("data") if has_data else null
			var has_error: bool = result.has("error")
			var error_message: String = str(result.get("error")) if has_error else ""
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": success_bool,
				"data_received": data_received,
				"error": error_message
			}

		_:
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": false,
				"error": "Unknown operation type: %s" % operation_type
			}
