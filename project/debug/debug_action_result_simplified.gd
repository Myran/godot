class_name DebugActionResultSimplified
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
static func success(data: Variant = null, duration: int = 0) -> DebugActionResultSimplified:
	return DebugActionResultSimplified.new(State.SUCCESS, data, "", duration)


static func failure(error_message: String, duration: int = 0) -> DebugActionResultSimplified:
	return DebugActionResultSimplified.new(State.FAILURE, null, error_message, duration)


static func restart_needed(data: Variant = null, duration: int = 0) -> DebugActionResultSimplified:
	return DebugActionResultSimplified.new(
		State.RESTART_NEEDED, data, "Restart required for validation", duration
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
