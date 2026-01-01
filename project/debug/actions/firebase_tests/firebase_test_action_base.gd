## Base class for Firebase SDK TDD tests.
## Provides assertions, platform gating, and test result tracking.
class_name FirebaseTestActionBase extends DebugAction

## Test result states
enum TestResult {
	PENDING,
	PASSED,
	FAILED,
	SKIPPED
}

## Test tracking
var _result: TestResult = TestResult.PENDING
var _failure_reason: String = ""
var _assertions_run: int = 0
var _assertions_passed: int = 0


## Platform gating - override in subclasses for platform-specific tests
func should_run_on_platform() -> bool:
	return true


## Core assertion methods

func assert_true(condition: bool, msg: String = "") -> bool:
	_assertions_run += 1
	if condition:
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected true, got false")
	return false


func assert_false(condition: bool, msg: String = "") -> bool:
	return assert_true(not condition, msg if msg else "Expected false, got true")


func assert_equals(expected: Variant, actual: Variant, msg: String = "") -> bool:
	_assertions_run += 1
	if expected == actual:
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected '%s' but got '%s'" % [str(expected), str(actual)])
	return false


func assert_not_null(value: Variant, msg: String = "") -> bool:
	_assertions_run += 1
	if value != null:
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected non-null value")
	return false


func assert_null(value: Variant, msg: String = "") -> bool:
	_assertions_run += 1
	if value == null:
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected null value")
	return false


func assert_not_empty(value: String, msg: String = "") -> bool:
	_assertions_run += 1
	if not value.is_empty():
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected non-empty string")
	return false


func assert_greater(a: Variant, b: Variant, msg: String = "") -> bool:
	_assertions_run += 1
	if a > b:
		_assertions_passed += 1
		return true
	_fail(msg if msg else "Expected %s > %s" % [str(a), str(b)])
	return false


## Result helpers

func _fail(reason: String) -> void:
	_result = TestResult.FAILED
	_failure_reason = reason
	Log.error("[TEST FAILED] %s: %s" % [action_name, reason])


func _pass() -> void:
	if _result != TestResult.FAILED:
		_result = TestResult.PASSED
		Log.info("[TEST PASSED] %s (%d/%d assertions)" % [action_name, _assertions_passed, _assertions_run])


func _skip(reason: String) -> void:
	_result = TestResult.SKIPPED
	Log.warning("[TEST SKIPPED] %s: %s" % [action_name, reason])


## Get test result as Dictionary
func get_result() -> Dictionary:
	return {
		"name": action_name,
		"result": TestResult.keys()[_result],
		"assertions_run": _assertions_run,
		"assertions_passed": _assertions_passed,
		"failure_reason": _failure_reason
	}


## Helper to check if running on desktop
func _is_desktop() -> bool:
	return OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux")


## Helper to check if running on mobile
func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


## Helper to get current platform as string
func _get_platform() -> String:
	if OS.has_feature("android"):
		return "android"
	elif OS.has_feature("ios"):
		return "ios"
	elif OS.has_feature("windows"):
		return "windows"
	elif OS.has_feature("macos"):
		return "macos"
	elif OS.has_feature("linux"):
		return "linux"
	else:
		return "unknown"


## Create a skip result for platform gating
func _skip_result(reason: String) -> DebugActionResult:
	_skip(reason)
	return DebugActionResult.new_success({"skipped": true, "reason": reason})


## Create a failure result from assertion failure
func _assertion_result() -> DebugActionResult:
	if _result == TestResult.PASSED:
		_pass()
		return DebugActionResult.new_success({"assertions_run": _assertions_run, "assertions_passed": _assertions_passed})
	elif _result == TestResult.SKIPPED:
		return _skip_result(_failure_reason)
	else:
		return DebugActionResult.new_failure(_failure_reason)


## Static logging helpers for TEST_SUCCESS and TEST_FAILURE markers
## NOTE: Matches DebugAction._log_test_success format for action result collection (Task-407)
static func _log_test_success(test_name: String, category: String, group: String, duration_ms: int, metadata: Dictionary = {}) -> void:
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = DebugAction.current_test_id if DebugAction.current_test_id != "" else test_metadata.get("test_id", "")

	DebugAction.test_success_count += 1  # Increment global counter for sequence numbering

	Log.info(
		"DEBUG_TEST_SUCCESS",
		{
			"test_id": config_test_id,
			"action": test_name,  # Use "action" key for compatibility with _collect-action-results
			"category": category,
			"group": group,
			"duration_ms": duration_ms,
			"params": metadata,  # Use "params" key for compatibility with _collect-action-results
			"pid": OS.get_process_id(),
			"sequence": DebugAction.test_success_count,
			"timestamp": Time.get_datetime_string_from_system()
		},
		["debug", "test", "success"]
	)


static func _log_test_failure(test_name: String, category: String, group: String, reason: String, metadata: Dictionary = {}) -> void:
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = DebugAction.current_test_id if DebugAction.current_test_id != "" else test_metadata.get("test_id", "")

	DebugAction.test_failure_count += 1  # Increment global counter for sequence numbering

	Log.error(
		"DEBUG_TEST_FAILURE",
		{
			"test_id": config_test_id,
			"action": test_name,  # Use "action" key for compatibility with _collect-action-results
			"category": category,
			"group": group,
			"duration_ms": 0,  # Duration not available in failure path
			"error_message": reason,
			"params": metadata,  # Use "params" key for compatibility with _collect-action-results
			"pid": OS.get_process_id(),
			"sequence": DebugAction.test_failure_count,
			"timestamp": Time.get_datetime_string_from_system().replace("T", " ").split(".")[0]
		},
		["debug", "test", "failure", "pid", "sequence"]
	)
