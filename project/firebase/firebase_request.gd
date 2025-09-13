class_name FirebaseRequest
extends RefCounted

signal completed(result: Variant)

var _request_id: int
var _is_completed: bool = false
var _result: Variant = {}


func _init(request_id: int) -> void:
	_request_id = request_id


func get_request_id() -> int:
	return _request_id


func is_completed() -> bool:
	return _is_completed


func complete_with_success(payload: Variant) -> void:
	Log.debug(
		"FirebaseRequest: complete_with_success called",
		{
			"request_id": _request_id,
			"is_completed": _is_completed,
			"payload_type": typeof(payload),
			"signal_connections": completed.get_connections().size()
		},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	if _is_completed:
		Log.warning(
			"FirebaseRequest: Attempt to complete already completed request",
			{"request_id": _request_id},
			[Log.TAG_FIREBASE, "await_debug"]
		)
		return

	var typed_result: Dictionary = {"status": "ok", "payload": payload}
	_result = typed_result
	_is_completed = true

	Log.debug(
		"FirebaseRequest: About to emit completed signal",
		{
			"request_id": _request_id,
			"result": _result,
			"signal_connections": completed.get_connections().size()
		},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	completed.emit(_result)

	Log.debug(
		"FirebaseRequest: completed signal emitted",
		{"request_id": _request_id},
		[Log.TAG_FIREBASE, "await_debug"]
	)


func complete_with_error(error_code: String, error_message: String) -> void:
	Log.debug(
		"FirebaseRequest: complete_with_error called",
		{
			"request_id": _request_id,
			"error_code": error_code,
			"error_message": error_message,
			"is_completed": _is_completed
		},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	if _is_completed:
		Log.warning(
			"FirebaseRequest: Attempt to error complete already completed request",
			{"request_id": _request_id},
			[Log.TAG_FIREBASE, "await_debug"]
		)
		return

	var typed_result: Dictionary = {"status": "error", "code": error_code, "message": error_message}
	_result = typed_result
	_is_completed = true

	Log.debug(
		"FirebaseRequest: About to emit error completed signal",
		{"request_id": _request_id, "result": _result},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	completed.emit(_result)

	Log.debug(
		"FirebaseRequest: error completed signal emitted",
		{"request_id": _request_id},
		[Log.TAG_FIREBASE, "await_debug"]
	)


func get_result() -> Variant:
	return _result


func await_completion() -> Variant:
	Log.debug(
		"FirebaseRequest: await_completion called",
		{
			"request_id": _request_id,
			"is_completed": _is_completed,
			"result_keys": _result.keys() if _result else [],
			"has_completed_signal": completed.get_connections().size() > 0
		},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	if _is_completed:
		Log.debug(
			"FirebaseRequest: Already completed, returning immediately",
			{"request_id": _request_id, "result": _result},
			[Log.TAG_FIREBASE, "await_debug"]
		)
		return _result

	Log.debug(
		"FirebaseRequest: About to await completed signal",
		{"request_id": _request_id, "signal_connections": completed.get_connections().size()},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	# Use SignalAwaiter.Timeout to prevent indefinite hangs
	# Production-ready timeout: Firebase SDK (30s) + processing buffer (15s)
	var timeout_seconds: float = 45.0
	var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(timeout_seconds)
	var racer: SignalAwaiter.Any = SignalAwaiter.Any.new()
	racer.add(completed)
	racer.add(timeout_awaiter.finished)
	await racer.finished

	Log.debug(
		"FirebaseRequest: timeout race completed",
		{
			"request_id": _request_id,
			"timed_out": not _is_completed,
			"timeout_seconds": timeout_seconds
		},
		[Log.TAG_FIREBASE, "await_debug"]
	)

	if _is_completed:
		# Normal completion - clean up timeout awaiter
		timeout_awaiter.queue_free()
		Log.debug(
			"FirebaseRequest: completed normally",
			{"request_id": _request_id, "result": _result},
			[Log.TAG_FIREBASE, "await_debug"]
		)
		return _result

	# Timeout occurred - return timeout result
	Log.warning(
		"FirebaseRequest: Operation timed out",
		{
			"request_id": _request_id,
			"timeout_seconds": timeout_seconds,
			"operation": "firebase_request"
		},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return {"status": "timeout", "error": "operation_timed_out"}
