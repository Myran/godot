class_name GodotSignalSigbusTestAction
extends DebugAction

signal test_signal_completed(result: Dictionary)


func _init() -> void:
	super._init()
	action_name = "system.godot_signal_sigbus_test"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var timed_op: Dictionary = await TestUtils.time_operation(
		"Godot Signal SIGBUS Test", _perform_signal_test
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not test_results.get("success", false):
		return TestUtils.make_failure_result(
			test_results.get("error", "Signal emission test failed"),
			TestConstants.ERROR_CODES.VALIDATION_FAILED,
			duration_ms,
			action_name,
			TestUtils.make_metadata("godot_signal_sigbus", test_results)
		)

	var metadata: Dictionary = TestUtils.make_metadata("godot_signal_sigbus", test_results)
	_update_status("Godot Signal SIGBUS test PASSED")
	return TestUtils.make_success_result(
		"Godot signal emission with large payloads completed successfully",
		duration_ms,
		action_name,
		metadata
	)


func _perform_signal_test() -> Dictionary:
	_update_status("Testing Godot signal emission with large Array payloads...")

	# Create a large array similar to card database (17 cards with multiple fields)
	var large_array: Array = []
	for i in range(17):
		(
			large_array
			. append(
				{
					"id": str(i),
					"name": "test_card_%d" % i,
					"description":
					"This is a test card with a long description to increase payload size",
					"attack": str(i + 1),
					"health": str(i + 2),
					"abilities": "ability1:1;ability2:2;ability3:3",
					"tags": "tag1,tag2,tag3",
					"tribe": "test_tribe",
					"upgrade_level": str((i % 3) + 1),
					"card_name": "Test Card Number %d" % i,
				}
			)
		)

	var payload_size: int = len(str(large_array))
	_update_status(
		"Created large array with %d items, ~%d bytes" % [large_array.size(), payload_size]
	)

	# Test 1: Create Dictionary with large Array (THIS IS WHERE FIREBASE CRASHES)
	_update_status("Test 1: Creating Dictionary with large Array payload...")
	var test_result: Dictionary = {}
	test_result["status"] = "ok"
	test_result["payload"] = large_array  # <-- This is the crash point in firebase_request.gd:43

	_update_status("✅ Test 1 PASSED - Dictionary created successfully")

	# Test 2: Emit signal with Dictionary containing large Array
	_update_status("Test 2: Emitting signal with large Array in Dictionary...")
	test_signal_completed.emit(test_result)  # <-- This would be firebase_request.gd:57

	_update_status("✅ Test 2 PASSED - Signal emitted successfully")

	# Test 3: Direct signal emission with large Array (no Dictionary wrapper)
	_update_status("Test 3: Emitting signal with raw large Array...")
	test_signal_completed.emit({"status": "ok", "payload": large_array})

	_update_status("✅ Test 3 PASSED - Direct signal emission succeeded")

	return {
		"success": true,
		"payload_size": payload_size,
		"array_items": large_array.size(),
		"tests_passed": 3
	}
