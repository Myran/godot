class_name TestValidation
extends RefCounted

## Simple validation utilities for debug actions following CLAUDE.md principles
## Strong typing, fail-fast validation, performance conscious


# Simple Firebase result validation with strong typing
static func validate_firebase_result(result: Variant, context: String) -> bool:
	if result == null:
		Log.error(
			"Firebase operation returned null",
			{"context": context, "result_type": typeof(result)},
			["firebase", "validation", "test"]
		)
		return false
	return true


# Simple timing validation with performance awareness (per CLAUDE.md)
static func validate_timing(
	duration_ms: int,
	operation: String,
	max_ms: int = GameConstants.DebugLimits.DEFAULT_OPERATION_TIMEOUT_MS
) -> bool:
	if duration_ms > max_ms:
		Log.warning(
			"Operation exceeded expected duration",
			{
				"operation": operation,
				"duration_ms": duration_ms,
				"max_ms": max_ms,
				"performance_impact": "potential"
			},
			["performance", "timing", "test"]
		)

	# Allow 2x threshold before considering it a failure
	return duration_ms < max_ms * 2


# Simple backend availability validation (common pattern in RTDB actions)
static func validate_backend_available(backend: Object, backend_name: String) -> bool:
	if not backend:
		Log.error(
			"Backend not available",
			{"backend_name": backend_name, "backend_null": true},
			["backend", "validation", "test"]
		)
		return false

	if not backend.has_method("is_available"):
		Log.error(
			"Backend missing is_available method",
			{"backend_name": backend_name, "methods": backend.get_method_list() if backend else []},
			["backend", "validation", "test"]
		)
		return false

	if not backend.is_available():
		Log.error(
			"Backend not initialized",
			{"backend_name": backend_name, "available": false},
			["backend", "validation", "test"]
		)
		return false

	return true


# Simple path validation for test paths
static func validate_test_path(
	path: Array, min_length: int = GameConstants.DebugLimits.MIN_TEST_PATH_LENGTH
) -> bool:
	if path.size() < min_length:
		Log.error(
			"Test path too short",
			{"path": path, "size": path.size(), "min_length": min_length},
			["validation", "test", "path"]
		)
		return false

	for element: Variant in path:
		if not (element is String):
			Log.error(
				"Test path contains non-string element",
				{"path": path, "invalid_element": element, "element_type": typeof(element)},
				["validation", "test", "path"]
			)
			return false

	return true
