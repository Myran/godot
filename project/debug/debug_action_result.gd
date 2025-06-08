# project/debug/debug_action_result.gd
class_name DebugActionResult
extends RefCounted

## Unified result class for debug action completion
## Provides type-safe, consistent handling of action results across all debug action categories

enum ErrorCategory {
	NONE,
	NETWORK,
	PERMISSION, 
	TIMEOUT,
	VALIDATION,
	SYSTEM,
	FIREBASE,
	DATABASE
}

# Core result data
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

## Static factory methods for clean result creation
static func new_success(
	payload: Variant = null,
	duration_ms: int = 0,
	operation: String = "",
	metadata: Dictionary = {}
) -> DebugActionResult:
	return DebugActionResult.new(
		true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, metadata
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
		false, payload, error_message, error_code, error_category, duration_ms, operation, metadata
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
		false, null, timeout_message, "TIMEOUT", ErrorCategory.TIMEOUT, 
		timeout_duration_ms, operation, metadata
	)

static func new_network_error(
	error_details: String,
	operation: String = "",
	duration_ms: int = 0,
	metadata: Dictionary = {}
) -> DebugActionResult:
	return DebugActionResult.new(
		false, null, "Network error: " + error_details, "NETWORK_ERROR", 
		ErrorCategory.NETWORK, duration_ms, operation, metadata
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
		false, null, message, "PERMISSION_DENIED", 
		ErrorCategory.PERMISSION, duration_ms, operation, metadata
	)

## Core query methods
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

## Fluent builder methods for complex results
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
	for key in metadata:
		_metadata[key] = metadata[key]
	return self

## Enhanced compatibility for existing systems
func to_completion_args() -> Array:
	"""Returns [success: bool, data: Variant] for current completion system"""
	if _success:
		return [true, _payload]
	else:
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

## Enhanced serialization 
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
		var base: String = "SUCCESS: %s (%dms)" % [_operation if not _operation.is_empty() else "Unknown", _duration_ms]
		if not _metadata.is_empty():
			base += " [metadata: %s]" % str(_metadata)
		return base
	else:
		var base: String = "FAILURE: %s - %s (%dms)" % [
			_operation if not _operation.is_empty() else "Unknown",
			_error_message,
			_duration_ms
		]
		if not _error_code.is_empty():
			base += " [code: %s]" % _error_code
		if _error_category != ErrorCategory.NONE:
			base += " [category: %s]" % ErrorCategory.keys()[_error_category]
		if not _metadata.is_empty():
			base += " [metadata: %s]" % str(_metadata)
		return base

## Validation helpers
func is_network_error() -> bool:
	return _error_category == ErrorCategory.NETWORK

func is_timeout_error() -> bool:
	return _error_category == ErrorCategory.TIMEOUT

func is_permission_error() -> bool:
	return _error_category == ErrorCategory.PERMISSION

func is_firebase_error() -> bool:
	return _error_category == ErrorCategory.FIREBASE

## Performance analysis helpers
func is_fast_operation(threshold_ms: int = 500) -> bool:
	return _duration_ms < threshold_ms

func is_slow_operation(threshold_ms: int = 2000) -> bool:
	return _duration_ms > threshold_ms

func get_performance_category() -> String:
	if _duration_ms < 500:
		return "FAST"
	elif _duration_ms < 2000:
		return "NORMAL"
	else:
		return "SLOW"