class_name ReplayStateValidator
extends RefCounted

# Replay state validation for ensuring consistency between original and replayed game states
# Provides comprehensive comparison and validation functionality

# Performance tracking for regression detection
static var _performance_metrics: Dictionary = {
	"comparison_times": [],
	"validation_times": [],
	"last_comparison_ms": 0.0,
	"last_validation_ms": 0.0,
	"total_comparisons": 0,
	"total_validations": 0
}

# Cross-platform validation settings
static var _cross_platform_config: Dictionary = {
	"normalize_platform_data": true,
	"ignore_timestamp_differences": true,
	"ignore_floating_point_precision": true,
	"platform_specific_tolerance": 0.001
}


## Compare two game states and return detailed comparison results
static func compare_states(
	state1: Dictionary, state2: Dictionary, options: Dictionary = {}
) -> Dictionary:
	"""Compare two game states with detailed analysis and platform normalization"""
	var start_time: int = Time.get_ticks_msec()

	var comparison_result: Dictionary = {
		"states_identical": false,
		"checksums_match": false,
		"differences": [],
		"comparison_type": "detailed",
		"platform_normalized": false,
		"timestamp_ms": Time.get_unix_time_from_system() * 1000.0
	}

	# Normalize states for cross-platform comparison if enabled
	var normalized_state1: Dictionary = state1
	var normalized_state2: Dictionary = state2

	if _cross_platform_config.normalize_platform_data:
		normalized_state1 = _normalize_platform_data(state1)
		normalized_state2 = _normalize_platform_data(state2)
		comparison_result.platform_normalized = true

	# Generate checksums for quick comparison
	var checksum1: String = StateExtractor.generate_checksum(normalized_state1)
	var checksum2: String = StateExtractor.generate_checksum(normalized_state2)

	comparison_result.checksums_match = checksum1 == checksum2
	comparison_result.states_identical = comparison_result.checksums_match

	# If checksums don't match, perform detailed diff analysis
	if not comparison_result.checksums_match:
		comparison_result.differences = _perform_detailed_diff(
			normalized_state1, normalized_state2, options
		)

	# Record performance metrics
	var comparison_time: float = Time.get_ticks_msec() - start_time
	_performance_metrics.comparison_times.append(comparison_time)
	_performance_metrics.last_comparison_ms = comparison_time
	_performance_metrics.total_comparisons += 1

	# Keep only last 100 measurements for memory efficiency
	if _performance_metrics.comparison_times.size() > 100:
		_performance_metrics.comparison_times = _performance_metrics.comparison_times.slice(-100)

	Log.debug(
		"State comparison completed",
		{
			"checksums_match": comparison_result.checksums_match,
			"differences_found": comparison_result.differences.size(),
			"comparison_time_ms": comparison_time,
			"platform_normalized": comparison_result.platform_normalized
		},
		["replay", "validation", "comparison"]
	)

	return comparison_result


## Validate replay state consistency for a complete session
static func validate_replay_state(
	session_id: String, expected_states: Array[Dictionary], options: Dictionary = {}
) -> Dictionary:
	"""Validate replay state consistency against expected states"""
	var start_time: int = Time.get_ticks_msec()

	var validation_result: Dictionary = {
		"validation_success": false,
		"total_states": expected_states.size(),
		"matched_states": 0,
		"mismatched_states": 0,
		"missing_states": 0,
		"state_comparisons": [],
		"overall_consistency": 0.0,
		"session_id": session_id,
		"timestamp_ms": Time.get_unix_time_from_system() * 1000.0,
		"post_action_states_verified": false,
		"post_action_states_available": 0
	}

	# CRITICAL: Verify post-action states are actually available
	var post_action_states_count: int = _verify_post_action_states_exist(
		session_id, expected_states.size()
	)
	validation_result.post_action_states_available = post_action_states_count
	validation_result.post_action_states_verified = post_action_states_count > 0

	if post_action_states_count == 0:
		Log.error(
			"CRITICAL: No post-action states found for validation",
			{
				"session_id": session_id,
				"expected_states": expected_states.size(),
				"validation_impossible": true,
				"likely_cause": "Post-action capture not working or delayed"
			},
			["replay", "validation", "critical_error"]
		)
		validation_result.validation_success = false
		return validation_result

	if post_action_states_count < expected_states.size():
		Log.warning(
			"Partial post-action states available for validation",
			{
				"session_id": session_id,
				"expected_states": expected_states.size(),
				"available_states": post_action_states_count,
				"missing_count": expected_states.size() - post_action_states_count
			},
			["replay", "validation", "partial_states"]
		)

	# Validate each expected state against stored post-action states
	for i in range(expected_states.size()):
		var expected_state: Dictionary = expected_states[i]
		var sequence: int = i + 1

		# Get stored post-action state for this sequence
		var stored_state: Dictionary = SessionManager.get_post_action_state(session_id, sequence)

		if stored_state.is_empty():
			validation_result.missing_states += 1
			validation_result.state_comparisons.append(
				{
					"sequence": sequence,
					"status": "missing",
					"error": "No stored post-action state found"
				}
			)
			continue

		# Compare expected vs stored state
		var state_comparison: Dictionary = compare_states(
			expected_state, stored_state.get("state_data", {}), options
		)

		state_comparison["sequence"] = sequence

		if state_comparison.states_identical:
			validation_result.matched_states += 1
			state_comparison["status"] = "match"
		else:
			validation_result.mismatched_states += 1
			state_comparison["status"] = "mismatch"

		validation_result.state_comparisons.append(state_comparison)

	# Calculate overall consistency percentage
	var total_validated: int = (
		validation_result.matched_states + validation_result.mismatched_states
	)
	if total_validated > 0:
		validation_result.overall_consistency = (
			float(validation_result.matched_states) / float(total_validated)
		)

	# Determine validation success with fallback strategies
	var success_threshold: float = options.get("success_threshold", 0.95)

	# Apply fallback validation if partial state availability
	if validation_result.post_action_states_available < validation_result.total_states:
		# Use more lenient threshold for partial state validation
		var partial_threshold: float = options.get("partial_success_threshold", 0.80)
		var state_availability_ratio: float = (
			float(validation_result.post_action_states_available)
			/ float(validation_result.total_states)
		)

		# Only consider validation successful if we have reasonable state coverage
		if state_availability_ratio >= 0.5:  # At least 50% of states available
			validation_result.validation_success = (
				validation_result.overall_consistency >= partial_threshold
			)

			Log.info(
				"Applied fallback validation strategy",
				{
					"session_id": session_id,
					"state_availability_ratio": state_availability_ratio,
					"applied_threshold": partial_threshold,
					"validation_success": validation_result.validation_success
				},
				["replay", "validation", "fallback"]
			)
		else:
			validation_result.validation_success = false
			Log.warning(
				"Insufficient state availability for reliable validation",
				{
					"session_id": session_id,
					"state_availability_ratio": state_availability_ratio,
					"minimum_required": 0.5
				},
				["replay", "validation", "insufficient_states"]
			)
	else:
		# Standard validation with full state availability
		validation_result.validation_success = (
			validation_result.overall_consistency >= success_threshold
		)

	# Record performance metrics
	var validation_time: float = Time.get_ticks_msec() - start_time
	_performance_metrics.validation_times.append(validation_time)
	_performance_metrics.last_validation_ms = validation_time
	_performance_metrics.total_validations += 1

	# Keep only last 100 measurements for memory efficiency
	if _performance_metrics.validation_times.size() > 100:
		_performance_metrics.validation_times = _performance_metrics.validation_times.slice(-100)

	Log.info(
		"Replay state validation completed",
		{
			"session_id": session_id,
			"validation_success": validation_result.validation_success,
			"overall_consistency": validation_result.overall_consistency,
			"matched_states": validation_result.matched_states,
			"total_states": validation_result.total_states,
			"validation_time_ms": validation_time
		},
		["replay", "validation", "complete"]
	)

	return validation_result


## Cross-platform validation with platform-specific handling
static func validate_cross_platform(
	states_by_platform: Dictionary, options: Dictionary = {}
) -> Dictionary:
	"""Validate state consistency across different platforms"""
	var validation_result: Dictionary = {
		"cross_platform_consistent": false,
		"platform_count": states_by_platform.size(),
		"platform_comparisons": [],
		"inconsistent_platforms": [],
		"consistency_score": 0.0
	}

	if states_by_platform.size() < 2:
		validation_result.cross_platform_consistent = true
		validation_result.consistency_score = 1.0
		return validation_result

	var platform_names: Array = states_by_platform.keys()
	var reference_platform: String = platform_names[0]
	var reference_states: Array = states_by_platform[reference_platform]

	var successful_comparisons: int = 0
	var total_comparisons: int = 0

	# Compare each platform against the reference platform
	for i in range(1, platform_names.size()):
		var platform_name: String = platform_names[i]
		var platform_states: Array = states_by_platform[platform_name]

		var platform_comparison: Dictionary = validate_replay_state(
			"cross_platform_validation", platform_states, options
		)

		platform_comparison["platform"] = platform_name
		platform_comparison["reference_platform"] = reference_platform

		validation_result.platform_comparisons.append(platform_comparison)

		if platform_comparison.validation_success:
			successful_comparisons += 1
		else:
			validation_result.inconsistent_platforms.append(platform_name)

		total_comparisons += 1

	# Calculate cross-platform consistency score
	if total_comparisons > 0:
		validation_result.consistency_score = (
			float(successful_comparisons) / float(total_comparisons)
		)

	validation_result.cross_platform_consistent = validation_result.consistency_score >= 0.95

	Log.info(
		"Cross-platform validation completed",
		{
			"cross_platform_consistent": validation_result.cross_platform_consistent,
			"consistency_score": validation_result.consistency_score,
			"platform_count": validation_result.platform_count,
			"inconsistent_platforms": validation_result.inconsistent_platforms
		},
		["replay", "validation", "cross_platform"]
	)

	return validation_result


## Get performance metrics for regression detection
static func get_performance_metrics() -> Dictionary:
	"""Get current performance metrics for monitoring and regression detection"""
	var metrics: Dictionary = _performance_metrics.duplicate()

	# Calculate average times
	if metrics.comparison_times.size() > 0:
		var total_comparison_time: float = 0.0
		for time: float in metrics.comparison_times:
			total_comparison_time += time
		metrics["avg_comparison_ms"] = total_comparison_time / metrics.comparison_times.size()
	else:
		metrics["avg_comparison_ms"] = 0.0

	if metrics.validation_times.size() > 0:
		var total_validation_time: float = 0.0
		for time: float in metrics.validation_times:
			total_validation_time += time
		metrics["avg_validation_ms"] = total_validation_time / metrics.validation_times.size()
	else:
		metrics["avg_validation_ms"] = 0.0

	return metrics


## Reset performance metrics (useful for testing)
static func reset_performance_metrics() -> void:
	"""Reset all performance metrics to clean state"""
	_performance_metrics = {
		"comparison_times": [],
		"validation_times": [],
		"last_comparison_ms": 0.0,
		"last_validation_ms": 0.0,
		"total_comparisons": 0,
		"total_validations": 0
	}


## Configure cross-platform validation settings
static func configure_cross_platform_validation(config: Dictionary) -> void:
	"""Configure cross-platform validation behavior"""
	for key: String in config.keys():
		if _cross_platform_config.has(key):
			_cross_platform_config[key] = config[key]


# PRIVATE HELPER METHODS


## Verify that post-action states exist for validation
static func _verify_post_action_states_exist(session_id: String, expected_count: int) -> int:
	"""Verify how many post-action states are available for the session"""
	var available_count: int = 0

	# Check each sequence number for post-action state availability
	for sequence in range(1, expected_count + 1):
		var post_action_state: Dictionary = SessionManager.get_post_action_state(
			session_id, sequence
		)
		if not post_action_state.is_empty() and post_action_state.has("state_data"):
			available_count += 1
		else:
			Log.debug(
				"Missing post-action state for sequence",
				{
					"session_id": session_id,
					"sequence": sequence,
					"state_empty": post_action_state.is_empty(),
					"has_state_data": post_action_state.has("state_data")
				},
				["replay", "validation", "missing_state"]
			)

	Log.info(
		"Post-action state verification completed",
		{
			"session_id": session_id,
			"expected_count": expected_count,
			"available_count": available_count,
			"availability_percentage":
			(float(available_count) / float(expected_count)) * 100.0 if expected_count > 0 else 0.0
		},
		["replay", "validation", "state_verification"]
	)

	return available_count


static func _normalize_platform_data(state: Dictionary) -> Dictionary:
	"""Normalize platform-specific data for consistent comparison"""
	var normalized: Dictionary = state.duplicate(true)

	# Remove or normalize platform-specific fields
	if normalized.has("platform_info"):
		var platform_info: Dictionary = normalized.platform_info

		# Keep only essential platform-independent data
		var essential_platform_data: Dictionary = {
			"screen_size_category": platform_info.get("screen_size_category", "unknown"),
			"input_method": platform_info.get("input_method", "unknown")
		}

		normalized.platform_info = essential_platform_data

	# Normalize floating-point precision issues
	if _cross_platform_config.ignore_floating_point_precision:
		_normalize_floating_point_values(normalized)

	# Remove timestamp fields if configured
	if _cross_platform_config.ignore_timestamp_differences:
		_remove_timestamp_fields(normalized)

	return normalized


static func _normalize_floating_point_values(data: Dictionary) -> void:
	"""Recursively normalize floating-point values to avoid precision issues"""
	for key: String in data.keys():
		var value: Variant = data[key]

		if value is float:
			# Round to 3 decimal places to avoid precision differences
			data[key] = round(value * 1000.0) / 1000.0
		elif value is Dictionary:
			_normalize_floating_point_values(value)
		elif value is Array:
			for i in range(value.size()):
				if value[i] is float:
					value[i] = round(value[i] * 1000.0) / 1000.0
				elif value[i] is Dictionary:
					_normalize_floating_point_values(value[i])


static func _remove_timestamp_fields(data: Dictionary) -> void:
	"""Recursively remove timestamp fields that vary between platforms"""
	var timestamp_fields: Array[String] = [
		"timestamp", "timestamp_ms", "created_at", "updated_at", "frame_time"
	]

	for field: String in timestamp_fields:
		if data.has(field):
			data.erase(field)

	# Recursively process nested dictionaries
	for key: String in data.keys():
		var value: Variant = data[key]
		if value is Dictionary:
			_remove_timestamp_fields(value)
		elif value is Array:
			for item: Variant in value:
				if item is Dictionary:
					_remove_timestamp_fields(item)


static func _perform_detailed_diff(
	state1: Dictionary, state2: Dictionary, options: Dictionary
) -> Array[Dictionary]:
	"""Perform detailed difference analysis between two states"""
	var differences: Array[Dictionary] = []

	# Check for keys present in state1 but missing in state2
	for key: String in state1.keys():
		if not state2.has(key):
			differences.append(
				{
					"type": "missing_key",
					"key": key,
					"expected_value": state1[key],
					"actual_value": null
				}
			)

	# Check for keys present in state2 but missing in state1
	for key: String in state2.keys():
		if not state1.has(key):
			differences.append(
				{
					"type": "extra_key",
					"key": key,
					"expected_value": null,
					"actual_value": state2[key]
				}
			)

	# Check for value differences in common keys
	for key: String in state1.keys():
		if state2.has(key):
			var value1: Variant = state1[key]
			var value2: Variant = state2[key]

			if not _values_equal(value1, value2, options):
				differences.append(
					{
						"type": "value_difference",
						"key": key,
						"expected_value": value1,
						"actual_value": value2
					}
				)

	return differences


static func _values_equal(value1: Variant, value2: Variant, options: Dictionary) -> bool:
	"""Deep comparison of two values with tolerance for floating-point differences"""
	if typeof(value1) != typeof(value2):
		return false

	if value1 is float and value2 is float:
		var tolerance: float = options.get(
			"float_tolerance", _cross_platform_config.platform_specific_tolerance
		)
		return abs(value1 - value2) <= tolerance

	if value1 is Dictionary and value2 is Dictionary:
		return _dictionaries_equal(value1, value2, options)

	if value1 is Array and value2 is Array:
		return _arrays_equal(value1, value2, options)

	return value1 == value2


static func _dictionaries_equal(dict1: Dictionary, dict2: Dictionary, options: Dictionary) -> bool:
	"""Deep comparison of two dictionaries"""
	if dict1.size() != dict2.size():
		return false

	for key: String in dict1.keys():
		if not dict2.has(key):
			return false

		if not _values_equal(dict1[key], dict2[key], options):
			return false

	return true


static func _arrays_equal(array1: Array, array2: Array, options: Dictionary) -> bool:
	"""Deep comparison of two arrays"""
	if array1.size() != array2.size():
		return false

	for i in range(array1.size()):
		if not _values_equal(array1[i], array2[i], options):
			return false

	return true
