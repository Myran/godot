class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.remove_value"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var unique_path: Array[String] = RTDBTestPaths.with_timestamp(RTDBTestPaths.SIMPLE_VALUE)
	var test_path: Array[Variant] = RTDBTestPaths.to_variant_array(unique_path)

	_update_status("Setting up test data for deletion...")
	var test_value: String = "DeleteTest_" + str(Time.get_ticks_msec())
	var setup_success: bool = await execute_simple_operation(
		"set_value_async", test_path, test_value, "Setup Delete Test Data"
	)

	if not setup_success:
		_update_status("ERROR: Failed to setup test data for deletion", true)
		return false

	_update_status("Deleting test data...")
	var delete_success: bool = await execute_simple_operation(
		"remove_value_async", test_path, null, action_name
	)

	if not delete_success:
		_update_status("ERROR: Delete operation failed", true)
		return false

	_update_status("Validating deletion...")
	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		_update_status("ERROR: Cannot validate deletion - Firebase backend unavailable", true)
		return false

	var key: String = test_path[-1] if test_path.size() > 0 else ""
	var path: Array = test_path.slice(0, -1) if test_path.size() > 1 else []
	var validation_result: Variant = await firebase_backend.get_data(path, key)

	if validation_result == null:
		_update_status("Delete validation successful - data confirmed removed")
		return true
	else:
		_update_status("ERROR: Delete validation failed - data still exists", true)
		return false
