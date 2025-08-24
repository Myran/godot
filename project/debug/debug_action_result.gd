class_name DebugActionResult
extends RefCounted

enum State { SUCCESS, FAILURE, RESTART_NEEDED }

var state: State
var data: Variant
var message: String
var duration_ms: int


func _init(p_state: State, p_data: Variant = null, p_message: String = "", p_duration: int = 0):
	state = p_state
	data = p_data
	message = p_message
	duration_ms = p_duration


# Factory methods for the 3 actual states we need
static func success(data: Variant = null, duration: int = 0):
	return new(State.SUCCESS, data, "", duration)


static func failure(error_message: String, duration: int = 0):
	return new(State.FAILURE, null, error_message, duration)


static func restart_needed(data: Variant = null, duration: int = 0):
	return new(State.RESTART_NEEDED, data, "Restart required for validation", duration)


# Simple accessors that match existing API
func is_success() -> bool:
	return state == State.SUCCESS


func is_failure() -> bool:
	return state == State.FAILURE


func needs_restart() -> bool:
	return state == State.RESTART_NEEDED


func get_data() -> Variant:
	return data


func get_message() -> String:
	return message


func get_duration_ms() -> int:
	return duration_ms


# Compatibility methods for existing usage patterns
func get_payload() -> Variant:
	return data


func get_error_message() -> String:
	return message if is_failure() else ""


func get_error_code() -> String:
	match state:
		State.RESTART_NEEDED:
			return "RESTART_NEEDED"
		State.FAILURE:
			return "FAILED"
		_:
			return ""


func get_operation() -> String:
	return ""  # Legacy compatibility - not used meaningfully


func get_metadata() -> Dictionary:
	return {}  # Legacy compatibility - not used meaningfully


func with_operation(operation: String):
	return self  # Legacy compatibility - chainable but no-op


func with_duration(duration: int):
	duration_ms = duration
	return self


func with_metadata(key: String, value: Variant):
	return self  # Legacy compatibility - chainable but no-op


# Simple debug output
func to_debug_string() -> String:
	match state:
		State.SUCCESS:
			var msg = "SUCCESS (%dms)" % duration_ms
			if data != null:
				msg += " - " + str(data)
			return msg
		State.FAILURE:
			return "FAILURE: %s (%dms)" % [message, duration_ms]
		State.RESTART_NEEDED:
			return "RESTART_NEEDED (%dms)" % duration_ms
		_:
			return "UNKNOWN"


# Legacy compatibility methods for specialized constructors
static func new_success(
	payload: Variant = null, duration_ms: int = 0, operation: String = "", metadata: Dictionary = {}
):
	return success(payload, duration_ms)


static func new_restart_pending(
	payload: Variant = null, duration_ms: int = 0, operation: String = "", metadata: Dictionary = {}
):
	return restart_needed(payload, duration_ms)


static func new_failure(
	error_message: String,
	error_code: String = "",
	error_category = null,
	payload: Variant = null,
	duration_ms: int = 0,
	operation: String = "",
	metadata: Dictionary = {}
):
	return failure(error_message, duration_ms)


# Additional specialized constructors that map to basic failure/success
static func new_timeout(
	timeout_duration_ms: int,
	operation: String = "",
	details: String = "",
	metadata: Dictionary = {}
):
	var timeout_message = "Operation timed out after %d ms" % timeout_duration_ms
	if not details.is_empty():
		timeout_message += ": " + details
	return failure(timeout_message, timeout_duration_ms)


static func new_performance_result(
	operation_metrics: Array,
	overall_success: bool,
	performance_thresholds: Dictionary = {},
	operation: String = "performance_test",
	duration_ms: int = 0,
	metadata: Dictionary = {}
):
	if overall_success:
		return success(
			{"metrics": operation_metrics, "thresholds": performance_thresholds}, duration_ms
		)
	else:
		return failure("Performance thresholds not met", duration_ms)


static func new_listener_result(
	callback_received: bool,
	callback_data: Dictionary = {},
	timeout_ms: int = 0,
	operation: String = "listener_test",
	duration_ms: int = 0,
	metadata: Dictionary = {}
):
	if callback_received:
		return success({"callback_data": callback_data, "timeout_ms": timeout_ms}, duration_ms)
	else:
		var error_message = "Listener callback not received"
		if timeout_ms > 0:
			error_message += " within " + str(timeout_ms) + "ms timeout"
		return failure(error_message, duration_ms)


static func new_batch_result(
	individual_results: Array,
	batch_success_rate: float,
	operation: String = "batch_operations",
	duration_ms: int = 0,
	metadata: Dictionary = {}
):
	var batch_is_success = batch_success_rate >= 0.5
	if batch_is_success:
		return success(
			{"total_operations": individual_results.size(), "success_rate": batch_success_rate},
			duration_ms
		)
	else:
		return failure("Batch operation success rate below threshold", duration_ms)


static func new_concurrent_result(
	operation_results: Array,
	success_rates: Dictionary,
	overall_success: bool,
	operation: String = "concurrent_operations",
	duration_ms: int = 0,
	metadata: Dictionary = {}
):
	if overall_success:
		return success(
			{"operation_results": operation_results, "success_rates": success_rates}, duration_ms
		)
	else:
		return failure("Concurrent operations did not meet success criteria", duration_ms)


# Legacy error category compatibility - all categories map to NONE since they're not meaningfully used
enum ErrorCategory {
	NONE,
	NETWORK,
	PERMISSION,
	TIMEOUT,
	VALIDATION,
	SYSTEM,
	FIREBASE,
	DATABASE,
	AUTHENTICATION,
	CONFIGURATION,
	CONCURRENT,
	DATA_INTEGRITY,
	LISTENER,
	BATCH_OPERATION,
	PERFORMANCE
}


func get_error_category():
	return ErrorCategory.NONE
