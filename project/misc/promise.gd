# File: project/misc/promise.gd
class_name Promise
extends RefCounted

## A lightweight Promise implementation for GDScript with timeout support.
## Provides mechanisms for asynchronous operations with proper error handling.

signal fulfilled(result: Variant) ## Emitted deferred when fulfilled.
signal rejected(reason: Variant) ## Emitted deferred when rejected.
signal timed_out() ## Emitted deferred on timeout.

# --- States ---
enum State { PENDING, FULFILLED, REJECTED }

# --- Debug Configuration ---
# Set true globally or via ProjectSettings/override to debug promises
static var enable_debug_logging: bool = ProjectSettings.get_setting("debug/promise_logging", false)

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
		# Ensure timer is added to the scene tree to function correctly
		_timeout_timer = Timer.new()
		_timeout_timer.name = "PromiseTimer_%d" % get_instance_id() # Unique name helps debugging
		var root : Window = Engine.get_main_loop().root
		if not root:
			push_error("Promise: Cannot add timer, root node not available yet.")
			_timeout_timer = null # Mark timer as unusable
			return
		root.add_child(_timeout_timer) # Add timer to the scene tree

		_timeout_timer.wait_time = timeout_seconds
		_timeout_timer.one_shot = true
		# Use CONNECT_DEFERRED to ensure timeout signal is processed in main thread loop
		_timeout_timer.timeout.connect(_on_timeout, CONNECT_DEFERRED)
		_timeout_timer.start()

		if enable_debug_logging and ClassDB.class_exists("Log"): # Check if Log exists
			Log.debug("Promise created with timeout.", {
				"timeout_sec": timeout_seconds,
				"instance_id": get_instance_id()
			}, ["async", "promise"])


# --- Public Methods ---

## Resolves the promise with the given result.
## Returns true if the promise was successfully resolved (was pending), false otherwise.
func resolve(result: Variant) -> bool:
	if _is_settled:
		if enable_debug_logging and ClassDB.class_exists("Log"):
			Log.warning("Promise already settled, ignoring resolve.", {
				"instance_id": get_instance_id(),
				"current_state": State.keys()[state]
			}, ["async", "promise"])
		return false

	value = result
	state = State.FULFILLED
	_is_settled = true
	_cleanup_timer() # Stop timeout timer if running
	emit_signal.call_deferred("fulfilled", result) # Emit deferred

	if enable_debug_logging and ClassDB.class_exists("Log"):
		var elapsed: float = Time.get_unix_time_from_system() - _creation_time
		Log.debug("Promise resolved.", {
			"instance_id": get_instance_id(),
			"elapsed_ms": int(elapsed * 1000)
		}, ["async", "promise"])
	return true

## Rejects the promise with the given reason.
## Returns true if the promise was successfully rejected (was pending), false otherwise.
func reject(reason: Variant) -> bool:
	if _is_settled:
		if enable_debug_logging and ClassDB.class_exists("Log"):
			Log.warning("Promise already settled, ignoring reject.", {
				"instance_id": get_instance_id(),
				"current_state": State.keys()[state]
			}, ["async", "promise"])
		return false

	rejection_reason = reason
	state = State.REJECTED
	_is_settled = true
	_cleanup_timer() # Stop timeout timer if running
	emit_signal.call_deferred("rejected", reason) # Emit deferred

	if enable_debug_logging and ClassDB.class_exists("Log"):
		var elapsed: float = Time.get_unix_time_from_system() - _creation_time
		Log.debug("Promise rejected.", {
			"instance_id": get_instance_id(),
			"elapsed_ms": int(elapsed * 1000),
			"reason": reason
		}, ["async", "promise", "error"]) # Add error tag
	return true


# --- Timeout Handling ---
func _on_timeout() -> void:
	# Check if already settled *before* modifying state
	if not _is_settled:
		if enable_debug_logging and ClassDB.class_exists("Log"):
			Log.warning("Promise timed out.", {
				"instance_id": get_instance_id(),
				"timeout_sec": timeout_seconds
			}, ["async", "promise", "error", "timeout"])

		state = State.REJECTED
		rejection_reason = { "code": "TIMEOUT", "message": "Operation timed out after %s seconds" % timeout_seconds }
		_is_settled = true

		# Emit signals deferred
		emit_signal.call_deferred("timed_out")
		emit_signal.call_deferred("rejected", rejection_reason)

	# Cleanup timer regardless of whether timeout occurred or was preempted by resolve/reject
	_cleanup_timer() # This is safe to call even if timer is already null/freed

## Safely cleans up the internal timer node.
func _cleanup_timer() -> void:
	if _timeout_timer != null:
		# Check if node is valid and still in the tree before queueing free
		if is_instance_valid(_timeout_timer) and _timeout_timer.is_inside_tree():
			_timeout_timer.stop()
			_timeout_timer.queue_free()
		_timeout_timer = null # Clear reference


# --- Static Helper Methods ---

## Creates a new Promise that is already resolved.
static func resolved(value_to_resolve: Variant = null) -> Promise:
	var promise : Promise = Promise.new()
	# Call resolve deferred to ensure signals are emitted after setup
	promise.resolve.call_deferred(value_to_resolve)
	return promise

## Creates a new Promise that is already rejected.
static func is_rejected(reason: Variant) -> Promise:
	var promise : Promise =  Promise.new()
	# Call reject deferred
	promise.reject.call_deferred(reason)
	return promise

## Creates a Promise that resolves after a specified delay.
#static func delay(seconds: float) -> Promise:
	#var promise := Promise.new()
	#var timer := Timer.new()
	#timer.name = "PromiseDelayTimer_%f" % randf() # Unique-ish name
	#Engine.get_main_loop().root.add_child(timer) # Add to scene tree
	#timer.wait_time = seconds
	#timer.one_shot = true
	#timer.timeout.connect(func():
		#promise.resolve()
		#timer.queue_free() # Clean up the timer
		#)
	#timer.start()
	#return promise

## Returns a Promise that fulfills when all Promises in the input array fulfill,
## or rejects when any Promise in the array rejects.
static func all(promises: Array[Promise], timeout_sec: float = 0.0) -> Promise:
	var all_promise : Promise = Promise.new(timeout_sec) # Apply timeout to the 'all' promise itself
	if promises.is_empty():
		all_promise.resolve.call_deferred([]) # Resolve immediately with empty array
		return all_promise

	var results: Array = []
	results.resize(promises.size()) # Pre-allocate array for results
	var remaining: int = promises.size()

	for i : int in range(promises.size()):
		var p: Promise = promises[i]
		if not p is Promise: # Basic type check
			all_promise.reject("Input array contains non-Promise element at index %d" % i)
			return all_promise # Early exit on invalid input

		# Use CONNECT_DEFERRED for safety
		p.fulfilled.connect(func(result : Variant)->void:
			if all_promise.state != Promise.State.PENDING: return # Already rejected/timed out
			results[i] = result
			remaining -= 1
			if remaining == 0:
				all_promise.resolve(results)
			, CONNECT_DEFERRED)

		p.rejected.connect(func(reason):
			if all_promise.state != Promise.State.PENDING: return # Already rejected/timed out
			all_promise.reject({ "reason": reason, "index": i }) # Reject 'all' if any rejects
			, CONNECT_DEFERRED)

		# Optional: Handle individual promise timeouts if needed, though the
		# main 'all_promise' timeout might be sufficient.
		# p.timed_out.connect(...)

	return all_promise

## Returns a Promise that fulfills or rejects as soon as one of the Promises
## in the input array fulfills or rejects.
static func race(promises: Array[Promise], timeout_sec: float = 0.0) -> Promise:
	var race_promise := Promise.new(timeout_sec) # Apply timeout to the 'race' promise
	if promises.is_empty():
		# Standard behavior is a promise that never settles, but resolving might be more practical
		race_promise.resolve.call_deferred(null) # Or keep pending indefinitely?
		return race_promise

	for p: Promise in promises:
		if not p is Promise:
			race_promise.reject("Input array contains non-Promise element")
			return race_promise

		# Use CONNECT_DEFERRED
		p.fulfilled.connect(func(result):
			if race_promise.state == Promise.State.PENDING:
				race_promise.resolve(result)
			, CONNECT_DEFERRED)

		p.rejected.connect(func(reason):
			if race_promise.state == Promise.State.PENDING:
				race_promise.reject(reason)
			, CONNECT_DEFERRED)

		# p.timed_out.connect(...) # Optional: Handle individual timeouts

	return race_promise
