class_name DebugActionResult
extends RefCounted

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

var _success: bool
var _payload: Variant
var _error_message: String
var _error_code: String
var _error_category: ErrorCategory
var _duration_ms: int
var _operation: String
var _metadata: Dictionary

func _init(
	p_success: bool = false,
	p_payload: Variant = null,
	p_error_message: String = "",
	p_error_code: String = "",
	p_error_category: ErrorCategory = ErrorCategory.NONE,
	p_duration_ms: int = 0,
	p_operation: String = "",
	p_metadata: Dictionary = {}
) -> void:
	_success = p_success
	_payload = p_payload
	_error_message = p_error_message
	_error_code = p_error_code
	_error_category = p_error_category
	_duration_ms = p_duration_ms
	_operation = p_operation
	_metadata = p_metadata.duplicate()

static func new_success(
	payload: Variant = null,
	duration_ms: int = 0,
	operation: String = "",
	metadata: Dictionary = {}
) -> DebugActionResult:
	return DebugActionResult.new(
		true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, metadata
	)

static func new_restart_pending(
	payload: Variant = null,
	duration_ms: int = 0,
	operation: String = "",
	metadata: Dictionary = {}
) -> DebugActionResult:
	return DebugActionResult.new(
		false,
		payload,
		"RESTART_PENDING",
		"RESTART_NEEDED",
		ErrorCategory.NONE,
		duration_ms,
		operation,
		metadata
	)

static func new_failure(
	error_message: String,
	error_code: String = "",
	error_category: ErrorCategory = ErrorCategory.SYSTEM,
	payload: Variant = null,
	duration_ms: int = 0,
	operation: String = "",
	metadata: Dictionary = {}
) -> DebugActionResult:
	if error_message.is_empty():
		error_message = "Unknown error"
	return DebugActionResult.new(
		false,
		payload,
		error_message,
		error_code,
		error_category,
		duration_ms,
		operation,
		metadata
	)

static func new_timeout(
	timeout_duration_ms: int,
	operation: String = "",
	details: String = "",
	metadata: Dictionary = {}
) -> DebugActionResult:
	var timeout_message: String = "Operation timed out after %d ms" % timeout_duration_ms
	if not details.is_empty():
		timeout_message += ": " + details
	return DebugActionResult.new(
		false,
		null,
		timeout_message,
		"TIMEOUT",
		ErrorCategory.TIMEOUT,
		timeout_duration_ms,
		operation,
		metadata
	)

static func new_network_error(
	error_details: String,
	operation: String = "",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	return DebugActionResult.new(
		false,
		null,
		"Network error: " + error_details,
		"NETWORK_ERROR",
		ErrorCategory.NETWORK,
		duration_ms,
		operation,
		metadata
	)

static func new_permission_error(
	resource: String = "",
	operation: String = "",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	var message: String = "Permission denied"
	if not resource.is_empty():
		message += " for resource: " + resource
	return DebugActionResult.new(
		false,
		null,
		message,
		"PERMISSION_DENIED",
		ErrorCategory.PERMISSION,
		duration_ms,
		operation,
		metadata
	)

static func new_performance_result(
	operation_metrics: Array,
	overall_success: bool,
	performance_thresholds: Dictionary = {},
	operation: String = "performance_test",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	var enhanced_metadata: Dictionary = metadata.duplicate()
	enhanced_metadata["performance_metrics"] = operation_metrics
	enhanced_metadata["performance_thresholds"] = performance_thresholds
	enhanced_metadata["result_type"] = "performance"

	var payload: Dictionary = {
		"overall_success": overall_success,
		"metrics": operation_metrics,
		"thresholds": performance_thresholds
	}

	if overall_success:
		return DebugActionResult.new(
			true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
		)

	return DebugActionResult.new(
		false,
		payload,
		"Performance thresholds not met",
		"PERFORMANCE_FAILURE",
		ErrorCategory.PERFORMANCE,
		duration_ms,
		operation,
		enhanced_metadata
	)

static func new_batch_result(
	individual_results: Array,
	batch_success_rate: float,
	operation: String = "batch_operations",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	var enhanced_metadata: Dictionary = metadata.duplicate()
	enhanced_metadata["batch_results"] = individual_results
	enhanced_metadata["success_rate"] = batch_success_rate
	enhanced_metadata["result_type"] = "batch"

	var total_operations: int = individual_results.size()
	var successful_operations: int = 0
	for result: Dictionary in individual_results:
		if result.get("success", false):
			successful_operations += 1

	var payload: Dictionary = {
		"total_operations": total_operations,
		"successful_operations": successful_operations,
		"success_rate": batch_success_rate,
		"individual_results": individual_results
	}

	var batch_is_success: bool = batch_success_rate >= 0.5
	var error_category: ErrorCategory = (
		ErrorCategory.BATCH_OPERATION if not batch_is_success else ErrorCategory.NONE
	)
	var error_message: String = (
		"" if batch_is_success else "Batch operation success rate below threshold"
	)
	var error_code: String = "" if batch_is_success else "BATCH_FAILURE"

	return DebugActionResult.new(
		batch_is_success,
		payload,
		error_message,
		error_code,
		error_category,
		duration_ms,
		operation,
		enhanced_metadata
	)

static func new_listener_result(
	callback_received: bool,
	callback_data: Dictionary = {},
	timeout_ms: int = 0,
	operation: String = "listener_test",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	var enhanced_metadata: Dictionary = metadata.duplicate()
	enhanced_metadata["callback_data"] = callback_data
	enhanced_metadata["timeout_ms"] = timeout_ms
	enhanced_metadata["result_type"] = "listener"

	var payload: Dictionary = {
		"callback_received": callback_received,
		"callback_data": callback_data,
		"timeout_ms": timeout_ms
	}

	if callback_received:
		return DebugActionResult.new(
			true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
		)

	var error_message: String = "Listener callback not received"
	if timeout_ms > 0:
		error_message += " within " + str(timeout_ms) + "ms timeout"
	return DebugActionResult.new(
		false,
		payload,
		error_message,
		"LISTENER_TIMEOUT",
		ErrorCategory.LISTENER,
		duration_ms,
		operation,
		enhanced_metadata
	)

static func new_concurrent_result(
	operation_results: Array,
	success_rates: Dictionary,
	overall_success: bool,
	operation: String = "concurrent_operations",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	var enhanced_metadata: Dictionary = metadata.duplicate()
	enhanced_metadata["operation_results"] = operation_results
	enhanced_metadata["success_rates"] = success_rates
	enhanced_metadata["result_type"] = "concurrent"

	var payload: Dictionary = {
		"overall_success": overall_success,
		"operation_results": operation_results,
		"success_rates": success_rates
	}

	if overall_success:
		return DebugActionResult.new(
			true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
		)

	return DebugActionResult.new(
		false,
		payload,
		"Concurrent operations did not meet success criteria",
		"CONCURRENT_FAILURE",
		ErrorCategory.CONCURRENT,
		duration_ms,
		operation,
		enhanced_metadata
	)

func is_success() -> bool:
	return _success

func is_failure() -> bool:
	return not _success

func get_payload() -> Variant:
	return _payload

func get_error_message() -> String:
	return _error_message

func get_error_code() -> String:
	return _error_code

func get_error_category() -> ErrorCategory:
	return _error_category

func get_duration_ms() -> int:
	return _duration_ms

func get_operation() -> String:
	return _operation

func get_metadata() -> Dictionary:
	return _metadata.duplicate()

func with_operation(operation: String) -> DebugActionResult:
	_operation = operation
	return self

func with_duration(duration_ms: int) -> DebugActionResult:
	_duration_ms = duration_ms
	return self

func with_metadata(key: String, value: Variant) -> DebugActionResult:
	_metadata[key] = value
	return self

func with_metadata_dict(metadata: Dictionary) -> DebugActionResult:
	for key: String in metadata:
		_metadata[key] = metadata[key]
	return self

func to_completion_args() -> Array:
	if _success:
		return [true, _payload]

	var error_data: Dictionary = {"error": _error_message}
	if not _error_code.is_empty():
		error_data["error_code"] = _error_code
	if _error_category != ErrorCategory.NONE:
		error_data["error_category"] = ErrorCategory.keys()[_error_category]
	if _duration_ms > 0:
		error_data["duration_ms"] = _duration_ms
	if not _operation.is_empty():
		error_data["operation"] = _operation
	if not _metadata.is_empty():
		error_data["metadata"] = _metadata
	return [false, error_data]

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"success": _success,
		"payload": _payload,
		"error_message": _error_message,
		"error_code": _error_code,
		"error_category": ErrorCategory.keys()[_error_category],
		"duration_ms": _duration_ms,
		"operation": _operation,
		"metadata": _metadata
	}
	return result

func to_debug_string() -> String:
	if _success:
		var base: String = (
			"SUCCESS: %s (%dms)"
			% [_operation if not _operation.is_empty() else "Unknown", _duration_ms]
		)
		if not _metadata.is_empty():
			base += " [metadata: %s]" % str(_metadata)
		return base

	var base: String = (
		"FAILURE: %s - %s (%dms)"
		% [_operation if not _operation.is_empty() else "Unknown", _error_message, _duration_ms]
	)
	if not _error_code.is_empty():
		base += " [code: %s]" % _error_code
	if _error_category != ErrorCategory.NONE:
		base += " [category: %s]" % ErrorCategory.keys()[_error_category]
	if not _metadata.is_empty():
		base += " [metadata: %s]" % str(_metadata)
	return base

func is_network_error() -> bool:
	return _error_category == ErrorCategory.NETWORK

func is_timeout_error() -> bool:
	return _error_category == ErrorCategory.TIMEOUT

func is_permission_error() -> bool:
	return _error_category == ErrorCategory.PERMISSION

func is_firebase_error() -> bool:
	return _error_category == ErrorCategory.FIREBASE

func is_fast_operation(threshold_ms: int = 500) -> bool:
	return _duration_ms < threshold_ms

func is_slow_operation(threshold_ms: int = 2000) -> bool:
	return _duration_ms > threshold_ms

func get_performance_category() -> String:
	if _duration_ms < 500:
		return "FAST"
	if _duration_ms < 2000:
		return "NORMAL"
	return "SLOW"

func get_performance_metrics() -> Dictionary:
	return _metadata.get("performance_metrics", {})

func is_performance_acceptable(thresholds: Dictionary = {}) -> bool:
	if _metadata.get("result_type") != "performance":
		return true
	var metrics: Dictionary = get_performance_metrics()
	if thresholds.is_empty():
		thresholds = _metadata.get("performance_thresholds", {})
	for threshold_name: String in thresholds:
		var threshold_value: Variant = thresholds[threshold_name]
		var metric_value: Variant = metrics.get(threshold_name)
		if metric_value != null and metric_value > threshold_value:
			return false
	return _success

func get_batch_success_rate() -> float:
	if _metadata.get("result_type") != "batch":
		return 1.0 if _success else 0.0
	return _metadata.get("success_rate", 0.0)

func get_failed_operations() -> Array:
	if _metadata.get("result_type") != "batch":
		return []
	var failed_ops: Array = []
	var batch_results: Array = _metadata.get("batch_results", [])
	for result: Dictionary in batch_results:
		if not result.get("success", false):
			failed_ops.append(result)
	return failed_ops

func get_batch_summary() -> Dictionary:
	if _metadata.get("result_type") != "batch":
		return {"total": 1, "successful": 1 if _success else 0, "failed": 0 if _success else 1}
	var batch_results: Array = _metadata.get("batch_results", [])
	var successful: int = 0
	var failed: int = 0
	for result: Dictionary in batch_results:
		if result.get("success", false):
			successful += 1
		else:
			failed += 1
	return {
		"total": batch_results.size(),
		"successful": successful,
		"failed": failed,
		"success_rate": get_batch_success_rate()
	}

func get_listener_callback_data() -> Dictionary:
	if _metadata.get("result_type") != "listener":
		return {}
	return _metadata.get("callback_data", {})

func was_callback_received() -> bool:
	if _metadata.get("result_type") != "listener":
		return _success
	var payload_dict: Dictionary = _payload if _payload is Dictionary else {}
	return payload_dict.get("callback_received", false)

func get_concurrent_success_rates() -> Dictionary:
	if _metadata.get("result_type") != "concurrent":
		return {}
	return _metadata.get("success_rates", {})

func get_concurrent_operation_results() -> Array:
	if _metadata.get("result_type") != "concurrent":
		return []
	return _metadata.get("operation_results", [])

func is_authentication_error() -> bool:
	return _error_category == ErrorCategory.AUTHENTICATION

func is_configuration_error() -> bool:
	return _error_category == ErrorCategory.CONFIGURATION

func is_concurrent_error() -> bool:
	return _error_category == ErrorCategory.CONCURRENT

func is_data_integrity_error() -> bool:
	return _error_category == ErrorCategory.DATA_INTEGRITY

func is_listener_error() -> bool:
	return _error_category == ErrorCategory.LISTENER

func is_batch_operation_error() -> bool:
	return _error_category == ErrorCategory.BATCH_OPERATION

func is_performance_error() -> bool:
	return _error_category == ErrorCategory.PERFORMANCE