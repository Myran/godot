class_name DebugActionResult
extends RefCounted

enum State { SUCCESS, FAILURE, RESTART_NEEDED }

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

var state: State
var data: Variant
var message: String
var duration_ms: int


func _init(
	p_state: State, p_data: Variant = null, p_message: String = "", p_duration: int = 0
) -> void:
	state = p_state
	data = p_data
	message = p_message
	duration_ms = p_duration


# Factory methods for the 3 actual states we need
static func success(result_data: Variant = null, duration: int = 0) -> DebugActionResult:
	return DebugActionResult.new(State.SUCCESS, result_data, "", duration)


static func failure(error_message: String, duration: int = 0) -> DebugActionResult:
	return DebugActionResult.new(State.FAILURE, null, error_message, duration)


static func restart_needed(result_data: Variant = null, duration: int = 0) -> DebugActionResult:
	return DebugActionResult.new(
		State.RESTART_NEEDED, result_data, "Restart required for validation", duration
	)


# Simple accessors that match existing API
func is_success() -> bool:
	return state == State.SUCCESS


func is_failure() -> bool:
	return state == State.FAILURE


func needs_restart() -> bool:
	return state == State.RESTART_NEEDED


func get_data() -> Variant:
	return data


func get_error_category() -> ErrorCategory:
	return ErrorCategory.NONE


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


# Simple debug output
func to_debug_string() -> String:
	match state:
		State.SUCCESS:
			var msg: String = "SUCCESS (%dms)" % duration_ms
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
	payload: Variant = null,
	result_duration_ms: int = 0,
	_operation: String = "",
	_metadata: Dictionary = {}
) -> DebugActionResult:
	return success(payload, result_duration_ms)


static func new_restart_pending(
	payload: Variant = null,
	result_duration_ms: int = 0,
	_operation: String = "",
	_metadata: Dictionary = {}
) -> DebugActionResult:
	return restart_needed(payload, result_duration_ms)


static func new_failure(
	error_message: String,
	_error_code: String = "",
	_error_category: Variant = null,
	_payload: Variant = null,
	result_duration_ms: int = 0,
	_operation: String = "",
	_metadata: Dictionary = {}
) -> DebugActionResult:
	return failure(error_message, result_duration_ms)


# Additional specialized constructors that map to basic failure/success
static func new_timeout(
	timeout_duration_ms: int,
	_operation: String = "",
	details: String = "",
	_metadata: Dictionary = {}
) -> DebugActionResult:
	var timeout_message: String = "Operation timed out after %d ms" % timeout_duration_ms
	if not details.is_empty():
		timeout_message += ": " + details
	return failure(timeout_message, timeout_duration_ms)


static func new_performance_result(
	operation_metrics: Array,
	overall_success: bool,
	performance_thresholds: Dictionary = {},
	_operation: String = "performance_test",
	result_duration_ms: int = 0,
	_metadata: Dictionary = {}
) -> DebugActionResult:
	if overall_success:
		return success(
			{"metrics": operation_metrics, "thresholds": performance_thresholds}, result_duration_ms
		)
	return failure("Performance thresholds not met", result_duration_ms)


static func new_listener_result(
	callback_received: bool,
	callback_data: Dictionary = {},
	timeout_ms: int = 0,
	_operation: String = "listener_test",
	result_duration_ms: int = 0,
	_metadata: Dictionary = {}
) -> DebugActionResult:
	if callback_received:
		return success(
			{"callback_data": callback_data, "timeout_ms": timeout_ms}, result_duration_ms
		)
	var error_message: String = "Listener callback not received"
	if timeout_ms > 0:
		error_message += " within " + str(timeout_ms) + "ms timeout"
	return failure(error_message, result_duration_ms)


static func new_batch_result(
	individual_results: Array,
	batch_success_rate: float,
	_operation: String = "batch_operations",
	result_duration_ms: int = 0,
	_metadata: Dictionary = {}
) -> DebugActionResult:
	var batch_is_success: bool = batch_success_rate >= 0.5
	if batch_is_success:
		return success(
			{"total_operations": individual_results.size(), "success_rate": batch_success_rate},
			result_duration_ms
		)
	return failure("Batch operation success rate below threshold", result_duration_ms)


static func new_concurrent_result(
	operation_results: Array,
	success_rates: Dictionary,
	overall_success: bool,
	_operation: String = "concurrent_operations",
	result_duration_ms: int = 0,
	_metadata: Dictionary = {}
) -> DebugActionResult:
	if overall_success:
		return success(
			{"operation_results": operation_results, "success_rates": success_rates},
			result_duration_ms
		)
	return failure("Concurrent operations did not meet success criteria", result_duration_ms)
