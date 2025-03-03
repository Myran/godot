@tool
class_name LoggerDock
extends Control
## UI dock for the Logger, allowing tag management and settings configuration

# Signal to notify that settings have changed
signal settings_changed

# Logger instance to control
var logger: Logger

# UI elements
var tab_container: TabContainer
var level_option: OptionButton
var buffer_size_spin: SpinBox
var retro_spin: SpinBox
var available_tags_tree: Tree
var filter_tags_tree: Tree
var ignore_tags_tree: Tree
var scan_tags_button: Button

# Format tab settings
var format_tab: FormatTab

func _init(logger_instance: Logger) -> void:
	if not logger_instance:
		push_error("Logger dock created with null logger instance")
		return

	logger = logger_instance
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	if not logger:
		push_error("Logger dock has no logger instance")
		return

	_setup_ui()
	_connect_signals()
	_update_ui_from_logger()

# Create the UI layout
func _setup_ui() -> void:
	# Main layout container
	var layout = VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# Tab container for multiple sections
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tab_container)

	# Create main tab
	var main_tab = VBoxContainer.new()
	main_tab.name = "General"
	tab_container.add_child(main_tab)

	# Create format tab
	format_tab = FormatTab.new(self, logger, tab_container)

	# Logger settings section
	var settings_section = _create_section(main_tab, "Logger Settings")

	# Log level
	var level_container = HBoxContainer.new()
	settings_section.add_child(level_container)

	var level_label = Label.new()
	level_label.text = "Log Level:"
	level_container.add_child(level_label)

	level_option = OptionButton.new()
	level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_log_level_options(level_option)
	level_container.add_child(level_option)

	# Buffer size
	var buffer_container = HBoxContainer.new()
	settings_section.add_child(buffer_container)

	var buffer_label = Label.new()
	buffer_label.text = "Buffer Size:"
	buffer_container.add_child(buffer_label)

	buffer_size_spin = SpinBox.new()
	buffer_size_spin.min_value = 10
	buffer_size_spin.max_value = 10000
	buffer_size_spin.step = 100
	buffer_size_spin.value = 1000
	buffer_size_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffer_container.add_child(buffer_size_spin)

	# Retroactive window
	var retro_container = HBoxContainer.new()
	settings_section.add_child(retro_container)

	var retro_label = Label.new()
	retro_label.text = "Retroactive Window (seconds):"
	retro_container.add_child(retro_label)

	retro_spin = SpinBox.new()
	retro_spin.min_value = 10
	retro_spin.max_value = 3600
	retro_spin.step = 10
	retro_spin.value = 300
	retro_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retro_container.add_child(retro_spin)

	# Tag management section
	var tag_section = _create_section(main_tab, "Tag Management")

	# Scan tags button
	var header_container = HBoxContainer.new()
	tag_section.add_child(header_container)

	var header_label = Label.new()
	header_label.text = "Tag Filtering"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(header_label)

	scan_tags_button = Button.new()
	scan_tags_button.text = "Scan for Tags"
	scan_tags_button.tooltip_text = "Scan log entries for all used tags"
	header_container.add_child(scan_tags_button)

	# Tags instructions
	var instructions = Label.new()
	instructions.text = "Drag tags between trees to change their status."
	tag_section.add_child(instructions)

	# Three trees for tag management
	var trees_container = HBoxContainer.new()
	trees_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_section.add_child(trees_container)

	# Available tags
	var available_container = VBoxContainer.new()
	available_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(available_container)

	var available_label = Label.new()
	available_label.text = "Available Tags"
	available_container.add_child(available_label)

	available_tags_tree = Tree.new()
	available_tags_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_tags_tree.allow_rmb_select = true
	available_container.add_child(available_tags_tree)

	# Filter tags
	var filter_container = VBoxContainer.new()
	filter_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(filter_container)

	var filter_label = Label.new()
	filter_label.text = "Filter Tags (Show Only)"
	filter_container.add_child(filter_label)

	filter_tags_tree = Tree.new()
	filter_tags_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filter_tags_tree.allow_rmb_select = true
	filter_container.add_child(filter_tags_tree)

	# Ignore tags
	var ignore_container = VBoxContainer.new()
	ignore_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ignore_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees_container.add_child(ignore_container)

	var ignore_label = Label.new()
	ignore_label.text = "Ignore Tags (Hide)"
	ignore_container.add_child(ignore_label)

	ignore_tags_tree = Tree.new()
	ignore_tags_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ignore_tags_tree.allow_rmb_select = true
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

	# Initialize trees
	_init_tree(available_tags_tree, "Available")
	_init_tree(filter_tags_tree, "Filter")
	_init_tree(ignore_tags_tree, "Ignore")

# Helper to create a section with title
func _create_section(parent: Container, title: String) -> VBoxContainer:
	if not parent or title.is_empty():
		push_error("Invalid parameters for create_section")
		return null

	var section: VBoxContainer = VBoxContainer.new()
	if not section:
		push_error("Failed to create section container")
		return null

	parent.add_child(section)

	var header: Label = Label.new()
	if not header:
		push_error("Failed to create section header")
		return section

	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	var separator: HSeparator = HSeparator.new()
	if separator:
		section.add_child(separator)

	return section

# Setup the log level options
func _setup_log_level_options(option_button: OptionButton) -> void:
	option_button.add_item("DEBUG", Logger.LogLevel.DEBUG)
	option_button.add_item("INFO", Logger.LogLevel.INFO)
	option_button.add_item("WARNING", Logger.LogLevel.WARNING)
	option_button.add_item("ERROR", Logger.LogLevel.ERROR)
	option_button.add_item("CRITICAL", Logger.LogLevel.CRITICAL)

# Initialize a tree with a root item
func _init_tree(tree: Tree, name: String) -> void:
	if not tree or name.is_empty():
		push_error("Invalid parameters for init_tree")
		return

	var root: TreeItem = tree.create_item()
	if not root:
		push_error("Failed to create root tree item")
		return

	root.set_text(0, name)
	root.set_selectable(0, false)

# Connect signals for UI interactions
func _connect_signals() -> void:
	level_option.item_selected.connect(_on_level_changed)
	buffer_size_spin.value_changed.connect(_on_buffer_size_changed)
	retro_spin.value_changed.connect(_on_retro_window_changed)
	scan_tags_button.pressed.connect(_on_scan_tags_pressed)

	available_tags_tree.item_activated.connect(_on_available_tag_activated)
	filter_tags_tree.item_activated.connect(_on_filter_tag_activated)
	ignore_tags_tree.item_activated.connect(_on_ignore_tag_activated)

# Update the UI from the logger state
func _update_ui_from_logger() -> void:
	if not logger:
		return

	# Update log level option
	level_option.select(logger._current_level)

	# Update spinners
	buffer_size_spin.value = logger._buffer_size
	retro_spin.value = logger._retroactive_window

	# Update tag trees
	_refresh_tag_trees()

# Refresh all tag trees
func _refresh_tag_trees() -> void:
	if not logger:
		return

	_refresh_available_tags_tree()
	_refresh_filter_tags_tree()
	_refresh_ignore_tags_tree()

# Refresh the available tags tree
func _refresh_available_tags_tree() -> void:
	if not available_tags_tree or not logger:
		push_error("Cannot refresh available tags: tree or logger not initialized")
		return

	# Clear tree except root
	var root: TreeItem = available_tags_tree.get_root()
	if not root:
		push_error("Available tags tree has no root item")
		return

	# Remove all children
	var child: TreeItem = root.get_first_child()
	while child:
		var next_child: TreeItem = child.get_next()
		child.free()
		child = next_child

	# Get available tags with counts
	var tags_with_counts: Dictionary = logger.get_available_tags_with_counts()
	var sorted_tags: Array = tags_with_counts.keys()
	sorted_tags.sort()

	var active_tags: Array[String] = logger.get_active_tags()
	var ignored_tags: Array[String] = logger.get_ignored_tags()

	# Add each tag with its count
	for tag in sorted_tags:
		if not tag is String or tag.is_empty():
			continue

		var count: int = tags_with_counts.get(tag, 0)

		# Skip tags that are already in filter or ignore
		if active_tags.has(tag) or ignored_tags.has(tag):
			continue

		var item: TreeItem = available_tags_tree.create_item(root)
		if not item:
			push_error("Failed to create tree item for tag: %s" % tag)
			continue

		item.set_text(0, "%s (%d)" % [tag, count])
		item.set_metadata(0, tag)

# Refresh the filter tags tree
func _refresh_filter_tags_tree() -> void:
	if not filter_tags_tree or not logger:
		push_error("Cannot refresh filter tags: tree or logger not initialized")
		return

	# Clear tree except root
	var root: TreeItem = filter_tags_tree.get_root()
	if not root:
		push_error("Filter tags tree has no root item")
		return

	# Remove all children
	var child: TreeItem = root.get_first_child()
	while child:
		var next_child: TreeItem = child.get_next()
		child.free()
		child = next_child

	# Add active tags
	var active_tags: Array[String] = logger.get_active_tags()
	for tag in active_tags:
		if not tag is String or tag.is_empty():
			continue

		var item: TreeItem = filter_tags_tree.create_item(root)
		if not item:
			push_error("Failed to create tree item for filter tag: %s" % tag)
			continue

		item.set_text(0, tag)
		item.set_metadata(0, tag)

# Refresh the ignore tags tree
func _refresh_ignore_tags_tree() -> void:
	if not ignore_tags_tree or not logger:
		push_error("Cannot refresh ignore tags: tree or logger not initialized")
		return

	# Clear tree except root
	var root: TreeItem = ignore_tags_tree.get_root()
	if not root:
		push_error("Ignore tags tree has no root item")
		return

	# Remove all children
	var child: TreeItem = root.get_first_child()
	while child:
		var next_child: TreeItem = child.get_next()
		child.free()
		child = next_child

	# Add ignored tags
	var ignored_tags: Array[String] = logger.get_ignored_tags()
	for tag in ignored_tags:
		if not tag is String or tag.is_empty():
			continue

		var item: TreeItem = ignore_tags_tree.create_item(root)
		if not item:
			push_error("Failed to create tree item for ignore tag: %s" % tag)
			continue

		item.set_text(0, tag)
		item.set_metadata(0, tag)

# Drag and drop handling
func _get_drag_data_fw(position: Vector2, from_control: Control) -> Variant:
	if not from_control is Tree:
		return null

	var tree = from_control as Tree
	var selected = tree.get_selected()

	if not selected or selected == tree.get_root():
		return null

	var tag = selected.get_metadata(0)
	if not tag:
		return null

	# Create a drag preview
	var preview = Label.new()
	preview.text = selected.get_text(0)
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)

	# Return tag data with source tree
	var data = {
		"tag": tag,
		"source": tree
	}
	return data

func _can_drop_data_fw(position: Vector2, data: Variant, to_control: Control) -> bool:
	# Check if data is valid
	if not data is Dictionary or not data.has("tag") or not data.has("source"):
		return false

	# Check if target is a tree
	if not to_control is Tree:
		return false

	# Don't allow dropping onto same tree
	if data["source"] == to_control:
		return false

	return true

func _drop_data_fw(position: Vector2, data: Variant, to_control: Control) -> void:
	if not data is Dictionary or not data.has("tag") or not data.has("source"):
		return

	var tag = data["tag"]
	var source_tree = data["source"]
	var target_tree = to_control

	if source_tree == available_tags_tree:
		if target_tree == filter_tags_tree:
			logger.add_tag(tag)
		elif target_tree == ignore_tags_tree:
			logger.add_ignored_tag(tag)

	elif source_tree == filter_tags_tree:
		if target_tree == available_tags_tree:
			logger.remove_tag(tag)
		elif target_tree == ignore_tags_tree:
			logger.remove_tag(tag)
			logger.add_ignored_tag(tag)

	elif source_tree == ignore_tags_tree:
		if target_tree == available_tags_tree:
			logger.remove_ignored_tag(tag)
		elif target_tree == filter_tags_tree:
			logger.remove_ignored_tag(tag)
			logger.add_tag(tag)

	# Refresh trees after changes
	_refresh_tag_trees()
	settings_changed.emit()

# Signal handlers
func _on_level_changed(index: int) -> void:
	var level = level_option.get_item_id(index)
	logger.set_level(level)
	settings_changed.emit()

func _on_buffer_size_changed(value: float) -> void:
	logger.set_buffer_size(int(value))
	settings_changed.emit()

func _on_retro_window_changed(value: float) -> void:
	logger.set_retroactive_window(int(value))
	settings_changed.emit()

func _on_scan_tags_pressed() -> void:
	logger.scan_for_tags()
	_refresh_available_tags_tree()
	print_rich("[color=green]Scan complete. Found %d unique tags.[/color]" % logger.get_available_tags().size())

# Tag activation handlers
func _on_available_tag_activated() -> void:
	var selected = available_tags_tree.get_selected()
	if not selected:
		return

	var tag = selected.get_metadata(0)
	logger.add_tag(tag)
	_refresh_tag_trees()
	settings_changed.emit()

func _on_filter_tag_activated() -> void:
	var selected = filter_tags_tree.get_selected()
	if not selected:
		return

	var tag = selected.get_metadata(0)
	logger.remove_tag(tag)
	_refresh_tag_trees()
	settings_changed.emit()

func _on_ignore_tag_activated() -> void:
	var selected = ignore_tags_tree.get_selected()
	if not selected:
		return

	var tag = selected.get_metadata(0)
	logger.remove_ignored_tag(tag)
	_refresh_tag_trees()
	settings_changed.emit()
