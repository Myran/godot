class_name Promise
extends RefCounted

## A lightweight Promise implementation for GDScript with timeout support.
## Provides mechanisms for asynchronous operations with proper error handling.
##
## WARNING: This version adopts a "fail-fast" approach. Methods like 'all',
## 'any', and 'then' chaining expect valid Promise objects. Providing other
## types (including null or non-Promise values in arrays) will likely result
## in immediate runtime errors (crashes) instead of attempting tolerant behavior.

signal fulfilled(result: Variant) ## Emitted deferred when fulfilled.
signal rejected(reason: Variant) ## Emitted deferred when rejected.
signal timed_out() ## Emitted deferred on timeout.

# --- Constants ---
const FLAG_ONE_SHOT: int = 4 # Integer value for Object.CONNECT_ONE_SHOT

# --- States ---
enum State { PENDING, FULFILLED, REJECTED }

# --- Debug Configuration ---
static var enable_debug_logging: bool = false

# --- Instance Properties ---
var state: State = State.PENDING
var value: Variant = null
var rejection_reason: Variant = null
var timeout_seconds: float = 0.0
var _creation_time: float = 0.0
var _timeout_timer: Timer = null
var _is_settled: bool = false


# --- Constructor ---
func _init(timeout_sec: float = 0.0) -> void:
	timeout_seconds = timeout_sec
	_creation_time = Time.get_unix_time_from_system()

	if timeout_seconds > 0:
		_timeout_timer = Timer.new()
		_timeout_timer.name = "PromiseTimer_%d" % get_instance_id()
		Engine.get_main_loop().root.add_child(_timeout_timer)
		_timeout_timer.wait_time = timeout_seconds
		_timeout_timer.one_shot = true
		_timeout_timer.timeout.connect(_on_timeout)
		_timeout_timer.start()
		if enable_debug_logging:
			Log.debug("Promise created with timeout.", {
				"timeout_sec": timeout_seconds,
				"instance_id": get_instance_id()
			}, ["async", "promise"])


# --- Public Methods ---
func resolve(result: Variant) -> bool:
	if _is_settled:
		if enable_debug_logging:
			Log.warning("Promise already settled, ignoring resolve.", {
				"instance_id": get_instance_id(),
				"current_state": State.keys()[state]
			}, ["async", "promise"])
		return false

	value = result
	state = State.FULFILLED
	_is_settled = true
	_cleanup_timer()
	emit_signal.call_deferred("fulfilled", result)

	if enable_debug_logging:
		var elapsed: float = Time.get_unix_time_from_system() - _creation_time
		Log.debug("Promise resolved.", {
			"instance_id": get_instance_id(),
			"elapsed_ms": int(elapsed * 1000)
		}, ["async", "promise"])
	return true


func reject(reason: Variant) -> bool:
	if _is_settled:
		if enable_debug_logging:
			Log.warning("Promise already settled, ignoring reject.", {
				"instance_id": get_instance_id(),
				"current_state": State.keys()[state]
			}, ["async", "promise"])
		return false

	rejection_reason = reason
	state = State.REJECTED
	_is_settled = true
	_cleanup_timer()
	emit_signal.call_deferred("rejected", reason)

	if enable_debug_logging:
		var elapsed: float = Time.get_unix_time_from_system() - _creation_time
		Log.debug("Promise rejected.", {
			"instance_id": get_instance_id(),
			"elapsed_ms": int(elapsed * 1000),
			"reason": reason
		}, ["async", "promise"])
	return true


## Registers callbacks to be called when the Promise is settled.
func then(on_fulfilled: Callable, on_rejected: Callable = Callable()) -> Promise:
	var next_promise: Promise = Promise.new()

	if state == State.FULFILLED:
		_handle_callback.call_deferred(on_fulfilled, value, next_promise)
		return next_promise
	elif state == State.REJECTED:
		if on_rejected.is_valid():
			_handle_callback.call_deferred(on_rejected, rejection_reason, next_promise)
		else:
			next_promise.reject.call_deferred(rejection_reason)
		return next_promise

	var _fulfill_conn: Error = self.fulfilled.connect(func(fulfill_value: Variant) -> void:
		_handle_callback.call_deferred(on_fulfilled, fulfill_value, next_promise)
	, Object.CONNECT_ONE_SHOT) # Use built-in enum

	if on_rejected.is_valid():
		var _reject_conn: Error = self.rejected.connect(func(reason: Variant) -> void:
			_handle_callback.call_deferred(on_rejected, reason, next_promise)
		, Object.CONNECT_ONE_SHOT)
	else:
		var _propagate_conn: Error = self.rejected.connect(func(reason: Variant) -> void:
			next_promise.reject.call_deferred(reason)
		, Object.CONNECT_ONE_SHOT)

	if _timeout_timer != null:
		var _timeout_conn: Error = self.timed_out.connect(func() -> void:
			next_promise.reject.call_deferred({
				"code": "TIMEOUT",
				"message": "Source promise timed out after %s seconds" % timeout_seconds
			})
		, Object.CONNECT_ONE_SHOT)

	return next_promise


## Registers a callback to be called when the Promise is rejected.
func catch(on_rejected: Callable) -> Promise:
	return then(func(passthrough_value: Variant) -> Variant: return passthrough_value, on_rejected)


## Resolves when all Promises are fulfilled, rejects on first rejection.
static func all(promises: Array) -> Promise:
	var result_promise: Promise = Promise.new()
	var total_count: int = promises.size()

	if total_count == 0:
		result_promise.resolve([])
		return result_promise

	var state_data: Dictionary = {
		"results": [],
		"pending_count": total_count,
		"has_rejected": false
	}
	state_data.results.resize(total_count)

	for i: int in range(total_count):
		var item: Promise = promises[i]
		var captured_index: int = i

		item.fulfilled.connect(func(fulfill_value: Variant) -> void:
			if state_data.has_rejected: return
			state_data.results[captured_index] = fulfill_value
			state_data.pending_count -= 1
			if state_data.pending_count == 0:
				# Use explicit .call() syntax
				result_promise.resolve.call(state_data.results)
		, Object.CONNECT_ONE_SHOT)

		item.rejected.connect(func(reason: Variant) -> void:
			if state_data.has_rejected: return
			state_data.has_rejected = true
			# Use explicit .call() syntax
			result_promise.reject.call(reason)
		, Object.CONNECT_ONE_SHOT)

		if item.state == State.FULFILLED:
			if not state_data.has_rejected:
				state_data.results[captured_index] = item.value
				state_data.pending_count -= 1
		elif item.state == State.REJECTED:
			if not state_data.has_rejected:
				state_data.has_rejected = true
				result_promise.reject.call_deferred(item.rejection_reason)

	if not state_data.has_rejected and state_data.pending_count == 0:
		# Use explicit .call() syntax
		result_promise.resolve.call(state_data.results)

	return result_promise


## Resolves on first fulfillment, rejects if all reject.
static func any(promises: Array) -> Promise:
	var result_promise: Promise = Promise.new()
	var total_count: int = promises.size()

	if total_count == 0:
		result_promise.reject({ "code": "EMPTY_ARRAY", "message": "Promise.any called with empty array" })
		return result_promise

	var state_data: Dictionary = {
		"rejection_reasons": [],
		"rejection_count": 0,
		"has_fulfilled": false
	}
	state_data.rejection_reasons.resize(total_count)

	for i: int in range(total_count):
		var item: Promise = promises[i]
		var captured_index: int = i

		item.fulfilled.connect(func(fulfill_value: Variant) -> void:
			if state_data.has_fulfilled: return
			if result_promise.state == State.PENDING:
				state_data.has_fulfilled = true
				# Use explicit .call() syntax - This was the error line
				result_promise.resolve.call(fulfill_value)
		, Object.CONNECT_ONE_SHOT)

		item.rejected.connect(func(reason: Variant) -> void:
			if state_data.has_fulfilled: return
			if result_promise.state == State.PENDING:
				if state_data.rejection_reasons[captured_index] == null:
					state_data.rejection_reasons[captured_index] = reason
					state_data.rejection_count += 1
					if state_data.rejection_count == total_count:
						# Use explicit .call() syntax
						result_promise.reject.call({
							"code": "ALL_REJECTED",
							"message": "All Promises were rejected in Promise.any",
							"reasons": state_data.rejection_reasons
						})
		, Object.CONNECT_ONE_SHOT)

		if item.state == State.FULFILLED:
			if not state_data.has_fulfilled and result_promise.state == State.PENDING:
				state_data.has_fulfilled = true
				result_promise.resolve.call_deferred(item.value)
		elif item.state == State.REJECTED:
			if not state_data.has_fulfilled and result_promise.state == State.PENDING:
				if state_data.rejection_reasons[captured_index] == null:
					state_data.rejection_reasons[captured_index] = item.rejection_reason
					state_data.rejection_count += 1

	if not state_data.has_fulfilled and state_data.rejection_count == total_count and result_promise.state == State.PENDING:
		# Use explicit .call() syntax
		result_promise.reject.call({
			"code": "ALL_REJECTED",
			"message": "All Promises were rejected in Promise.any (initial check)",
			"reasons": state_data.rejection_reasons
		})

	return result_promise

# --- Private Methods ---

## Internal: Handles callback execution and chaining for `then`.
func _handle_callback(callback: Callable, arg: Variant, next_promise: Promise) -> void:
	if next_promise.state != State.PENDING: return

	if not callback.is_valid():
		# Use explicit .call() syntax
		next_promise.resolve.call(arg)
		return

	var result: Variant = callback.call(arg)

	if next_promise.state != State.PENDING: return

	# Strict Chaining: Assume 'result' is a Promise, will crash if not.
	result.fulfilled.connect(func(fulfill_value: Variant) -> void:
		# Use explicit .call() syntax
		next_promise.resolve.call(fulfill_value)
	, Object.CONNECT_ONE_SHOT)

	result.rejected.connect(func(reason: Variant) -> void:
		# Use explicit .call() syntax
		next_promise.reject.call(reason)
	, Object.CONNECT_ONE_SHOT)

	if result.state == State.FULFILLED:
		# Use explicit .call() syntax
		next_promise.resolve.call(result.value)
	elif result.state == State.REJECTED:
		# Use explicit .call() syntax
		next_promise.reject.call(result.rejection_reason)


# --- Static Helper Methods ---
# (delay, resolved, new_rejected unchanged)
static func delay(delay_sec: float, value_to_resolve: Variant = null) -> Promise:
	var promise: Promise = Promise.new()
	var timer: Timer = Timer.new()
	timer.name = "PromiseDelayTimer_%d" % promise.get_instance_id()
	Engine.get_main_loop().root.add_child(timer)
	timer.wait_time = delay_sec
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		promise.resolve.call(value_to_resolve) # Use .call() here too for consistency
		timer.queue_free()
	)
	timer.start()
	promise.fulfilled.connect(timer.queue_free)
	promise.rejected.connect(timer.queue_free)
	return promise

static func resolved(value_to_resolve: Variant = null) -> Promise:
	var promise: Promise = Promise.new()
	promise.resolve.call_deferred(value_to_resolve)
	return promise

static func new_rejected(reason: Variant) -> Promise:
	var promise: Promise = Promise.new()
	promise.reject.call_deferred(reason)
	return promise

# --- Timeout Handling ---
# (_on_timeout, _cleanup_timer unchanged)
func _on_timeout() -> void:
	if not _is_settled:
		if enable_debug_logging:
			Log.warning("Promise timed out.", {
				"instance_id": get_instance_id(),
				"timeout_sec": timeout_seconds
			}, ["async", "promise", "error", "timeout"])
		state = State.REJECTED
		rejection_reason = { "code": "TIMEOUT", "message": "Operation timed out after %s seconds" % timeout_seconds }
		_is_settled = true
		emit_signal.call_deferred("timed_out")
		emit_signal.call_deferred("rejected", rejection_reason)
	_cleanup_timer()

func _cleanup_timer() -> void:
	if _timeout_timer != null and is_instance_valid(_timeout_timer):
		_timeout_timer.stop()
		_timeout_timer.queue_free()
	_timeout_timer = null
