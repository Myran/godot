# project/debug/actions/rtdb/rtdb_transaction_test_action.gd
@tool
class_name RTDBTransactionTestAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Transaction Test"
	group = "Advanced"
	description = "Tests atomic updates using RTDB transactions for concurrent-safe operations."


func execute() -> Array:
	var db = get_firebase_database()
	if not db:
		return get_last_error_result()

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.TRANSACTIONS)

	_update_status( "Starting transaction test at path '%s'..." % str(full_path))

	# Initialize counter for transaction test
	var initial_data: Dictionary = {
		"counter": 0, "last_updated": TimeUtils.now_ms(), "transaction_test": true
	}

	var op_manager := FirebaseOperationManager.new(db)
	var setup_result: Dictionary = await op_manager.execute(
		"set_value_async", [full_path, initial_data]
	)

	if not setup_result.success:
		return _failure("Failed to initialize transaction test data")

	# Perform multiple concurrent-like transactions
	var transaction_results: Array[Dictionary] = []

	for i in range(3):
		var transaction_result: Dictionary = await _perform_counter_transaction(
			db, full_path, i + 1)
		)
		transaction_results.append(transaction_result)

	# Verify final state
	var verify_result: Dictionary = await op_manager.execute("get_value_async", [full_path])

	var expected_final_count: int = 3
	var actual_final_count: int = 0

	if verify_result.success and verify_result.data is Dictionary:
		actual_final_count = verify_result.data.get("counter", 0)

	var all_transactions_successful: bool = true
	for result in transaction_results:
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
	_update_status( status_msg, not test_successful)

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

	return _success(
		{
			"operation": "transaction_test",
			"path": full_path,
			"success": test_successful,
			"transaction_count": transaction_results.size(),
			"final_counter": actual_final_count,
			"expected_counter": expected_final_count,
			"transaction_results": transaction_results,
			"timestamp": TimeUtils.now_ms()
		}
	)


func _perform_counter_transaction(
	db: Object, path: Array[Variant], transaction_number: int
) -> Dictionary:
	# TODO: When C++ module supports transactions, replace with:
	# return await db.run_transaction(path, _transaction_update_function)

	# TEMPORARY: Transaction simulation for testing
	push_warning("Transaction test using simulation - C++ module doesn't support transactions yet")

	var op_manager := FirebaseOperationManager.new(db)

	# 1. Read current value
	var get_result: Dictionary = await op_manager.execute("get_value_async", [path])
	if not get_result.success:
		return {
			"transaction_number": transaction_number,
			"success": false,
			"error": "Failed to read current value"
		}

	# 2. Extract current counter
	var current_data: Dictionary = get_result.get("data", {})
	var current_counter: int = current_data.get("counter", 0)

	# 3. Increment counter
	var new_counter: int = current_counter + 1
	var updated_data: Dictionary = {
		"counter": new_counter,
		"last_updated": TimeUtils.now_ms(),
		"transaction_test": true,
		"transaction_number": transaction_number
	}

	# 4. Write updated value (in real transaction, this would be atomic)
	var set_result: Dictionary = await op_manager.execute("set_value_async", [path, updated_data])

	return {
		"transaction_number": transaction_number,
		"previous_value": current_counter,
		"new_value": new_counter,
		"success": set_result.success,
		"error": set_result.get("error", "")
	}
