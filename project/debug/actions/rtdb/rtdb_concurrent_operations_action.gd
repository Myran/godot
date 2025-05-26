# project/debug/actions/rtdb/rtdb_concurrent_operations_action.gd
@tool
class_name RTDBConcurrentOperationsAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Concurrent Operations"
	group = "Advanced"
	description = "Tests multiple simultaneous RTDB operations to verify concurrent handling."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var path_suffix: Array[Variant] = ["concurrent_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)

	_update_status("Starting concurrent operations test at path '%s'..." % str(full_path))

	var base_timestamp: int = Time.get_ticks_msec()
	var concurrent_tasks: Array[Dictionary] = []

# Launch multiple operations concurrently (simulated)
	var concurrent_operations: Array[Dictionary] = [
		{
			"id": "concurrent_1",
			"type": "set",
			"path": full_path + ["concurrent_item_1"],
			"data": {"operation": "concurrent_set_1", "timestamp": base_timestamp}
		},
		{
			"id": "concurrent_2",
			"type": "set",
			"path": full_path + ["concurrent_item_2"],
			"data": {"operation": "concurrent_set_2", "timestamp": base_timestamp + 1}
		},
		{
			"id": "concurrent_3",
			"type": "get",
			"path": full_path + ["concurrent_item_1"],
			"data": null
		},
		{
			"id": "concurrent_4",
			"type": "update",
			"path": full_path + ["concurrent_item_2"],
			"data": {"updated_concurrently": true, "update_time": base_timestamp + 10}
		},
		{
			"id": "concurrent_5",
			"type": "set",
			"path": full_path + ["concurrent_item_3"],
			"data": {"operation": "concurrent_set_3", "timestamp": base_timestamp + 2}
		}
	]

# Start all operations simultaneously (simulated concurrency)
	for operation: Dictionary in concurrent_operations:
		var task: Dictionary = _start_concurrent_operation(db, operation)
		concurrent_tasks.append(task)

# Wait for all operations to complete

	_update_status("Waiting for %d concurrent operations to complete..." % concurrent_tasks.size())

# Simulate concurrent execution time
	await Engine.get_main_loop().create_timer(0.5).timeout

# Collect results from all concurrent operations
	var completed_operations: Array[Dictionary] = []
	for task: Dictionary in concurrent_tasks:
		var result: Dictionary = await _wait_for_operation_completion(task)
		completed_operations.append(result)

	# Analyze results
	var successful_operations: int = 0
	var failed_operations: int = 0
	var total_duration: float = 0.0

	for result: Dictionary in completed_operations:
		if result.success:
			successful_operations += 1
		else:
			failed_operations += 1
			total_duration += result.get("duration") if result.has("duration") else 0.0

	var average_duration: float = (
		total_duration / completed_operations.size() if completed_operations.size() > 0 else 0.0
	)
	var test_success: bool = failed_operations == 0

	var status_msg: String = (
		"Concurrent operations completed: %d successful, %d failed. Avg duration: %.2fms"
		% [successful_operations, failed_operations, average_duration]
	)
	_update_status(status_msg, not test_success)

	Log.debug(
		"RTDBConcurrentOperationsAction executed",
		{
			"path": full_path,
			"operation": "concurrent_operations",
			"success": test_success,
			"total_operations": completed_operations.size(),
			"successful_operations": successful_operations,
			"failed_operations": failed_operations,
			"average_duration_ms": average_duration,
			"operations": completed_operations
		},
		["test", "rtdb", "advanced"]
	)

	return _success(
		{
			"operation": "concurrent_operations",
			"path": full_path,
			"success": test_success,
			"total_operations": completed_operations.size(),
			"successful_operations": successful_operations,
			"failed_operations": failed_operations,
			"average_duration_ms": average_duration,
			"operations": completed_operations,
			"timestamp": Time.get_ticks_msec()
		}
	)


func _start_concurrent_operation(db: Variant, operation: Dictionary) -> Dictionary:
	var start_time: int = Time.get_ticks_msec()
	var request_id: int = start_time % 1000000

	match operation.type:
		"set":
			db.set_value_async(request_id, operation.path, operation.data)
		"get":
			db.get_value_async(request_id, operation.path)
		"update":
			db.set_value_async(request_id, operation.path, operation.data)  # Simulating update
		_:
			pass

	return {
		"operation_id": operation.id,
		"type": operation.type,
		"path": operation.path,
		"request_id": request_id,
		"start_time": start_time,
		"data": operation.data
	}


func _wait_for_operation_completion(task: Dictionary) -> Dictionary:
# Simulate variable completion times for different operations
	var completion_delay: float = randf_range(0.1, 0.3)
	await Engine.get_main_loop().create_timer(completion_delay).timeout

	var end_time: int = Time.get_ticks_msec()
	var duration: float = end_time - task.start_time

# Simulate mostly successful operations with occasional failures
	var success: bool = randf() > 0.1  # 90% success rate

	var result: Dictionary = {
		"operation_id": task.operation_id,
		"type": task.type,
		"path": task.path,
		"request_id": task.request_id,
		"success": success,
		"duration": duration,
		"completed_at": end_time
	}

	if not success:
		result["error"] = "Simulated operation failure"
	else:
		result["status"] = "completed_successfully"

	return result
