# project/debug/actions/rtdb/rtdb_batch_operations_action.gd
@tool
class_name RTDBBatchOperationsAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Batch Operations"
	group = "Advanced"
	description = "Performs multiple RTDB operations in sequence to test batch processing."


func execute(target_node: Node = null) -> Array:
	var db = get_firebase_database_for_target(target_node)
	if not db:
		return get_last_error_result()

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.BATCH_OPS)

	_update_status(target_node, "Starting batch operations test at path '%s'..." % str(full_path))

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
	for i in range(operations_to_perform.size()):
		var operation: Dictionary = operations_to_perform[i]
		var operation_result: Dictionary = await _execute_single_operation(
			db, operation, i, target_node
		)
		batch_operations.append(operation_result)

		# Brief delay between operations
		await target_node.get_tree().create_timer(0.1).timeout

# Count successful operations
	var successful_operations: int = 0
	var failed_operations: int = 0

	for result in batch_operations:
		if result.success:
			successful_operations += 1
		else:
			failed_operations += 1

	var batch_success: bool = failed_operations == 0
	var status_msg: String = (
		"Batch operations completed: %d successful, %d failed out of %d total"
		% [successful_operations, failed_operations, batch_operations.size()]
	)
	_update_status(target_node, status_msg, not batch_success)

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
	db: Object, operation: Dictionary, operation_index: int, target_node: Node
) -> Dictionary:
	var operation_type: String = operation.type
	var operation_path: Array[Variant] = operation.path
	var operation_data: Variant = operation.data
	var op_manager := FirebaseOperationManager.new(db)

	match operation_type:
		"set":
			var result: Dictionary = await op_manager.execute(
				"set_value_async", [operation_path, operation_data]
			)
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": result.success,
				"data_sent": operation_data,
				"error": result.get("error", "")
			}

		"update":
			# Use set for now as C++ module may not have update_value_async
			var result: Dictionary = await op_manager.execute(
				"set_value_async", [operation_path, operation_data]
			)
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": result.success,
				"data_updated": operation_data,
				"error": result.get("error", "")
			}

		"get":
			var result: Dictionary = await op_manager.execute("get_value_async", [operation_path])
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": result.success,
				"data_received": result.get("data", null),
				"error": result.get("error", "")
			}

		_:
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": false,
				"error": "Unknown operation type: %s" % operation_type
			}
