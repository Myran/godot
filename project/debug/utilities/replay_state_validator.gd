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

		# Note: Post-action state capture was removed during checksum validation simplification
		# This validation method is part of the old system and needs to be updated
		var stored_state: Dictionary = {}

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

	# Note: Post-action state capture was removed during checksum validation simplification
	# This method is part of the old system - no post-action states are available
	Log.info(
		"Post-action state verification skipped - simplified system uses checksum logging",
		{
			"session_id": session_id,
			"expected_count": expected_count,
			"note": "Post-action capture removed, using semantic logging checksums"
		},
		["replay", "validation", "simplified_system"]
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


## Validate action states by comparing pre/post action states using checksums
## This is the primary validation method for semantic action consistency
static func validate_action_states(
	pre_action_state: Dictionary, post_action_state: Dictionary, action_type: String = ""
) -> Dictionary:
	"""Validate action states by comparing pre and post action checksums and data"""
	var start_time: int = Time.get_ticks_msec()

	var validation_result: Dictionary = {
		"action_valid": false,
		"checksum_match": false,
		"state_consistent": false,
		"action_type": action_type,
		"differences": [],
		"error_message": "",
		"validation_time_ms": 0.0
	}

	# Validate input states
	if pre_action_state.is_empty() or post_action_state.is_empty():
		validation_result.error_message = "Missing pre-action or post-action state data"
		Log.error(
			"Action state validation failed: missing state data",
			{
				"action_type": action_type,
				"pre_empty": pre_action_state.is_empty(),
				"post_empty": post_action_state.is_empty()
			},
			["replay", "validation", "error"]
		)
		return validation_result

	# Extract checksums for comparison
	var pre_checksum: String = pre_action_state.get("checksum", "")
	var post_checksum: String = post_action_state.get("checksum", "")

	if pre_checksum.is_empty() or post_checksum.is_empty():
		validation_result.error_message = "Missing checksum data in state entries"
		Log.error(
			"Action state validation failed: missing checksums",
			{
				"action_type": action_type,
				"pre_checksum_empty": pre_checksum.is_empty(),
				"post_checksum_empty": post_checksum.is_empty()
			},
			["replay", "validation", "error"]
		)
		return validation_result

	# Compare checksums for quick validation
	validation_result.checksum_match = (pre_checksum == post_checksum)

	# Perform detailed state comparison if checksums differ
	if not validation_result.checksum_match:
		var state_diff: Dictionary = generate_state_diff_report(
			pre_action_state.get("state_data", {}), post_action_state.get("state_data", {})
		)
		validation_result.differences = state_diff.get("differences", [])
		validation_result.state_consistent = state_diff.get("states_similar", false)
	else:
		validation_result.state_consistent = true

	# Determine overall action validity
	validation_result.action_valid = (
		validation_result.checksum_match or validation_result.state_consistent
	)

	# Record performance metrics
	var validation_time: float = Time.get_ticks_msec() - start_time
	validation_result.validation_time_ms = validation_time
	_performance_metrics.comparison_times.append(validation_time)
	_performance_metrics.last_comparison_ms = validation_time
	_performance_metrics.total_comparisons += 1

	Log.debug(
		"Action state validation completed",
		{
			"action_type": action_type,
			"action_valid": validation_result.action_valid,
			"checksum_match": validation_result.checksum_match,
			"state_consistent": validation_result.state_consistent,
			"differences_count": validation_result.differences.size(),
			"validation_time_ms": validation_time
		},
		["replay", "validation", "action_states"]
	)

	return validation_result


## Generate detailed state difference report for mismatch analysis
## Provides comprehensive analysis of state differences for debugging
static func generate_state_diff_report(state1: Dictionary, state2: Dictionary) -> Dictionary:
	"""Generate detailed diff report between two game states"""
	var start_time: int = Time.get_ticks_msec()

	var diff_report: Dictionary = {
		"states_identical": false,
		"states_similar": false,
		"similarity_score": 0.0,
		"differences": [],
		"added_keys": [],
		"removed_keys": [],
		"modified_keys": [],
		"analysis_time_ms": 0.0
	}

	# Normalize states for comparison
	var norm_state1: Dictionary = _normalize_platform_data(state1)
	var norm_state2: Dictionary = _normalize_platform_data(state2)

	# Check for exact match first
	if norm_state1.hash() == norm_state2.hash():
		diff_report.states_identical = true
		diff_report.states_similar = true
		diff_report.similarity_score = 1.0
		Log.debug("States are identical after normalization", {}, ["replay", "validation", "diff"])
		return diff_report

	# Analyze key differences
	var all_keys: Array = []
	for key in norm_state1.keys():
		if key not in all_keys:
			all_keys.append(key)
	for key in norm_state2.keys():
		if key not in all_keys:
			all_keys.append(key)

	var matching_keys: int = 0
	var total_keys: int = all_keys.size()

	for key in all_keys:
		if norm_state1.has(key) and norm_state2.has(key):
			# Both states have this key - check if values match
			if _values_equal(norm_state1[key], norm_state2[key], {}):
				matching_keys += 1
			else:
				diff_report.modified_keys.append(key)
				diff_report.differences.append(
					{
						"key": key,
						"type": "modified",
						"state1_value": norm_state1[key],
						"state2_value": norm_state2[key]
					}
				)
		elif norm_state1.has(key):
			# Key only in state1
			diff_report.removed_keys.append(key)
			diff_report.differences.append(
				{
					"key": key,
					"type": "removed",
					"state1_value": norm_state1[key],
					"state2_value": null
				}
			)
		else:
			# Key only in state2
			diff_report.added_keys.append(key)
			diff_report.differences.append(
				{
					"key": key,
					"type": "added",
					"state1_value": null,
					"state2_value": norm_state2[key]
				}
			)

	# Calculate similarity score
	if total_keys > 0:
		diff_report.similarity_score = float(matching_keys) / float(total_keys)
		diff_report.states_similar = diff_report.similarity_score >= 0.8  # 80% similarity threshold

	# Record analysis time
	var analysis_time: float = Time.get_ticks_msec() - start_time
	diff_report.analysis_time_ms = analysis_time

	Log.debug(
		"State diff analysis completed",
		{
			"states_identical": diff_report.states_identical,
			"states_similar": diff_report.states_similar,
			"similarity_score": diff_report.similarity_score,
			"differences_count": diff_report.differences.size(),
			"added_keys": diff_report.added_keys.size(),
			"removed_keys": diff_report.removed_keys.size(),
			"modified_keys": diff_report.modified_keys.size(),
			"analysis_time_ms": analysis_time
		},
		["replay", "validation", "diff_analysis"]
	)

	return diff_report


## Check cross-platform consistency for replay validation
## Ensures game states are consistent across different platforms
static func check_cross_platform_consistency(
	states: Array, platform_info: Dictionary = {}
) -> Dictionary:
	"""Check consistency of game states across multiple platforms"""
	var start_time: int = Time.get_ticks_msec()

	var consistency_result: Dictionary = {
		"platform_consistent": false,
		"consistency_score": 0.0,
		"platform_differences": [],
		"normalized_states": [],
		"analysis_platforms": [],
		"check_time_ms": 0.0
	}

	if states.size() < 2:
		consistency_result.platform_consistent = true
		consistency_result.consistency_score = 1.0
		Log.debug(
			"Single or no states provided, marking as consistent",
			{},
			["replay", "validation", "cross_platform"]
		)
		return consistency_result

	# Normalize all states for cross-platform comparison
	var normalized_states: Array = []
	for state in states:
		if state is Dictionary:
			normalized_states.append(_normalize_platform_data(state))
		else:
			Log.warning(
				"Non-dictionary state found in cross-platform check",
				{"state_type": typeof(state)},
				["replay", "validation", "cross_platform"]
			)

	consistency_result.normalized_states = normalized_states

	# Compare all states with the first one as baseline
	var baseline_state: Dictionary = normalized_states[0] if normalized_states.size() > 0 else {}
	var consistent_comparisons: int = 0
	var total_comparisons: int = normalized_states.size() - 1

	for i in range(1, normalized_states.size()):
		var comparison: Dictionary = compare_states(baseline_state, normalized_states[i])
		if comparison.get("states_identical", false):
			consistent_comparisons += 1
		else:
			# Record platform difference
			consistency_result.platform_differences.append(
				{
					"baseline_index": 0,
					"comparison_index": i,
					"differences": comparison.get("differences", []),
					"similarity_score": comparison.get("similarity_score", 0.0)
				}
			)

	# Calculate overall consistency score
	if total_comparisons > 0:
		consistency_result.consistency_score = (
			float(consistent_comparisons) / float(total_comparisons)
		)
		consistency_result.platform_consistent = consistency_result.consistency_score >= 0.95  # 95% consistency threshold
	else:
		consistency_result.platform_consistent = true
		consistency_result.consistency_score = 1.0

	# Record check time
	var check_time: float = Time.get_ticks_msec() - start_time
	consistency_result.check_time_ms = check_time

	Log.info(
		"Cross-platform consistency check completed",
		{
			"platform_consistent": consistency_result.platform_consistent,
			"consistency_score": consistency_result.consistency_score,
			"states_checked": states.size(),
			"platform_differences": consistency_result.platform_differences.size(),
			"check_time_ms": check_time
		},
		["replay", "validation", "cross_platform"]
	)

	return consistency_result
