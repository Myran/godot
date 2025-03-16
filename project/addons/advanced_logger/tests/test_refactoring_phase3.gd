@tool
extends Node
## Test for Phase 3 Refactoring
##
## This script tests that the refactored components work correctly
## after splitting LoggerDock into smaller components.

# Dependencies
var LoggerDock = preload("res://addons/advanced_logger/logger_dock.gd")
var TagListController = preload("res://addons/advanced_logger/ui/tag_list_controller.gd") 
var SetupListController = preload("res://addons/advanced_logger/ui/setup_list_controller.gd")
var DragDropHelper = preload("res://addons/advanced_logger/ui/drag_drop_helper.gd")
var ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")
var TagManager = preload("res://addons/advanced_logger/tag_manager.gd")
var TagSetupManager = preload("res://addons/advanced_logger/tag_setup_manager.gd")

# Test results
var _tests_passed = 0
var _tests_failed = 0

func _ready():
	print("\n=== Running Phase 3 Refactoring Tests ===")
	
	test_component_creation()
	test_tag_list_controller()
	test_setup_list_controller()
	test_drag_drop_helper()
	
	print("\nTest results: %d passed, %d failed" % [_tests_passed, _tests_failed])
	print("=== Phase 3 Refactoring Tests Complete ===\n")

func log_test_result(test_name: String, passed: bool, details: String = ""):
	if passed:
		_tests_passed += 1
		print("✓ %s" % test_name)
	else:
		_tests_failed += 1
		print("✗ %s%s" % [test_name, ": " + details if details else ""])

# Test creating all components to ensure they initialize properly
func test_component_creation():
	print("\nTesting component creation...")
	
	# Test TagListController creation
	var tag_manager = TagManager.new()
	var config = ConfigManager.get_instance()
	var tag_list_controller = null
	
	var success = true
	var error_msg = ""
	
	tag_list_controller = TagListController.new(tag_manager, config)
	
	if not tag_list_controller:
		success = false
		error_msg = "Failed to create TagListController"
	
	log_test_result("TagListController creation", success, error_msg)
	
	# Test SetupListController creation
	var setup_manager = TagSetupManager.new(config)
	var setup_list_controller = null
	
	success = true
	error_msg = ""
	
	setup_list_controller = SetupListController.new(setup_manager)
	
	if not setup_list_controller:
		success = false
		error_msg = "Failed to create SetupListController"
	
	log_test_result("SetupListController creation", success, error_msg)
	
	# Test DragDropHelper creation
	var drag_drop_helper = null
	
	success = true
	error_msg = ""
	
	drag_drop_helper = DragDropHelper.new(tag_manager)
	
	if not drag_drop_helper:
		success = false
		error_msg = "Failed to create DragDropHelper"
	
	log_test_result("DragDropHelper creation", success, error_msg)

# Test TagListController functionality
func test_tag_list_controller():
	print("\nTesting TagListController...")
	
	var tag_manager = TagManager.new()
	var config = ConfigManager.get_instance()
	var controller = TagListController.new(tag_manager, config)
	
	# Test getting tag lists
	var tag_lists = controller.get_tag_lists()
	log_test_result("get_tag_lists returns a dictionary", 
		tag_lists is Dictionary and tag_lists.has("available_tags") and 
		tag_lists.has("active_tags") and tag_lists.has("ignored_tags"))
	
	# Test move_tag
	var test_tag = "test_tag"
	controller.move_tag(test_tag, "available", "active")
	tag_lists = controller.get_tag_lists()
	log_test_result("move_tag from available to active", 
		tag_lists.active_tags.has(test_tag))
	
	controller.move_tag(test_tag, "active", "ignored")
	tag_lists = controller.get_tag_lists()
	log_test_result("move_tag from active to ignored", 
		tag_lists.ignored_tags.has(test_tag) and not tag_lists.active_tags.has(test_tag))
	
	controller.move_tag(test_tag, "ignored", "available")
	tag_lists = controller.get_tag_lists()
	log_test_result("move_tag from ignored to available", 
		not tag_lists.ignored_tags.has(test_tag) and not tag_lists.active_tags.has(test_tag))

# Test SetupListController functionality
func test_setup_list_controller():
	print("\nTesting SetupListController...")
	
	var config = ConfigManager.get_instance()
	var setup_manager = TagSetupManager.new(config)
	var controller = SetupListController.new(setup_manager)
	
	# Test save_setup
	var test_name = "test_setup_" + str(randi())
	var active_tags: Array[String] = ["active1", "active2"]
	var ignored_tags: Array[String] = ["ignored1"]
	
	var result = controller.save_setup(test_name, active_tags, ignored_tags)
	log_test_result("save_setup", result == OK)
	
	# Test get_setup
	var setup = controller.load_setup(test_name)
	log_test_result("load_setup returns correct data", 
		setup.has("setup_name") and setup.setup_name == test_name and
		setup.has("active_tags") and setup.active_tags.size() == 2 and
		setup.has("ignored_tags") and setup.ignored_tags.size() == 1)
	
	# Test delete_setup
	result = controller.delete_setup(test_name)
	log_test_result("delete_setup", result == OK)
	
	# Verify deletion
	setup = controller.load_setup(test_name)
	log_test_result("setup was deleted", setup.is_empty())

# Test DragDropHelper functionality
func test_drag_drop_helper():
	print("\nTesting DragDropHelper...")
	
	var tag_manager = TagManager.new()
	var helper = DragDropHelper.new(tag_manager)
	
	# Test can_drop_tag
	var active_tags: Array[String] = ["tag1"]
	var ignored_tags: Array[String] = []
	
	log_test_result("can't drop to same list", 
		not helper.can_drop_tag("test", "available", "available", active_tags, ignored_tags))
	
	log_test_result("can drop from available to active", 
		helper.can_drop_tag("test", "available", "active", active_tags, ignored_tags))
	
	log_test_result("can't drop already active tag to active", 
		not helper.can_drop_tag("tag1", "available", "active", active_tags, ignored_tags))
	
	# Test drag preview creation
	var preview = helper.create_drag_preview("Test Tag")
	log_test_result("create_drag_preview returns a Control", preview is Control)
