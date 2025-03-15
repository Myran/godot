@tool
extends Node
class_name TestTagSetupManager

# This test validates the TagSetupManager functionality

var ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")
var TagSetupManager = preload("res://addons/advanced_logger/tag_setup_manager.gd")

# Instance to test
var _setup_manager = null
var _config = null

# Test signals
var _signal_received: bool = false
var _signal_name: String = ""
var _signal_params: Array = []

func _ready():
    print("\n=== Running TagSetupManager Tests ===")
    setup_test_environment()
    
    test_create_manager()
    test_default_setups()
    test_save_setup()
    test_rename_setup()
    test_delete_setup()
    test_signals()
    
    cleanup_test_environment()
    print("=== TagSetupManager Tests Complete ===\n")

func setup_test_environment():
    # Get config instance
    _config = ConfigManager.get_instance()
    
    # Create a setup manager for testing
    _setup_manager = TagSetupManager.new(_config)
    
    # Connect signals for testing
    _setup_manager.setup_changed.connect(_on_setup_changed)
    _setup_manager.setup_deleted.connect(_on_setup_deleted)
    _setup_manager.setup_renamed.connect(_on_setup_renamed)
    
    # Clear any existing setups in config
    var setups = _setup_manager.get_all_setups()
    for setup_name in setups:
        _config.set_value(_config.SECTION_SETUPS, setup_name, null)
    _config.save()

func cleanup_test_environment():
    # Clean up test setups
    var setups = _setup_manager.get_all_setups()
    for setup_name in setups:
        if setup_name.begins_with("test_"):
            _config.set_value(_config.SECTION_SETUPS, setup_name, null)
    _config.save()

# Signal handlers for testing
func _on_setup_changed(setup_name: String, is_new: bool):
    _signal_received = true
    _signal_name = "setup_changed"
    _signal_params = [setup_name, is_new]

func _on_setup_deleted(setup_name: String):
    _signal_received = true
    _signal_name = "setup_deleted"
    _signal_params = [setup_name]

func _on_setup_renamed(old_name: String, new_name: String):
    _signal_received = true
    _signal_name = "setup_renamed"
    _signal_params = [old_name, new_name]

func reset_signal_data():
    _signal_received = false
    _signal_name = ""
    _signal_params.clear()

# Test creating the manager
func test_create_manager():
    print("\nTesting TagSetupManager creation:")
    
    var is_valid = _setup_manager != null
    print("- Manager created: %s" % ("✓" if is_valid else "✗"))
    
    var is_config_valid = _setup_manager._config != null
    print("- Manager has config: %s" % ("✓" if is_config_valid else "✗"))
    
    print("Manager creation test: %s" % ("PASSED" if is_valid and is_config_valid else "FAILED"))

# Test creating default setups
func test_default_setups():
    print("\nTesting default setups creation:")
    
    # Create default setups
    _setup_manager.create_default_setups()
    
    # Check if they exist
    var setups = _setup_manager.get_all_setups()
    var has_default = setups.has("default")
    var has_debug_network = setups.has("debug_network")
    
    print("- Default setup created: %s" % ("✓" if has_default else "✗"))
    print("- Debug network setup created: %s" % ("✓" if has_debug_network else "✗"))
    
    # Verify contents
    var default_setup = _setup_manager.get_setup("default")
    var default_active_empty = default_setup.has("active_tags") and default_setup["active_tags"].size() == 0
    var default_ignored_empty = default_setup.has("ignored_tags") and default_setup["ignored_tags"].size() == 0
    
    print("- Default setup has empty active tags: %s" % ("✓" if default_active_empty else "✗"))
    print("- Default setup has empty ignored tags: %s" % ("✓" if default_ignored_empty else "✗"))
    
    var debug_setup = _setup_manager.get_setup("debug_network")
    var debug_has_network = debug_setup.has("active_tags") and debug_setup["active_tags"].size() == 1 and debug_setup["active_tags"][0] == "network"
    
    print("- Debug setup has network tag: %s" % ("✓" if debug_has_network else "✗"))
    
    print("Default setups test: %s" % ("PASSED" if has_default and has_debug_network and 
                                        default_active_empty and default_ignored_empty and 
                                        debug_has_network else "FAILED"))

# Test saving setups
func test_save_setup():
    print("\nTesting setup saving:")
    
    # Test saving a new setup
    reset_signal_data()
    var result = _setup_manager.save_setup("test_setup", ["tag1", "tag2"], ["tag3"])
    
    var success = result == OK
    print("- Save returned OK: %s" % ("✓" if success else "✗"))
    
    var setup_exists = _setup_manager.get_all_setups().has("test_setup")
    print("- Setup exists after save: %s" % ("✓" if setup_exists else "✗"))
    
    # Check if signal was emitted
    var signal_correct = _signal_received and _signal_name == "setup_changed" and _signal_params.size() == 2 and _signal_params[0] == "test_setup" and _signal_params[1] == true
    print("- Setup changed signal emitted correctly: %s" % ("✓" if signal_correct else "✗"))
    
    # Verify contents
    var setup = _setup_manager.get_setup("test_setup")
    var has_correct_active = setup.has("active_tags") and setup["active_tags"].size() == 2 and setup["active_tags"][0] == "tag1" and setup["active_tags"][1] == "tag2"
    var has_correct_ignored = setup.has("ignored_tags") and setup["ignored_tags"].size() == 1 and setup["ignored_tags"][0] == "tag3"
    
    print("- Setup has correct active tags: %s" % ("✓" if has_correct_active else "✗"))
    print("- Setup has correct ignored tags: %s" % ("✓" if has_correct_ignored else "✗"))
    
    # Test updating an existing setup
    reset_signal_data()
    result = _setup_manager.save_setup("test_setup", ["tag4"], ["tag5", "tag6"])
    
    success = result == OK
    var signal_update_correct = _signal_received and _signal_name == "setup_changed" and _signal_params.size() == 2 and _signal_params[0] == "test_setup" and _signal_params[1] == false
    print("- Update signal emitted correctly: %s" % ("✓" if signal_update_correct else "✗"))
    
    # Verify updated contents
    setup = _setup_manager.get_setup("test_setup")
    var has_updated_active = setup.has("active_tags") and setup["active_tags"].size() == 1 and setup["active_tags"][0] == "tag4"
    var has_updated_ignored = setup.has("ignored_tags") and setup["ignored_tags"].size() == 2 and setup["ignored_tags"][0] == "tag5" and setup["ignored_tags"][1] == "tag6"
    
    print("- Setup has updated active tags: %s" % ("✓" if has_updated_active else "✗"))
    print("- Setup has updated ignored tags: %s" % ("✓" if has_updated_ignored else "✗"))
    
    print("Setup saving test: %s" % ("PASSED" if success and setup_exists and signal_correct and 
                                      has_correct_active and has_correct_ignored and 
                                      signal_update_correct and has_updated_active and 
                                      has_updated_ignored else "FAILED"))

# Test renaming setups
func test_rename_setup():
    print("\nTesting setup renaming:")
    
    # First create a setup to rename
    _setup_manager.save_setup("test_rename_source", ["tag1"], ["tag2"])
    
    # Test renaming
    reset_signal_data()
    var result = _setup_manager.rename_setup("test_rename_source", "test_rename_target")
    
    var success = result == OK
    print("- Rename returned OK: %s" % ("✓" if success else "✗"))
    
    var old_exists = _setup_manager.get_all_setups().has("test_rename_source")
    var new_exists = _setup_manager.get_all_setups().has("test_rename_target")
    
    print("- Old setup name no longer exists: %s" % ("✓" if not old_exists else "✗"))
    print("- New setup name exists: %s" % ("✓" if new_exists else "✗"))
    
    # Check if signal was emitted
    var signal_correct = _signal_received and _signal_name == "setup_renamed" and _signal_params.size() == 2 and _signal_params[0] == "test_rename_source" and _signal_params[1] == "test_rename_target"
    print("- Setup renamed signal emitted correctly: %s" % ("✓" if signal_correct else "✗"))
    
    # Verify data was preserved
    var setup = _setup_manager.get_setup("test_rename_target")
    var data_preserved = setup.has("active_tags") and setup["active_tags"].size() == 1 and setup["active_tags"][0] == "tag1" and setup.has("ignored_tags") and setup["ignored_tags"].size() == 1 and setup["ignored_tags"][0] == "tag2"
    
    print("- Setup data preserved after rename: %s" % ("✓" if data_preserved else "✗"))
    
    # Test renaming non-existent setup
    result = _setup_manager.rename_setup("nonexistent_setup", "new_name")
    var fails_correctly = result == ERR_DOES_NOT_EXIST
    print("- Renaming non-existent setup fails correctly: %s" % ("✓" if fails_correctly else "✗"))
    
    print("Setup renaming test: %s" % ("PASSED" if success and not old_exists and new_exists and 
                                        signal_correct and data_preserved and fails_correctly else "FAILED"))

# Test deleting setups
func test_delete_setup():
    print("\nTesting setup deletion:")
    
    # First create a setup to delete
    _setup_manager.save_setup("test_delete", ["tag1"], ["tag2"])
    
    # Test deletion
    reset_signal_data()
    var result = _setup_manager.delete_setup("test_delete")
    
    var success = result == OK
    print("- Delete returned OK: %s" % ("✓" if success else "✗"))
    
    var setup_exists = _setup_manager.get_all_setups().has("test_delete")
    print("- Setup no longer exists: %s" % ("✓" if not setup_exists else "✗"))
    
    # Check if signal was emitted
    var signal_correct = _signal_received and _signal_name == "setup_deleted" and _signal_params.size() == 1 and _signal_params[0] == "test_delete"
    print("- Setup deleted signal emitted correctly: %s" % ("✓" if signal_correct else "✗"))
    
    # Test deleting non-existent setup
    result = _setup_manager.delete_setup("nonexistent_setup")
    var fails_correctly = result == ERR_DOES_NOT_EXIST
    print("- Deleting non-existent setup fails correctly: %s" % ("✓" if fails_correctly else "✗"))
    
    print("Setup deletion test: %s" % ("PASSED" if success and not setup_exists and signal_correct and 
                                        fails_correctly else "FAILED"))

# Test signal emissions
func test_signals():
    print("\nTesting signal emissions:")
    
    # Test setup_changed signal with new setup
    reset_signal_data()
    _setup_manager.save_setup("test_signal_new", ["tag1"], [])
    
    var new_signal_correct = _signal_received and _signal_name == "setup_changed" and _signal_params.size() == 2 and _signal_params[0] == "test_signal_new" and _signal_params[1] == true
    print("- setup_changed signal (new setup): %s" % ("✓" if new_signal_correct else "✗"))
    
    # Test setup_changed signal with existing setup
    reset_signal_data()
    _setup_manager.save_setup("test_signal_new", ["tag2"], [])
    
    var update_signal_correct = _signal_received and _signal_name == "setup_changed" and _signal_params.size() == 2 and _signal_params[0] == "test_signal_new" and _signal_params[1] == false
    print("- setup_changed signal (update setup): %s" % ("✓" if update_signal_correct else "✗"))
    
    # Test setup_renamed signal
    reset_signal_data()
    _setup_manager.rename_setup("test_signal_new", "test_signal_renamed")
    
    var rename_signal_correct = _signal_received and _signal_name == "setup_renamed" and _signal_params.size() == 2 and _signal_params[0] == "test_signal_new" and _signal_params[1] == "test_signal_renamed"
    print("- setup_renamed signal: %s" % ("✓" if rename_signal_correct else "✗"))
    
    # Test setup_deleted signal
    reset_signal_data()
    _setup_manager.delete_setup("test_signal_renamed")
    
    var delete_signal_correct = _signal_received and _signal_name == "setup_deleted" and _signal_params.size() == 1 and _signal_params[0] == "test_signal_renamed"
    print("- setup_deleted signal: %s" % ("✓" if delete_signal_correct else "✗"))
    
    print("Signal emissions test: %s" % ("PASSED" if new_signal_correct and update_signal_correct and 
                                          rename_signal_correct and delete_signal_correct else "FAILED"))
