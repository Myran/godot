extends Node
## Complete test suite for the Promise class
## 
## This test suite covers all functionality of the Promise class including:
## - Basic resolve/reject operations
## - Timeout handling
## - Static helper methods
## - Promise.all() for parallel execution
## - Promise.race() for competitive execution
## - Error handling and edge cases
##
## The tests handle GDScript's deferred signal emission and lambda capture
## limitations properly by using Dictionary for signal data and waiting
## for deferred signals with get_tree().process_frame.

var current_test_name: String = ""
var test_results: Dictionary = {}
var active_promises: Array[Promise] = []  # Keep references to prevent GC

func _ready() -> void:
	print("Starting Promise tests...")

	# Run all tests
	await test_basic_resolve()
	await test_basic_reject()
	await test_timeout()
	await test_static_helpers()
	await test_promise_all_success()
	await test_promise_all_failure()
	await test_promise_all_empty()
	await test_promise_race_success()
	await test_promise_race_failure()
	await test_promise_race_empty()
	await test_error_handling()

	# Print summary
	print("\n=== Test Summary ===")
	var passed: int = 0
	var failed: int = 0
	for test_name in test_results:
		if test_results[test_name]:
			passed += 1
			print("✓ %s: PASSED" % test_name)
		else:
			failed += 1
			print("✗ %s: FAILED" % test_name)

	print("\nTotal tests: %d" % (passed + failed))
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)

	if failed == 0:
		print("\nAll Promise tests passed successfully!")
	else:
		print("\nSome tests failed. Please check the output above.")

	# Give time for any pending signals
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func start_test(test_name: String) -> void:
	current_test_name = test_name
	test_results[test_name] = true  # Assume pass until failure
	active_promises.clear()  # Clear previous test's promises
	print("\n[TEST] %s" % test_name)

func assert_test(condition: bool, message: String) -> void:
	if not condition:
		print("  ✗ Assertion failed: %s" % message)
		test_results[current_test_name] = false
	else:
		print("  ✓ %s" % message)

## Test basic resolve functionality
func test_basic_resolve() -> void:
	start_test("Basic Resolve")

	var promise: Promise = Promise.new()
	active_promises.append(promise)
	var signal_data: Dictionary = {"fulfilled_value": null, "fulfilled_called": false}

	promise.fulfilled.connect(func(value: Variant) -> void:
		signal_data.fulfilled_value = value
		signal_data.fulfilled_called = true
	)

	# Test resolving with value
	promise.resolve("test_value")

	# Wait for deferred signal to be processed
	await get_tree().process_frame

	assert_test(signal_data.fulfilled_called, "Fulfilled signal should be emitted")
	assert_test(signal_data.fulfilled_value == "test_value", "Resolved value should match")
	assert_test(promise.state == Promise.State.FULFILLED, "State should be FULFILLED")
	assert_test(promise.value == "test_value", "Promise value should be set")

	# Test that resolve can't be called again
	var second_resolve: bool = promise.resolve("second_value")
	assert_test(not second_resolve, "Second resolve should return false")
	assert_test(promise.value == "test_value", "Value should not change on second resolve")

## Test basic reject functionality
func test_basic_reject() -> void:
	start_test("Basic Reject")

	var promise: Promise = Promise.new()
	active_promises.append(promise)
	var signal_data: Dictionary = {"rejected_reason": null, "rejected_called": false}

	promise.rejected.connect(func(reason: Variant) -> void:
		signal_data.rejected_reason = reason
		signal_data.rejected_called = true
	)

	# Test rejecting with reason
	promise.reject("error_reason")

	# Wait for deferred signal to be processed
	await get_tree().process_frame

	assert_test(signal_data.rejected_called, "Rejected signal should be emitted")
	assert_test(signal_data.rejected_reason == "error_reason", "Rejection reason should match")
	assert_test(promise.state == Promise.State.REJECTED, "State should be REJECTED")
	assert_test(promise.rejection_reason == "error_reason", "Rejection reason should be set")

	# Test that reject can't be called again
	var second_reject: bool = promise.reject("second_reason")
	assert_test(not second_reject, "Second reject should return false")
	assert_test(promise.rejection_reason == "error_reason", "Reason should not change on second reject")

## Test timeout functionality
func test_timeout() -> void:
	start_test("Timeout")

	var promise: Promise = Promise.new(0.1) # 100ms timeout
	active_promises.append(promise)
	var signal_data: Dictionary = {"timed_out": false, "rejected_called": false, "rejected_reason": null}

	promise.timed_out.connect(func() -> void:
		signal_data.timed_out = true
	)

	promise.rejected.connect(func(reason: Variant) -> void:
		signal_data.rejected_called = true
		signal_data.rejected_reason = reason
	)

	# Wait for timeout - using slightly longer wait to ensure timeout fires
	await get_tree().create_timer(0.2).timeout

	assert_test(signal_data.timed_out, "Timed out signal should be emitted")
	assert_test(signal_data.rejected_called, "Rejected signal should be emitted on timeout")
	assert_test(promise.state == Promise.State.REJECTED, "State should be REJECTED after timeout")
	assert_test(signal_data.rejected_reason is Dictionary, "Rejection reason should be a Dictionary")
	if signal_data.rejected_reason is Dictionary:
		assert_test(signal_data.rejected_reason.code == "TIMEOUT", "Rejection code should be TIMEOUT")

## Test static helper methods
func test_static_helpers() -> void:
	start_test("Static Helpers")

	# Test resolved
	var resolved_promise: Promise = Promise.resolved("instant_value")
	active_promises.append(resolved_promise)
	await get_tree().process_frame
	assert_test(resolved_promise.state == Promise.State.FULFILLED, "Resolved promise should be fulfilled")
	assert_test(resolved_promise.value == "instant_value", "Resolved promise should have correct value")

	# Test create_rejected
	var rejected_promise: Promise = Promise.create_rejected("instant_error")
	active_promises.append(rejected_promise)
	await get_tree().process_frame
	assert_test(rejected_promise.state == Promise.State.REJECTED, "Rejected promise should be rejected")
	assert_test(rejected_promise.rejection_reason == "instant_error", "Rejected promise should have correct reason")

	# Test is_rejected (backward compatibility)
	var is_rejected_promise: Promise = Promise.is_rejected("backward_compat")
	active_promises.append(is_rejected_promise)
	await get_tree().process_frame
	assert_test(is_rejected_promise.state == Promise.State.REJECTED, "is_rejected should create rejected promise")
	assert_test(is_rejected_promise.rejection_reason == "backward_compat", "is_rejected should have correct reason")

## Test Promise.all with successful promises
func test_promise_all_success() -> void:
	start_test("Promise.all Success")

	var promises: Array[Promise] = []
	promises.append(create_delayed_promise("value1", 0.05, false))
	promises.append(create_delayed_promise("value2", 0.1, false))
	promises.append(create_delayed_promise("value3", 0.15, false))

	var all_promise: Promise = Promise.all(promises)
	active_promises.append(all_promise)

	# Wait for all promises to resolve
	await get_tree().create_timer(0.3).timeout

	assert_test(all_promise.state == Promise.State.FULFILLED, "All promise should be fulfilled")
	assert_test(all_promise.value is Array, "Results should be an array")
	assert_test(all_promise.value.size() == 3, "Results should have 3 values")
	assert_test(all_promise.value[0] == "value1", "First result should match")
	assert_test(all_promise.value[1] == "value2", "Second result should match")
	assert_test(all_promise.value[2] == "value3", "Third result should match")

## Test Promise.all with one failure
func test_promise_all_failure() -> void:
	start_test("Promise.all Failure")

	var promises: Array[Promise] = []
	promises.append(create_delayed_promise("value1", 0.05, false))
	promises.append(create_delayed_promise("error2", 0.1, true)) # This will reject
	promises.append(create_delayed_promise("value3", 0.15, false))

	var all_promise: Promise = Promise.all(promises)
	active_promises.append(all_promise)

	# Wait for rejection
	await get_tree().create_timer(0.2).timeout

	assert_test(all_promise.state == Promise.State.REJECTED, "All promise should be rejected")
	assert_test(all_promise.rejection_reason is Dictionary, "Rejection reason should be a dictionary")
	assert_test(all_promise.rejection_reason.reason == "error2", "Rejection reason should match")
	assert_test(all_promise.rejection_reason.index == 1, "Rejection index should be 1")

## Test Promise.all with empty array
func test_promise_all_empty() -> void:
	start_test("Promise.all Empty")

	var promises: Array[Promise] = []
	var all_promise: Promise = Promise.all(promises)
	active_promises.append(all_promise)

	# Wait for deferred signal
	await get_tree().process_frame

	assert_test(all_promise.state == Promise.State.FULFILLED, "All promise should be fulfilled for empty array")
	assert_test(all_promise.value is Array, "Results should be an array")
	assert_test(all_promise.value.size() == 0, "Results should be empty")

## Test Promise.race with success
func test_promise_race_success() -> void:
	start_test("Promise.race Success")

	var promises: Array[Promise] = []
	promises.append(create_delayed_promise("slow", 0.15, false))
	promises.append(create_delayed_promise("fast", 0.05, false)) # This will win
	promises.append(create_delayed_promise("medium", 0.1, false))

	var race_promise: Promise = Promise.race(promises)
	active_promises.append(race_promise)

	# Wait for fastest promise
	await get_tree().create_timer(0.1).timeout

	assert_test(race_promise.state == Promise.State.FULFILLED, "Race promise should be fulfilled")
	assert_test(race_promise.value == "fast", "Fastest promise should win")

## Test Promise.race with failure
func test_promise_race_failure() -> void:
	start_test("Promise.race Failure")

	var promises: Array[Promise] = []
	promises.append(create_delayed_promise("slow", 0.15, false))
	promises.append(create_delayed_promise("fast_error", 0.05, true)) # This will reject first
	promises.append(create_delayed_promise("medium", 0.1, false))

	var race_promise: Promise = Promise.race(promises)
	active_promises.append(race_promise)

	# Wait for fastest rejection
	await get_tree().create_timer(0.1).timeout

	assert_test(race_promise.state == Promise.State.REJECTED, "Race promise should be rejected")
	assert_test(race_promise.rejection_reason == "fast_error", "Fastest rejection should win")

## Test Promise.race with empty array
func test_promise_race_empty() -> void:
	start_test("Promise.race Empty")

	var promises: Array[Promise] = []
	var race_promise: Promise = Promise.race(promises)
	active_promises.append(race_promise)

	# Wait for deferred signal
	await get_tree().process_frame

	assert_test(race_promise.state == Promise.State.FULFILLED, "Race promise should be fulfilled for empty array")
	assert_test(race_promise.value == null, "Result should be null for empty race")

## Test error handling edge cases
func test_error_handling() -> void:
	start_test("Error Handling")

	# Test Promise.all with invalid input - this test needs to be adjusted
	# because we can't put null in a typed array
	print("  Note: Skipping invalid input test for Promise.all due to typed array constraints")

	# Test resolving after timeout
	var timeout_promise: Promise = Promise.new(0.05)
	active_promises.append(timeout_promise)

	# Wait for timeout (using longer wait to ensure timeout completes)
	await get_tree().create_timer(0.1).timeout

	# Try to resolve after timeout
	var resolve_result: bool = timeout_promise.resolve("too_late")
	assert_test(not resolve_result, "Should not be able to resolve after timeout")
	assert_test(timeout_promise.state == Promise.State.REJECTED, "Promise should remain rejected")

## Helper function to create a delayed promise
func create_delayed_promise(value: Variant, delay: float, should_reject: bool) -> Promise:
	var promise: Promise = Promise.new()
	active_promises.append(promise)  # Keep promise alive

	# Create a timer to resolve/reject after delay
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if should_reject:
			promise.reject(value)
		else:
			promise.resolve(value)
		timer.queue_free()
	)
	timer.start()

	return promise
