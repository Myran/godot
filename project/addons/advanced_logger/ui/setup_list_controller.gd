@tool
class_name SetupListController
extends RefCounted
## Controller for tag setup list operations
##
## Manages the tag setups list UI and operations, including
## loading, saving, renaming, and deleting tag setups.

signal setup_loaded(setup_name: String, active_tags: Array, ignored_tags: Array)
signal setup_selected(setup_name: String)
signal setup_renamed(old_name: String, new_name: String)
signal setup_deleted(setup_name: String)

# UI Components
var _setups_list: ItemList

# Dependencies
var _setup_manager

# Signal connection tracking
var _signals_connected: bool = false

# Initialize the controller with dependencies
func _init(setup_manager) -> void:
	_setup_manager = setup_manager
	
	# Connect to setup manager signals
	_setup_manager.setup_changed.connect(_on_setup_changed)
	_setup_manager.setup_deleted.connect(_on_setup_deleted)
	_setup_manager.setup_renamed.connect(_on_setup_renamed)

## Setup the UI components
func setup(setups_list: ItemList) -> void:
	_setups_list = setups_list
	
	# Configure ItemList settings
	if _setups_list:
		_setups_list.mouse_filter = Control.MOUSE_FILTER_PASS
		_setups_list.focus_mode = Control.FOCUS_ALL
		_setups_list.allow_rmb_select = true
		_setups_list.allow_reselect = true
		
		# Only connect signals if not already connected
		if not _signals_connected:
			_connect_signals()
			_signals_connected = true

## Connect UI signals - only called once
func _connect_signals() -> void:
	if _setups_list:
		_setups_list.item_activated.connect(_on_setups_list_item_activated)
		_setups_list.item_clicked.connect(_on_setups_list_item_clicked)

## Load setups from configuration and refresh the UI
func load_setups() -> void:
	# Create default setups if none exist
	if _setup_manager.get_all_setups().is_empty():
		_setup_manager.create_default_setups()
	
	refresh_setups_list()

## Refresh the setups list UI
func refresh_setups_list() -> void:
	if not _setups_list:
		return
		
	_setups_list.clear()

	# Get all setups and sort them
	var setups = _setup_manager.get_all_setups()
	var sorted_names = setups.keys()
	sorted_names.sort()

	for setup_name in sorted_names:
		# Assign icons based on setup content
		var icon_index = 0 # Default icon
		var setup = setups[setup_name]

		# Different icon if it has active tags
		if setup.has("active_tags") and setup["active_tags"].size() > 0:
			icon_index = 1

		# Different icon if it has both active and ignored tags
		if setup.has("ignored_tags") and setup["ignored_tags"].size() > 0:
			icon_index = 2

		_setups_list.add_item(setup_name, null, true)

## Save current tag selection as a setup
func save_setup(setup_name: String, active_tags: Array[String], ignored_tags: Array[String]) -> Error:
	var result = _setup_manager.save_setup(setup_name, active_tags, ignored_tags)
	if result == OK:
		refresh_setups_list()
	return result

## Load a tag setup
func load_setup(setup_name: String) -> Dictionary:
	var setup = _setup_manager.get_setup(setup_name)
	if setup.is_empty():
		push_warning("Tag setup not found: %s" % setup_name)
		return {}
	
	print_rich("[color=#%s]DEBUG: Raw setup data: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, setup])
		
	# Extract active and ignored tags
	var active_tags: Array[String] = []
	var ignored_tags: Array[String] = []
	
	if setup.has("active_tags"):
		var raw_active = setup["active_tags"]
		print_rich("[color=#%s]DEBUG: Raw active tags: %s (type: %s)[/color]" % 
			[LoggerColors.DEBUG_HTML, raw_active, typeof(raw_active)])
		
		if raw_active is Array:
			for tag in raw_active:
				if tag is String:
					active_tags.append(tag)
	
	if setup.has("ignored_tags"):
		var raw_ignored = setup["ignored_tags"]
		print_rich("[color=#%s]DEBUG: Raw ignored tags: %s (type: %s)[/color]" % 
			[LoggerColors.DEBUG_HTML, raw_ignored, typeof(raw_ignored)])
		
		if raw_ignored is Array:
			for tag in raw_ignored:
				if tag is String:
					ignored_tags.append(tag)
	
	print_rich("[color=#%s]DEBUG: Converted active tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, active_tags])
	print_rich("[color=#%s]DEBUG: Converted ignored tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, ignored_tags])
	
	# Emit signal
	setup_loaded.emit(setup_name, active_tags, ignored_tags)
	
	return {
		"setup_name": setup_name,
		"active_tags": active_tags,
		"ignored_tags": ignored_tags
	}

## Rename a setup
func rename_setup(old_name: String, new_name: String) -> Error:
	return _setup_manager.rename_setup(old_name, new_name)

## Delete a setup
func delete_setup(setup_name: String) -> Error:
	return _setup_manager.delete_setup(setup_name)

## Signal handlers
func _on_setups_list_item_activated(index: int) -> void:
	var setup_name = _setups_list.get_item_text(index)
	load_setup(setup_name)

func _on_setups_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	# Only show context menu on right click
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var setup_name = _setups_list.get_item_text(index)
	setup_selected.emit(setup_name)
	
	# Create context menu
	var menu = PopupMenu.new()
	menu.add_item("Load", 0)
	menu.add_item("Rename", 1)
	menu.add_item("Delete", 2)

	var handle_menu_selection = func(idx: int):
		match idx:
			0: # Load
				load_setup(setup_name)
			1: # Rename
				setup_renamed.emit(setup_name, "")  # Signal to show rename dialog
			2: # Delete
				delete_setup(setup_name)
		menu.queue_free()

	menu.id_pressed.connect(handle_menu_selection)

	# Add menu to scene and position at mouse
	_setups_list.get_parent().get_parent().get_parent().add_child(menu)
	menu.position = _setups_list.get_global_transform().origin + at_position
	menu.popup()

# Handlers for setup manager signals
func _on_setup_changed(setup_name: String, is_new: bool) -> void:
	refresh_setups_list()

func _on_setup_deleted(setup_name: String) -> void:
	refresh_setups_list()
	setup_deleted.emit(setup_name)

func _on_setup_renamed(old_name: String, new_name: String) -> void:
	refresh_setups_list()
