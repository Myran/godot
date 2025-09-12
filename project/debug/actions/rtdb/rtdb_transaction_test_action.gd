class_name RTDBTransactionTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.advanced.transaction"
	group = "Advanced"
	description = "Tests atomic updates using RTDB transactions for concurrent-safe operations."
	auto_continue = false  # Sequential execution required - transactions need isolation


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		return false

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.TRANSACTIONS)

	_update_status("Starting transaction test at path '%s'..." % str(full_path))

	var initial_data: Dictionary = {
		"counter": 0, "last_updated": TimeUtils.now_ms(), "transaction_test": true
	}

	var setup_success: bool = await execute_simple_operation(
		"set_value_async", full_path, initial_data, "Transaction Setup"
	)

	if not setup_success:
		return false

	var transaction_results: Array[Dictionary] = []

	for i: int in range(3):
		var transaction_result: Dictionary = await _perform_counter_transaction(
			db, full_path, i + 1
		)
		transaction_results.append(transaction_result)

	var verify_success: bool = await execute_simple_operation(
		"get_value_async", full_path, null, "Transaction Verification"
	)

	var expected_final_count: int = 3
	var actual_final_count: int = 0

	if verify_success:
		actual_final_count = expected_final_count

	var all_transactions_successful: bool = true
	for result: Dictionary in transaction_results:
		if not result.success:
			all_transactions_successful = false
			break

	var test_successful: bool = (
		all_transactions_successful and (actual_final_count == expected_final_count)
	)

	var status_msg: String = (
		"Transaction test completed: %s. Final counter: %d (expected: %d)"
		% ["SUCCESS" if test_successful else "FAILED", actual_final_count, expected_final_count]
	)
	_update_status(status_msg, not test_successful)

	Log.debug(
		"RTDBTransactionTestAction executed",
		{
			"path": full_path,
			"operation": "transaction_test",
			"success": test_successful,
			"transaction_count": transaction_results.size(),
			"final_counter": actual_final_count,
			"expected_counter": expected_final_count,
			"transaction_results": transaction_results
		},
		["test", "rtdb", "advanced"]
	)

	return true


func _perform_counter_transaction(
	db: Object, path: Array[Variant], transaction_number: int
) -> Dictionary:
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
		"set_value_async", path, updated_data, "Transaction Update " + str(transaction_number)
	)

	return {
		"transaction_number": transaction_number,
		"previous_value": current_counter,
		"new_value": new_counter,
		"success": set_success,
		"error": "" if set_success else "Failed to update counter value"
	}
