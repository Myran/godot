@tool
class_name LoggerDock
extends Control

# Single signal to notify of any settings change
signal settings_changed

@export var logger: Logger
@export var run_tests: bool = true

# UI Builder helper class for creating UI elements
class UIBuilder:
	## Creates a section with a title in a VBoxContainer
	## Returns the created section container
	func create_section(parent: Container, title: String, font_size: int = 16) -> VBoxContainer:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return null

		var section := VBoxContainer.new()
		parent.add_child(section)

		var header := Label.new()
		header.text = title
		header.add_theme_font_size_override("font_size", font_size)
		section.add_child(header)

		return section

	## Creates a header with a button
	## Returns the created button for connecting signals
	func create_header_with_button(parent: Container, title: String,
			button_text: String, font_size: int = 16) -> Button:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return null

		var header := HBoxContainer.new()
		parent.add_child(header)

		var label := Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", font_size)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(label)

		var button := Button.new()
		button.text = button_text
		header.add_child(button)

		return button

	## Creates a labeled field container
	## Returns the container for adding controls
	func create_labeled_field(parent: Container, label_text: String) -> HBoxContainer:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return null

		var container := HBoxContainer.new()
		parent.add_child(container)

		var label := Label.new()
		label.text = label_text
		container.add_child(label)

		return container

	## Creates a spinner with an apply button
	## Returns [SpinBox, Button]
	func create_spinner_with_button(parent: Container, min_val: float, max_val: float,
			step: float, default_val: float, button_text: String) -> Array[Control]:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return []

		var container := HBoxContainer.new()
		parent.add_child(container)

		var spinner := SpinBox.new()
		spinner.min_value = min_val
		spinner.max_value = max_val
		spinner.step = step
		spinner.value = default_val
		spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(spinner)

		var button := Button.new()
		button.text = button_text
		container.add_child(button)

		return [spinner, button]

	## Creates a note label with custom color
	## Returns the created label
	func create_note_label(parent: Container, text: String, color: Color = Color(1,1,1,0.6)) -> Label:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return null

		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		parent.add_child(label)
		return label

	## Creates a grid container with specified columns
	## Returns the created grid container
	func create_grid(parent: Container, columns: int = 2) -> GridContainer:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return null

		var grid := GridContainer.new()
		grid.columns = columns
		parent.add_child(grid)
		return grid

	## Creates a tree section with a title
	## Returns [Container, Tree]
	func create_tree_section(parent: Container, title: String) -> Array[Control]:
		if not parent:
			push_error("UIBuilder: Parent container is null")
			return []

		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent.add_child(container)

		var label := Label.new()
		label.text = title
		container.add_child(label)

		var tree := Tree.new()
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tree.allow_rmb_select = true
		container.add_child(tree)

		return [container, tree]

	## Creates a labeled control with any control type
	## Returns the created control for further customization
	func create_labeled_control(parent: Container, label_text: String, control: Control) -> Control:
		if not parent or not control:
			push_error("UIBuilder: Parent container or control is null")
			return null

		var container := HBoxContainer.new()
		parent.add_child(container)

		var label := Label.new()
		label.text = label_text
		container.add_child(label)

		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(control)

		return control

# Tag Tree Control for managing tags with consistent interface
class TagTreeControl extends Tree:
	## Emitted when a tag is activated (double-clicked)
	signal tag_activated(tag_data: TagData)
	## Emitted when a tag is selected
	signal tag_selected(tag_data: TagData)
	## Emitted when a tag is added to the tree
	signal tag_added(tag: String)
	## Emitted when a tag is removed from the tree
	signal tag_removed(tag: String)

	var title: String
	var tag_type: String
	var tag_color: Color
	var root_item: TreeItem

	func _init(p_title: String, p_tag_type: String, p_color: Color) -> void:
		title = p_title
		tag_type = p_tag_type
		tag_color = p_color

		# Setup tree
		allow_rmb_select = true
		select_mode = SELECT_MULTI

		# Create root
		root_item = create_item()
		if root_item:
			root_item.set_text(0, title)
			root_item.set_selectable(0, false)
		else:
			push_error("TagTreeControl: Failed to create root item")

		# Connect signals
		item_activated.connect(_on_item_activated)
		item_selected.connect(_on_item_selected)

	## Adds a tag to the tree
	## Returns the created TreeItem or null if failed
	func add_tag(tag: String, count: int = 0) -> TreeItem:
		if tag.is_empty() or not root_item:
			push_warning("TagTreeControl: Cannot add empty tag or root is null")
			return null

		# Check if tag already exists
		var existing_item = find_tag_item(tag)
		if existing_item:
			return existing_item

		var item := create_item(root_item)
		if not item:
			push_error("TagTreeControl: Failed to create tree item")
			return null

		var display_text = tag
		if count > 0:
			display_text = "%s (%d)" % [tag, count]

		# Check if it's a level tag, group tag, or regular tag
		if tag.begins_with("level:"):
			# Style for level tags
			item.set_custom_color(0, Color(0.8, 0.6, 0.2))  # Orange-ish color
			item.set_text(0, tag)
		elif "+" in tag:
			# Style for group tags
			item.set_custom_bg_color(0, Color(0.3, 0.3, 0.5, 0.2))  # Blueish background
			item.set_text(0, "[Group] " + tag)
		else:
			# Regular tag
			item.set_text(0, display_text)
			item.set_custom_color(0, tag_color)

		var tag_data := TagData.new(tag, tag_type, count)
		item.set_metadata(0, tag_data)

		tag_added.emit(tag)
		return item

	## Finds a tag item by name
	## Returns the TreeItem or null if not found
	func find_tag_item(tag: String) -> TreeItem:
		if tag.is_empty() or not root_item:
			return null

		var child := root_item.get_first_child()
		while child:
			var metadata = child.get_metadata(0)
			if metadata is TagData and metadata.tag == tag:
				return child
			child = child.get_next()
		return null

	## Removes a tag from the tree
	## Returns true if successful
	func remove_tag(tag: String) -> bool:
		if tag.is_empty() or not root_item:
			return false

		var child := root_item.get_first_child()
		while child:
			var metadata = child.get_metadata(0)
			if metadata is TagData and metadata.tag == tag:
				child.free()
				tag_removed.emit(tag)
				return true
			child = child.get_next()
		return false

	## Clears all tags from the tree
	func clear_tags() -> void:
		if not root_item:
			return

		var child := root_item.get_first_child()
		while child:
			var next_child = child.get_next()

			# Get tag before removing
			var metadata = child.get_metadata(0)
			if metadata is TagData:
				tag_removed.emit(metadata.tag)

			child.free()
			child = next_child

	## Gets the currently selected tag data
	## Returns TagData or null if none selected
	func get_selected_tag_data() -> TagData:
		var selected := get_selected()
		if not selected:
			return null

		if selected.has_meta(str(0)):
			var metadata = selected.get_metadata(0)
			if metadata is TagData:
				return metadata
		return null

	## Gets all selected tag data items
	## Returns an array of TagData objects
	func get_selected_tag_data_array() -> Array[TagData]:
		var data_array: Array[TagData] = []
		var selected = get_selected()

		while selected:
			var metadata = selected.get_metadata(0)
			if metadata is TagData:
				data_array.append(metadata)
			selected = get_next_selected(selected)

		return data_array

	## Gets all tags in the tree
	## Returns an array of tag strings
	func get_all_tags() -> Array[String]:
		var tags: Array[String] = []
		if not root_item:
			return tags

		var child := root_item.get_first_child()
		while child:
			var metadata = child.get_metadata(0)
			if metadata is TagData:
				tags.append(metadata.tag)
			child = child.get_next()
		return tags

	## Gets all selected items
	## Returns an array of TreeItems
	func get_selected_items() -> Array[TreeItem]:
		var items: Array[TreeItem] = []
		var selected = get_selected()

		while selected:
			items.append(selected)
			selected = get_next_selected(selected)

		return items

	## Checks if the tree contains a tag
	func has_tag(tag: String) -> bool:
		return find_tag_item(tag) != null

	## Returns true if the tree is empty
	func is_empty() -> bool:
		return not root_item or not root_item.get_first_child()

	## Handles item activation internally
	func _on_item_activated() -> void:
		var tag_data := get_selected_tag_data()
		if tag_data:
			tag_activated.emit(tag_data)

	## Handles item selection internally
	func _on_item_selected() -> void:
		var tag_data := get_selected_tag_data()
		if tag_data:
			tag_selected.emit(tag_data)

# TagData class for storing tag information with proper typing
class TagData extends Resource:
	## The tag string
	var tag: String
	## The type of tag (available, filter, ignore)
	var type: String
	## Usage count for the tag
	var count: int

	func _init(p_tag: String = "", p_type: String = "", p_count: int = 0) -> void:
		tag = p_tag
		type = p_type
		count = p_count

	## Creates a visual preview for drag operations
	## Returns a Label control
	func create_preview() -> Label:
		var preview := Label.new()
		var display_text = tag
		if count > 0:
			display_text += " (%d)" % count

		preview.text = display_text
		preview.modulate = Color(1, 1, 1, 0.8)

		# Add padding for better visibility
		preview.add_theme_constant_override("margin_left", 10)
		preview.add_theme_constant_override("margin_right", 10)
		preview.add_theme_constant_override("margin_top", 5)
		preview.add_theme_constant_override("margin_bottom", 5)

		return preview

	## Returns a string representation of the tag data
	func _to_string() -> String:
		if count > 0:
			return "%s (%d) [%s]" % [tag, count, type]
		return "%s [%s]" % [tag, type]

# UI elements
var ui_builder: UIBuilder
var level_option: OptionButton
var buffer_size_spin: SpinBox
var retro_spin: SpinBox
var run_tests_check: CheckBox
var buffer_apply_button: Button
var retro_apply_button: Button
var run_tests_button: Button
var scan_tags_button: Button
var group_selected_button: Button

# Tag tree controls
var available_tags_tree: TagTreeControl
var filter_tags_tree: TagTreeControl
var ignore_tags_tree: TagTreeControl

# Tag setup library
var setups_tree: Tree
var setup_root: TreeItem

# Tab related elements
var tab_container: TabContainer
var format_tab: FormatTab

# Initialization
func _init(logger_instance: Logger) -> void:
	if not logger_instance:
		push_error("Logger dock created with null logger instance")
		return

	logger = logger_instance
	ui_builder = UIBuilder.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	if not logger:
		push_error("Logger dock has no logger instance")
		return

	_setup_ui()
	_connect_signals()
	_update_ui_from_logger()

# UI Setup with UIBuilder pattern
func _setup_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# Create tab container for multiple tabs
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tab_container)

	# Create main tab
	var main_tab = VBoxContainer.new()
	main_tab.name = "General"
	tab_container.add_child(main_tab)

	# Create format tab
	format_tab = FormatTab.new(self, logger, ui_builder, tab_container)

	# General settings
	var general_section = ui_builder.create_section(main_tab, "General Settings")

	# Test section
	var test_section = ui_builder.create_section(main_tab, "Self-Test Settings")
	if not test_section:
		push_error("Failed to create test section")
		return

	var test_container := HBoxContainer.new()
	test_section.add_child(test_container)

	run_tests_check = CheckBox.new()
	run_tests_check.text = "Run Self-Tests on Project Start"
	run_tests_check.tooltip_text = "If enabled, Logger will automatically run self-tests when the project starts"
	run_tests_check.button_pressed = run_tests
	test_container.add_child(run_tests_check)

	run_tests_button = Button.new()
	run_tests_button.text = "Run Tests Now"
	run_tests_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	test_container.add_child(run_tests_button)

	main_tab.add_child(HSeparator.new())

	# Logger settings using a grid
	var settings_grid = ui_builder.create_grid(main_tab)
	if not settings_grid:
		push_error("Failed to create settings grid")
		return

	# Log level
	var level_label = Label.new()
	level_label.text = "Log Level:"
	settings_grid.add_child(level_label)

	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_log_level_options(level_option)
	settings_grid.add_child(level_option)

	# Buffer size
	var buffer_label = Label.new()
	buffer_label.text = "Buffer Size:"
	settings_grid.add_child(buffer_label)

	var buffer_controls = ui_builder.create_spinner_with_button(
		settings_grid,
		Logger.LoggerConfig.MIN_BUFFER_SIZE as float,
		Logger.LoggerConfig.MAX_BUFFER_SIZE as float,
		100.0,
		1000.0,
		"Apply"
	)

	if buffer_controls.size() >= 2:
		buffer_size_spin = buffer_controls[0] as SpinBox
		buffer_apply_button = buffer_controls[1] as Button
	else:
		push_error("Failed to create buffer size controls")
		return

	# Retroactive window
	var retro_label = Label.new()
	retro_label.text = "Retroactive Window (s):"
	settings_grid.add_child(retro_label)

	var retro_controls = ui_builder.create_spinner_with_button(
		settings_grid,
		Logger.LoggerConfig.MIN_TIME_WINDOW as float,
		Logger.LoggerConfig.MAX_TIME_WINDOW as float,
		10.0,
		300.0,
		"Apply"
	)

	if retro_controls.size() >= 2:
		retro_spin = retro_controls[0] as SpinBox
		retro_apply_button = retro_controls[1] as Button
	else:
		push_error("Failed to create retroactive window controls")
		return

	# Tag management section separator
	main_tab.add_child(HSeparator.new())

	# Tag management header
	var tag_management = ui_builder.create_section(main_tab, "Tag Management")

	scan_tags_button = ui_builder.create_header_with_button(
		tag_management,
		"Tag Management",
		"Scan for Tags"
	)
	scan_tags_button.tooltip_text = "Scan log entries for all used tags"

	ui_builder.create_note_label(
		tag_management,
		"Drag tags between containers to change their status"
	)

	# Three-column layout for tag trees
	var trees_container := HBoxContainer.new()
	trees_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_management.add_child(trees_container)

	# Create available tags section with group button
	var available_container := VBoxContainer.new()
	available_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(available_container)

	var available_header = HBoxContainer.new()
	available_container.add_child(available_header)

	var available_label = Label.new()
	available_label.text = "Available Tags"
	available_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_header.add_child(available_label)

	group_selected_button = Button.new()
	group_selected_button.text = "Group Selected"
	group_selected_button.tooltip_text = "Create a tag group from selected tags"
	available_header.add_child(group_selected_button)

	# Create tag trees
	available_tags_tree = TagTreeControl.new(
		"Available Tags",
		"available",
		logger.TAGS_COLOR
	)
	filter_tags_tree = TagTreeControl.new(
		"Filter Tags (Show Only)",
		"filter",
		logger.TAGS_COLOR
	)
	ignore_tags_tree = TagTreeControl.new(
		"Ignore Tags (Hide)",
		"ignore",
		logger.TAGS_COLOR.darkened(0.3)
	)

	available_container.add_child(available_tags_tree)

	# Filter tags section
	var filter_container := VBoxContainer.new()
	filter_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(filter_container)

	var filter_label := Label.new()
	filter_label.text = "Filter Tags (Show Only)"
	filter_container.add_child(filter_label)
	filter_container.add_child(filter_tags_tree)

	# Ignore tags section
	var ignore_container := VBoxContainer.new()
	ignore_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ignore_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(ignore_container)

	var ignore_label := Label.new()
	ignore_label.text = "Ignore Tags (Hide)"
	ignore_container.add_child(ignore_label)
	ignore_container.add_child(ignore_tags_tree)

	# Setup drag and drop
	available_tags_tree.set_drag_forwarding(
		Callable(self, "_get_drag_data_fw").bind(available_tags_tree),
		Callable(self, "_can_drop_data_fw"),
		Callable(self, "_drop_data_fw")
	)

	filter_tags_tree.set_drag_forwarding(
		Callable(self, "_get_drag_data_fw").bind(filter_tags_tree),
		Callable(self, "_can_drop_data_fw"),
		Callable(self, "_drop_data_fw")
	)

	ignore_tags_tree.set_drag_forwarding(
		Callable(self, "_get_drag_data_fw").bind(ignore_tags_tree),
		Callable(self, "_can_drop_data_fw"),
		Callable(self, "_drop_data_fw")
	)

	# Add Tag Setup Library section
	main_tab.add_child(HSeparator.new())

	var setup_section = ui_builder.create_section(main_tab, "Tag Setup Library")

	# Header with Save Current button
	var setup_header = HBoxContainer.new()
	setup_section.add_child(setup_header)

	var setup_title = Label.new()
	setup_title.text = "Saved Tag Setups"
	setup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_header.add_child(setup_title)

	var save_setup_btn = Button.new()
	save_setup_btn.text = "Save Current"
	save_setup_btn.tooltip_text = "Save current tag setup"
	save_setup_btn.pressed.connect(_on_save_setup_pressed)
	setup_header.add_child(save_setup_btn)

	# Setup tree for saved setups
	setups_tree = Tree.new()
	setups_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setups_tree.custom_minimum_size.y = 150
	setups_tree.allow_rmb_select = true
	setup_section.add_child(setups_tree)

	# Initialize tree
	setup_root = setups_tree.create_item()
	setup_root.set_text(0, "Setups")
	setup_root.set_selectable(0, false)

# Helper method to setup log level options
func _setup_log_level_options(option_button: OptionButton) -> void:
	if not option_button:
		return

	option_button.add_item("DEBUG", Logger.LogLevel.DEBUG)
	option_button.add_item("INFO", Logger.LogLevel.INFO)
	option_button.add_item("WARNING", Logger.LogLevel.WARNING)
	option_button.add_item("ERROR", Logger.LogLevel.ERROR)
	option_button.add_item("CRITICAL", Logger.LogLevel.CRITICAL)

# Connect signals
func _connect_signals() -> void:
	if not _verify_ui_elements():
		push_error("Required UI elements not properly initialized")
		return

	# Connect UI element signals
	level_option.item_selected.connect(func(idx: int) -> void: _on_level_changed(idx))
	run_tests_check.toggled.connect(func(en: bool) -> void: _on_run_tests_toggled(en))

	buffer_apply_button.pressed.connect(func() -> void: _on_buffer_size_applied(buffer_size_spin.value))
	retro_apply_button.pressed.connect(func() -> void: _on_retro_window_applied(retro_spin.value))
	run_tests_button.pressed.connect(func() -> void: _on_run_tests_now_pressed())
	scan_tags_button.pressed.connect(func() -> void: _on_scan_tags_pressed())

	# Connect group button
	group_selected_button.pressed.connect(func() -> void: _on_group_selected_pressed())

	# Connect tag tree signals
	filter_tags_tree.tag_selected.connect(func(tag_data: TagData) -> void: _on_filter_tag_selected(tag_data))
	ignore_tags_tree.tag_selected.connect(func(tag_data: TagData) -> void: _on_ignore_tag_selected(tag_data))

	available_tags_tree.tag_activated.connect(func(tag_data: TagData) -> void: _on_available_tag_activated(tag_data))
	filter_tags_tree.tag_activated.connect(func(tag_data: TagData) -> void: _on_filter_tag_activated(tag_data))
	ignore_tags_tree.tag_activated.connect(func(tag_data: TagData) -> void: _on_ignore_tag_activated(tag_data))

	# Connect setup tree signals
	setups_tree.item_activated.connect(func() -> void: _on_setup_activated())
	setups_tree.item_mouse_selected.connect(func(position: Vector2, button_index: int) -> void:
		_on_setup_mouse_selected(position, button_index)
	)

	# Load existing setups
	_refresh_setups_list()

# Verify all UI elements are properly initialized
func _verify_ui_elements() -> bool:
	return level_option != null && \
		buffer_size_spin != null && \
		retro_spin != null && \
		run_tests_check != null && \
		buffer_apply_button != null && \
		retro_apply_button != null && \
		run_tests_button != null && \
		scan_tags_button != null && \
		available_tags_tree != null && \
		filter_tags_tree != null && \
		ignore_tags_tree != null && \
		group_selected_button != null && \
		setups_tree != null && \
		setup_root != null

# Update UI from logger state
func _update_ui_from_logger() -> void:
	if not logger or not _verify_ui_elements():
		push_error("Cannot update UI from logger: invalid state")
		return

	level_option.select(logger._current_level)
	buffer_size_spin.value = logger._buffer.buffer.size()
	retro_spin.value = logger._config.retroactive_time_window

	_refresh_tag_trees()

# Refresh all tag trees
func _refresh_tag_trees() -> void:
	if not logger:
		return

	_refresh_filter_tree()
	_refresh_ignore_tree()
	_refresh_available_tags_tree()

# Refresh the filter tags tree
func _refresh_filter_tree() -> void:
	if not filter_tags_tree or not logger:
		return

	filter_tags_tree.clear_tags()

	# Add active tags - these are the filter tags
	for tag in logger.get_active_tags():
		filter_tags_tree.add_tag(tag)

# Refresh the ignore tags tree
func _refresh_ignore_tree() -> void:
	if not ignore_tags_tree or not logger:
		return

	ignore_tags_tree.clear_tags()

	# Add ignored tags
	for tag in logger.get_ignored_tags():
		ignore_tags_tree.add_tag(tag)

# Refresh available tags tree
func _refresh_available_tags_tree() -> void:
	if not available_tags_tree or not logger:
		return

	available_tags_tree.clear_tags()

	# Get available tags with counts
	var tags_with_counts = logger.get_available_tags_with_counts()
	var sorted_tags = tags_with_counts.keys()
	sorted_tags.sort()

	# Add each tag with its count
	for tag in sorted_tags:
		var count = tags_with_counts[tag]

		# Skip tags that are already in filter or ignore
		if logger.get_active_tags().has(tag) or logger.get_ignored_tags().has(tag):
			continue

		available_tags_tree.add_tag(tag, count)

	# Add level tags (always available)
	var level_names = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
	for level_name in level_names:
		var level_tag = "level:" + level_name
		if not logger.get_active_tags().has(level_tag) and not logger.get_ignored_tags().has(level_tag):
			available_tags_tree.add_tag(level_tag, 0)


# Tag management methods
func _add_tag_to_filter(tag: String) -> void:
	if not logger:
		return

	# Add to active tags (filter)
	if logger.add_tag(tag) == OK:
		_refresh_tag_trees()
		settings_changed.emit()

func _add_tag_to_ignore(tag: String) -> void:
	if not logger:
		return

	# Add to ignore list
	if logger.add_ignored_tag(tag) == OK:
		_refresh_tag_trees()
		settings_changed.emit()

func _remove_tag_from_filter(tag: String) -> void:
	if not logger:
		return

	logger.remove_tag(tag)
	_refresh_tag_trees()
	settings_changed.emit()

func _remove_tag_from_ignore(tag: String) -> void:
	if not logger:
		return

	logger.remove_ignored_tag(tag)
	_refresh_tag_trees()
	settings_changed.emit()

# Group tags functionality
func _on_group_selected_pressed() -> void:
	# Get all selected items from the available tags tree
	var selected_data = available_tags_tree.get_selected_tag_data_array()
	var selected_tags: Array[String] = []

	# Extract tags from selected items
	for tag_data in selected_data:
		selected_tags.append(tag_data.tag)

	# Need at least 2 tags to form a group
	if selected_tags.size() < 2:
		OS.alert("Please select at least 2 tags to create a group.", "Not Enough Tags")
		return

	# Create the group tag directly
	var group_tag = "+".join(selected_tags)

	# Add group tag to available tags
	available_tags_tree.add_tag(group_tag)

	# Deselect all
	available_tags_tree.deselect_all()

	# Refresh tag trees to ensure UI is consistent
	_refresh_tag_trees()

# Drag and drop handling
func _get_drag_data_fw(position: Vector2, from_control: Control) -> Variant:
	if not from_control is TagTreeControl:
		return null

	var tree_control := from_control as TagTreeControl
	if tree_control.is_empty():
		return null

	var selected_tag = tree_control.get_selected_tag_data()
	if not selected_tag:
		return null

	# Create a drag preview
	var preview = selected_tag.create_preview()
	set_drag_preview(preview)

	# Return tag data
	return selected_tag

func _can_drop_data_fw(position: Vector2, data: Variant, to_control: Control) -> bool:
	# Check if data is valid
	if not data is TagData:
		return false

	# Check control validity
	if not to_control is TagTreeControl:
		return false

	# Get source and destination types
	var src_type = data.type
	var dst_type = ""

	if to_control == available_tags_tree:
		dst_type = "available"
	elif to_control == filter_tags_tree:
		dst_type = "filter"
	elif to_control == ignore_tags_tree:
		dst_type = "ignore"
	else:
		return false

	# Don't allow dropping onto the same tree type
	if src_type == dst_type:
		return false

	# Check if the tag already exists in the destination tree
	var tree_control := to_control as TagTreeControl
	if tree_control.has_tag(data.tag):
		return false

	return true

func _drop_data_fw(position: Vector2, data: Variant, to_control: Control) -> void:
	if not data is TagData:
		return

	var tag = data.tag
	if tag.is_empty():
		return

	if not to_control is TagTreeControl:
		push_warning("LoggerDock: Invalid drop target control")
		return

	# Based on destination tree, handle the tag differently
	if to_control == available_tags_tree:
		# Remove tag from filter or ignore
		if data.type == "filter":
			_remove_tag_from_filter(tag)
		elif data.type == "ignore":
			_remove_tag_from_ignore(tag)

	elif to_control == filter_tags_tree:
		# Add tag to filter
		_add_tag_to_filter(tag)

	elif to_control == ignore_tags_tree:
		# Add tag to ignore
		_add_tag_to_ignore(tag)

# Setup Library functions
func _refresh_setups_list() -> void:
	# Clear existing items
	var child = setup_root.get_first_child()
	while child:
		var next_child = child.get_next()
		child.free()
		child = next_child

	# Get setups from config
	var setups = LoggerSettings.get_tag_setups()

	# Add to tree
	var setup_names = setups.keys()
	setup_names.sort()  # Sort alphabetically

	for name in setup_names:
		var item = setups_tree.create_item(setup_root)
		item.set_text(0, name)
		item.set_metadata(0, name)

func _on_save_setup_pressed() -> void:
	# Create dialog for entering setup name
	var dialog = ConfirmationDialog.new()
	dialog.title = "Save Tag Setup"
	dialog.min_size = Vector2(300, 150)

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	vbox.add_child(_create_label("Enter a name for this tag setup:"))

	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "My Tag Setup"
	vbox.add_child(name_edit)

	add_child(dialog)

	# Handle confirmation
	dialog.confirmed.connect(func() -> void:
		var setup_name = name_edit.text.strip_edges()
		if setup_name.is_empty():
			OS.alert("Please enter a valid name.", "Invalid Name")
			return

		# Save setup to config
		var result = LoggerSettings.save_tag_setup(
			setup_name,
			logger.get_active_tags(),
			logger.get_ignored_tags(),
			logger._current_level
		)

		if result != OK:
			OS.alert("Failed to save tag setup.", "Error")
		else:
			# Refresh list
			_refresh_setups_list()
			print_rich("[color=green]Saved tag setup: %s[/color]" % setup_name)

		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	dialog.popup_centered()

func _on_setup_activated() -> void:
	var selected = setups_tree.get_selected()
	if not selected or not selected.has_meta(str(0)):
		return

	var setup_name = selected.get_metadata(0) as String
	var setups = LoggerSettings.get_tag_setups()

	if not setups.has(setup_name):
		OS.alert("Setup not found.", "Error")
		return

	var setup = setups[setup_name]

	# Apply the setup
	logger.set_level(setup.log_level)

	# Clear existing tags
	logger.clear_tags()
	logger.clear_ignored_tags()

	# Add active tags
	for tag in setup.active_tags:
		logger.add_tag(tag)

	# Add ignored tags
	for tag in setup.ignored_tags:
		logger.add_ignored_tag(tag)

	# Refresh UI
	_update_ui_from_logger()
	print_rich("[color=green]Loaded tag setup: %s[/color]" % setup_name)

	# Notify of settings change
	settings_changed.emit()

func _on_setup_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	# Check for right-click
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var selected = setups_tree.get_selected()
	if not selected or not selected.has_meta(str(0)):
		return

	var setup_name = selected.get_metadata(0) as String

	# Create context menu
	var menu = PopupMenu.new()
	menu.add_item("Load", 0)
	menu.add_separator()
	menu.add_item("Delete", 1)

	add_child(menu)

	# Connect to menu item selection
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0:  # Load
				_on_setup_activated()
			1:  # Delete
				# Confirm deletion
				var dialog = ConfirmationDialog.new()
				dialog.title = "Delete Tag Setup"
				dialog.dialog_text = "Are you sure you want to delete '%s'?" % setup_name
				add_child(dialog)

				dialog.confirmed.connect(func() -> void:
					var result = LoggerSettings.delete_tag_setup(setup_name)
					if result != OK:
						OS.alert("Failed to delete tag setup.", "Error")
					_refresh_setups_list()
					dialog.queue_free()
				)

				dialog.canceled.connect(func() -> void:
					dialog.queue_free()
				)

				dialog.popup_centered()

		menu.queue_free()
	)

	# Show at mouse position
	var global_pos = get_global_mouse_position()
	menu.position = global_pos
	menu.popup()

# Handle tag activation (double-click)
func _on_available_tag_activated(tag_data: TagData) -> void:
	_add_tag_to_filter(tag_data.tag)

func _on_filter_tag_activated(tag_data: TagData) -> void:
	_remove_tag_from_filter(tag_data.tag)

func _on_ignore_tag_activated(tag_data: TagData) -> void:
	_remove_tag_from_ignore(tag_data.tag)

# Handle tag selection
func _on_filter_tag_selected(tag_data: TagData) -> void:
	# Clear selection in other trees
	ignore_tags_tree.deselect_all()
	available_tags_tree.deselect_all()

func _on_ignore_tag_selected(tag_data: TagData) -> void:
	# Clear selection in other trees
	filter_tags_tree.deselect_all()
	available_tags_tree.deselect_all()

# Event handlers
func _on_level_changed(index: int) -> void:
	if not level_option or not logger:
		push_error("Level changed but logger or UI not initialized")
		return

	var level := level_option.get_item_id(index)
	if logger.set_level(level) == OK:
		print_rich("[color=green]Log level changed to: %s[/color]" % Logger.LogLevel.keys()[level])
		settings_changed.emit()
	else:
		push_error("Failed to change log level to: %s" % Logger.LogLevel.keys()[level])
		# Revert UI to match logger state
		_update_ui_from_logger()

func _on_buffer_size_applied(size: float) -> void:
	var value := int(size)
	if value < Logger.LoggerConfig.MIN_BUFFER_SIZE or value > Logger.LoggerConfig.MAX_BUFFER_SIZE:
		push_warning("Buffer size must be between %d and %d" %
			[Logger.LoggerConfig.MIN_BUFFER_SIZE, Logger.LoggerConfig.MAX_BUFFER_SIZE])
		_update_ui_from_logger() # Revert UI
		return

	if logger and logger.set_buffer_size(value) == OK:
		print_rich("[color=green]Buffer size changed to: %d[/color]" % value)
		settings_changed.emit()
	else:
		push_error("Failed to change buffer size")
		_update_ui_from_logger() # Revert UI

func _on_retro_window_applied(seconds: float) -> void:
	var value := int(seconds)
	if value < Logger.LoggerConfig.MIN_TIME_WINDOW or value > Logger.LoggerConfig.MAX_TIME_WINDOW:
		push_warning("Retroactive window must be between %d and %d seconds" %
			[Logger.LoggerConfig.MIN_TIME_WINDOW, Logger.LoggerConfig.MAX_TIME_WINDOW])
		_update_ui_from_logger() # Revert UI
		return

	if logger and logger.set_retroactive_window(value) == OK:
		print_rich("[color=green]Retroactive window changed to: %d seconds[/color]" % value)
		settings_changed.emit()
	else:
		push_error("Failed to change retroactive window")
		_update_ui_from_logger() # Revert UI

func _on_run_tests_toggled(enabled: bool) -> void:
	run_tests = enabled
	print_rich("[color=%s]Logger self-tests will %s on next project start[/color]" %
		["green" if enabled else "yellow", "run" if enabled else "NOT run"])
	settings_changed.emit()

func _on_run_tests_now_pressed() -> void:
	if not logger:
		push_error("Cannot run tests: logger not initialized")
		return

	print_rich("[color=green]Running Logger self-tests manually...[/color]")
	print("(Plain text) Running Logger self-tests manually...")

	# Store original settings to restore later
	var original_level: int = logger._current_level
	var original_enabled: bool = logger._enabled
	var original_test_mode: bool = false
	if "testing_mode" in logger:
		original_test_mode = logger._testing_mode

	var had_active_tags: bool = not logger.get_active_tags().is_empty()
	var active_tags_backup: Array[String] = logger.get_active_tags()

	# Force the logger to DEBUG level temporarily to show all messages
	logger.set_level(Logger.LogLevel.DEBUG)

	# Force the logger to be enabled
	logger._enabled = true

	# Enable testing mode if available
	if logger.has_method("enable_testing_mode"):
		logger.enable_testing_mode()

	# Autoload handling with safeguards
	var created_singleton: bool = false
	var autoload_logger = null

	# Check for Log singleton
	if Engine.has_singleton("Log"):
		autoload_logger = Engine.get_singleton("Log")

		# Only proceed if autoload_logger is valid Logger instance
		if autoload_logger and autoload_logger is Logger:
			# Make sure settings are properly transferred
			var transfer_result = LoggerSettings.apply_logger_to_logger(logger, autoload_logger)
			if transfer_result == OK:
				# Force the autoload logger to be enabled with DEBUG level
				autoload_logger._enabled = true
				autoload_logger._current_level = Logger.LogLevel.DEBUG

				# Enable testing mode on autoload logger if available
				if autoload_logger.has_method("enable_testing_mode"):
					autoload_logger.enable_testing_mode()

				print("Autoload logger enabled for testing")
			else:
				push_warning("Failed to transfer settings to autoload logger")
				autoload_logger = null
		else:
			push_warning("Log singleton is not a valid Logger instance")
			autoload_logger = null

	# Create temporary singleton if needed
	if not autoload_logger:
		print("Log singleton not available - using local logger for tests")
		# Try to register a temporary singleton
		if not Engine.has_singleton("Log"):
			Engine.register_singleton("Log", logger)
			created_singleton = true
			print("Temporarily registered local logger as Log singleton")
		else:
			push_warning("Cannot register temporary Log singleton - name already in use")

	# Run tests directly without creating a new instance
	print("Attempting to run logger tests directly...")

	# Direct test execution
	print_rich("\n[color=green]=== Starting Log.Self-Test (Manual) ===\n[/color]")

	# Basic test logs using local logger directly
	logger.debug("Manual test: Debug level message")
	logger.info("Manual test: Info level message")
	logger.warning("Manual test: Warning level message")

	# Test context data
	logger.info(
		"Manual test: Context data example",
		{"number": 42, "text": "Hello", "vector": Vector2(100, 200)}
	)

	# Test tag system
	logger.add_tag("manual-test")
	logger.info("Manual test: Tagged message", {"test_id": 1}, ["manual-test"])

	# Test error with retroactive display
	logger.debug("Manual test: This should appear in retroactive display")
	logger.error(
		"Manual test: Error message with retroactive display",
		{"error_code": 404, "details": "Testing error handling"}
	)

	# Test tag removal & cleanup
	logger.remove_tag("manual-test")
	logger.clear_tags()

	print_rich("\n[color=green]=== Manual Test Complete ===\n[/color]")

	# Now try loading and running the test script with safeguards
	var test_script = null
	var script_path = "res://addons/advanced_logger/logger_test.gd"

	if ResourceLoader.exists(script_path):
		print("Logger test script found at %s" % script_path)

		var TestScript = load(script_path)
		if TestScript:
			print("Logger test script loaded successfully")
			# GDScript doesn't have try/except, so we need to be careful
			test_script = TestScript.new()

			if test_script:
				# Configure test script with property existence checks
				# Using reflection to safely set properties
				if test_script.get("_logger_ready") != null:
					test_script._logger_ready = true
				if test_script.get("_initialization_attempts") != null:
					test_script._initialization_attempts = 0
				if test_script.get("_should_run_tests") != null:
					test_script._should_run_tests = true
				if test_script.get("_max_attempts") != null:
					test_script._max_attempts = 0

				add_child(test_script)

				# Connect to the tests_completed signal if it exists
				if test_script.has_signal("tests_completed"):
					test_script.connect("tests_completed", func() -> void:
						print("Logger test script completed execution")
						if is_instance_valid(test_script):
							test_script.queue_free()
					)

				# Run tests directly if the method exists
				if test_script.has_method("run_tests"):
					test_script.call("run_tests")
					print("Logger test script execution initiated")
				else:
					push_error("Test script doesn't have run_tests method")
					test_script.queue_free()
			else:
				push_error("Failed to instantiate test script")
		else:
			push_error("Failed to load logger_test.gd - running fallback tests only")
	else:
		push_error("Logger test script not found at %s - running fallback tests only" % script_path)

	# Cleanup after a delay regardless of test script execution
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		# Remove temporary singleton if we added it
		if created_singleton and Engine.has_singleton("Log"):
			Engine.unregister_singleton("Log")
			print("Removed temporary Log singleton")

		# Disable testing mode if available
		if logger.has_method("disable_testing_mode"):
			logger.disable_testing_mode()

		# Also check the autoload logger
		if autoload_logger and autoload_logger is Logger and autoload_logger.has_method("disable_testing_mode"):
			autoload_logger.disable_testing_mode()

		# Restore original settings
		logger.set_level(original_level)
		logger._enabled = original_enabled

		if "testing_mode" in logger:
			logger._testing_mode = original_test_mode

		# Restore original tags if needed
		logger.clear_tags()
		if had_active_tags:
			for tag in active_tags_backup:
				logger.add_tag(tag)

		print_rich("[color=green]Test run complete, settings restored.[/color]")
		print("(Plain text) Test run complete, settings restored.")

		# Update UI to reflect restored settings
		call_deferred("_update_ui_from_logger")
	)

# Handle available tags scanning
func _on_scan_tags_pressed() -> void:
	if not logger:
		push_error("Cannot scan tags: logger not initialized")
		return

	print_rich("[color=green]Scanning log entries for available tags...[/color]")

	# Scan for tags in the buffer
	logger.scan_for_available_tags()

	# Refresh the available tags tree
	_refresh_available_tags_tree()

	print_rich("[color=green]Scan complete. Found %d unique tags.[/color]" % logger.get_available_tags().size())

# Helper method to create a simple label
func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func should_run_tests() -> bool:
	return run_tests
