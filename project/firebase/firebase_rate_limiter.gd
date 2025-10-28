class_name FirebaseRateLimiter
extends RefCounted

## Firebase C++ SDK Rate Limiter
## Prevents resource exhaustion and Bus error crashes in Firebase C++ SDK
## Based on analysis of Firebase C++ SDK GitHub issues #268, #356, #737, #1570

signal rate_limit_triggered(reason: String)
signal rate_limit_released

# Rate limiting configuration
const MIN_DELAY_MS: int = 20  # Minimum delay between operations (reduced for better performance)
const MAX_DELAY_MS: int = 1000  # Maximum delay for circuit breaker
const BURST_LIMIT: int = 8  # Max operations before rate limiting kicks in (increased for multi-action tests)
const CIRCUIT_BREAKER_THRESHOLD: int = 5  # Consecutive failures to trigger circuit breaker
const RECOVERY_TIME_MS: int = 5000  # Time to wait before circuit breaker recovery
const MAX_DURATION_SAMPLES: int = 10

# Internal state
var _last_operation_time_ms: int = 0
var _operations_in_burst: int = 0
var _consecutive_failures: int = 0
var _circuit_breaker_active: bool = false
var _circuit_breaker_start_time: int = 0
var _pending_request_count: int = 0
var _total_operations: int = 0

# Performance tracking
var _average_delay_ms: float = MIN_DELAY_MS
var _recent_durations: Array[int] = []


func _init() -> void:
	Log.info(
		"FirebaseRateLimiter initialized",
		{
			"min_delay_ms": MIN_DELAY_MS,
			"max_delay_ms": MAX_DELAY_MS,
			"burst_limit": BURST_LIMIT,
			"circuit_breaker_threshold": CIRCUIT_BREAKER_THRESHOLD
		},
		[Log.TAG_FIREBASE, "rate_limiter"]
	)


## Check if operation should be rate limited and calculate delay
func should_rate_limit() -> Dictionary:
	var current_time: int = Time.get_ticks_msec()
	var time_since_last: int = current_time - _last_operation_time_ms

	# Check circuit breaker
	if _circuit_breaker_active:
		if current_time - _circuit_breaker_start_time > RECOVERY_TIME_MS:
			_reset_circuit_breaker()
		else:
			return {
				"should_limit": true,
				"delay_ms": MAX_DELAY_MS,
				"reason": "circuit_breaker_active",
				"recovery_time_remaining_ms":
				RECOVERY_TIME_MS - (current_time - _circuit_breaker_start_time)
			}

	# Calculate burst window (1 second)
	if time_since_last > 1000:
		_operations_in_burst = 0

	# Determine if rate limiting needed
	var needs_rate_limiting: bool = false
	var delay_ms: int = 0
	var reason: String = ""

	# CRITICAL: Always enforce minimum delay to prevent Firebase C++ SDK signal emission crashes
	# See: task-207 SIGBUS analysis - crash occurs during C++ signal emission if operations too close
	# This MUST be checked first, before burst/pending checks
	if time_since_last < MIN_DELAY_MS:
		needs_rate_limiting = true
		delay_ms = MIN_DELAY_MS - time_since_last
		reason = "min_delay_required_for_cpp_stability"
	elif _operations_in_burst >= BURST_LIMIT:
		needs_rate_limiting = true
		delay_ms = _calculate_adaptive_delay()
		reason = "burst_limit_exceeded"
	elif _pending_request_count > 3:
		needs_rate_limiting = true
		delay_ms = _calculate_adaptive_delay() * 2
		reason = "too_many_pending_requests"

	return {
		"should_limit": needs_rate_limiting,
		"delay_ms": delay_ms,
		"reason": reason,
		"operations_in_burst": _operations_in_burst,
		"pending_requests": _pending_request_count
	}


## Record operation start
func record_operation_start() -> void:
	_last_operation_time_ms = Time.get_ticks_msec()
	_operations_in_burst += 1
	_pending_request_count += 1
	_total_operations += 1

	Log.debug(
		"Firebase operation started",
		{
			"operations_in_burst": _operations_in_burst,
			"pending_requests": _pending_request_count,
			"total_operations": _total_operations
		},
		[Log.TAG_FIREBASE, "rate_limiter"]
	)


## Record operation completion
func record_operation_complete(success: bool, duration_ms: int) -> void:
	_pending_request_count = max(0, _pending_request_count - 1)

	if success:
		_consecutive_failures = 0
		_update_performance_metrics(duration_ms)
	else:
		_consecutive_failures += 1
		if _consecutive_failures >= CIRCUIT_BREAKER_THRESHOLD:
			_activate_circuit_breaker()

	Log.debug(
		"Firebase operation completed",
		{
			"success": success,
			"duration_ms": duration_ms,
			"pending_requests": _pending_request_count,
			"consecutive_failures": _consecutive_failures
		},
		[Log.TAG_FIREBASE, "rate_limiter"]
	)


## Apply rate limiting delay
func apply_rate_limit(delay_ms: int, reason: String) -> void:
	if delay_ms <= 0:
		return

	Log.info(
		"Firebase rate limiting applied",
		{"delay_ms": delay_ms, "reason": reason, "pending_requests": _pending_request_count},
		[Log.TAG_FIREBASE, "rate_limiter"]
	)

	rate_limit_triggered.emit(reason)

	# Use frame-based delay to avoid blocking
	var delay_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - delay_start < delay_ms:
		await Engine.get_main_loop().process_frame


## Calculate adaptive delay based on system performance
func _calculate_adaptive_delay() -> int:
	var base_delay: int = MIN_DELAY_MS

	# Increase delay based on pending requests
	if _pending_request_count > 1:
		base_delay += ((_pending_request_count - 1) * 100)

	# Increase delay based on consecutive failures
	if _consecutive_failures > 0:
		base_delay += _consecutive_failures * 1000

	# Increase delay based on recent performance
	if _average_delay_ms > MIN_DELAY_MS:
		base_delay = int(_average_delay_ms * 1.5)

	return min(base_delay, MAX_DELAY_MS)


## Update performance metrics
func _update_performance_metrics(duration_ms: int) -> void:
	_recent_durations.append(duration_ms)
	if _recent_durations.size() > MAX_DURATION_SAMPLES:
		_recent_durations.pop_front()

	# Calculate average
	var total: int = 0
	for duration: int in _recent_durations:
		total += duration
	_average_delay_ms = float(total) / float(_recent_durations.size())


## Activate circuit breaker
func _activate_circuit_breaker() -> void:
	_circuit_breaker_active = true
	_circuit_breaker_start_time = Time.get_ticks_msec()

	Log.warning(
		"Firebase circuit breaker activated",
		{
			"consecutive_failures": _consecutive_failures,
			"pending_requests": _pending_request_count,
			"recovery_time_ms": RECOVERY_TIME_MS
		},
		[Log.TAG_FIREBASE, "rate_limiter", Log.TAG_ERROR]
	)


## Reset circuit breaker
func _reset_circuit_breaker() -> void:
	_circuit_breaker_active = false
	_consecutive_failures = 0

	Log.info(
		"Firebase circuit breaker reset",
		{"total_operations": _total_operations},
		[Log.TAG_FIREBASE, "rate_limiter"]
	)

	rate_limit_released.emit()


## Get current rate limiter status
func get_status() -> Dictionary:
	return {
		"circuit_breaker_active": _circuit_breaker_active,
		"operations_in_burst": _operations_in_burst,
		"pending_requests": _pending_request_count,
		"consecutive_failures": _consecutive_failures,
		"average_delay_ms": _average_delay_ms,
		"total_operations": _total_operations
	}
