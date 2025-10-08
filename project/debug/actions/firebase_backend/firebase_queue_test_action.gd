class_name FirebaseQueueTestAction
extends BackendFirebaseDebugAction

## Test action to validate FirebaseRequestQueue implementation
## Task-207: Validates SIGBUS crash prevention


func _init() -> void:
	super._init()
	action_name = "backend.firebase.queue_test"
	auto_continue = false  # Sequential execution for proper ordering


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var timed_op: Dictionary = await TestUtils.time_operation(
		"FirebaseRequestQueue Test", _perform_queue_test
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not TestUtils.is_valid_result(test_results):
		return TestUtils.make_failure_result(
			"FirebaseQueueTest failed - queue not available",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("firebase_queue_test", {"queue_available": false})
		)

	var queue_stats: Dictionary = test_results.get("queue_stats", {})
	var sigbus_fix_active: bool = test_results.get("sigbus_fix_active", false)
	var test_success: bool = test_results.get("test_success", false)

	var metadata: Dictionary = TestUtils.make_metadata(
		"firebase_queue_test",
		{
			"queue_stats": queue_stats,
			"sigbus_fix_active": sigbus_fix_active,
			"test_success": test_success,
			"connection_type": "CONNECT_DEFERRED + queue"
		}
	)

	if test_success and sigbus_fix_active:
		_update_status("FirebaseRequestQueue test PASSED - SIGBUS fix active")
		return TestUtils.make_success_result(
			"FirebaseRequestQueue working correctly - Task-207 SIGBUS fix validated",
			duration_ms,
			action_name,
			metadata
		)

	_update_status("FirebaseRequestQueue test FAILED", true)
	return TestUtils.make_failure_result(
		"FirebaseRequestQueue test failed - Task-207 fix not working",
		str(TestConstants.ERROR_CODES.BACKEND_ERROR),
		duration_ms,
		action_name,
		metadata
	)


func _perform_queue_test() -> Dictionary:
	_update_status("Testing FirebaseRequestQueue implementation...")

	# Get FirebaseService and check queue status
	var firebase_service: Node = FirebaseService
	if not firebase_service:
		return {"error": "FirebaseService not available"}

	var queue_status: Dictionary = firebase_service.get_firebase_request_queue_status()
	if not queue_status.get("sigbus_fix_active", false):
		return {
			"error": "FirebaseRequestQueue not active",
			"queue_status": queue_status,
			"sigbus_fix_active": false
		}

	_update_status("FirebaseRequestQueue active, testing sequential operations...")

	# Test sequential Firebase operations through the queue
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {"error": "Firebase backend not available"}

	var test_base_path: Array[Variant] = [TestConstants.FIREBASE_BACKEND_PREFIX, "queue_test"]
	var test_timestamp: String = str(Time.get_ticks_msec())

	# Test sequential operations that previously caused SIGBUS
	var results: Dictionary = {}

	# Operation 1: Set value (this was request 6 in original crash)
	var set_test_path: Array[Variant] = []
	set_test_path.assign(test_base_path + ["set_test"])
	var set_key: String = "queue_test_" + test_timestamp
	var set_value: String = "Queue test: " + test_timestamp

	_update_status("Testing queued set operation...")
	var set_start: int = Time.get_ticks_msec()
	var set_result: Variant = backend.set_data(set_test_path, set_key, set_value)
	var set_duration: int = Time.get_ticks_msec() - set_start
	results["set_operation"] = {
		"success": set_result != null, "duration_ms": set_duration, "result": set_result
	}

	# Operation 2: Get value (this was request 7 in original crash)
	_update_status("Testing queued get operation...")
	var get_start: int = Time.get_ticks_msec()
	var get_result: Variant = backend.get_data(set_test_path, set_key)
	var get_duration: int = Time.get_ticks_msec() - get_start
	results["get_operation"] = {
		"success": get_result == set_value,
		"duration_ms": get_duration,
		"result": get_result,
		"expected": set_value
	}

	# Operation 3: Push value (this was request 8 in original crash)
	_update_status("Testing queued push operation...")
	var push_path: Array[Variant] = []
	push_path.assign(test_base_path + ["push_test"])
	var push_value: Dictionary = {"test": "queue_test", "timestamp": test_timestamp}

	var push_start: int = Time.get_ticks_msec()
	var push_result: Variant = backend.push_data(push_path, push_value)
	var push_duration: int = Time.get_ticks_msec() - push_start
	results["push_operation"] = {
		"success": push_result != null, "duration_ms": push_duration, "result": push_result
	}

	# Get final queue statistics
	var final_queue_stats: Dictionary = firebase_service.get_firebase_request_queue_status()

	# Validate test results
	var all_operations_successful: bool = (
		results.get("set_operation", {}).get("success", false)
		and results.get("get_operation", {}).get("success", false)
		and results.get("push_operation", {}).get("success", false)
	)

	# Check that operations completed in reasonable time (no 459ms delays)
	var max_acceptable_delay: int = 200  # ms
	var no_excessive_delays: bool = (
		results.get("set_operation", {}).get("duration_ms", 999) < max_acceptable_delay
		and results.get("get_operation", {}).get("duration_ms", 999) < max_acceptable_delay
		and results.get("push_operation", {}).get("duration_ms", 999) < max_acceptable_delay
	)

	var test_success: bool = all_operations_successful and no_excessive_delays

	_update_status(
		(
			"Queue test "
			+ ("PASSED" if test_success else "FAILED")
			+ " (Operations: "
			+ str(results.keys().size())
			+ ")"
		)
	)

	return {
		"test_success": test_success,
		"sigbus_fix_active": queue_status.get("sigbus_fix_active", false),
		"queue_stats": final_queue_stats,
		"operation_results": results,
		"all_operations_successful": all_operations_successful,
		"no_excessive_delays": no_excessive_delays,
		"max_acceptable_delay_ms": max_acceptable_delay
	}
