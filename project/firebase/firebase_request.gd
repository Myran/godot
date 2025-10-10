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
			[Log.TAG_FIREBASE]
		)
		return

	# CRITICAL SAFETY: Deep copy payload to prevent ARM64 alignment crashes
	# Firebase C++ SDK can return misaligned memory that causes SIGBUS when accessed
	# by GDScript. Deep copying ensures proper memory alignment before storing.
	var safe_payload = _safe_copy_variant(payload)

	_result = {"status": "ok", "payload": safe_payload}
	_is_completed = true

	Log.debug(
		"FirebaseRequest: Emitting completed signal",
		{
			"request_id": _request_id,
			"result_status": _result.status,
			"signal_connections": completed.get_connections().size()
		},
		[Log.TAG_FIREBASE]
	)

	completed.emit(_result)

	Log.debug(
		"FirebaseRequest: Completed signal emitted successfully",
		{"request_id": _request_id},
		[Log.TAG_FIREBASE, "await_debug"]
	)


# SAFETY: Deep copy Variants from Firebase to prevent ARM64 alignment crashes
# Firebase C++ SDK can return Variants with misaligned memory addresses
# (e.g., 0x533b000bdf mod 8 = 7) that cause SIGBUS crashes on ARM64
# when accessed by GDScript. This function ensures proper memory alignment.
func _safe_copy_variant(variant: Variant) -> Variant:
	Log.debug(
		"FirebaseRequest: _safe_copy_variant called",
		{"input_type": typeof(variant), "request_id": _request_id},
		[Log.TAG_FIREBASE, "alignment_debug"]
	)

	# Handle null or empty variants safely
	if variant == null:
		Log.debug(
			"FirebaseRequest: _safe_copy_variant returning null",
			{},
			[Log.TAG_FIREBASE, "alignment_debug"]
		)
		return null

	match typeof(variant):
		TYPE_DICTIONARY:
			Log.debug(
				"FirebaseRequest: _safe_copy_variant processing DICTIONARY",
				{},
				[Log.TAG_FIREBASE, "alignment_debug"]
			)
			var dict: Dictionary = variant
			var safe_dict: Dictionary = {}
			for key: Variant in dict.keys():
				safe_dict[key] = _safe_copy_variant(dict[key])
			return safe_dict
		TYPE_ARRAY:
			Log.debug(
				"FirebaseRequest: _safe_copy_variant processing ARRAY",
				{},
				[Log.TAG_FIREBASE, "alignment_debug"]
			)
			var arr: Array = variant
			var safe_arr: Array = []
			for item: Variant in arr:
				safe_arr.append(_safe_copy_variant(item))
			return safe_arr
		TYPE_STRING:
			Log.debug(
				"FirebaseRequest: _safe_copy_variant processing STRING",
				{},
				[Log.TAG_FIREBASE, "alignment_debug"]
			)
			# Strings might have misaligned memory internally, create a safe copy
			return String(variant)
		_:
			# Primitives (int, float, bool) are safe to return directly
			Log.debug(
				"FirebaseRequest: _safe_copy_variant returning primitive",
				{"type": typeof(variant), "value": str(variant)},
				[Log.TAG_FIREBASE, "alignment_debug"]
			)
			return variant


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

	# Timeout occurred - clean up pending request and return timeout result
	Log.warning(
		"FirebaseRequest: Operation timed out - cleaning up to prevent memory leak",
		{
			"request_id": _request_id,
			"timeout_seconds": timeout_seconds,
			"operation": "firebase_request"
		},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)

	# Critical fix: Clean up timed-out request from FirebaseService._pending_requests
	# to prevent memory leaks when GDScript strong typing silently drops Firebase C++ callbacks
	if FirebaseService != null:
		FirebaseService.cleanup_timed_out_request(_request_id)

	return {"status": "timeout", "error": "operation_timed_out"}
