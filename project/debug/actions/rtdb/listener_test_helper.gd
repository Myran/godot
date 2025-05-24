@tool
class_name ListenerTestHelper
extends RefCounted
## Helper class for testing Firebase listeners with proper timeout and callback verification.
## Simplifies the common pattern of waiting for listener callbacks.

signal callback_received(data: Dictionary)

var _callback_data: Dictionary = {}
var _received: bool = false
var _start_time_ms: int = 0


func reset() -> void:
	_callback_data = {}
	_received = false
	_start_time_ms = TimeUtils.now_ms()


func mark_callback_received(key: String, value: Variant, additional_data: Dictionary = {}) -> void:
	_received = true
	_callback_data = {
		"key": key,
		"value": value,
		"received_at_ms": TimeUtils.now_ms(),
		"elapsed_ms": TimeUtils.elapsed_ms(_start_time_ms)
	}
	_callback_data.merge(additional_data)
	callback_received.emit(_callback_data)


func wait_for_callback(timeout_sec: float = 5.0) -> Dictionary:
	var deadline: int = TimeUtils.deadline_ms(timeout_sec)

	while not _received and not TimeUtils.is_past_deadline(deadline):
		await Engine.get_main_loop().process_frame

	if _received:
		return {"success": true, "data": _callback_data}
	else:
		return {
			"success": false,
			"error": "Timeout waiting for callback after %.1f seconds" % timeout_sec,
			"elapsed_ms": TimeUtils.elapsed_ms(_start_time_ms)
		}


func is_callback_received() -> bool:
	return _received


func get_callback_data() -> Dictionary:
	return _callback_data


func get_elapsed_time_ms() -> int:
	return TimeUtils.elapsed_ms(_start_time_ms)
