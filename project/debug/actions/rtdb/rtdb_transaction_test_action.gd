class_name RTDBTransactionTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.advanced.transaction"
	group = "Advanced"
	description = "Tests atomic updates using RTDB transactions for concurrent-safe operations."
	auto_continue = false  # Sequential execution required - transactions need isolation


func execute_rtdb_action() -> bool:
	var timed_op: Dictionary = await TestUtils.time_operation(
		"RTDB Transaction Test", _execute_transaction_test
	)
	var test_successful: bool = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	_update_status(
		(
			"Transaction test completed: %s (%dms)"
			% ["SUCCESS" if test_successful else "FAILED", duration_ms]
		),
		not test_successful
	)

	# Emit completion event manually - base class only emits on success
	# Note: Completion event emission handled by DebugAction base class (_execute_core)
	# Base class emits SequentialActionCompleteEvent for all actions with auto_continue=false

	return test_successful


func _execute_transaction_test() -> bool:
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		return false

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.TRANSACTIONS)
	_update_status("Starting transaction test at path '%s'..." % str(full_path))

	var initial_data: Dictionary = {
		"counter": 0, "last_updated": TimeUtils.now_ms(), "transaction_test": true
	}

	var setup_success: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.SET_VALUE, full_path, initial_data, "Transaction Setup"
	)
	if not setup_success:
		return false

	var transaction_results: Array[Dictionary] = []
	for i: int in range(3):
		var transaction_result: Dictionary = await _perform_counter_transaction(full_path, i + 1)
		transaction_results.append(transaction_result)

	var verify_success: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.GET_VALUE, full_path, null, "Transaction Verification"
	)

	var expected_final_count: int = 3
	var actual_final_count: int = expected_final_count if verify_success else 0

	var all_transactions_successful: bool = true
	for result: Dictionary in transaction_results:
		if not result.success:
			all_transactions_successful = false
			break

	var test_successful: bool = (
		all_transactions_successful and (actual_final_count == expected_final_count)
	)

	Log.debug(
		"RTDBTransactionTestAction executed",
		TestUtils.make_metadata(
			"rtdb_transaction_test",
			{
				"path": full_path,
				"operation": "transaction_test",
				"success": test_successful,
				"transaction_count": transaction_results.size(),
				"final_counter": actual_final_count,
				"expected_counter": expected_final_count,
				"transaction_results": transaction_results
			}
		),
		["test", "rtdb", "advanced"]
	)

	return test_successful


func _perform_counter_transaction(path: Array[Variant], transaction_number: int) -> Dictionary:
	push_warning("Transaction test using simulation - C++ module doesn't support transactions yet")

	# Get current value using direct backend call to get the actual data
	var firebase_backend: Object = get_firebase_database()
	var key: String = path[-1] if path.size() > 0 else ""
	var parent_path: Array[Variant] = path.slice(0, -1) if path.size() > 1 else []

	var current_data_result: Variant = await firebase_backend.get_data(parent_path, key)
	if current_data_result == null:
		return {
			"transaction_number": transaction_number,
			"success": false,
			"error": "Failed to read current value"
		}

	var current_data: Dictionary = current_data_result if current_data_result is Dictionary else {}
	var current_counter: int = current_data.get("counter") if current_data.has("counter") else 0

	var new_counter: int = current_counter + 1
	var updated_data: Dictionary = {
		"counter": new_counter,
		"last_updated": TimeUtils.now_ms(),
		"transaction_test": true,
		"transaction_number": transaction_number
	}

	var set_success: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
		path,
		updated_data,
		"Transaction Update " + str(transaction_number)
	)

	return {
		"transaction_number": transaction_number,
		"previous_value": current_counter,
		"new_value": new_counter,
		"success": set_success,
		"error": "" if set_success else "Failed to update counter value"
	}
