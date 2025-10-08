class_name FirebaseRequestQueue
extends RefCounted

## Firebase Request Queue (FRQ)
## Maintains ordered completion processing for Firebase async operations
## Prevents CONNECT_DEFERRED race conditions that cause SIGBUS crashes

signal queue_completed(processed_count: int)
signal queue_overflow(dropped_count: int)
signal queue_processed(request_id: int, success: bool)

var _queue: Array[Dictionary] = []
var _processing: bool = false
var _max_queue_size: int = 100
var _processing_batch_size: int = 5
var _total_processed: int = 0
var _total_dropped: int = 0
var _queue_enabled: bool = true


func _init(max_size: int = 100, batch_size: int = 5) -> void:
	_max_queue_size = max_size
	_processing_batch_size = batch_size

	Log.info(
		"FirebaseRequestQueue initialized",
		{
			"max_queue_size": _max_queue_size,
			"batch_size": _processing_batch_size,
			"queue_enabled": _queue_enabled
		},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func enqueue_request(request_id: int, result: Variant) -> bool:
	## Add a Firebase request completion to the queue
	## Returns true if enqueued successfully, false if queue is full/disabled

	if not _queue_enabled:
		Log.debug(
			"FirebaseRequestQueue: Queue disabled, processing immediately",
			{"request_id": request_id},
			[Log.TAG_FIREBASE, "queue_debug"]
		)
		_process_request_immediately(request_id, result)
		return true

	if _queue.size() >= _max_queue_size:
		_total_dropped += 1
		var dropped_count: int = 1

		Log.warning(
			"FirebaseRequestQueue: Queue overflow - dropping oldest requests",
			{
				"current_size": _queue.size(),
				"max_size": _max_queue_size,
				"dropped_requests": dropped_count,
				"total_dropped": _total_dropped,
				"new_request_id": request_id
			},
			[Log.TAG_FIREBASE, Log.TAG_WARNING]
		)

		# Drop oldest requests to make room (FIFO overflow handling)
		var drop_count: int = min(_processing_batch_size, _queue.size())
		for i: int in range(drop_count):
			_queue.pop_front()

		queue_overflow.emit(drop_count)
		return false

	var queue_item: Dictionary = {
		"request_id": request_id,
		"result": result,
		"timestamp": Time.get_ticks_msec(),
		"queue_time": 0
	}

	_queue.push_back(queue_item)

	Log.debug(
		"FirebaseRequestQueue: Request enqueued",
		{
			"request_id": request_id,
			"result_status": result.get("status", "unknown") if result is Dictionary else "unknown",
			"queue_size": _queue.size(),
			"result_valid": result != null
		},
		[Log.TAG_FIREBASE, "queue_debug"]
	)

	# Start processing if not already running
	if not _processing:
		_process_queue.call_deferred()

	return true


func _process_queue() -> void:
	## Process queued requests on main thread in batches
	## Uses call_deferred to ensure main thread execution

	if _processing or _queue.is_empty():
		return

	_processing = true
	var processed_count: int = 0
	var batch_start_time: int = Time.get_ticks_msec()

	Log.debug(
		"FirebaseRequestQueue: Starting queue processing",
		{
			"queue_size": _queue.size(),
			"batch_size": _processing_batch_size,
			"processing_thread": "main_thread"
		},
		[Log.TAG_FIREBASE, "queue_debug"]
	)

	while not _queue.is_empty() and processed_count < _processing_batch_size:
		var queue_item: Dictionary = _queue.pop_front()
		var request_id: int = queue_item.request_id
		var result: Variant = queue_item.result
		var queue_time: int = Time.get_ticks_msec() - queue_item.timestamp

		Log.debug(
			"FirebaseRequestQueue: Processing queued request",
			{
				"request_id": request_id,
				"queue_time_ms": queue_time,
				"remaining_queue": _queue.size(),
				"processed_in_batch": processed_count + 1
			},
			[Log.TAG_FIREBASE, "queue_debug"]
		)

		# Process the request completion
		var success: bool = _process_request_completion(request_id, result)
		_total_processed += 1
		processed_count += 1

		queue_processed.emit(request_id, success)

		# Yield periodically to prevent blocking main thread
		if processed_count % 2 == 0:  # Yield every 2 requests
			await Engine.get_main_loop().process_frame

	var batch_duration: int = Time.get_ticks_msec() - batch_start_time

	Log.info(
		"FirebaseRequestQueue: Batch processing completed",
		{
			"processed_count": processed_count,
			"batch_duration_ms": batch_duration,
			"remaining_queue": _queue.size(),
			"total_processed": _total_processed,
			"avg_request_time_ms":
			float(batch_duration) / float(processed_count) if processed_count > 0 else 0.0
		},
		[Log.TAG_FIREBASE]
	)

	_processing = false
	queue_completed.emit(processed_count)

	# Continue processing if more items in queue
	if not _queue.is_empty():
		_process_queue.call_deferred()


func _process_request_immediately(request_id: int, result: Variant) -> void:
	## Process request immediately when queue is disabled (bypass mode)
	Log.debug(
		"FirebaseRequestQueue: Immediate processing (queue disabled)",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, "queue_debug"]
	)

	_process_request_completion(request_id, result)


func _process_request_completion(request_id: int, result: Variant) -> bool:
	## Process a single request completion
	## This is implemented by FirebaseService to maintain existing logic

	# This method will be overridden by FirebaseService to handle actual completion
	# The queue calls this method, and FirebaseService provides the implementation

	if FirebaseService and FirebaseService.has_method("_queue_process_request_completion"):
		return FirebaseService._queue_process_request_completion(request_id, result)

	Log.error(
		"FirebaseRequestQueue: FirebaseService integration not available",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func get_queue_stats() -> Dictionary:
	## Get comprehensive queue statistics for monitoring

	return {
		"current_size": _queue.size(),
		"max_size": _max_queue_size,
		"processing": _processing,
		"enabled": _queue_enabled,
		"total_processed": _total_processed,
		"total_dropped": _total_dropped,
		"batch_size": _processing_batch_size,
		"oldest_request_age_ms": _get_oldest_request_age(),
		"queue_utilization": float(_queue.size()) / float(_max_queue_size) * 100.0
	}


func _get_oldest_request_age() -> int:
	## Get age of oldest request in queue (in milliseconds)

	if _queue.is_empty():
		return 0

	var oldest_item: Dictionary = _queue.front()
	return Time.get_ticks_msec() - oldest_item.timestamp


func set_queue_enabled(enabled: bool) -> void:
	## Enable or disable the queue (for testing/rollback)

	if _queue_enabled == enabled:
		return

	_queue_enabled = enabled

	Log.info(
		"FirebaseRequestQueue: Queue " + ("enabled" if enabled else "disabled"),
		{
			"previous_state": not _queue_enabled,
			"current_queue_size": _queue.size(),
			"total_processed": _total_processed,
			"total_dropped": _total_dropped
		},
		[Log.TAG_FIREBASE]
	)

	# Process remaining queue if disabling
	if not enabled and not _queue.is_empty():
		Log.warning(
			"FirebaseRequestQueue: Disabling with non-empty queue - processing remaining items",
			{"remaining_items": _queue.size()},
			[Log.TAG_FIREBASE, Log.TAG_WARNING]
		)
		_process_queue.call_deferred()


func clear_queue() -> int:
	## Clear all pending requests (emergency use only)

	var cleared_count: int = _queue.size()
	_queue.clear()

	Log.warning(
		"FirebaseRequestQueue: Emergency queue clear",
		{"cleared_count": cleared_count},
		[Log.TAG_FIREBASE, Log.TAG_WARNING]
	)

	return cleared_count


func configure_queue(max_size: int, batch_size: int) -> void:
	## Reconfigure queue parameters

	_max_queue_size = max_size
	_processing_batch_size = batch_size

	Log.info(
		"FirebaseRequestQueue: Configuration updated",
		{
			"new_max_size": _max_queue_size,
			"new_batch_size": _processing_batch_size,
			"current_queue_size": _queue.size()
		},
		[Log.TAG_FIREBASE]
	)
