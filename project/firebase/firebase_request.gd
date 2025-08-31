class_name FirebaseRequest
extends RefCounted

signal completed(result: Dictionary)

var _request_id: int
var _is_completed: bool = false
var _result: Dictionary = {}


func _init(request_id: int) -> void:
	_request_id = request_id


func get_request_id() -> int:
	return _request_id


func is_completed() -> bool:
	return _is_completed


func complete_with_success(payload: Variant) -> void:
	if _is_completed:
		return

	_result = {"status": "ok", "payload": payload}
	_is_completed = true
	completed.emit(_result)


func complete_with_error(error_code: String, error_message: String) -> void:
	if _is_completed:
		return

	_result = {"status": "error", "code": error_code, "message": error_message}
	_is_completed = true
	completed.emit(_result)


func get_result() -> Dictionary:
	return _result


func await_completion() -> Dictionary:
	if _is_completed:
		return _result

	await completed
	return _result
