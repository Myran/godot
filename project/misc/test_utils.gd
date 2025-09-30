class_name TestUtils
extends RefCounted

## Simple utility functions for debug action test repetition removal
## Follows CLAUDE.md principles: strong typing, no complex abstractions, simple static functions


# Simple timing helper for operations (used in all 68 actions)
static func time_operation(operation_name: String, callable: Callable) -> Dictionary:
	var start_ms: int = Time.get_ticks_msec()
	var result: Variant = await callable.call()
	var duration_ms: int = Time.get_ticks_msec() - start_ms

	return {
		"result": result,
		"duration_ms": duration_ms,
		"operation": operation_name,
		"timestamp": start_ms
	}


# Simple helper to extract duration as int from time_operation result
static func get_duration_ms(timing_result: Dictionary) -> int:
	return timing_result.get("duration_ms", 0)


# Simple test path generator (repeated in 40+ actions)
static func make_test_path(category: String, operation: String) -> Array[String]:
	return [category, "direct", operation, str(Time.get_ticks_msec())]


# Simple test value generator with consistent format
static func make_test_value(prefix: String) -> String:
	return "%s: %d" % [prefix, Time.get_ticks_msec()]


# Simple test key generator with consistent format
static func make_test_key(prefix: String) -> String:
	return "%s_%d" % [prefix, Time.get_ticks_msec()]


# Simple success result creation (eliminates 10-15 lines per action)
static func make_success_result(
	message: String, duration_ms: int, action_name: String, metadata: Dictionary
) -> DebugActionResult:
	return DebugActionResult.new_success(message, duration_ms, action_name, metadata)


# Simple failure result creation (eliminates 10-15 lines per action)
static func make_failure_result(
	message: String, error_code: String, duration_ms: int, action_name: String, metadata: Dictionary
) -> DebugActionResult:
	return DebugActionResult.new_failure(
		message,
		error_code,
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration_ms,
		action_name,
		metadata
	)


# Simple result validation (repeated pattern)
static func is_valid_result(result: Variant) -> bool:
	return result != null


# Simple metadata creation with common fields
static func make_metadata(test_type: String, additional_data: Dictionary = {}) -> Dictionary:
	var base_metadata: Dictionary = {
		"test_type": test_type, "timestamp": Time.get_ticks_msec(), "platform": OS.get_name()
	}

	# Merge additional data into base metadata
	for key: String in additional_data:
		base_metadata[key] = additional_data[key]

	return base_metadata
