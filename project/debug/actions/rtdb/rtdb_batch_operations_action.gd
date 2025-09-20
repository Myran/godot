class_name RTDBBatchOperationsAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.advanced.batch_ops"
	group = "Advanced"
	description = "Performs multiple RTDB operations in sequence to test batch processing."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var db: Object = get_firebase_database()
	if not db:
		return DebugActionResult.new_failure(
			"Firebase database not available",
			"DATABASE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.BATCH_OPS)
	var batch_operations: Array[Dictionary] = []
	var base_timestamp: int = TimeUtils.now_ms()

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

	for i: int in range(operations_to_perform.size()):
		var operation: Dictionary = operations_to_perform[i]
		var operation_result: Dictionary = await _execute_single_operation(db, operation, i)
		batch_operations.append(operation_result)

	var successful_operations: int = 0
	for result: Dictionary in batch_operations:
		if result.get("success", false):
			successful_operations += 1

	var total_operations: int = batch_operations.size()
	var success_rate: float = (
		float(successful_operations) / float(total_operations) if total_operations > 0 else 0.0
	)
	var duration_ms: int = Time.get_ticks_msec() - start_time

	return DebugActionResult.new_batch_result(
		batch_operations,
		success_rate,
		action_name,
		duration_ms,
		{
			"batch_type": "sequential_operations",
			"test_path": full_path,
			"base_timestamp": base_timestamp
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _execute_single_operation(
	_db: Object, operation: Dictionary, operation_index: int
) -> Dictionary:
	var operation_type_variant: Variant = operation.get("type")
	var operation_type: String = str(operation_type_variant)
	var operation_path_variant: Variant = operation.get("path")
	var operation_path: Array = operation_path_variant
	var operation_data: Variant = operation.get("data")
	match operation_type:
		"set":
			var success_bool: bool = await execute_simple_operation(
				"set_value_async", operation_path, operation_data, "Batch Set Operation"
			)
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": success_bool,
				"data_sent": operation_data,
				"error": "" if success_bool else "Set operation failed"
			}

		"update":
			var success_bool: bool = await execute_simple_operation(
				"set_value_async", operation_path, operation_data, "Batch Update Operation"
			)
			return {
				"operation_index": operation_index,
				"type": operation_type,
				"path": operation_path,
				"success": success_bool,
				"data_updated": operation_data,
				"error": "" if success_bool else "Update operation failed"
			}

		"get":
			var success_bool: bool = await execute_simple_operation(
				"get_value_async", operation_path, null, "Batch Get Operation"
			)
			var data_received: Variant = null  # execute_simple_operation doesn't return data
			var error_message: String = "" if success_bool else "Get operation failed"
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
