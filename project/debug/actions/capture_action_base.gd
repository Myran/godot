class_name CaptureActionBase
extends RefCounted

# Base class for checksum capture actions - handles all the common logic
static var _last_checksums: Dictionary = {}

# Abstract method - subclasses implement their specific capture
func capture_data() -> Dictionary:
	assert(false, "capture_data() must be implemented in subclass")
	return {}

func get_state_type() -> String:
	assert(false, "get_state_type() must be implemented in subclass")
	return ""

# Main execution method - used by DebugAction callable
func execute() -> DebugAction.Result:
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()
	var state_type = get_state_type()
	
	Log.info(
		"=== CHECKSUM CAPTURE ENTRY ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"state_type": state_type,
			"timestamp": Time.get_datetime_string_from_system(),
			"phase": "capture"
		},
		["debug", "checksum", "capture", "pid", "phase"]
	)
	
	var state_data = capture_data()
	
	if state_data.is_empty():
		Log.error(
			"Failed to capture state data",
			{
				"state_type": state_type,
				"pid": process_id,
				"test_id": current_test_id
			},
			["debug", "checksum", "capture", "error", "pid"]
		)
		return DebugAction.Result.new_failure("Failed to capture " + state_type, "CAPTURE_FAILED")
	
	# Generate checksum using existing DictUtils and store
	var checksum = generate_checksum(state_data)
	_last_checksums[state_type] = checksum
	
	# Rich logging with PID tracking like battle determinism
	Log.info("CHECKSUM_CAPTURED", {
		"checksum": checksum,
		"state_type": state_type,
		"pid": process_id,
		"test_id": current_test_id,
		"data_size": JSON.stringify(state_data).length()
	}, ["checksum", "capture", state_type, "pid"])
	
	# Check if this should trigger restart for validation
	if _should_trigger_restart():
		_emit_restart_signal(checksum, state_type, process_id, current_test_id)
	
	return DebugAction.Result.new_success(
		{
			"checksum": checksum,
			"state_type": state_type,
			"action": "captured",
			"pid": process_id
		},
		0,  # No duration tracking for capture
		"checksum_captured"
	)

# Helper method to determine if restart should be triggered
func _should_trigger_restart() -> bool:
	# For checksum system, we want to restart to validate after capture
	# This allows the justfile to detect the signal and re-execute for validation
	return true

# Helper method to emit restart signal that justfile can detect
func _emit_restart_signal(checksum: String, state_type: String, process_id: int, test_id: String) -> void:
	Log.info(
		"DEBUG_TEST_RESTART_NEEDED",
		{
			"reason": "checksum_baseline_saved",
			"checksum": checksum,
			"state_type": state_type,
			"pid": process_id,
			"test_id": test_id,
			"restart_type": "full",
			"timestamp": Time.get_datetime_string_from_system()
		},
		["debug", "restart", "checksum", "signal", "pid"]
	)

static func generate_checksum(data: Dictionary) -> String:
	# Use existing project functionality for deterministic hashing
	return DictUtils.deterministic_hash(normalize_data_recursive(data))

static func normalize_data_recursive(data: Variant) -> Dictionary:
	# Convert any nested data structure to normalized Dictionary
	if data is Dictionary:
		var normalized = {}
		# Use existing DictUtils for deterministic key ordering
		for item in DictUtils.get_sorted_items(data):
			var key = item.key
			var value = item.value
			normalized[key] = normalize_value(value)
		return normalized
	else:
		# Wrap non-dictionary data
		return {"data": normalize_value(data)}

static func normalize_value(value: Variant) -> Variant:
	# Normalize individual values for consistency
	if value is Dictionary:
		return normalize_data_recursive(value)
	elif value is Array:
		var normalized_array = []
		for item in value:
			normalized_array.append(normalize_value(item))
		return normalized_array
	elif value is float:
		# Round floats to avoid precision differences
		return round(value * 1000000.0) / 1000000.0  # 6 decimal places
	else:
		# Primitives (int, String, bool, null): return as-is
		return value

static func get_last_checksum(state_type: String) -> String:
	return _last_checksums.get(state_type, "")