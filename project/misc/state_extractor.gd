class_name StateExtractor
extends RefCounted

## StateExtractor - Continuous state checksum system for recording and playback integrity validation
##
## This utility class provides deterministic game state extraction and checksum generation
## for validating replay integrity and ensuring consistent state across different platforms.
##
## Key Features:
## - Real-time state extraction (< 5ms performance target)
## - Deterministic checksum generation using DictUtils.deterministic_hash()
## - Data normalization for cross-platform consistency
## - Integration with SessionManager for pre-action state capture
## - Comprehensive error handling for edge cases
##
## Usage Example:
## var game_state: Dictionary = StateExtractor.extract_game_state()
## var checksum: String = StateExtractor.generate_checksum(game_state)
## if StateExtractor.is_state_valid(game_state):
##     SessionManager.store_pre_action_state(checksum, game_state)


## Extract complete game state from all relevant game components
## Returns normalized dictionary containing current game state
## Performance target: < 5ms execution time
static func extract_game_state() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var game_state: Dictionary = {}

	# Extract core game components
	game_state["lineup"] = extract_lineup_state()
	game_state["board"] = extract_board_state()
	game_state["metadata"] = _extract_metadata()

	# Normalize data for deterministic hashing
	game_state = normalize_data(game_state)

	var execution_time: int = Time.get_ticks_msec() - start_time

	# Log performance metrics
	Log.debug(
		"StateExtractor: Game state extracted",
		{
			"execution_time_ms": execution_time,
			"state_size": game_state.size(),
			"performance_target_met": execution_time < 5
		},
		["state_extractor", "performance"]
	)

	# Warn if performance target missed
	if execution_time >= 5:
		Log.warning(
			"StateExtractor: Performance target missed",
			{"execution_time_ms": execution_time, "target_ms": 5},
			["state_extractor", "performance", "warning"]
		)

	return game_state


## Generate deterministic checksum for game state dictionary
## Uses DictUtils.deterministic_hash() for consistency
## Returns SHA256 hash string (64 characters hex)
static func generate_checksum(data: Dictionary) -> String:
	if not is_state_valid(data):
		Log.error(
			"StateExtractor: Cannot generate checksum for invalid state",
			{"data_size": data.size()},
			["state_extractor", "error"]
		)
		return ""

	# Use existing DictUtils implementation for consistency
	var checksum: String = DictUtils.deterministic_hash(data)

	Log.debug(
		"StateExtractor: Checksum generated",
		{"checksum": checksum, "data_size": data.size()},
		["state_extractor", "checksum"]
	)

	return checksum


## Normalize data for deterministic hashing and cross-platform consistency
## Handles float precision, key sorting, null values, and circular references
static func normalize_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}

	var normalized: Dictionary = {}

	# Process keys in deterministic order
	var sorted_keys: Array = DictUtils.keys_sorted(data)

	for key: Variant in sorted_keys:
		var value: Variant = data[key]
		var normalized_value: Variant = _normalize_value(value)

		# Skip null/invalid values to maintain consistency
		if normalized_value != null:
			normalized[key] = normalized_value

	return normalized


## Extract lineup state from game components
## Returns dictionary containing current lineup data
static func extract_lineup_state() -> Dictionary:
	var lineup_state: Dictionary = {}

	# Check if Core autoload exists and has lineup data
	if Core and Core.has_method("get_lineup_data"):
		var lineup_data: Dictionary = Core.get_lineup_data()
		if lineup_data and not lineup_data.is_empty():
			lineup_state = DictUtils.make_deterministic(lineup_data)

	# Add lineup metadata
	lineup_state["extracted_at"] = Time.get_unix_time_from_system()
	lineup_state["extraction_type"] = "lineup_state"

	return lineup_state


## Extract board state from game components
## Returns dictionary containing current board data
static func extract_board_state() -> Dictionary:
	var board_state: Dictionary = {}

	# Check if Core autoload exists and has board data
	if Core and Core.has_method("get_board_data"):
		var board_data: Dictionary = Core.get_board_data()
		if board_data and not board_data.is_empty():
			board_state = DictUtils.make_deterministic(board_data)

	# Add board metadata
	board_state["extracted_at"] = Time.get_unix_time_from_system()
	board_state["extraction_type"] = "board_state"

	return board_state


## Validate that game state dictionary is valid for checksum generation
## Returns true if state can be safely processed
static func is_state_valid(data: Dictionary) -> bool:
	# Handle null/empty state
	if not data or data.is_empty():
		Log.debug(
			"StateExtractor: Empty state detected",
			{"data_null": data == null, "data_empty": data.is_empty()},
			["state_extractor", "validation"]
		)
		return false

	# Validate deterministic keys
	if not DictUtils.validate_deterministic_keys(data):
		Log.warning(
			"StateExtractor: Non-deterministic keys detected",
			{"data_size": data.size()},
			["state_extractor", "validation", "warning"]
		)
		return false

	# Check for circular references (basic detection)
	if _has_circular_references(data):
		Log.error(
			"StateExtractor: Circular references detected",
			{"data_size": data.size()},
			["state_extractor", "error", "circular_ref"]
		)
		return false

	return true


## Private helper: Extract metadata about the current game state
static func _extract_metadata() -> Dictionary:
	var metadata: Dictionary = {}

	metadata["timestamp"] = Time.get_unix_time_from_system()
	metadata["platform"] = OS.get_name()
	metadata["extractor_version"] = "1.0.0"
	metadata["godot_version"] = Engine.get_version_info()

	return metadata


## Private helper: Normalize individual values for consistency
static func _normalize_value(value: Variant) -> Variant:
	# Handle null values
	if value == null:
		return null

	match typeof(value):
		TYPE_FLOAT:
			# Normalize floats to 6 decimal places for consistency
			var normalized_float: float = snappedf(value, 0.000001)
			return normalized_float

		TYPE_DICTIONARY:
			# Recursively normalize nested dictionaries
			return normalize_data(value)

		TYPE_ARRAY:
			# Normalize arrays by processing each element
			var normalized_array: Array = []
			for item: Variant in value:
				var normalized_item: Variant = _normalize_value(item)
				if normalized_item != null:
					normalized_array.append(normalized_item)
			return normalized_array

		TYPE_STRING:
			# Ensure string consistency (trim whitespace)
			return str(value).strip_edges()

		_:
			# Return other types as-is
			return value


## Private helper: Basic circular reference detection
static func _has_circular_references(data: Dictionary, visited: Array = []) -> bool:
	# Simple depth-based detection (prevents infinite recursion)
	if visited.size() > 10:  # Maximum reasonable nesting depth
		return true

	for key: Variant in data:
		var value: Variant = data[key]

		# Check if we've seen this exact dictionary before
		if value is Dictionary:
			if value in visited:
				return true

			var new_visited: Array = visited.duplicate()
			new_visited.append(value)

			if _has_circular_references(value, new_visited):
				return true

	return false
