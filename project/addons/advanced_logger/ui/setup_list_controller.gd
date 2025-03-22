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
		
		# Check if signals need to be connected or reconnected
		if not _signals_connected:
			# First time setup
			_connect_signals()
			_signals_connected = true
		else:
			# Reconnect signals to ensure they work after refresh
			_disconnect_signals()
			_connect_signals()

## Disconnect UI signals if they're connected
func _disconnect_signals() -> void:
	if _setups_list:
		if _setups_list.item_activated.is_connected(_on_setups_list_item_activated):
			_setups_list.item_activated.disconnect(_on_setups_list_item_activated)
		if _setups_list.item_clicked.is_connected(_on_setups_list_item_clicked):
			_setups_list.item_clicked.disconnect(_on_setups_list_item_clicked)
			
	# Reset signal connection flag to ensure proper reconnection
	_signals_connected = false

## Connect UI signals
func _connect_signals() -> void:
	if _setups_list:
		_setups_list.item_activated.connect(_on_setups_list_item_activated)
		_setups_list.item_clicked.connect(_on_setups_list_item_clicked)
		
	# Signal connection is now established
	_signals_connected = true

## Load setups from configuration and refresh the UI
func load_setups() -> void:
	# Create default setups if none exist
	if _setup_manager.get_all_setups().is_empty():
		_setup_manager.create_default_setups()
	
	refresh_setups_list()

## Refresh the setups list UI
func refresh_setups_list() -> void:
	if not _setups_list:
		print_rich("[color=#%s]ERROR: Setup list is null, cannot refresh[/color]" % [LoggerColors.ERROR_HTML])
		return
		
	# Debug output before refresh
	print_rich("[color=#%s]DEBUG: Refreshing setup list[/color]" % [LoggerColors.DEBUG_HTML])
	
	# Clear the list
	_setups_list.clear()

	# Get all setups and sort them
	var setups = _setup_manager.get_all_setups()
	var sorted_names = setups.keys()
	sorted_names.sort()
	
	print_rich("[color=#%s]DEBUG: Found %d setups to display[/color]" % 
		[LoggerColors.DEBUG_HTML, sorted_names.size()])

	# Track setup index for debugging
	var setup_index = 0
	
	for setup_name in sorted_names:
		# Skip null or empty setup names
		if setup_name == null or setup_name.is_empty():
			print_rich("[color=#%s]WARNING: Skipping empty/null setup name[/color]" % [LoggerColors.WARNING_HTML])
			continue
			
		# Get setup info
		var setup = setups[setup_name]
		var has_active = setup.has("active_tags") and setup["active_tags"].size() > 0
		var has_ignored = setup.has("ignored_tags") and setup["ignored_tags"].size() > 0
		
		# Format name with emoji based on content
		var display_name = ""
		
		if has_active and has_ignored:
			display_name = "📋 " + setup_name  # Setup with both active and ignored tags
		elif has_active:
			display_name = "📥 " + setup_name  # Setup with only active tags
		elif has_ignored:
			display_name = "📤 " + setup_name  # Setup with only ignored tags
		else:
			display_name = "📄 " + setup_name  # Empty setup
		
		# Add the formatted item with the exact setup name as metadata
		_setups_list.add_item(display_name, null, true)
		
		# Make sure we're setting metadata at the correct index
		var item_index = _setups_list.item_count - 1
		
		# Set the metadata - the exact, unmodified setup_name is critical
		_setups_list.set_item_metadata(item_index, setup_name)
		
		# Add tooltip showing the exact name to help with debugging
		_setups_list.set_item_tooltip(item_index, "Setup name: '" + setup_name + "'")
		
		# Verify metadata was set correctly
		var verify_metadata = _setups_list.get_item_metadata(item_index)
		if verify_metadata != setup_name:
			print_rich("[color=#%s]ERROR: Metadata verification failed for setup '%s' (got '%s')[/color]" % 
				[LoggerColors.ERROR_HTML, setup_name, str(verify_metadata)])
				
		# Debug output
		print_rich("[color=#%s]DEBUG: Added setup #%d: '%s' at index %d with metadata '%s'[/color]" % 
			[LoggerColors.DEBUG_HTML, setup_index, display_name, item_index, setup_name])
			
		setup_index += 1
	
	# Reconnect signals after refreshing the list
	if _signals_connected:
		_disconnect_signals()
	_connect_signals()
	
	print_rich("[color=#%s]DEBUG: Setup list refresh complete with %d items[/color]" % 
		[LoggerColors.DEBUG_HTML, _setups_list.item_count])

## Save current tag selection as a setup
func save_setup(setup_name: String, active_tags: Array[String], ignored_tags: Array[String]) -> Error:
	var result = _setup_manager.save_setup(setup_name, active_tags, ignored_tags)
	if result == OK:
		refresh_setups_list()
	return result

## Load a tag setup
func load_setup(setup_name: String) -> Dictionary:
	if setup_name == null or setup_name.is_empty():
		print_rich("[color=#%s]ERROR: Cannot load setup with null/empty name[/color]" % [LoggerColors.ERROR_HTML])
		return {}
	
	print_rich("[color=#%s]DEBUG: Loading setup: '%s'[/color]" % [LoggerColors.DEBUG_HTML, setup_name])
	
	var setup = _setup_manager.get_setup(setup_name)
	if setup.is_empty():
		print_rich("[color=#%s]WARNING: Tag setup not found: '%s'[/color]" % [LoggerColors.WARNING_HTML, setup_name])
		
		# Try to find the setup by checking all setup names case-insensitive
		var all_setups = _setup_manager.get_all_setups()
		var found_alternate = false
		
		for existing_name in all_setups.keys():
			if existing_name.to_lower() == setup_name.to_lower():
				print_rich("[color=#%s]RECOVERY: Found case-insensitive match '%s' for '%s'[/color]" % 
					[LoggerColors.WARNING_HTML, existing_name, setup_name])
				setup_name = existing_name
				setup = all_setups[existing_name]
				found_alternate = true
				break
				
		if not found_alternate:
			return {}
	
	print_rich("[color=#%s]DEBUG: Raw setup data: %s[/color]" % [LoggerColors.DEBUG_HTML, setup])
		
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
	print_rich("[color=#%s]DEBUG: Emitting setup_loaded signal for '%s'[/color]" % 
		[LoggerColors.DEBUG_HTML, setup_name])
	setup_loaded.emit(setup_name, active_tags, ignored_tags)
	
	print_rich("[color=#%s]SUCCESS: Setup '%s' loaded successfully[/color]" % 
		[LoggerColors.SUCCESS_HTML, setup_name])
	
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
	# First debug the list contents to verify what we have
	if _setups_list.item_count > 0:
		print_rich("[color=#%s]DEBUG: Current setup list contents:[/color]" % [LoggerColors.DEBUG_HTML])
		for i in range(_setups_list.item_count):
			var item_text = _setups_list.get_item_text(i)
			var item_meta = _setups_list.get_item_metadata(i)
			print_rich("[color=#%s]  Item #%d: Text='%s', Metadata='%s'[/color]" % 
				[LoggerColors.DEBUG_HTML, i, item_text, str(item_meta)])
	
	if index < 0 or index >= _setups_list.item_count:
		print_rich("[color=#%s]ERROR: Invalid setup index: %d (item count: %d)[/color]" % 
			[LoggerColors.ERROR_HTML, index, _setups_list.item_count])
		return
		
	# Get the display text for context
	var display_text = _setups_list.get_item_text(index)
	print_rich("[color=#%s]DEBUG: Item activated: index=%d, text='%s'[/color]" % 
		[LoggerColors.DEBUG_HTML, index, display_text])
		
	var setup_name = _setups_list.get_item_metadata(index)
	if setup_name == null or not (setup_name is String):
		print_rich("[color=#%s]ERROR: Invalid setup name metadata at index %d[/color]" % [LoggerColors.ERROR_HTML, index])
		
		# Try to recover by using the display name instead
		var display_name = _setups_list.get_item_text(index)
		if display_name and display_name.length() > 3:
			# Find the first space after the emoji (which might be multi-byte)
			var space_pos = display_name.find(" ")
			if space_pos != -1 and space_pos + 1 < display_name.length():
				# Extract everything after the space
				setup_name = display_name.substr(space_pos + 1).strip_edges()
				print_rich("[color=#%s]RECOVERY: Using display name: '%s'[/color]" % [LoggerColors.WARNING_HTML, setup_name])
			else:
				print_rich("[color=#%s]ERROR: Could not parse display name: '%s'[/color]" % [LoggerColors.ERROR_HTML, display_name])
				return
		else:
			# Cannot recover
			print_rich("[color=#%s]ERROR: Display name too short: '%s'[/color]" % [LoggerColors.ERROR_HTML, display_name])
			return
	
	# Now we have a valid setup_name
	load_setup(setup_name)

func _on_setups_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	# Only show context menu on right click
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var setup_name = _setups_list.get_item_metadata(index)
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

	# Instead of adding the menu to the parent, use the popup_menu method
	# This is the simplest and most reliable way to show a context menu
	# in Godot and handles all positioning correctly
	
	# Create a new PopupMenu directly
	var popup = PopupMenu.new()
	popup.add_item("Load", 0)
	popup.add_item("Rename", 1)
	popup.add_item("Delete", 2)
	
	# Validate setup_name before using it
	if setup_name == null or not (setup_name is String):
		print_rich("[color=#%s]ERROR: Invalid setup name metadata at index %d[/color]" % [LoggerColors.ERROR_HTML, index])
		
		# Try to recover by using the display name instead
		var display_name = _setups_list.get_item_text(index)
		if display_name and display_name.length() > 3:
			# Find the first space after the emoji (which might be multi-byte)
			var space_pos = display_name.find(" ")
			if space_pos != -1 and space_pos + 1 < display_name.length():
				# Extract everything after the space
				setup_name = display_name.substr(space_pos + 1).strip_edges()
				print_rich("[color=#%s]RECOVERY: Using display name: '%s'[/color]" % [LoggerColors.WARNING_HTML, setup_name])
			else:
				print_rich("[color=#%s]ERROR: Could not parse display name: '%s'[/color]" % [LoggerColors.ERROR_HTML, display_name])
				popup.queue_free()
				return
		else:
			# Cannot recover
			print_rich("[color=#%s]ERROR: Display name too short: '%s'[/color]" % [LoggerColors.ERROR_HTML, display_name])
			popup.queue_free()
			return
	
	# Now setup_name is validated and guaranteed to be a valid string
	print_rich("[color=#%s]DEBUG: Using setup name for menu actions: '%s'[/color]" % [LoggerColors.DEBUG_HTML, setup_name])
	
	# Connect to the index_pressed signal
	popup.id_pressed.connect(func(idx: int):
		match idx:
			0: # Load
				load_setup(setup_name)
			1: # Rename
				# Extra validation before emitting signal
				if setup_name != null and setup_name is String and not setup_name.is_empty():
					print_rich("[color=#%s]DEBUG: Emitting setup_renamed signal for '%s'[/color]" % 
						[LoggerColors.DEBUG_HTML, setup_name])
					setup_renamed.emit(setup_name, "")  # Signal to show rename dialog
				else:
					print_rich("[color=#%s]ERROR: Cannot rename setup with invalid name: '%s'[/color]" % 
						[LoggerColors.ERROR_HTML, setup_name])
			2: # Delete
				if setup_name != null and setup_name is String and not setup_name.is_empty():
					delete_setup(setup_name)
				else:
					print_rich("[color=#%s]ERROR: Cannot delete setup with invalid name: '%s'[/color]" % 
						[LoggerColors.ERROR_HTML, setup_name])
		popup.queue_free()
	)
	
	# Add to tree temporarily
	_setups_list.add_child(popup)
	
	# Show the popup menu at the right-click position
	var global_rect = Rect2(_setups_list.get_screen_position() + at_position, Vector2.ONE)
	popup.popup(global_rect)
	
	# Debug output
	print_rich("[color=#%s]DEBUG: Menu positioning - rect position: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, global_rect.position])

# Handlers for setup manager signals
func _on_setup_changed(setup_name: String, is_new: bool) -> void:
	refresh_setups_list()

func _on_setup_deleted(setup_name: String) -> void:
	refresh_setups_list()
	setup_deleted.emit(setup_name)

func _on_setup_renamed(old_name: String, new_name: String) -> void:
	refresh_setups_list()
