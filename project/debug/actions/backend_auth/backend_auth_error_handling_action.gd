class_name BackendAuthErrorHandlingAction
extends BackendAuthDebugAction

## Tests error handling for invalid scenarios: empty custom token, get_id_token when not signed in.
## Validates that AuthService properly handles and reports error conditions.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.error_handling"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing error handling scenarios...")
	var start_time: int = Time.get_ticks_msec()

	# Get AuthService
	var auth: AuthService = _get_auth_service()
	if not auth:
		return DebugActionResult.new_failure(
			"AuthService not available",
			"SERVICE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var test_results: Array[Dictionary] = []
	var all_passed: bool = true

	# Test 1: Empty custom token should fail
	_update_status("Test 1/3: Empty custom token...")
	var test1_result: Dictionary = await _test_empty_custom_token(auth)
	test_results.append(test1_result)
	if not test1_result.get("passed", false):
		all_passed = false

	# Test 2: get_id_token when not signed in should fail
	_update_status("Test 2/3: get_id_token without sign in...")

	# Ensure we're signed out first
	if auth.is_signed_in():
		@warning_ignore("redundant_await")
		await auth.sign_out()

	var test2_result: Dictionary = await _test_get_id_token_not_signed_in(auth)
	test_results.append(test2_result)
	if not test2_result.get("passed", false):
		all_passed = false

	# Test 3: Sign out when already signed out should handle gracefully
	_update_status("Test 3/3: Sign out when not signed in...")

	var test3_result: Dictionary = await _test_sign_out_when_signed_out(auth)
	test_results.append(test3_result)
	if not test3_result.get("passed", false):
		all_passed = false

	var duration: int = Time.get_ticks_msec() - start_time

	# Compile results
	var passed_count: int = 0
	for result: Dictionary in test_results:
		if result.get("passed", false):
			passed_count += 1

	var metadata: Dictionary = {
		"total_tests": test_results.size(),
		"passed": passed_count,
		"failed": test_results.size() - passed_count,
		"results": test_results
	}

	if all_passed:
		Log.info(
			"Error handling: All error scenarios handled correctly",
			metadata,
			["debug", "backend_auth", "success"]
		)
		return DebugActionResult.new_success(true, duration, action_name, metadata)

	Log.error(
		"Error handling: Some error scenarios not handled correctly",
		metadata,
		["debug", "backend_auth", "error"]
	)
	var failure_msg: String = (
		"Error handling tests failed: "
		+ str(test_results.size() - passed_count)
		+ "/"
		+ str(test_results.size())
		+ " failed"
	)
	return DebugActionResult.new_failure(
		failure_msg,
		"ERROR_HANDLING_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		null,
		duration,
		action_name,
		metadata
	)


func _test_empty_custom_token(auth: AuthService) -> Dictionary:
	var test_start: int = Time.get_ticks_msec()

	@warning_ignore("redundant_await")
	var result: Variant = await auth.sign_in_with_custom_token("")

	var duration: int = Time.get_ticks_msec() - test_start

	if result is Dictionary:
		var status: String = result.get("status", "")
		var code: String = result.get("code", "")

		if status == "error" and code == "INVALID_ARGUMENT":
			Log.info(
				"Error handling: Empty custom token rejected correctly",
				{"code": code},
				["debug", "backend_auth"]
			)
			return {
				"test": "empty_custom_token",
				"passed": true,
				"duration_ms": duration,
				"error_code": code
			}

		return {
			"test": "empty_custom_token",
			"passed": false,
			"duration_ms": duration,
			"expected": "error with INVALID_ARGUMENT",
			"actual_status": status,
			"actual_code": code
		}

	return {
		"test": "empty_custom_token",
		"passed": false,
		"duration_ms": duration,
		"expected": "Dictionary error result",
		"actual_type": typeof(result)
	}


func _test_get_id_token_not_signed_in(auth: AuthService) -> Dictionary:
	var test_start: int = Time.get_ticks_msec()

	# Double-check we're not signed in
	if auth.is_signed_in():
		@warning_ignore("redundant_await")
		await auth.sign_out()

	@warning_ignore("redundant_await")
	var result: Variant = await auth.get_id_token(false)

	var duration: int = Time.get_ticks_msec() - test_start

	if result is Dictionary:
		var status: String = result.get("status", "")
		var code: String = result.get("code", "")

		if status == "error" and code == "NOT_SIGNED_IN":
			Log.info(
				"Error handling: get_id_token rejected when not signed in",
				{"code": code},
				["debug", "backend_auth"]
			)
			return {
				"test": "get_id_token_not_signed_in",
				"passed": true,
				"duration_ms": duration,
				"error_code": code
			}

		return {
			"test": "get_id_token_not_signed_in",
			"passed": false,
			"duration_ms": duration,
			"expected": "error with NOT_SIGNED_IN",
			"actual_status": status,
			"actual_code": code
		}

	return {
		"test": "get_id_token_not_signed_in",
		"passed": false,
		"duration_ms": duration,
		"expected": "Dictionary error result",
		"actual_type": typeof(result)
	}


func _test_sign_out_when_signed_out(auth: AuthService) -> Dictionary:
	var test_start: int = Time.get_ticks_msec()

	# Ensure we're signed out
	if auth.is_signed_in():
		@warning_ignore("redundant_await")
		await auth.sign_out()

	@warning_ignore("redundant_await")
	var result: Variant = await auth.sign_out()

	var duration: int = Time.get_ticks_msec() - test_start

	# Sign out when already signed out should handle gracefully (return ok)
	if result is Dictionary:
		var status: String = result.get("status", "")

		if status == "ok":
			Log.info(
				"Error handling: Sign out when already signed out handled gracefully",
				{},
				["debug", "backend_auth"]
			)
			return {"test": "sign_out_when_signed_out", "passed": true, "duration_ms": duration}

		return {
			"test": "sign_out_when_signed_out",
			"passed": false,
			"duration_ms": duration,
			"expected": "ok",
			"actual_status": status
		}

	return {
		"test": "sign_out_when_signed_out",
		"passed": false,
		"duration_ms": duration,
		"expected": "Dictionary result",
		"actual_type": typeof(result)
	}
