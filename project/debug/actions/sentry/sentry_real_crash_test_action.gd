class_name SentryRealCrashTestAction
extends DebugAction


func _init() -> void:
	super._init()
	action_name = "sentry.test_real_crashes"
	category = "Sentry Debug"
	action_callable = Callable(self, "execute_real_crash_testing")
	auto_continue = true


func execute_real_crash_testing() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"🔍 Real Sentry crash testing started (global test context already set)",
		{"action": action_name, "platform": OS.get_name()},
		["debug", "sentry", "trace", "crash_test"]
	)

	_update_status("Testing REAL Sentry crash scenario capture...")

	var crash_test_results: Dictionary = {
		"null_dereference_crash": false,
		"bounds_access_crash": false,
		"type_violation_crash": false,
		"resource_corruption_crash": false,
		"total_crashes_triggered": 0
	}

	# NOTE: These are DESIGNED to cause actual crashes to validate Sentry
	# Each crash is isolated and should crash the app immediately
	# Sentry should capture and report these with proper stack traces

	# Test 1: Null dereference crash - UNCONDITIONAL to guarantee crash
	Log.debug("TRIGGERING REAL null dereference crash...", {}, ["debug", "sentry", "crash"])
	crash_test_results.null_dereference_crash = _trigger_null_dereference_crash()

	# If we reach here, null dereference was caught (unlikely on Android)
	# Test 2: Bounds access crash
	Log.debug("TRIGGERING REAL bounds access crash...", {}, ["debug", "sentry", "crash"])
	crash_test_results.bounds_access_crash = _trigger_bounds_access_crash()

	# If we reach here, bounds access was somehow handled
	# Test 3: Type violation crash
	Log.debug("TRIGGERING REAL type violation crash...", {}, ["debug", "sentry", "crash"])
	crash_test_results.type_violation_crash = _trigger_type_violation_crash()

	# If we reach here, type violation was handled
	# Test 4: Resource corruption crash
	Log.debug("TRIGGERING REAL resource corruption crash...", {}, ["debug", "sentry", "crash"])
	crash_test_results.resource_corruption_crash = _trigger_resource_corruption_crash()

	# Calculate totals
	var crashes_triggered: int = 0
	if crash_test_results.null_dereference_crash:
		crashes_triggered += 1
	if crash_test_results.bounds_access_crash:
		crashes_triggered += 1
	if crash_test_results.type_violation_crash:
		crashes_triggered += 1
	if crash_test_results.resource_corruption_crash:
		crashes_triggered += 1

	crash_test_results.total_crashes_triggered = crashes_triggered

	# Log final crash test summary
	Log.info(
		"Real crash testing summary",
		{
			"crashes_triggered": crash_test_results.total_crashes_triggered,
			"null_dereference": crash_test_results.null_dereference_crash,
			"bounds_access": crash_test_results.bounds_access_crash,
			"type_violation": crash_test_results.type_violation_crash,
			"resource_corruption": crash_test_results.resource_corruption_crash
		},
		["debug", "sentry", "crash_test"]
	)

	_update_status(
		"✅ Real crash testing complete - triggered " + str(crashes_triggered) + " crashes"
	)

	return DebugActionResult.new_success(crash_test_results, 0, action_name)


func _trigger_null_dereference_crash() -> bool:
	# GUARANTEED null dereference - no safety checks
	# This WILL crash and should be captured by Sentry
	Log.debug(
		"EXECUTING: Forced null dereference - THIS WILL CRASH", {}, ["debug", "sentry", "crash"]
	)

	var obj: Node = null
	# UNCONDITIONAL dereference - no safety check to prevent crash
	# This line should crash the app and trigger Sentry
	obj.some_method_that_does_not_exist()

	# This should never be reached
	return true


func _trigger_bounds_access_crash() -> bool:
	# GUARANTEED bounds violation - no safety checks
	Log.debug(
		"EXECUTING: Forced array bounds violation - THIS WILL CRASH",
		{},
		["debug", "sentry", "crash"]
	)

	var arr: Array[String] = ["a", "b", "c"]
	# UNCONDITIONAL out-of-bounds access - this will crash
	var invalid_item: String = arr[999]  # Index out of bounds

	# This should never be reached
	return true


func _trigger_type_violation_crash() -> bool:
	# GUARANTEED type violation - no safety checks
	Log.debug(
		"EXECUTING: Forced type violation - THIS WILL CRASH", {}, ["debug", "sentry", "crash"]
	)

	var node: Node = Node.new()
	# Force type violation through unsafe casting
	var invalid_call: Button = node  # Invalid type assignment that should crash
	invalid_call.text = "test"  # This should crash due to type violation

	# This should never be reached
	return true


func _trigger_resource_corruption_crash() -> bool:
	# GUARANTEED resource corruption - no safety checks
	Log.debug(
		"EXECUTING: Forced resource corruption - THIS WILL CRASH", {}, ["debug", "sentry", "crash"]
	)

	# Force corruption through invalid node tree access - THIS WILL CRASH
	# Create a node that gets deleted while still being accessed
	var invalid_node: Node = Node.new()
	invalid_node.queue_free()  # Queue for deletion
	invalid_node.name = "corrupted_node"  # Access after queuing - should crash

	# This should never be reached
	return true
