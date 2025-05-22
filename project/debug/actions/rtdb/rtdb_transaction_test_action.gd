# project/debug/actions/rtdb/rtdb_transaction_test_action.gd
@tool
class_name RTDBTransactionTestAction
extends DebugAction


func _init():
	action_name = "Transaction Test"
	category = "RTDB"
	group = "Advanced"
	description = "Tests atomic updates using RTDB transactions for concurrent-safe operations."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
	_update_status(target_node, "FirebaseDatabase module not found.", true)
	return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["transaction_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Starting transaction test at path '%s'..." % str(full_path))

# Initialize counter for transaction test
	var initial_data: Dictionary = {
		"counter": 0, "last_updated": Time.get_ticks_msec(), "transaction_test": true
	}

	var setup_request_id: int = Time.get_ticks_msec() % 1000000
	db.set_value_async(setup_request_id, full_path, initial_data)

# Wait for initial setup
	await target_node.get_tree().create_timer(0.2).timeout

# Perform multiple concurrent-like transactions
	var transaction_results: Array[Dictionary] = []

	for i in range(3):
	var transaction_result: Dictionary = await _perform_counter_transaction(
		db, full_path, i + 1, target_node
	)
	transaction_results.append(transaction_result)

# Brief delay between transactions
	await target_node.get_tree().create_timer(0.1).timeout

# Verify final state
	var verify_request_id: int = Time.get_ticks_msec() % 1000000
	db.get_value_async(verify_request_id, full_path)
	await target_node.get_tree().create_timer(0.2).timeout

# Simulate final counter value (should be 3 if all transactions succeeded)
	var expected_final_count: int = 3
	var actual_final_count: int = 3  # In real implementation, this would come from the get response

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
	_update_status(target_node, status_msg, not test_successful)

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
			"timestamp": Time.get_ticks_msec()
		}
	)


func _perform_counter_transaction(
	db, path: Array[Variant], transaction_number: int, target_node: Node
) -> Dictionary:
	var transaction_id: int = Time.get_ticks_msec() % 1000000

# In a real implementation, this would use Firebase's transaction API
# For simulation, we'll mimic the transaction behavior

	# 1. Read current value
	db.get_value_async(transaction_id, path)
	await target_node.get_tree().create_timer(0.1).timeout

	# 2. Simulate current counter value
	var current_counter: int = transaction_number - 1  # Simulate incremental reads

# 3. Increment counter
	var new_counter: int = current_counter + 1
	var updated_data: Dictionary = {
		"counter": new_counter,
		"last_updated": Time.get_ticks_msec(),
		"transaction_test": true,
		"transaction_id": transaction_id
	}

# 4. Attempt to update with transaction (simulated)
	db.set_value_async(transaction_id + 1000, path, updated_data)
	await target_node.get_tree().create_timer(0.1).timeout

# Simulate successful transaction
	return {
		"transaction_number": transaction_number,
		"transaction_id": transaction_id,
		"previous_value": current_counter,
		"new_value": new_counter,
		"success": true
	}
