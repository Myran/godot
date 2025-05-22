# project/debug/validation_script.gd
@tool
extends Node

const REQUIRED_FILES = [
	"res://debug/actions/debug_action.gd",
	"res://debug/actions/rtdb/rtdb_set_simple_value_action.gd",
	"res://debug/debug_action_registry.gd",
	"res://debug/debug_menu_controller.gd",
	"res://autoloads/debug_manager.gd",
	"res://autoloads/debug.gd",
]

const REQUIRED_CLASSES = [
	"DebugAction",
	"RTDBSetSimpleValueAction",
	"DebugActionRegistry",
	"DebugMenuController",
]

const REQUIRED_AUTOLOADS = ["DebugManager", "DebugRegistry"]

var errors = []
var warnings = []
var success_count = 0


func _run_validation():
	print("\n=== DEBUG SYSTEM VALIDATION ===\n")

	validate_files()
	validate_classes()
	validate_autoloads()
	validate_component_interfaces()

	print("\n=== VALIDATION RESULTS ===\n")

	if errors.size() > 0:
		print("❌ ERRORS: " + str(errors.size()))
		for error in errors:
			print("  - " + error)
	else:
		print("✅ No errors detected")

	if warnings.size() > 0:
		print("\n⚠️ WARNINGS: " + str(warnings.size()))
		for warning in warnings:
			print("  - " + warning)

	print("\n✅ Successful checks: " + str(success_count))

	if errors.size() == 0 and warnings.size() == 0:
		print(
			"\n🎉 Validation passed successfully! The debug system refactoring appears complete and correct."
		)
	elif errors.size() == 0:
		print("\n🔶 Validation passed with warnings. Most critical elements are in place.")
	else:
		print("\n❌ Validation failed. Please fix the errors before proceeding.")

	return errors.size() == 0


func validate_files():
	print("Checking required files...")
	for file_path in REQUIRED_FILES:
		if FileAccess.file_exists(file_path):
			print("  ✅ " + file_path)
			success_count += 1
		else:
			errors.append("Missing file: " + file_path)
			print("  ❌ " + file_path)


func validate_classes():
	print("\nChecking required classes...")
	for class_name in REQUIRED_CLASSES:
		if ClassDB.class_exists(class_name) or Script.new().get_global_class_list().has(class_name):
			print("  ✅ " + class_name)
			success_count += 1
		else:
			warnings.append("Class might not be properly registered: " + class_name)
			print("  ⚠️ " + class_name + " (might not be registered yet)")


func validate_autoloads():
	print("\nChecking required autoloads...")
	for autoload in REQUIRED_AUTOLOADS:
		if Engine.has_singleton(autoload):
			print("  ✅ " + autoload)
			success_count += 1
		else:
			warnings.append(
				"Autoload not found: " + autoload + ". Make sure it's added in Project Settings."
			)
			print("  ⚠️ " + autoload + " (not found in Engine singletons)")


func validate_component_interfaces():
	print("\nValidating component interfaces...")

	# Check DebugManager
	var debug_manager_path = "res://autoloads/debug_manager.gd"
	if FileAccess.file_exists(debug_manager_path):
		var script = load(debug_manager_path)
		if (
			script.has_method("action")
			and script.has_source_code().find("enum DebugEventType") >= 0
		):
			print("  ✅ DebugManager has required interface")
			success_count += 1
		else:
			warnings.append("DebugManager might be missing required interface elements")
			print("  ⚠️ DebugManager interface check")

	# Check DebugMenuController
	var controller_path = "res://debug/debug_menu_controller.gd"
	if FileAccess.file_exists(controller_path):
		var script = load(controller_path)
		if (
			script.has_method("_populate_main_categories_view")
			and script.has_method("_execute_single_action")
		):
			print("  ✅ DebugMenuController has required interface")
			success_count += 1
		else:
			warnings.append("DebugMenuController might be missing required methods")
			print("  ⚠️ DebugMenuController interface check")

	# Check DebugAction base class
	var action_path = "res://debug/actions/debug_action.gd"
	if FileAccess.file_exists(action_path):
		var script = load(action_path)
		if script.has_method("execute") and script.has_method("_update_status"):
			print("  ✅ DebugAction has required methods")
			success_count += 1
		else:
			warnings.append("DebugAction might be missing required methods")
			print("  ⚠️ DebugAction interface check")

	# Check DebugActionRegistry
	var registry_path = "res://debug/debug_action_registry.gd"
	if FileAccess.file_exists(registry_path):
		var script = load(registry_path)
		if script.has_method("get_actions") and script.has_method("get_categories"):
			print("  ✅ DebugActionRegistry has required methods")
			success_count += 1
		else:
			warnings.append("DebugActionRegistry might be missing required methods")
			print("  ⚠️ DebugActionRegistry interface check")


func _ready():
	_run_validation()
	# In a real tool script, you might want to:
	# get_tree().quit()


# This allows running from command line: godot --script project/debug/validation_script.gd
static func run():
	var validator = load("res://debug/validation_script.gd").new()
	var success = validator._run_validation()
	return success
