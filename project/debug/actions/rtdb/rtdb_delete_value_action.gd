# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Delete Value"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")
	
	# Use unique path to avoid test interference
	var unique_path: Array[String] = RTDBTestPaths.with_timestamp(RTDBTestPaths.SIMPLE_VALUE)
	var test_path: Array[Variant] = RTDBTestPaths.to_variant_array(unique_path)
	
	# First, ensure there's something to delete by setting a test value
	_update_status("Setting up test data for deletion...")
	var test_value: String = "DeleteTest_" + str(Time.get_ticks_msec())
	var setup_success: bool = await execute_simple_operation(
		"set_value_async",
		test_path,
		test_value,
		"Setup Delete Test Data"
	)
	
	if not setup_success:
		_update_status("ERROR: Failed to setup test data for deletion", true)
		execution_completed.emit(false, {"error": "Setup failed: Cannot create test data"})
		return false
	
	# Now attempt to delete the data
	_update_status("Deleting test data...")
	var delete_success: bool = await execute_simple_operation(
		"remove_value_async",
		test_path,
		null,
		action_name
	)
	
	if not delete_success:
		_update_status("ERROR: Delete operation failed", true)
		execution_completed.emit(false, {"error": "Delete operation returned false"})
		return false
	
	# Validate that the data was actually deleted
	_update_status("Validating deletion...")
	var validation_result: Variant = await execute_simple_operation(
		"get_value_async",
		test_path,
		null,
		"Validate Deletion"
	)
	
	# If we get null/empty, deletion worked
	if validation_result == null:
		_update_status("Delete validation successful - data confirmed removed")
		execution_completed.emit(true, {"result": "Data successfully deleted and validated"})
		return true
	else:
		_update_status("ERROR: Delete validation failed - data still exists", true)
		execution_completed.emit(false, {"error": "Validation failed: Data still exists after delete", "remaining_data": validation_result})
		return false