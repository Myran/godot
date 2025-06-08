# project/debug/actions/debug_action.gd
class_name DebugAction
extends Resource

# Preload the output service for unified output handling
const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")


## Inner class for debug action results
class Result:
	extends RefCounted
	## Unified result class for debug action completion
	## Provides type-safe, consistent handling of action results across all debug action categories

	enum ErrorCategory {
		NONE, NETWORK, PERMISSION, TIMEOUT, VALIDATION, SYSTEM, FIREBASE, DATABASE,
		# Enhanced categories for comprehensive error handling
		AUTHENTICATION,     # Auth failures, permission denied  
		CONFIGURATION,      # Setup/config errors, missing settings
		CONCURRENT,         # Race conditions, concurrency issues
		DATA_INTEGRITY,     # Data validation, corruption, format errors
		LISTENER,           # Listener registration, callback issues
		BATCH_OPERATION,    # Multi-operation failures, partial success
		PERFORMANCE         # Performance threshold violations
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
	) -> DebugAction.Result:
		return DebugAction.Result.new(
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
	) -> DebugAction.Result:
		if error_message.is_empty():
			error_message = "Unknown error"
		return DebugAction.Result.new(
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
	) -> DebugAction.Result:
		var timeout_message: String = "Operation timed out after %d ms" % timeout_duration_ms
		if not details.is_empty():
			timeout_message += ": " + details
		return DebugAction.Result.new(
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
	) -> DebugAction.Result:
		return DebugAction.Result.new(
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
	) -> DebugAction.Result:
		var message: String = "Permission denied"
		if not resource.is_empty():
			message += " for resource: " + resource
		return DebugAction.Result.new(
			false,
			null,
			message,
			"PERMISSION_DENIED",
			ErrorCategory.PERMISSION,
			duration_ms,
			operation,
			metadata
		)

	## Specialized factory methods for common debug action patterns
	
	static func new_performance_result(
		operation_metrics: Array,
		overall_success: bool,
		performance_thresholds: Dictionary = {},
		operation: String = "performance_test",
		duration_ms: int = 0,
		metadata: Dictionary = {}
	) -> DebugAction.Result:
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
			return DebugAction.Result.new(
				true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
			)
		else:
			return DebugAction.Result.new(
				false, payload, "Performance thresholds not met", "PERFORMANCE_FAILURE", 
				ErrorCategory.PERFORMANCE, duration_ms, operation, enhanced_metadata
			)

	static func new_batch_result(
		individual_results: Array,
		batch_success_rate: float,
		operation: String = "batch_operations",
		duration_ms: int = 0,
		metadata: Dictionary = {}
	) -> DebugAction.Result:
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
		
		var batch_is_success: bool = batch_success_rate >= 0.5  # At least 50% success
		var error_category: ErrorCategory = ErrorCategory.BATCH_OPERATION if not batch_is_success else ErrorCategory.NONE
		var error_message: String = "" if batch_is_success else "Batch operation success rate below threshold"
		var error_code: String = "" if batch_is_success else "BATCH_FAILURE"
		
		return DebugAction.Result.new(
			batch_is_success, payload, error_message, error_code, error_category, duration_ms, operation, enhanced_metadata
		)

	static func new_listener_result(
		callback_received: bool,
		callback_data: Dictionary = {},
		timeout_ms: int = 0,
		operation: String = "listener_test",
		duration_ms: int = 0,
		metadata: Dictionary = {}
	) -> DebugAction.Result:
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
			return DebugAction.Result.new(
				true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
			)
		else:
			var error_message: String = "Listener callback not received"
			if timeout_ms > 0:
				error_message += " within " + str(timeout_ms) + "ms timeout"
			return DebugAction.Result.new(
				false, payload, error_message, "LISTENER_TIMEOUT", 
				ErrorCategory.LISTENER, duration_ms, operation, enhanced_metadata
			)

	static func new_concurrent_result(
		operation_results: Array,
		success_rates: Dictionary,
		overall_success: bool,
		operation: String = "concurrent_operations",
		duration_ms: int = 0,
		metadata: Dictionary = {}
	) -> DebugAction.Result:
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
			return DebugAction.Result.new(
				true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, enhanced_metadata
			)
		else:
			return DebugAction.Result.new(
				false, payload, "Concurrent operations did not meet success criteria", 
				"CONCURRENT_FAILURE", ErrorCategory.CONCURRENT, duration_ms, operation, enhanced_metadata
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
	func with_operation(operation: String) -> DebugAction.Result:
		_operation = operation
		return self

	func with_duration(duration_ms: int) -> DebugAction.Result:
		_duration_ms = duration_ms
		return self

	func with_metadata(key: String, value: Variant) -> DebugAction.Result:
		_metadata[key] = value
		return self

	func with_metadata_dict(metadata: Dictionary) -> DebugAction.Result:
		for key: String in metadata:
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
			var base: String = (
				"SUCCESS: %s (%dms)"
				% [_operation if not _operation.is_empty() else "Unknown", _duration_ms]
			)
			if not _metadata.is_empty():
				base += " [metadata: %s]" % str(_metadata)
			return base
		else:
			var base: String = (
				"FAILURE: %s - %s (%dms)"
				% [
					_operation if not _operation.is_empty() else "Unknown",
					_error_message,
					_duration_ms
				]
			)
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

	## Enhanced analysis methods for specialized result types
	
	func get_performance_metrics() -> Dictionary:
		"""Get performance metrics if this is a performance result"""
		return _metadata.get("performance_metrics", {})
	
	func is_performance_acceptable(thresholds: Dictionary = {}) -> bool:
		"""Check if performance metrics meet specified thresholds"""
		if _metadata.get("result_type") != "performance":
			return true  # Not a performance result, assume acceptable
		
		var metrics: Dictionary = get_performance_metrics()
		if thresholds.is_empty():
			thresholds = _metadata.get("performance_thresholds", {})
		
		# Check each threshold
		for threshold_name: String in thresholds:
			var threshold_value: Variant = thresholds[threshold_name]
			var metric_value: Variant = metrics.get(threshold_name)
			if metric_value != null and metric_value > threshold_value:
				return false
		
		return _success
	
	func get_batch_success_rate() -> float:
		"""Get success rate for batch operations"""
		if _metadata.get("result_type") != "batch":
			return 1.0 if _success else 0.0
		
		return _metadata.get("success_rate", 0.0)
	
	func get_failed_operations() -> Array:
		"""Get list of failed operations from batch result"""
		if _metadata.get("result_type") != "batch":
			return []
		
		var failed_ops: Array = []
		var batch_results: Array = _metadata.get("batch_results", [])
		for result: Dictionary in batch_results:
			if not result.get("success", false):
				failed_ops.append(result)
		
		return failed_ops
	
	func get_batch_summary() -> Dictionary:
		"""Get summary of batch operation results"""
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
		"""Get callback data for listener results"""
		if _metadata.get("result_type") != "listener":
			return {}
		
		return _metadata.get("callback_data", {})
	
	func was_callback_received() -> bool:
		"""Check if listener callback was received"""
		if _metadata.get("result_type") != "listener":
			return _success
		
		var payload_dict: Dictionary = _payload if _payload is Dictionary else {}
		return payload_dict.get("callback_received", false)
	
	func get_concurrent_success_rates() -> Dictionary:
		"""Get success rates for concurrent operations"""
		if _metadata.get("result_type") != "concurrent":
			return {}
		
		return _metadata.get("success_rates", {})
	
	func get_concurrent_operation_results() -> Array:
		"""Get individual operation results from concurrent test"""
		if _metadata.get("result_type") != "concurrent":
			return []
		
		return _metadata.get("operation_results", [])

	## Enhanced error category helpers
	
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


@export var action_name: String = "Unnamed Action"
@export var category: String = "General"  # e.g., "RTDB", "Auth", "Config"
@export var group: String = ""  # e.g., "Basic", "Listeners", "Connectivity"
@export_multiline var description: String = "No description."
@export var requires_confirmation: bool = false
@export var keyboard_shortcut: String = ""

# Signal for status updates - decouples actions from UI
signal status_updated(text: String, is_error: bool)
signal execution_completed(success: bool, result: Variant)

# Add support for callable-based actions
var action_callable: Callable

# Static test tracking variables for smart test system
static var current_test_id: String = ""
static var test_action_count: int = 0
static var test_success_count: int = 0
static var test_failure_count: int = 0


func _init(p_name: String = "", p_callable: Callable = Callable()) -> void:
	action_name = p_name
	action_callable = p_callable


# Builder pattern methods for fluent configuration
func set_category(p_category: String) -> DebugAction:
	category = p_category
	return self


func set_group(p_group: String) -> DebugAction:
	group = p_group
	return self


func set_description(p_description: String) -> DebugAction:
	description = p_description
	return self


func set_requires_confirmation(p_requires_confirmation: bool) -> DebugAction:
	requires_confirmation = p_requires_confirmation
	return self


func set_keyboard_shortcut(p_shortcut: String) -> DebugAction:
	keyboard_shortcut = p_shortcut
	return self


# Static test context management for smart testing
static func set_test_context(test_id: String) -> void:
	"""Set the current test ID for all debug actions"""
	current_test_id = test_id
	test_action_count = 0
	test_success_count = 0
	test_failure_count = 0
	Log.info("DEBUG_TEST_START", {"test_id": test_id}, ["debug", "test", "start"])


static func clear_test_context() -> void:
	"""Clear test context and emit completion signal"""
	if current_test_id != "":
		Log.info(
			"DEBUG_TEST_COMPLETE",
			{
				"test_id": current_test_id,
				"total_actions": test_action_count,
				"successful_actions": test_success_count,
				"failed_actions": test_failure_count
			},
			["debug", "test", "complete"]
		)
		current_test_id = ""


static func get_current_test_id() -> String:
	"""Get the current test ID (useful for debugging)"""
	return current_test_id


static func is_test_active() -> bool:
	"""Check if we're currently in a test context"""
	return current_test_id != ""


# Static factory method for creating programmatic actions
static func create(p_name: String, p_callable: Callable) -> DebugAction:
	var action: DebugAction = DebugAction.new(p_name, p_callable)
	return action


# Legacy factory method for compatibility
static func create_from_callable(
	p_name: String,
	p_callable: Callable,
	p_category: String = "Manual",
	p_group: String = "",
	p_description: String = ""
) -> DebugAction:
	var action: DebugAction = DebugAction.new(p_name, p_callable)
	action.category = p_category
	action.group = p_group
	action.description = p_description if p_description else "Execute " + p_name
	return action


# Enhanced execute method with smart test tracking
func execute() -> void:
	# Track test execution if we're in test context
	if current_test_id != "":
		test_action_count += 1

	var start_time: int = Time.get_ticks_msec()
	var success: bool = false
	var error_message: String = ""
	var result: Variant = null

	_update_status("Executing " + action_name + "...")

	if action_callable.is_valid():
		# Execute the action - GDScript doesn't have try/except
		result = await action_callable.call()

		# Determine success based on standardized return patterns
		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
	else:
		# No callable defined
		success = false
		error_message = "No execute method defined for " + action_name
		_update_status("ERROR: No execute method defined for " + action_name, true)

	var duration_ms: int = Time.get_ticks_msec() - start_time

	# Emit test tracking signals if in test context
	if current_test_id != "":
		if success:
			test_success_count += 1
			Log.info(
				"DEBUG_TEST_SUCCESS",
				{
					"test_id": current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"duration_ms": duration_ms
				},
				["debug", "test", "success"]
			)
		else:
			test_failure_count += 1
			Log.error(
				"DEBUG_TEST_FAILURE",
				{
					"test_id": current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"error": error_message,
					"duration_ms": duration_ms
				},
				["debug", "test", "failure"]
			)


# Type-safe result evaluation methods
func _evaluate_action_result(result: Variant) -> bool:
	"""Determine if an action result indicates success using standardized patterns"""
	# Handle null/void results as failure
	if result == null:
		return false

	# Handle DebugAction.Result (new pattern)
	if result is DebugAction.Result:
		return result.is_success()

	# Handle boolean results
	if result is bool:
		return result

	# Handle array pattern [success: bool, data: Variant]
	if result is Array and result.size() >= 1:
		return result[0] == true

	# Handle dictionary with error key
	if result is Dictionary and result.has("error"):
		return false

	# Handle dictionary with success key
	if result is Dictionary and result.has("success"):
		return result["success"] == true

	# Any other non-null result is considered success
	return true


func _extract_error_message(result: Variant) -> String:
	"""Extract error message from failed action result"""
	if result == null:
		return "Action returned null"

	# Handle DebugAction.Result (new pattern)
	if result is DebugAction.Result:
		if result.is_failure():
			return result.get_error_message()
		else:
			return "Action succeeded but error message requested"

	if result == false:
		return "Action returned false"

	# Handle array pattern [false, error_data]
	if result is Array and result.size() >= 2:
		var error_data: Variant = result[1]
		if error_data is String:
			return error_data
		elif error_data is Dictionary and error_data.has("error"):
			return str(error_data["error"])
		else:
			return str(error_data)

	# Handle dictionary with error key
	if result is Dictionary and result.has("error"):
		return str(result["error"])

	# Fallback to string representation
	return str(result)


# Helper to update status via signal instead of direct UI access
func _update_status(text: String, is_error: bool = false) -> void:
	# Unified output for all execution paths using DebugOutputService
	DebugOutputService.output_action_status(self, text, is_error)

	# Emit status update signal
	status_updated.emit(text, is_error)

	# Keep original logging for system logs
	Log.info(
		text,
		{"category": category, "group": group, "action": action_name, "error": is_error},
		["debug", "test"]
	)
