class_name Promise
extends RefCounted
## A lightweight Promise implementation for GDScript with timeout support.
## Provides mechanisms for asynchronous operations with proper error handling.

signal fulfilled(result: Variant) ## Emitted when fulfilled.
signal rejected(reason: Variant) ## Emitted when rejected.
@warning_ignore("unused_signal")
signal timed_out() ## Emitted on timeout.

# --- States ---
enum State { PENDING, FULFILLED, REJECTED }

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
		# Create and configure timer
		_timeout_timer = Timer.new()
		_timeout_timer.name = "PromiseTimer_%d" % get_instance_id()

		# Add timer to the scene tree via deferred call to avoid issues during construction
		call_deferred("_setup_timer")

# --- Timer Setup ---
func _setup_timer() -> void:
	if not _timeout_timer or _is_settled:
		return

	var root: Window = Engine.get_main_loop().root
	if not root:
		push_error("Promise: Cannot add timer, root node not available yet.")
		_timeout_timer.free()
		_timeout_timer = null
		return

	root.add_child(_timeout_timer)
	_timeout_timer.wait_time = timeout_seconds
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_timeout)
	_timeout_timer.start()

# --- Public Methods ---

## Resolves the promise with the given result.
## Returns true if the promise was successfully resolved (was pending), false otherwise.
func resolve(result: Variant = null) -> bool:
	if _is_settled:
		return false

	value = result
	state = State.FULFILLED
	_is_settled = true
	_cleanup_timer()
	call_deferred("emit_signal", "fulfilled", result)
	return true

## Rejects the promise with the given reason.
## Returns true if the promise was successfully rejected (was pending), false otherwise.
func reject(reason: Variant = null) -> bool:
	if _is_settled:
		return false

	rejection_reason = reason
	state = State.REJECTED
	_is_settled = true
	_cleanup_timer()
	call_deferred("emit_signal", "rejected", reason)
	return true

# --- Timeout Handling ---
func _on_timeout() -> void:
	if not _is_settled:
		state = State.REJECTED
		rejection_reason = { "code": "TIMEOUT", "message": "Operation timed out after %s seconds" % timeout_seconds }
		_is_settled = true

		# Emit signals deferred
		call_deferred("emit_signal", "timed_out")
		call_deferred("emit_signal", "rejected", rejection_reason)

	_cleanup_timer()

## Safely cleans up the internal timer node.
func _cleanup_timer() -> void:
	if _timeout_timer != null:
		if is_instance_valid(_timeout_timer):
			# Disconnect any connected signals first
			if _timeout_timer.timeout.is_connected(_on_timeout):
				_timeout_timer.timeout.disconnect(_on_timeout)

			_timeout_timer.stop()

			if _timeout_timer.is_inside_tree():
				_timeout_timer.queue_free()
			else:
				_timeout_timer.free()
		_timeout_timer = null

# --- Cleanup notification ---
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Ensure we can safely access our properties
		if is_instance_valid(self):
			_cleanup_timer()

# --- Static Helper Methods ---

## Creates a new Promise that is already resolved.
static func resolved(value_to_resolve: Variant = null) -> Promise:
	var promise: Promise = Promise.new()
	promise.call_deferred("resolve", value_to_resolve)
	return promise

## Creates a new Promise that is already rejected.
static func create_rejected(reason: Variant = null) -> Promise:
	var promise: Promise = Promise.new()
	promise.call_deferred("reject", reason)
	return promise

## For backward compatibility with older code that uses is_rejected
static func is_rejected(reason: Variant = null) -> Promise:
	return create_rejected(reason)

# Helper class for storing mutable counter in lambdas
class _CounterRef extends RefCounted:
	var count: int = 0

## Returns a Promise that fulfills when all Promises in the input array fulfill,
## or rejects when any Promise in the array rejects.
static func all(promises: Array[Promise], timeout_sec: float = 0.0) -> Promise:
	var all_promise: Promise = Promise.new(timeout_sec)
	if promises.is_empty():
		all_promise.call_deferred("resolve", [])
		return all_promise

	var results: Array[Variant] = []
	results.resize(promises.size())

	var counter: _CounterRef = _CounterRef.new()
	counter.count = promises.size()

	for i: int in range(promises.size()):
		var p: Promise = promises[i]
		if not p is Promise:
			all_promise.reject("Input array contains non-Promise element at index %d" % i)
			return all_promise

		# Define dedicated functions with explicit return types
		var on_fulfilled: Callable = func(result: Variant) -> void:
			if all_promise.state != State.PENDING:
				return
			results[i] = result
			counter.count -= 1
			if counter.count == 0:
				all_promise.resolve(results)

		var on_rejected: Callable = func(reason: Variant) -> void:
			if all_promise.state != State.PENDING:
				return
			all_promise.reject({ "reason": reason, "index": i })

		# Connect the callbacks with CONNECT_DEFERRED for safety
		p.fulfilled.connect(on_fulfilled, CONNECT_DEFERRED)
		p.rejected.connect(on_rejected, CONNECT_DEFERRED)

	return all_promise

## Returns a Promise that fulfills or rejects as soon as one of the Promises
## in the input array fulfills or rejects.
static func race(promises: Array[Promise], timeout_sec: float = 0.0) -> Promise:
	var race_promise: Promise = Promise.new(timeout_sec)
	if promises.is_empty():
		race_promise.call_deferred("resolve", null)
		return race_promise

	for p: Promise in promises:
		if not p is Promise:
			race_promise.reject("Input array contains non-Promise element")
			return race_promise

		# Define dedicated functions with explicit return types
		var on_fulfilled: Callable = func(result: Variant) -> void:
			if race_promise.state == State.PENDING:
				race_promise.resolve(result)

		var on_rejected: Callable = func(reason: Variant) -> void:
			if race_promise.state == State.PENDING:
				race_promise.reject(reason)

		# Connect the callbacks with CONNECT_DEFERRED for safety
		p.fulfilled.connect(on_fulfilled, CONNECT_DEFERRED)
		p.rejected.connect(on_rejected, CONNECT_DEFERRED)

	return race_promise
