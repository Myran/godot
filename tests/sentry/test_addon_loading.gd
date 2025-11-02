extends Node

class_name SentryAddonLoadingTest

# TDD Test: Sentry Addon Loading Validation
# This test defines the expected behavior for Sentry addon loading
# We will implement the functionality to make this test pass

var test_passed: bool = false
var test_results: Dictionary = {}
var original_project_settings: Dictionary

func _ready():
	name = "SentryAddonLoadingTest"

# Test: Sentry addon should be enabled in project settings
func test_sentry_addon_enabled() -> Dictionary:
	print("🧪 TDD: Testing Sentry addon loading...")

	# Setup: Store original project settings
	original_project_settings = _backup_project_settings()

	# Expected behavior: Sentry addon should be enabled
	var expected_plugin_name = "sentry"
	var expected_integration_plugin_name = "sentry_game_two_integration"

	# Test conditions (these must pass for successful implementation)
	var conditions = {
		"sentry_plugin_enabled": false,
		"sentry_integration_plugin_enabled": false,
		"sentry_plugin_path_exists": false,
		"sentry_integration_plugin_path_exists": false,
		"project_settings_updated": false
	}

	# Condition 1: Sentry addon path should exist
	conditions.sentry_plugin_path_exists = FileAccess.file_exists("res://addons/sentry/plugin.cfg")
	conditions.sentry_integration_plugin_path_exists = FileAccess.file_exists("res://addons/sentry_game_two_integration/plugin.cfg")

	# Condition 2: Project settings should include Sentry plugins
	if ProjectSettings.has_setting("plugins/enabled"):
		var enabled_plugins = ProjectSettings.get_setting("plugins/enabled", [])
		conditions.sentry_plugin_enabled = expected_plugin_name in enabled_plugins
		conditions.sentry_integration_plugin_enabled = expected_integration_plugin_name in enabled_plugins
		conditions.project_settings_updated = true

	# Condition 3: Sentry manager should be available as autoload
	var sentry_manager_loaded = ClassDB.class_exists("SentryManager") or Engine.has_singleton("SentryManager")

	test_results = {
		"test_name": "sentry_addon_loading",
		"conditions": conditions,
		"sentry_manager_autoload_available": sentry_manager_loaded,
		"test_passed": _evaluate_test_conditions(conditions, sentry_manager_loaded),
		"implementation_notes": _get_implementation_notes(conditions, sentry_manager_loaded)
	}

	return test_results

# Helper methods for test evaluation
func _backup_project_settings() -> Dictionary:
	var backup = {}
	if ProjectSettings.has_setting("plugins/enabled"):
		backup["plugins/enabled"] = ProjectSettings.get_setting("plugins/enabled", [])
	return backup

func _evaluate_test_conditions(conditions: Dictionary, sentry_manager_loaded: bool) -> bool:
	# All conditions must pass for test to succeed
	return (
		conditions.sentry_plugin_enabled and
		conditions.sentry_integration_plugin_enabled and
		conditions.sentry_plugin_path_exists and
		conditions.sentry_integration_plugin_path_exists and
		conditions.project_settings_updated and
		sentry_manager_loaded
	)

func _get_implementation_notes(conditions: Dictionary, sentry_manager_loaded: bool) -> Array[String]:
	var notes: Array[String] = []

	if not conditions.sentry_plugin_path_exists:
		notes.append("❌ MISSING: res://addons/sentry/plugin.cfg - Sentry SDK not installed as addon")

	if not conditions.sentry_integration_plugin_path_exists:
		notes.append("❌ MISSING: res://addons/sentry_game_two_integration/plugin.cfg - GameTwo integration addon not created")

	if not conditions.sentry_plugin_enabled:
		notes.append("❌ MISSING: Sentry plugin not enabled in Project Settings > Plugins")

	if not conditions.sentry_integration_plugin_enabled:
		notes.append("❌ MISSING: GameTwo integration plugin not enabled in Project Settings > Plugins")

	if not conditions.project_settings_updated:
		notes.append("❌ MISSING: Project settings not updated to include Sentry plugins")

	if not sentry_manager_loaded:
		notes.append("❌ MISSING: SentryManager singleton not available - plugin autoload not configured")

	if notes.is_empty():
		notes.append("✅ All addon loading conditions satisfied - ready for next implementation phase")

	return notes

# Test cleanup
func cleanup():
	print("🧹 Cleaning up Sentry addon loading test...")
	# Restore original project settings if needed
	# In TDD, we typically keep changes made during implementation
	pass

# Generate implementation TODO list based on test failures
func generate_implementation_todo() -> Array[String]:
	var todo_items: Array[String] = []

	if not test_results.get("conditions", {}).get("sentry_plugin_path_exists", false):
		todo_items.append("Download Sentry SDK v1.1.0 and extract to project/addons/sentry/")

	if not test_results.get("conditions", {}).get("sentry_integration_plugin_path_exists", false):
		todo_items.append("Create GameTwo integration addon at project/addons/sentry_game_two_integration/")

	if not test_results.get("conditions", {}).get("sentry_plugin_enabled", false):
		todo_items.append("Enable Sentry plugin in Project Settings > Plugins")

	if not test_results.get("conditions", {}).get("sentry_integration_plugin_enabled", false):
		todo_items.append("Enable GameTwo integration plugin in Project Settings > Plugins")

	if not test_results.get("sentry_manager_autoload_available", false):
		todo_items.append("Configure SentryManager as autoload singleton in plugin configuration")

	return todo_items

# Static method for running this test in test framework
static func run_test() -> Dictionary:
	var test_instance = SentryAddonLoadingTest.new()
	return test_instance.test_sentry_addon_enabled()