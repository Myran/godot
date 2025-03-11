@tool
extends Node
## Test script for Advanced Logger functionality
## Run this script to validate the logger's tag filtering features

# Test tags
const TEST_TAGS = [
	"test_tag_1",
	"test_tag_2",
	"test_tag_3",
	"database",
	"network",
	"ui",
	"gameplay"
]

# Test results
var _original_active_tags: Array[String] = []
var _original_ignored_tags: Array[String] = []
var _test_passed = true
var _error_messages = []

@onready var _result_label = $ResultLabel
@onready var _run_test_button = $RunTestButton
@onready var _restore_button = $RestoreButton


func _ready() -> void:
	if not Engine.is_editor_hint():
		_run_test_button.pressed.connect(_run_tests)
		_restore_button.pressed.connect(_restore_settings)
		
		# Add test tags to available tags in logger
		_backup_current_settings()
		
		_result_label.text = "Press 'Run Tests' to start the logger validation"


func _exit_tree() -> void:
	# Automatically restore settings when scene exits
	_restore_settings()


## Backup current logger settings so we can restore them after testing
func _backup_current_settings() -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		if config.has_section_key("logger", "active_tags"):
			var tags = config.get_value("logger", "active_tags")
			for tag in tags:
				_original_active_tags.append(tag)
		
		if config.has_section_key("logger", "ignored_tags"):
			var tags = config.get_value("logger", "ignored_tags")
			for tag in tags:
				_original_ignored_tags.append(tag)
	
	print("Original settings backed up: active=%s, ignored=%s" % [_original_active_tags, _original_ignored_tags])


## Run a series of tests to validate logger functionality
func _run_tests() -> void:
	_test_passed = true
	_error_messages.clear()
	_result_label.text = "Running tests..."
	
	print_rich("[color=#a9b665]====== ADVANCED LOGGER TEST STARTING ======[/color]")
	
	# Test 1: Add tags to Logger
	_test_adding_tags()
	
	# Test 2: Test tag filtering
	_test_tag_filtering()
	
	# Test 3: Test tag ignoring
	_test_tag_ignoring()
	
	# Test 4: Test drag and drop via simulated settings
	_test_tag_movement()
	
	# Display results
	if _test_passed:
		_result_label.text = "All tests PASSED!"
	else:
		_result_label.text = "Tests FAILED!\n" + "\n".join(_error_messages)
	
	print_rich("[color=#a9b665]====== ADVANCED LOGGER TEST COMPLETE ======[/color]")
	
	# Automatically restore original settings after test completes
	_restore_settings()


## Test adding tags to the logger
func _test_adding_tags() -> void:
	print_rich("[color=#7daea3]Test 1: Adding tags to Logger[/color]")
	
	# First clear any existing tags
	_clear_all_tags()
	
	# Add some test tags to available tags so they're visible in the UI
	_add_tags_to_available()
	
	# Log with each test tag
	_log_with_test_tags()
	
	print_rich("[color=#a9b665]Test 1 complete[/color]")


## Test tag filtering functionality
func _test_tag_filtering() -> void:
	print_rich("[color=#7daea3]Test 2: Testing tag filtering[/color]")
	
	# Clear existing and set up fresh
	_clear_all_tags()
	
	# Add active tags to filter on
	_set_active_tags(["test_tag_1", "ui"])
	
	print_rich("[color=#7daea3]The following logs should appear:[/color]")
	Log.info("This log should appear (test_tag_1)", {}, ["test_tag_1"])
	Log.warning("This log should appear (ui)", {}, ["ui"])
	Log.error("This log should appear (has both active tags)", {}, ["test_tag_1", "ui"])
	
	print_rich("[color=#7daea3]The following logs should NOT appear because of tag filtering:[/color]")
	Log.info("This log should NOT appear (test_tag_2)", {}, ["test_tag_2"])
	Log.warning("This log should NOT appear (no tags)", {})
	Log.error("This log should NOT appear (network tag)", {}, ["network"])
	
	print_rich("[color=#a9b665]Test 2 complete - check if logs appeared as expected[/color]")


## Test tag ignoring functionality
func _test_tag_ignoring() -> void:
	print_rich("[color=#7daea3]Test 3: Testing tag ignoring[/color]")
	
	# Clear existing and set up fresh
	_clear_all_tags()
	
	# Add tags to ignore
	_set_ignored_tags(["database", "network"])
	
	print_rich("[color=#7daea3]The following logs should appear:[/color]")
	Log.info("This log should appear (test_tag_1)", {}, ["test_tag_1"])
	Log.warning("This log should appear (ui)", {}, ["ui"])
	Log.error("This log should appear (no tags)", {})
	
	print_rich("[color=#7daea3]The following logs should NOT appear because of ignored tags:[/color]")
	Log.info("This log should NOT appear (database)", {}, ["database"])
	Log.warning("This log should NOT appear (network)", {}, ["network"])
	Log.error("This log should NOT appear (has an ignored tag)", {}, ["test_tag_1", "database"])
	
	print_rich("[color=#a9b665]Test 3 complete - check if logs appeared as expected[/color]")


## Test tag movement between categories (simulated drag and drop)
func _test_tag_movement() -> void:
	print_rich("[color=#7daea3]Test 4: Simulating tag movement between categories[/color]")
	
	# Clear existing and set up fresh
	_clear_all_tags()
	
	# Start with all tags in available
	_add_tags_to_available()
	
	# Move tags from available to active
	_move_tags_between_categories(["test_tag_1", "ui"], "available", "active")
	
	# Move tags from available to ignored
	_move_tags_between_categories(["database", "network"], "available", "ignored")
	
	# Move a tag from active to ignored
	_move_tags_between_categories(["ui"], "active", "ignored")
	
	# Move a tag from ignored to active
	_move_tags_between_categories(["database"], "ignored", "active")
	
	# Verify final state
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		var active_tags = []
		var ignored_tags = []
		
		if config.has_section_key("logger", "active_tags"):
			active_tags = config.get_value("logger", "active_tags")
		
		if config.has_section_key("logger", "ignored_tags"):
			ignored_tags = config.get_value("logger", "ignored_tags")
		
		print("Final active tags: %s" % active_tags)
		print("Final ignored tags: %s" % ignored_tags)
		
		# Check if expected tags are in the right places
		if "test_tag_1" in active_tags and "database" in active_tags:
			print_rich("[color=#a9b665]Active tags verified correctly[/color]")
		else:
			_test_passed = false
			_error_messages.append("Failed to verify active tags")
			print_rich("[color=#ea6962]Active tags verification failed[/color]")
		
		if "network" in ignored_tags and "ui" in ignored_tags:
			print_rich("[color=#a9b665]Ignored tags verified correctly[/color]")
		else:
			_test_passed = false
			_error_messages.append("Failed to verify ignored tags")
			print_rich("[color=#ea6962]Ignored tags verification failed[/color]")
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file")
		print_rich("[color=#ea6962]Failed to load config file[/color]")
	
	print_rich("[color=#a9b665]Test 4 complete[/color]")


## Restore the original logger settings from before testing
func _restore_settings() -> void:
	print("Restoring original settings")
	
	# Only restore if we have original settings to restore
	if _original_active_tags != null or _original_ignored_tags != null:
		# Clear all tags
		_clear_all_tags()
		
		# Restore original active tags
		_set_active_tags(_original_active_tags)
		
		# Restore original ignored tags
		_set_ignored_tags(_original_ignored_tags)
		
		if is_instance_valid(_result_label):
			_result_label.text = "Original settings restored"
		print("Original settings restored")


## Log messages with all test tags
func _log_with_test_tags() -> void:
	print_rich("[color=#7daea3]Logging messages with test tags[/color]")
	
	for tag in TEST_TAGS:
		Log.info("Test log with tag: %s" % tag, {}, [tag])
	
	# Log with multiple tags
	Log.warning("Test log with multiple tags", {}, ["test_tag_1", "test_tag_2"])
	Log.error("Another test with multiple tags", {}, ["database", "network"])


## Clear all active and ignored tags
func _clear_all_tags() -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		config.set_value("logger", "active_tags", PackedStringArray([]))
		config.set_value("logger", "ignored_tags", PackedStringArray([]))
		config.save("res://addons/advanced_logger/settings.cfg")
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file for clearing tags")
		print_rich("[color=#ea6962]Failed to load config file for clearing tags[/color]")


## Add test tags to available tags
func _add_tags_to_available() -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		config.set_value("logger", "available_tags", PackedStringArray(TEST_TAGS))
		config.save("res://addons/advanced_logger/settings.cfg")
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file for adding available tags")
		print_rich("[color=#ea6962]Failed to load config file for adding available tags[/color]")


## Set active tags
func _set_active_tags(tags: Array) -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		config.set_value("logger", "active_tags", PackedStringArray(tags))
		config.save("res://addons/advanced_logger/settings.cfg")
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file for setting active tags")
		print_rich("[color=#ea6962]Failed to load config file for setting active tags[/color]")


## Set ignored tags
func _set_ignored_tags(tags: Array) -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		config.set_value("logger", "ignored_tags", PackedStringArray(tags))
		config.save("res://addons/advanced_logger/settings.cfg")
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file for setting ignored tags")
		print_rich("[color=#ea6962]Failed to load config file for setting ignored tags[/color]")


## Simulate moving tags between categories (available, active, ignored)
func _move_tags_between_categories(tags: Array, from_category: String, to_category: String) -> void:
	var config = ConfigFile.new()
	var load_result = config.load("res://addons/advanced_logger/settings.cfg")
	
	if load_result == OK:
		var available_tags = []
		var active_tags = []
		var ignored_tags = []
		
		if config.has_section_key("logger", "available_tags"):
			available_tags = config.get_value("logger", "available_tags")
		
		if config.has_section_key("logger", "active_tags"):
			active_tags = config.get_value("logger", "active_tags")
		
		if config.has_section_key("logger", "ignored_tags"):
			ignored_tags = config.get_value("logger", "ignored_tags")
		
		# Remove tags from source category
		if from_category == "available":
			for tag in tags:
				if tag in available_tags:
					available_tags.erase(tag)
		elif from_category == "active":
			for tag in tags:
				if tag in active_tags:
					active_tags.erase(tag)
		elif from_category == "ignored":
			for tag in tags:
				if tag in ignored_tags:
					ignored_tags.erase(tag)
		
		# Add tags to destination category
		if to_category == "available":
			for tag in tags:
				if not tag in available_tags:
					available_tags.append(tag)
		elif to_category == "active":
			for tag in tags:
				if not tag in active_tags:
					active_tags.append(tag)
		elif to_category == "ignored":
			for tag in tags:
				if not tag in ignored_tags:
					ignored_tags.append(tag)
		
		# Save updated categories
		config.set_value("logger", "available_tags", PackedStringArray(available_tags))
		config.set_value("logger", "active_tags", PackedStringArray(active_tags))
		config.set_value("logger", "ignored_tags", PackedStringArray(ignored_tags))
		config.save("res://addons/advanced_logger/settings.cfg")
		
		print("Moved tags %s from %s to %s" % [tags, from_category, to_category])
	else:
		_test_passed = false
		_error_messages.append("Failed to load config file for moving tags")
		print_rich("[color=#ea6962]Failed to load config file for moving tags[/color]")
