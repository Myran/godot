extends Node

class_name SentryManagerAutoloadTest

# TDD Test: SentryManager Autoload Validation
# This test defines the expected behavior for SentryManager singleton
# We will implement the functionality to make this test pass

var test_passed: bool = false
var test_results: Dictionary = {}

func _ready():
	name = "SentryManagerAutoloadTest"

# Test: SentryManager should be available as autoload singleton
func test_sentry_manager_autoload() -> Dictionary:
	print("🧪 TDD: Testing SentryManager autoload singleton...")

	# Expected behavior: SentryManager should be available globally
	var conditions = {
		"sentry_manager_class_exists": false,
		"sentry_manager_singleton_available": false,
		"sentry_manager_initialized": false,
		"sentry_manager_has_required_methods": false,
		"sentry_manager_performance_properties": false
	}

	# Condition 1: SentryManager class should exist
	conditions.sentry_manager_class_exists = ClassDB.class_exists("SentryManager")

	# Condition 2: SentryManager should be available as global singleton
	if Engine.has_singleton("SentryManager") or has_node("/root/SentryManager"):
		conditions.sentry_manager_singleton_available = true

	# Condition 3: SentryManager should be properly initialized
	var sentry_manager = _get_sentry_manager_instance()
	if sentry_manager:
		conditions.sentry_manager_initialized = sentry_manager.is_inside_tree()

		# Condition 4: SentryManager should have required methods
		var required_methods = ["is_initialized", "should_enable_sentry", "emergency_disable", "get_cpu_overhead", "get_memory_overhead"]
		var has_all_methods = true
		for method in required_methods:
			if not sentry_manager.has_method(method):
				has_all_methods = false
				break
		conditions.sentry_manager_has_required_methods = has_all_methods

		# Condition 5: SentryManager should have performance budget properties
		if sentry_manager.get_script():
			var script = sentry_manager.get_script()
			conditions.sentry_manager_performance_properties = (
				script.get_script_property_list().any(func(prop): return prop.name == "MAX_CPU_OVERHEAD") and
				script.get_script_property_list().any(func(prop): return prop.name == "MAX_MEMORY_OVERHEAD")
			)

	test_results = {
		"test_name": "sentry_manager_autoload",
		"conditions": conditions,
		"sentry_manager_instance": sentry_manager != null,
		"test_passed": _evaluate_test_conditions(conditions, sentry_manager != null),
		"implementation_notes": _get_implementation_notes(conditions, sentry_manager != null)
	}

	return test_results

# Helper methods
func _get_sentry_manager_instance() -> Node:
	if Engine.has_singleton("SentryManager"):
		return Engine.get_singleton("SentryManager")
	elif has_node("/root/SentryManager"):
		return get_node("/root/SentryManager")
	return null

func _evaluate_test_conditions(conditions: Dictionary, manager_available: bool) -> bool:
	return (
		conditions.sentry_manager_class_exists and
		conditions.sentry_manager_singleton_available and
		conditions.sentry_manager_initialized and
		conditions.sentry_manager_has_required_methods and
		conditions.sentry_manager_performance_properties and
		manager_available
	)

func _get_implementation_notes(conditions: Dictionary, manager_available: bool) -> Array[String]:
	var notes: Array[String] = []

	if not conditions.sentry_manager_class_exists:
		notes.append("❌ MISSING: SentryManager class not found - GameTwo integration addon not properly created")

	if not conditions.sentry_manager_singleton_available:
		notes.append("❌ MISSING: SentryManager not available as global singleton - plugin autoload not configured")

	if not conditions.sentry_manager_initialized:
		notes.append("❌ MISSING: SentryManager not properly initialized in scene tree")

	if not conditions.sentry_manager_has_required_methods:
		notes.append("❌ MISSING: SentryManager missing required methods (is_initialized, should_enable_sentry, emergency_disable, etc.)")

	if not conditions.sentry_manager_performance_properties:
		notes.append("❌ MISSING: SentryManager missing performance budget properties (MAX_CPU_OVERHEAD, MAX_MEMORY_OVERHEAD)")

	if not manager_available:
		notes.append("❌ MISSING: Cannot access SentryManager instance - autoload configuration failed")

	if notes.is_empty():
		notes.append("✅ SentryManager autoload successfully configured - ready for initialization testing")

	return notes

# Generate implementation TODO list
func generate_implementation_todo() -> Array[String]:
	var todo_items: Array[String] = []

	if not test_results.get("conditions", {}).get("sentry_manager_class_exists", false):
		todo_items.append("Create SentryManager class in project/addons/sentry_game_two_integration/sentry_manager.gd")

	if not test_results.get("conditions", {}).get("sentry_manager_singleton_available", false):
		todo_items.append("Configure SentryManager as autoload singleton in plugin.cfg")

	if not test_results.get("conditions", {}).get("sentry_manager_initialized", false):
		todo_items.append("Ensure SentryManager properly initializes when added to scene tree")

	if not test_results.get("conditions", {}).get("sentry_manager_has_required_methods", false):
		todo_items.append("Implement required methods in SentryManager: is_initialized, should_enable_sentry, emergency_disable, get_cpu_overhead, get_memory_overhead")

	if not test_results.get("conditions", {}).get("sentry_manager_performance_properties", false):
		todo_items.append("Add performance budget constants to SentryManager: MAX_CPU_OVERHEAD, MAX_MEMORY_OVERHEAD")

	return todo_items