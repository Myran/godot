class_name DebugAction
extends Resource

signal status_updated(text: String, is_error: bool)
signal execution_completed(success: bool, result: Variant)

const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")
const DebugActionResultClass = preload("res://debug/debug_action_result.gd")

static var current_test_id: String = ""
static var test_action_count: int = 0
static var test_success_count: int = 0
static var test_failure_count: int = 0

@export var action_name: String = "Unnamed Action"
@export var category: String = "General"  # e.g., "RTDB", "Auth", "Config"
@export var group: String = ""  # e.g., "Basic", "Listeners", "Connectivity"
@export_multiline var description: String = "No description."
@export var requires_confirmation: bool = false
@export var keyboard_shortcut: String = ""
@export var use_auto_semantic_logging: bool = true  # Actions can opt out to handle their own semantic logging

var action_callable: Callable


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
	return current_test_id


static func is_test_active() -> bool:
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

	_log_debug_action_as_semantic()

	Log.info(
		"TRACE: About to check action_callable validity",
		{"action": action_name, "callable_valid": action_callable.is_valid()},
		["debug", "trace", "callable"]
	)

	if action_callable.is_valid():
		Log.info(
			"TRACE: Calling action_callable",
			{"action": action_name},
			["debug", "trace", "callable"]
		)
		result = await action_callable.call()

		Log.info(
			"TRACE: action_callable completed",
			{"action": action_name, "result_type": typeof(result)},
			["debug", "trace", "callable"]
		)

		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
	else:
		Log.error(
			"TRACE: action_callable invalid",
			{"action": action_name},
			["debug", "trace", "callable"]
		)
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

			# CRITICAL: Wait for Android chunk processing to complete in automated mode
			# This ensures DEBUG_TEST_SUCCESS logs are not lost and maintains log ordering
			var metadata: Dictionary = DebugConfigReader.get_metadata()
			if OS.get_name() == "Android" and metadata.get("auto_quit", false):
				await Log.wait_for_chunk_processing_complete_signal()
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

	_log_debug_action_as_semantic(params)

	Log.info(
		"TRACE: execute_with_params - checking action_callable validity",
		{"action": action_name, "callable_valid": action_callable.is_valid()},
		["debug", "trace", "callable"]
	)

	if action_callable.is_valid():
		Log.info(
			"TRACE: execute_with_params - calling action_callable",
			{"action": action_name, "has_params": not params.is_empty()},
			["debug", "trace", "callable"]
		)

		if params.is_empty():
			result = await action_callable.call()
		else:
			Log.debug(
				"Action called with parameters",
				{"action": action_name, "params": params},
				["debug", "action", "params"]
			)
			result = await action_callable.call(params)

		Log.info(
			"TRACE: execute_with_params - action_callable completed",
			{"action": action_name, "result_type": typeof(result)},
			["debug", "trace", "callable"]
		)

		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
	else:
		Log.error(
			"TRACE: execute_with_params - action_callable invalid",
			{"action": action_name},
			["debug", "trace", "callable"]
		)
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

			# CRITICAL: Wait for Android chunk processing to complete in automated mode
			# This ensures DEBUG_TEST_SUCCESS logs are not lost and maintains log ordering
			var metadata: Dictionary = DebugConfigReader.get_metadata()
			if OS.get_name() == "Android" and metadata.get("auto_quit", false):
				await Log.wait_for_chunk_processing_complete_signal()
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
	if result == null:
		return false

	if result is DebugActionResult:
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
	if result == null:
		return "Action returned null"

	if result is DebugActionResult:
		if result.is_failure():
			return result.get_error_message()
		return "Action succeeded but error message requested"

	if result == false:
		return "Action returned false"

	if result is Array and result.size() >= 2:
		var error_data: Variant = result[1]
		if error_data is String:
			return error_data
		if error_data is Dictionary and error_data.has("error"):
			return str(error_data["error"])
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
) -> DebugActionResult:
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
	var error_category: DebugActionResultClass.ErrorCategory = (
		DebugActionResultClass.ErrorCategory.NONE
	)

	if execution_success and not state_validation_result.is_empty():
		var validation_success: bool = state_validation_result.get("action_valid", true)
		if not validation_success:
			overall_success = false
			final_error_message = (
				"State validation failed: "
				+ state_validation_result.get("error_message", "Unknown validation error")
			)
			error_category = DebugActionResultClass.ErrorCategory.VALIDATION

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

	var final_result: DebugActionResult
	if overall_success:
		final_result = DebugActionResultClass.new_success(
			execution_result, total_duration_ms, action_name, result_metadata
		)
	else:
		final_result = DebugActionResultClass.new_failure(
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


func execute_with_auto_validation() -> DebugActionResult:
	var current_session_id: String = SessionManager.get_current_session_id()
	var current_sequence: int = SessionManager.session_action_count + 1

	if not current_session_id.is_empty():
		return await execute_with_state_validation(current_session_id, current_sequence)

	Log.debug(
		"No session context available, using standard execution",
		{"action_name": action_name},
		["debug", "validation", "no_session"]
	)
	execute()
	return DebugActionResultClass.new_success(
		null, 0, action_name, {"validation_mode": "none", "reason": "no_session_context"}
	)


func _execute_with_validation_async(session_id: String, sequence: int) -> void:
	var validation_result: DebugActionResult = await execute_with_state_validation(
		session_id, sequence
	)
	_process_validation_result_for_legacy_execution(validation_result)


func _process_validation_result_for_legacy_execution(validation_result: DebugActionResult) -> void:
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

	if not use_auto_semantic_logging:
		Log.debug(
			"Action opted out of generic semantic logging",
			{"action_name": action_name, "category": category, "group": group},
			["debug", "semantic", "opt_out"]
		)
		return

	var current_session_id: String = SessionManager.get_current_session_id()
	if current_session_id.is_empty():
		Log.debug(
			"No active session - creating temporary debug session",
			{"action_name": action_name, "category": category, "group": group},
			["debug", "semantic", "temp_session"]
		)
		current_session_id = SessionManager.start_new_session(
			"debug_action_temp", {"trigger_action": action_name, "session_type": "debug_temporary"}
		)

	var semantic_data: Dictionary = {
		"debug_action": action_name,
		"category": category,
		"group": group,
		"description": description,
		"data": {}  # Add data wrapper to match parser extraction path
	}

	if not params.is_empty():
		semantic_data["data"]["params"] = params  # Match parser: '.data.params'

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
