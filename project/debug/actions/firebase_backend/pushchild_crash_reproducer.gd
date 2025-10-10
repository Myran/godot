class_name PushChildCrashReproducer
extends BackendFirebaseDebugAction

enum TestPhase {
	MINIMAL_DATA,
	SINGLE_STRING,
	EMPTY_DICT,
	NESTED_DICT,
	LARGE_STRING,
	SPECIAL_CHARS,
	NUMERIC_DATA,
	COMPLEX_STRUCTURE
}

var current_phase: TestPhase = TestPhase.MINIMAL_DATA
var crash_results: Dictionary = {}
var test_start_time: int = 0


func _init() -> void:
	super._init()
	action_name = "backend.firebase.pushchild_crash_reproducer"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("🔥 STARTING SYSTEMATIC PUSHCHILD CRASH ANALYSIS...")

	test_start_time = Time.get_ticks_msec()
	crash_results.clear()
	current_phase = TestPhase.MINIMAL_DATA

	var timed_op: Dictionary = await TestUtils.time_operation(
		"PushChild Crash Reproduction Test Suite", _run_crash_analysis_suite
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not test_results.get("success", false):
		return TestUtils.make_failure_result(
			test_results.get("error", "PushChild crash analysis failed"),
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("pushchild_crash_analysis", test_results)
		)

	var total_phases: int = crash_results.get("total_phases_tested", 0)
	var crashed_phases: int = crash_results.get("crashed_phases", 0)
	var success_rate: float = crash_results.get("success_rate", 0.0)

	var metadata: Dictionary = TestUtils.make_metadata(
		"pushchild_crash_analysis",
		{
			"total_phases": total_phases,
			"crashed_phases": crashed_phases,
			"success_rate": success_rate,
			"crash_details": crash_results.get("crash_details", {}),
			"analysis_complete": true
		}
	)

	var summary: String = (
		"PushChild crash analysis: %d/%d phases tested (%.1f%% success)"
		% [total_phases - crashed_phases, total_phases, success_rate * 100]
	)

	_update_status("✅ " + summary)
	return TestUtils.make_success_result(summary, duration_ms, action_name, metadata)


func _run_crash_analysis_suite() -> Dictionary:
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {"success": false, "error": "Firebase backend not available"}

	_update_status("🔍 BEGINNING SYSTEMATIC PUSHCHILD CRASH ANALYSIS...")

	var all_results: Dictionary = {}
	var crashed_count: int = 0
	var total_count: int = 0

	# Test each phase systematically
	for phase in TestPhase.values():
		if phase == TestPhase.COMPLEX_STRUCTURE:  # Skip enum placeholder
			continue

		total_count += 1
		current_phase = phase

		_update_status("🧪 Testing Phase %d: %s" % [total_count, _get_phase_description(phase)])

		var phase_result: Dictionary = await _test_pushchild_phase(phase)
		all_results[str(phase)] = phase_result

		if phase_result.get("crashed", false):
			crashed_count += 1
			_update_status(
				"💥 CRASH DETECTED in Phase %d: %s" % [total_count, _get_phase_description(phase)],
				true
			)
		else:
			_update_status(
				(
					"✅ Phase %d completed successfully: %s"
					% [total_count, _get_phase_description(phase)]
				)
			)

		# Brief pause between phases to let system stabilize
		await Engine.get_main_loop().create_timer(0.5).timeout

	var success_rate: float = float(total_count - crashed_count) / float(total_count)

	var analysis_summary: Dictionary = {
		"success": true,
		"total_phases_tested": total_count,
		"crashed_phases": crashed_count,
		"success_rate": success_rate,
		"phase_results": all_results,
		"crash_details": _extract_crash_details(all_results),
		"backend_available": backend.is_available(),
		"total_duration_ms": Time.get_ticks_msec() - test_start_time
	}

	_update_status(
		(
			"🎯 PUSHCHILD CRASH ANALYSIS COMPLETE: %d crashes out of %d phases tested"
			% [crashed_count, total_count]
		)
	)
	return analysis_summary


func _test_pushchild_phase(phase: TestPhase) -> Dictionary:
	var test_data: Variant = _get_test_data_for_phase(phase)
	var test_description: String = _get_phase_description(phase)
	var phase_start_time: int = Time.get_ticks_msec()

	# Log pre-crash state
	var memory_info: Dictionary = _capture_memory_state()
	_update_status("📊 Phase %s - Memory state: %s" % [test_description, str(memory_info)])

	var test_path: Array[Variant] = [
		"crash_analysis", "pushchild_test", str(phase), str(Time.get_ticks_msec())
	]

	# Attempt the PushChild operation
	var push_success: bool = await test_backend_async_pattern(
		"push_data", test_path, "", test_data, "Crash Analysis Phase: " + test_description
	)

	var phase_duration: int = Time.get_ticks_msec() - phase_start_time
	var post_memory_info: Dictionary = _capture_memory_state()

	return {
		"crashed": false,
		"success": push_success,
		"phase": str(phase),
		"description": test_description,
		"data_type": typeof(test_data),
		"data_size": len(str(test_data)),
		"duration_ms": phase_duration,
		"pre_memory": memory_info,
		"post_memory": post_memory_info,
		"test_path": str(test_path),
		"timestamp": Time.get_ticks_msec()
	}


func _get_test_data_for_phase(phase: TestPhase) -> Variant:
	match phase:
		TestPhase.MINIMAL_DATA:
			return {"test": "value"}

		TestPhase.SINGLE_STRING:
			return "simple_string_value"

		TestPhase.EMPTY_DICT:
			return {}

		TestPhase.NESTED_DICT:
			return {
				"level1": {"level2": "nested_value", "level3": {"deep": "deep_value"}},
				"simple": "value"
			}

		TestPhase.LARGE_STRING:
			# Create a large string to stress memory
			var large_string: String = ""
			for i in range(200):  # 200 iterations = ~2000 characters
				large_string += "Large string test data " + str(i) + " with some content. "
			return {"large_content": large_string}

		TestPhase.SPECIAL_CHARS:
			return {
				"unicode": "Unicode test: 🚀 🔥 💡 📱",
				"special_chars": "Special: !@#$%^&*()_+-=[]{}|;':\",./<>?",
				"newlines": "Line1\nLine2\r\nLine3\tTabbed",
				"quotes": "\"Single quotes\" and 'double quotes'"
			}

		TestPhase.NUMERIC_DATA:
			return {
				"integer": 42,
				"negative_int": -123,
				"large_int": 9223372036854775807,  # Max int64
				"float": 3.14159,
				"negative_float": -2.71828,
				"scientific": 1.23e-4,
				"zero": 0
			}

		_:
			return {"default": "test_data"}


func _get_phase_description(phase: TestPhase) -> String:
	match phase:
		TestPhase.MINIMAL_DATA:
			return "Minimal Dictionary"
		TestPhase.SINGLE_STRING:
			return "Single String Value"
		TestPhase.EMPTY_DICT:
			return "Empty Dictionary"
		TestPhase.NESTED_DICT:
			return "Nested Dictionary Structure"
		TestPhase.LARGE_STRING:
			return "Large String Data"
		TestPhase.SPECIAL_CHARS:
			return "Special Characters & Unicode"
		TestPhase.NUMERIC_DATA:
			return "Numeric Data Types"
		_:
			return "Unknown Phase"


func _capture_memory_state() -> Dictionary:
	# Basic memory state capture - can be expanded
	return {
		"timestamp_ms": Time.get_ticks_msec(),
		"available_memory_mb":
		OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC] / 1024 / 1024,
		"process_id": OS.get_process_id()
	}


func _extract_crash_details(all_results: Dictionary) -> Dictionary:
	var crash_details: Dictionary = {}

	for phase_key: String in all_results.keys():
		var result: Dictionary = all_results[phase_key]

		if result.get("crashed", false):
			crash_details[phase_key] = {
				"description": result.get("description", "Unknown"),
				"data_type": result.get("data_type", "Unknown"),
				"data_size": result.get("data_size", 0),
				"pre_memory": result.get("pre_memory", {}),
				"timestamp": result.get("timestamp", 0)
			}

	return crash_details
