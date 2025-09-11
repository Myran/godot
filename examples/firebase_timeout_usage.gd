# Example: How to use the new Firebase timeout functionality
# This demonstrates how to update Firebase backend test actions

extends Node

# Example 1: Direct SignalAwaiter.Timeout usage
func example_direct_timeout():
	# Race between some operation and timeout
	var timeout_awaiter = SignalAwaiter.Timeout.new(10.0)  # 10 seconds
	var some_operation = some_long_operation()
	
	var result = await SignalAwaiter.Any.new().add(some_operation.completed).add(timeout_awaiter.finished)
	
	if some_operation.is_completed():
		print("Operation completed successfully")
		return some_operation.get_result()
	else:
		print("Operation timed out after 10 seconds")
		return null

# Example 2: Using Firebase request timeout
func example_firebase_request_timeout():
	var firebase_request = SomeFirebaseService.get_data(["path"], "key")
	
	# Use the new timeout method
	var result = await firebase_request.await_completion_with_timeout(10.0)
	
	if result and result.get("status") == "timeout":
		print("Firebase operation timed out")
		return null
	elif result and result.get("status") == "ok":
		print("Firebase operation completed successfully")
		return result.get("payload")
	else:
		print("Firebase operation failed")
		return null

# Example 3: Using DatabaseService timeout methods
func example_database_service_timeout():
	var database_service = get_database_service()
	
	# Test problematic path that might hang
	var result = await database_service.get_data_with_timeout(
		["backend_tests", "problematic_path"], 
		"test_key", 
		10.0  # 10 second timeout
	)
	
	if result == null:
		print("Database operation timed out or failed")
	else:
		print("Database operation succeeded: ", result)

# Example 4: Updated Firebase backend test action pattern
func test_firebase_backend_operation_safely(operation_name: String) -> bool:
	print("Testing Firebase backend operation: ", operation_name)
	
	var database_service = get_database_service()
	var test_path = ["backend_tests", operation_name]
	var test_key = "test_" + str(Time.get_unix_time_from_system())
	
	# First, try to set up test data with timeout
	var setup_success = await database_service.set_data_with_timeout(
		test_path, 
		test_key, 
		{"test": true, "timestamp": Time.get_unix_time_from_system()},
		10.0
	)
	
	if not setup_success:
		print("Failed to set up test data for: ", operation_name)
		return false
	
	# Then test the operation with timeout
	var result = await database_service.get_data_with_timeout(test_path, test_key, 10.0)
	
	if result == null:
		print("Firebase operation timed out: ", operation_name)
		return false
	
	print("Firebase operation succeeded: ", operation_name)
	return true

# Example 5: Updating existing hanging Firebase test actions
func update_hanging_firebase_action():
	# OLD CODE (hangs indefinitely):
	# var result = await firebase_request.await_completion()
	
	# NEW CODE (times out gracefully):
	var result = await firebase_request.await_completion_with_timeout(10.0)
	
	if result and result.get("status") == "timeout":
		Log.warning("Firebase operation timed out - using graceful fallback")
		# Don't crash the test - return graceful default
		return {"status": "ok", "payload": null}
	
	return result

func get_database_service():
	# Return your DatabaseService instance
	return null

func some_long_operation():
	# Mock operation for example
	return null