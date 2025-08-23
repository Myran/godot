class_name DebugAction
extends Resource

const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")


class Result:
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
		AUTHENTICATION,  # Auth failures, permission denied
		CONFIGURATION,  # Setup/config errors, missing settings
		CONCURRENT,  # Race conditions, concurrency issues
		DATA_INTEGRITY,  # Data validation, corruption, format errors
		LISTENER,  # Listener registration, callback issues
		BATCH_OPERATION,  # Multi-operation failures, partial success
		PERFORMANCE  # Performance threshold violations
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
	) -> DebugAction.Result:
		return DebugAction.Result.new(
			true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, metadata
		)

	static func new_restart_pending(
		payload: Variant = null,
		duration_ms: int = 0,
		operation: String = "",
		metadata: Dictionary = {}
	) -> DebugAction.Result:
		return DebugAction.Result.new(
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

		return DebugAction.Result.new(
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
		var error_category: ErrorCategory = (
			ErrorCategory.BATCH_OPERATION if not batch_is_success else ErrorCategory.NONE
		)
		var error_message: String = (
			"" if batch_is_success else "Batch operation success rate below threshold"
		)
		var error_code: String = "" if batch_is_success else "BATCH_FAILURE"

		return DebugAction.Result.new(
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

		var error_message: String = "Listener callback not received"
		if timeout_ms > 0:
			error_message += " within " + str(timeout_ms) + "ms timeout"
		return DebugAction.Result.new(
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

		return DebugAction.Result.new(
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
		elif _duration_ms < 2000:
			return "NORMAL"
		else:
			return "SLOW"

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
@export var use_auto_semantic_logging: bool = true  # Actions can opt out to handle their own semantic logging

signal status_updated(text: String, is_error: bool)
signal execution_completed(success: bool, result: Variant)

var action_callable: Callable

static var current_test_id: String = ""
static var test_action_count: int = 0
static var test_success_count: int = 0
static var test_failure_count: int = 0


func _init(p_name: String = "", p_callable: Callable = Callable()) -> void:
	action_name = p_name
	action_callable = p_callable


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


static func set_test_context(test_id: String) -> void:
	"""Set the current test ID for all debug actions"""
	current_test_id = test_id
	test_action_count = 0
	test_success_count = 0
	test_failure_count = 0
	Log.info(
		"DEBUG_TEST_START",
		{
			"test_id": test_id,
			"pid": OS.get_process_id(),
			"timestamp": Time.get_datetime_string_from_system(),
			"platform": OS.get_name()
		},
		["debug", "test", "start", "pid"]
	)


static func clear_test_context() -> void:
	"""Clear test context and emit completion signal"""
	if current_test_id != "":
		Log.info(
			"DEBUG_TEST_COMPLETE",
			{
				"test_id": current_test_id,
				"total_actions": test_action_count,
				"successful_actions": test_success_count,
				"failed_actions": test_failure_count,
				"pid": OS.get_process_id(),
				"timestamp": Time.get_datetime_string_from_system(),
				"duration_since_start": Time.get_datetime_string_from_system()
			},
			["debug", "test", "complete", "pid"]
		)
		current_test_id = ""


static func get_current_test_id() -> String:
	"""Get the current test ID (useful for debugging)"""
	return current_test_id


static func is_test_active() -> bool:
	"""Check if we're currently in a test context"""
	return current_test_id != ""


static func create(p_name: String, p_callable: Callable) -> DebugAction:
	var action: DebugAction = DebugAction.new(p_name, p_callable)
	return action


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


func execute() -> void:
	if current_test_id != "":
		test_action_count += 1

	var start_time: int = Time.get_ticks_msec()
	var success: bool = false
	var error_message: String = ""
	var result: Variant = null

	_update_status("Executing " + action_name + "...")

	# 🚨 CRITICAL: Log as SEMANTIC_ACTION before execution for replay generation
	_log_debug_action_as_semantic()

	if action_callable.is_valid():
		result = await action_callable.call()

		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
	else:
		success = false
		error_message = "No execute method defined for " + action_name
		_update_status("ERROR: No execute method defined for " + action_name, true)

	var duration_ms: int = Time.get_ticks_msec() - start_time

	if current_test_id != "":
		var process_id: int = OS.get_process_id()
		if success:
			test_success_count += 1
			(
				Log
				. info(
					"DEBUG_TEST_SUCCESS",
					{
						"test_id": current_test_id,
						"action": action_name,
						"category": category,
						"group": group,
						"duration_ms": duration_ms,
						"pid": OS.get_process_id(),
						"sequence": test_success_count,
						"timestamp": Time.get_datetime_string_from_system(),
					},
					["debug", "test", "success", "pid", "sequence"]
				)
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
					"duration_ms": duration_ms,
					"pid": OS.get_process_id(),
					"sequence": test_failure_count,
					"timestamp": Time.get_datetime_string_from_system(),
					"success_count_before_failure": test_success_count
				},
				["debug", "test", "failure", "pid", "sequence"]
			)

	execution_completed.emit(success, result)


func execute_with_params(params: Dictionary = {}) -> void:
	"""Execute action with optional parameters - enhanced version of execute()"""

	Log.debug(
		"TEMP DEBUG: execute_with_params called",
		{"action": action_name, "count": test_action_count},
		["debug", "temp"]
	)

	if current_test_id != "":
		test_action_count += 1

	var start_time: int = Time.get_ticks_msec()
	var success: bool = false
	var error_message: String = ""
	var result: Variant = null

	_update_status("Executing " + action_name + " with params...")

	# 🚨 CRITICAL: Log as SEMANTIC_ACTION before execution for replay generation
	_log_debug_action_as_semantic(params)

	if action_callable.is_valid():
		if params.is_empty():
			result = await action_callable.call()
		else:
			Log.debug(
				"Action called with parameters",
				{"action": action_name, "params": params},
				["debug", "action", "params"]
			)
			result = await action_callable.call(params)

		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
	else:
		success = false
		error_message = "No execute method defined for " + action_name
		_update_status("ERROR: No execute method defined for " + action_name, true)

	var duration_ms: int = Time.get_ticks_msec() - start_time

	if current_test_id != "":
		if success:
			test_success_count += 1
			(
				Log
				. info(  # Using Log.info for proper semantic logging level
					"DEBUG_TEST_SUCCESS",
					{
						"test_id": current_test_id,
						"action": action_name,
						"category": category,
						"group": group,
						"duration_ms": duration_ms,
						"params": params,
						"pid": OS.get_process_id(),
						"sequence": test_success_count,
						"timestamp": Time.get_datetime_string_from_system(),
					},
					["debug", "test", "success", "pid", "sequence"]
				)
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
					"duration_ms": duration_ms,
					"params": params,
					"pid": OS.get_process_id(),
					"sequence": test_failure_count,
					"timestamp": Time.get_datetime_string_from_system(),
					"success_count_before_failure": test_success_count
				},
				["debug", "test", "failure", "pid", "sequence"]
			)

	execution_completed.emit(success, result)


func _evaluate_action_result(result: Variant) -> bool:
	"""Determine if an action result indicates success using standardized patterns"""
	if result == null:
		return false

	if result is DebugAction.Result:
		if result.get_error_code() == "RESTART_NEEDED":
			return true  # Treat restart pending as success to avoid test failure
		return result.is_success()

	if result is bool:
		return result

	if result is Array and result.size() >= 1:
		return result[0] == true

	if result is Dictionary and result.has("error"):
		return false

	if result is Dictionary and result.has("success"):
		return result["success"] == true

	return true


func _extract_error_message(result: Variant) -> String:
	"""Extract error message from failed action result"""
	if result == null:
		return "Action returned null"

	if result is DebugAction.Result:
		if result.is_failure():
			return result.get_error_message()
		else:
			return "Action succeeded but error message requested"

	if result == false:
		return "Action returned false"

	if result is Array and result.size() >= 2:
		var error_data: Variant = result[1]
		if error_data is String:
			return error_data
		elif error_data is Dictionary and error_data.has("error"):
			return str(error_data["error"])
		else:
			return str(error_data)

	if result is Dictionary and result.has("error"):
		return str(result["error"])

	return str(result)


func _update_status(text: String, is_error: bool = false) -> void:
	DebugOutputService.output_action_status(self, text, is_error)

	status_updated.emit(text, is_error)

	Log.info(
		text,
		{"category": category, "group": group, "action": action_name, "error": is_error},
		["debug", "test"]
	)


func execute_with_state_validation(
	session_id: String = "", sequence: int = -1
) -> DebugAction.Result:
	"""Execute action with full state validation integration - CRITICAL FOR COMPANY SURVIVAL"""
	var start_time: int = Time.get_ticks_msec()

	Log.info(
		"Starting action execution with state validation",
		{
			"action_name": action_name,
			"session_id": session_id,
			"sequence": sequence,
			"category": category,
			"group": group
		},
		["debug", "validation", "execution"]
	)

	var pre_action_state: Dictionary = {}
	if not session_id.is_empty() and sequence >= 0:
		(
			Log
			. debug(
				"Pre-action state handled by semantic logging system",
				{
					"action_name": action_name,
					"session_id": session_id,
					"sequence": sequence,
					"note":
					"Pre-action checksums are captured automatically in SessionManager.log_semantic_action"
				},
				["debug", "validation", "pre_state"]
			)
		)

	var execution_result: Variant = null
	var execution_success: bool = false
	var error_message: String = ""

	_update_status("Executing " + action_name + " with validation...")

	# 🚨 CRITICAL: Log as SEMANTIC_ACTION before execution for replay generation
	_log_debug_action_as_semantic()

	if action_callable.is_valid():
		execution_result = await action_callable.call()
		execution_success = _evaluate_action_result(execution_result)

		if not execution_success:
			error_message = _extract_error_message(execution_result)
			Log.error(
				"Action execution failed",
				{
					"action_name": action_name,
					"error_message": error_message,
					"result_type": typeof(execution_result)
				},
				["debug", "validation", "execution_error"]
			)
	else:
		execution_success = false
		error_message = "No callable defined for action: " + action_name
		Log.error(
			"Action has no callable defined",
			{"action_name": action_name},
			["debug", "validation", "configuration_error"]
		)

	var post_action_state: Dictionary = {}
	var state_validation_result: Dictionary = {}

	if not session_id.is_empty() and sequence >= 0:
		Log.debug(
			"State validation simplified to checksum-based approach",
			{
				"action_name": action_name,
				"session_id": session_id,
				"sequence": sequence,
				"note": "Post-action capture removed, using semantic logging checksums"
			},
			["debug", "validation", "post_state"]
		)

		Log.info(
			"Using simplified checksum validation approach",
			{
				"action_name": action_name,
				"session_id": session_id,
				"sequence": sequence,
				"validation_approach": "semantic_logging_checksums",
				"previous_approach": "complex_state_capture_removed"
			},
			["debug", "validation", "state_validation"]
		)

	var total_duration_ms: int = Time.get_ticks_msec() - start_time

	var result_metadata: Dictionary = {
		"action_name": action_name,
		"category": category,
		"group": group,
		"session_id": session_id,
		"sequence": sequence,
		"execution_time_ms": total_duration_ms,
		"state_validation": state_validation_result,
		"execution_result": execution_result
	}

	var overall_success: bool = execution_success
	var final_error_message: String = error_message
	var error_category: DebugAction.Result.ErrorCategory = DebugAction.Result.ErrorCategory.NONE

	if execution_success and not state_validation_result.is_empty():
		var validation_success: bool = state_validation_result.get("action_valid", true)
		if not validation_success:
			overall_success = false
			final_error_message = (
				"State validation failed: "
				+ state_validation_result.get("error_message", "Unknown validation error")
			)
			error_category = DebugAction.Result.ErrorCategory.VALIDATION

			Log.error(
				"Action execution succeeded but state validation failed",
				{
					"action_name": action_name,
					"execution_success": execution_success,
					"validation_success": validation_success,
					"error_message": final_error_message
				},
				["debug", "validation", "validation_failure"]
			)

	if overall_success:
		_update_status("Completed: " + action_name + " (validated)")
	else:
		_update_status("ERROR: " + action_name + " - " + final_error_message, true)

	var final_result: DebugAction.Result
	if overall_success:
		final_result = DebugAction.Result.new_success(
			execution_result, total_duration_ms, action_name, result_metadata
		)
	else:
		final_result = DebugAction.Result.new_failure(
			final_error_message,
			"",
			error_category,
			execution_result,
			total_duration_ms,
			action_name,
			result_metadata
		)

	Log.info(
		"Action execution with validation completed",
		{
			"action_name": action_name,
			"overall_success": overall_success,
			"execution_success": execution_success,
			"state_validation_success": state_validation_result.get("action_valid", true),
			"total_duration_ms": total_duration_ms,
			"session_id": session_id,
			"sequence": sequence
		},
		["debug", "validation", "execution_complete"]
	)

	return final_result


func execute_with_auto_validation() -> DebugAction.Result:
	"""Execute with automatic state validation detection based on current session context"""
	var current_session_id: String = SessionManager.get_current_session_id()
	var current_sequence: int = SessionManager.session_action_count + 1

	if not current_session_id.is_empty():
		return await execute_with_state_validation(current_session_id, current_sequence)
	else:
		Log.debug(
			"No session context available, using standard execution",
			{"action_name": action_name},
			["debug", "validation", "no_session"]
		)
		execute()
		return DebugAction.Result.new_success(
			null, 0, action_name, {"validation_mode": "none", "reason": "no_session_context"}
		)


func _execute_with_validation_async(session_id: String, sequence: int) -> void:
	"""Execute state validation asynchronously and handle result"""
	var validation_result: DebugAction.Result = await execute_with_state_validation(
		session_id, sequence
	)
	_process_validation_result_for_legacy_execution(validation_result)


func _process_validation_result_for_legacy_execution(validation_result: DebugAction.Result) -> void:
	"""Convert state validation result to legacy execution result format"""
	var success: bool = validation_result.is_success()
	var result: Variant = validation_result.payload
	var error_message: String = validation_result.error_message

	if success:
		_update_status("Completed with validation: " + action_name)
	else:
		_update_status("ERROR with validation: " + action_name + " - " + error_message, true)

	execution_completed.emit(success, result)

	Log.info(
		"Legacy execution conversion completed",
		{
			"action": action_name,
			"success": success,
			"has_error": not error_message.is_empty(),
			"validation_used": true
		},
		["debug", "validation", "legacy_conversion"]
	)


func _log_debug_action_as_semantic(params: Dictionary = {}) -> void:
	"""🚨 CRITICAL: Log debug actions as SEMANTIC_ACTION for automatic replay generation

	This ensures debug menu actions are automatically logged as semantic actions and can be
	replayed without individual case-by-case handling. Actions can opt out to handle their
	own specialized logging (e.g., gamestate actions that need domain-specific metadata).
	"""

	# Check if action opted out of generic logging
	if not use_auto_semantic_logging:
		Log.debug(
			"Action opted out of generic semantic logging",
			{"action_name": action_name, "category": category, "group": group},
			["debug", "semantic", "opt_out"]
		)
		return

	# Check for active session, create fallback session if needed
	var current_session_id: String = SessionManager.get_current_session_id()
	if current_session_id.is_empty():
		# For development/testing: create temporary session for debug actions
		Log.debug(
			"No active session - creating temporary debug session",
			{"action_name": action_name, "category": category, "group": group},
			["debug", "semantic", "temp_session"]
		)
		current_session_id = SessionManager.start_new_session(
			"debug_action_temp", {"trigger_action": action_name, "session_type": "debug_temporary"}
		)

	# Prepare semantic action data with proper structure for parser extraction
	var semantic_data: Dictionary = {
		"debug_action": action_name,
		"category": category,
		"group": group,
		"description": description,
		"data": {}  # Add data wrapper to match parser extraction path
	}

	# Include parameters in data wrapper if provided
	if not params.is_empty():
		semantic_data["data"]["params"] = params  # Match parser: '.data.params'

	# Domain-specific data is handled by individual actions that opt out of generic logging

	# Log as semantic action using SessionManager
	# This ensures proper checksum capture and session tracking
	SessionManager.log_semantic_action(action_name, semantic_data)

	Log.debug(
		"Debug action logged as SEMANTIC_ACTION",
		{
			"action_name": action_name,
			"session_id": current_session_id,
			"has_params": not params.is_empty(),
			"category": category,
			"group": group
		},
		["debug", "semantic", "logged"]
	)
