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
	var state_data = capture_data()
	var state_type = get_state_type()
	
	if state_data.is_empty():
		return DebugAction.Result.new_failure("Failed to capture " + state_type)
	
	# Generate checksum using existing DictUtils and store
	var checksum = generate_checksum(state_data)
	_last_checksums[state_type] = checksum
	
	# Log for justfile to capture
	Log.info("CHECKSUM_CAPTURED", {
		"checksum": checksum,
		"state_type": state_type
	}, ["checksum", "capture", state_type])
	
	return DebugAction.Result.new_success({"checksum": checksum})

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