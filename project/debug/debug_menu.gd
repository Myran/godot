class_name DebugMenu
extends Control

## A comprehensive debug menu system for GameTwo project

# Configuration constants
const SETTINGS_PATH: String = "user://debug_menu_settings.cfg"
const DEFAULT_THEME: String = "default"

# Categories dictionary: path -> DebugCategory
var categories: Dictionary = {}

# UI references
var ui_container: Control = null
var back_button: Button = null
var current_path_label: RichTextLabel = null
var search_field: LineEdit = null
var search_clear_button: Button = null
var status_label: Label = null
var results_text_area: RichTextLabel = null

# Navigation state
var current_category_path: String = ""
var navigation_history: Array[String] = []
var current_search_term: String = ""
var active_ui_elements: Array = []

# Config and themes
var settings: ConfigFile = null
var themes: Dictionary = {
	"default":
	{
		"background_color": Color(0.15, 0.15, 0.15, 0.95),
		"text_color": Color(0.9, 0.9, 0.9),
		"button_color": Color(0.25, 0.25, 0.25),
		"button_hover_color": Color(0.35, 0.35, 0.35),
		"button_text_color": Color(0.9, 0.9, 0.9),
		"category_color": Color(0.2, 0.4, 0.6),
		"header_color": Color(0.8, 0.8, 0.8),
		"success_color": Color(0.3, 0.8, 0.3),
		"error_color": Color(0.8, 0.3, 0.3)
	},
	"light":
	{
		"background_color": Color(0.95, 0.95, 0.95, 0.95),
		"text_color": Color(0.1, 0.1, 0.1),
		"button_color": Color(0.8, 0.8, 0.8),
		"button_hover_color": Color(0.7, 0.7, 0.7),
		"button_text_color": Color(0.1, 0.1, 0.1),
		"category_color": Color(0.4, 0.6, 0.8),
		"header_color": Color(0.2, 0.2, 0.2),
		"success_color": Color(0.0, 0.6, 0.0),
		"error_color": Color(0.8, 0.0, 0.0)
	},
	"dark_blue":
	{
		"background_color": Color(0.05, 0.1, 0.2, 0.95),
		"text_color": Color(0.8, 0.9, 1.0),
		"button_color": Color(0.15, 0.2, 0.3),
		"button_hover_color": Color(0.2, 0.3, 0.4),
		"button_text_color": Color(0.8, 0.9, 1.0),
		"category_color": Color(0.3, 0.5, 0.8),
		"header_color": Color(0.7, 0.8, 0.9),
		"success_color": Color(0.3, 0.8, 0.5),
		"error_color": Color(0.8, 0.3, 0.3)
	},
	"high_contrast":
	{
		"background_color": Color(0.0, 0.0, 0.0, 0.95),
		"text_color": Color(1.0, 1.0, 1.0),
		"button_color": Color(0.1, 0.1, 0.1),
		"button_hover_color": Color(0.2, 0.2, 0.2),
		"button_text_color": Color(1.0, 1.0, 1.0),
		"category_color": Color(0.0, 0.5, 1.0),
		"header_color": Color(1.0, 1.0, 0.0),
		"success_color": Color(0.0, 1.0, 0.0),
		"error_color": Color(1.0, 0.0, 0.0)
	}
}
var current_theme: String = DEFAULT_THEME


# Ready
func _ready() -> void:
	setup_ui()
	_load_settings()
	_apply_theme(current_theme)

	# Show root category initially
	show_category("")


## Load settings from disk
func _load_settings() -> void:
	settings = ConfigFile.new()
	var error = settings.load(SETTINGS_PATH)

	# If settings file doesn't exist, create it with defaults
	if error != OK:
		Log.info("Creating new debug menu settings file", {}, ["debug_menu"])
		settings.set_value("appearance", "theme", DEFAULT_THEME)
		settings.set_value("navigation", "last_category", "")
		settings.save(SETTINGS_PATH)
	else:
		# Load the theme
		if settings.has_section_key("appearance", "theme"):
			current_theme = settings.get_value("appearance", "theme", DEFAULT_THEME)

		# Load the last visited category
		if settings.has_section_key("navigation", "last_category"):
			var last_category = settings.get_value("navigation", "last_category", "")
			if not last_category.is_empty():
				current_category_path = last_category


## Apply a theme to the debug menu
func _apply_theme(theme_name: String) -> void:
	if not themes.has(theme_name):
		Log.warning("Theme not found: " + theme_name + ", using default", {}, ["debug_menu"])
		theme_name = DEFAULT_THEME

	current_theme = theme_name
	if settings:
		settings.set_value("appearance", "theme", theme_name)
		settings.save(SETTINGS_PATH)

	var theme_data = themes[theme_name]

	# Apply theme to UI elements
	var stylebox_panel = StyleBoxFlat.new()
	stylebox_panel.bg_color = theme_data.background_color
	stylebox_panel.corner_radius_top_left = 5
	stylebox_panel.corner_radius_top_right = 5
	stylebox_panel.corner_radius_bottom_left = 5
	stylebox_panel.corner_radius_bottom_right = 5

	var panel_container = get_node_or_null("PanelContainer")
	if panel_container and panel_container is PanelContainer:
		panel_container.add_theme_stylebox_override("panel", stylebox_panel)

	# Apply text colors
	if is_instance_valid(status_label):
		status_label.add_theme_color_override("font_color", theme_data.text_color)

	Log.info("Applied theme: " + theme_name, {}, ["debug_menu"])


## Save settings to disk
func _save_settings() -> void:
	if settings:
		settings.save(SETTINGS_PATH)


# Setup UI for debug menu
func setup_ui() -> void:
	# Main panel container
	var panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	add_child(panel)

	# Main layout - VBox for overall arrangement
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(main_vbox)

	# Header area with title, back button, etc.
	var header = HBoxContainer.new()
	header.set_custom_minimum_size(Vector2(0, 50))
	main_vbox.add_child(header)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.set_custom_minimum_size(Vector2(80, 0))
	back_button.pressed.connect(func(): _on_back_button_pressed())
	back_button.visible = false
	header.add_child(back_button)

	# Current path label (with breadcrumbs)
	current_path_label = RichTextLabel.new()
	current_path_label.bbcode_enabled = true
	current_path_label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	current_path_label.set_v_size_flags(Control.SIZE_FILL)
	current_path_label.set_custom_minimum_size(Vector2(0, 30))
	current_path_label.scroll_active = false
	current_path_label.selection_enabled = false
	current_path_label.meta_underlined = true
	current_path_label.fit_content = true
	header.add_child(current_path_label)

	# Search area
	var search_container = HBoxContainer.new()
	main_vbox.add_child(search_container)

	var search_label = Label.new()
	search_label.text = "Search:"
	search_container.add_child(search_label)

	search_field = LineEdit.new()
	search_field.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	search_field.clear_button_enabled = true
	search_field.placeholder_text = "Search categories and functions..."
	search_field.text_changed.connect(func(new_text): _on_search_field_text_changed(new_text))
	search_container.add_child(search_field)

	search_clear_button = Button.new()
	search_clear_button.text = "Clear"
	search_clear_button.pressed.connect(_on_search_clear_pressed)
	search_container.add_child(search_clear_button)

	# Create a split container for main content and results area
	var split = HSplitContainer.new()
	split.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	split.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	main_vbox.add_child(split)

	# Content area (main debug categories and buttons)
	var content_container = ScrollContainer.new()
	content_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	content_container.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	split.add_child(content_container)

	ui_container = VBoxContainer.new()
	ui_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	ui_container.set_custom_minimum_size(Vector2(400, 0))
	content_container.add_child(ui_container)

	# Results area (for detailed test output)
	var results_container = VBoxContainer.new()
	results_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	results_container.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	split.add_child(results_container)

	var results_label = Label.new()
	results_label.text = "Test Results"
	results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_container.add_child(results_label)

	results_text_area = RichTextLabel.new()
	results_text_area.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	results_text_area.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	results_text_area.bbcode_enabled = true
	results_text_area.set_custom_minimum_size(Vector2(300, 0))
	results_container.add_child(results_text_area)

	# Status bar at bottom
	status_label = Label.new()
	status_label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	status_label.set_custom_minimum_size(Vector2(0, 30))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.text = "Ready"
	main_vbox.add_child(status_label)

	# Set split container position
	split.split_offset = 300


## Handle search field text changes
func _on_search_field_text_changed(new_text: String) -> void:
	current_search_term = new_text

	if new_text.is_empty():
		# If search is cleared, return to regular view
		if not current_category_path.is_empty():
			show_category(current_category_path)
		else:
			show_category("")
	else:
		# Perform search across all categories and buttons
		_display_search_results(new_text)


## Clear search field
func _on_search_clear_pressed() -> void:
	search_field.text = ""
	current_search_term = ""

	# Return to regular view
	if not current_category_path.is_empty():
		show_category(current_category_path)
	else:
		show_category("")


## Display search results for a given search term
func _display_search_results(search_term: String) -> void:
	_clear_active_ui_elements()

	# Create a "searching for..." label
	var search_label = Label.new()
	search_label.text = "Searching for: " + search_term
	search_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui_container.add_child(search_label)
	active_ui_elements.append(search_label)

	# Add a separator
	var separator = HSeparatorWithMargin.new()
	ui_container.add_child(separator)
	active_ui_elements.append(separator)

	# Track if we found any results
	var results_found = false

	# Search through all categories and buttons
	for category_path in categories.keys():
		var category = categories[category_path]

		for button_data in category.buttons:
			if search_term.to_lower() in button_data.text.to_lower():
				# Found a match!
				results_found = true

				# Create a label for the category path
				var path_label = Label.new()
				if category_path.is_empty():
					path_label.text = "[Root]"
				else:
					path_label.text = category_path
				path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				path_label.modulate = Color(0.7, 0.7, 0.7)  # Gray color
				ui_container.add_child(path_label)
				active_ui_elements.append(path_label)

				# Create the button UI
				var button_ui = _create_button_ui(button_data)
				ui_container.add_child(button_ui)
				active_ui_elements.append(button_ui)

	# If no results found, show a message
	if not results_found:
		var no_results_label = Label.new()
		no_results_label.text = "No results found for: " + search_term
		no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui_container.add_child(no_results_label)
		active_ui_elements.append(no_results_label)


## Utility class for separator with margins
class HSeparatorWithMargin:
	extends HSeparator

	func _init() -> void:
		custom_minimum_size = Vector2(0, 20)
		add_theme_constant_override("separation", 10)


## Show menu content (called externally)
func show_menu_content() -> void:
	show_category("")


## Create a new category
func create_category(category_path: String, description: String = "") -> DebugCategory:
	if categories.has(category_path):
		# Category already exists, return it
		return categories[category_path]

	# Create a new category
	var category = DebugCategory.new(category_path, description)
	category.full_path = category_path
	categories[category_path] = category

	# If this is a subcategory, create it in the parent
	if "/" in category_path:
		var parent_path = category_path.substr(0, category_path.rfind("/"))

		# Ensure parent category exists recursively
		var parent_category: DebugCategory
		if not categories.has(parent_path):
			parent_category = create_category(parent_path)
		else:
			parent_category = categories[parent_path]

		# Find the category name (last part after /)
		var category_name = category_path.substr(category_path.rfind("/") + 1)

		# Create a button for this category in the parent if not already exists
		if not parent_category.has_subcategory(category_name):
			var category_button = DebugButton.create_category_button(category_name, category_path)
			parent_category.add_button(category_button)

	return category


## Add a button to a category
func add_button(
	category_path: String,
	label: String,
	callback: Callable,
	is_test: bool = false,
	description: String = ""
) -> void:
	# Ensure category exists
	if not categories.has(category_path):
		create_category(category_path)

	# Create and add button to the category
	categories[category_path].create_button(label, callback, is_test, description)


## Create button UI for a DebugButton data
func _create_button_ui(button_data: DebugButton) -> Button:
	var button = Button.new()
	button.text = button_data.text
	button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	button.set_custom_minimum_size(Vector2(0, 40))  # Larger for mobile touch

	# Style differently based on type
	if button_data.is_category:
		# Category button styling
		button.text = button_data.text + " >"

		# Configure button for navigation
		button.pressed.connect(func(): show_category(button_data.category))
	else:
		# Regular button or test
		if button_data.is_test:
			# Test button with special styling
			button.pressed.connect(func(): _execute_test_button(button_data, button))
		else:
			# Regular button
			button.pressed.connect(func(): _execute_action_button(button_data, button))

	return button


## Execute a regular action button (non-test)
func _execute_action_button(button_data: DebugButton, button_ui: Button) -> void:
	if not is_instance_valid(button_ui):
		Log.warning("Button UI no longer valid for action execution", {}, ["debug_menu"])
		return

	var original_text = button_ui.text
	button_ui.text = "Running..."
	button_ui.modulate = Color(0.7, 0.7, 0.7)

	# Execute action
	var result = button_data.execute()

	# Update status
	if is_instance_valid(status_label):
		status_label.text = "Action completed: " + original_text

	# Reset button appearance
	button_ui.text = original_text
	button_ui.modulate = Color.WHITE


## Execute a test button and show result
func _execute_test_button(button_data: DebugButton, button_ui: Button) -> void:
	if not is_instance_valid(button_ui):
		Log.warning("Button UI no longer valid for test execution", {}, ["debug_menu"])
		return

	var original_text = button_ui.text
	button_ui.text = "Running..."
	button_ui.modulate = Color(0.7, 0.7, 0.7)

	# Store for async operation
	var test_start_time = Time.get_ticks_msec()

	# Execute test and handle result
	var result = button_data.run_test()

	if result[0]:  # Success
		var message = result[1]
		if message is Dictionary and message.has("awaiting") and message.awaiting:
			# Awaitable test - we need to wait for result
			Log.debug("Test is awaitable, waiting for completion signal", {}, ["debug_menu"])

			# Connect to completed signal
			var completion_callable = func(success: bool, data: Variant):
				_on_test_completed(success, data, button_ui, original_text, test_start_time)

			# Connect only if not already connected
			if not button_data.test_passed.is_connected(completion_callable):
				button_data.test_passed.connect(completion_callable)
			if not button_data.test_failed.is_connected(completion_callable):
				button_data.test_failed.connect(completion_callable)

			# Result will be processed via signal
			return
		else:
			# Direct success
			_on_test_completed(true, message, button_ui, original_text, test_start_time)
	else:  # Failure
		_on_test_completed(false, result[1], button_ui, original_text, test_start_time)


## Handle test completion (direct or via signal)
func _on_test_completed(
	success: bool, data: Variant, button_ui: Button, original_text: String, start_time: int
) -> void:
	var duration = Time.get_ticks_msec() - start_time

	# Update status
	if is_instance_valid(status_label):
		status_label.text = (
			"Test " + ("Passed" if success else "Failed") + " in " + str(duration) + "ms"
		)

	# Update detailed results
	if is_instance_valid(results_text_area):
		results_text_area.clear()
		results_text_area.append_text("[b]Test:[/b] " + original_text + "\n")
		results_text_area.append_text(
			(
				"[b]Status:[/b] "
				+ ("[color=green]Passed[/color]" if success else "[color=red]Failed[/color]")
				+ "\n"
			)
		)
		results_text_area.append_text("[b]Duration:[/b] " + str(duration) + "ms\n\n")
		results_text_area.append_text("[b]Details:[/b]\n")

		_append_formatted_data(results_text_area, data)

	# Visual feedback on button
	if is_instance_valid(button_ui):
		button_ui.modulate = Color(0.5, 1.0, 0.5) if success else Color(1.0, 0.5, 0.5)
		button_ui.text = original_text + (" ✓" if success else " ✗")

	# Schedule reset of appearance after a delay
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(button_ui):  # Check if button is still valid (e.g. not cleared)
		button_ui.text = original_text
		button_ui.modulate = Color.WHITE


## Clean up active UI elements
func _clear_active_ui_elements() -> void:
	# Remove all active UI elements
	for element in active_ui_elements:
		if is_instance_valid(element):
			element.queue_free()

	# Clear the array
	active_ui_elements.clear()


## Format and append data to the results text area
func _append_formatted_data(text_area: RichTextLabel, data: Variant, level: int = 0) -> void:
	var indent = "    ".repeat(level)

	if data is Dictionary:
		for key in data.keys():
			var value = data[key]
			if value is Dictionary or value is Array:
				text_area.append_text(indent + "[b]" + str(key) + ":[/b]\n")
				_append_formatted_data(text_area, value, level + 1)
			else:
				text_area.append_text(indent + "[b]" + str(key) + ":[/b] " + str(value) + "\n")
	elif data is Array:
		for i in range(data.size()):
			var value = data[i]
			if value is Dictionary or value is Array:
				text_area.append_text(indent + "[b]" + str(i) + ":[/b]\n")
				_append_formatted_data(text_area, value, level + 1)
			else:
				text_area.append_text(indent + "[b]" + str(i) + ":[/b] " + str(value) + "\n")
	else:
		text_area.append_text(indent + str(data) + "\n")


## Show a specific category by path
## Go back to previous category
func _on_back_button_pressed() -> void:
	if navigation_history.is_empty():
		show_category("")  # Go to root if no history
	else:
		var previous_category = navigation_history.pop_back()
		show_category(previous_category)


## Create nested categories from a path string (like "Parent/Child/Grandchild")
func create_nested_categories(path: String) -> void:
	if path.is_empty():
		return

	# Split the path by '/'
	var parts: Array = path.split("/", false)
	var current_path: String = ""

	# Create each level of the hierarchy
	for i: int in range(parts.size()):
		if current_path.is_empty():
			current_path = parts[i]
		else:
			current_path += "/" + parts[i]

		# Create the category if it doesn't exist
		if not categories.has(current_path):
			create_category(current_path)


## Show a specific category by path
func show_category(category_path: String) -> void:
	if not ui_container or not is_instance_valid(ui_container):
		Log.warning("UI container not ready for show_category.", {}, ["debug_menu"])
		return

	_clear_active_ui_elements()

	# Update current category path and history
	if category_path != current_category_path:
		if current_category_path != "":  # Don't add empty root to history if navigating from it
			var already_in_history = false
			if (
				not navigation_history.is_empty()
				and navigation_history.back() == current_category_path
			):
				already_in_history = true  # Avoid duplicate if navigating back then forward
			if not already_in_history:
				navigation_history.append(current_category_path)
		current_category_path = category_path

		# Save the current category path in settings
		if settings:  # Check if settings object is valid
			settings.set_value("navigation", "last_category", current_category_path)

	# Show back button if we're not at the root
	if is_instance_valid(back_button):
		back_button.visible = (category_path != "")

	# Show current path if we're not at the root
	if is_instance_valid(current_path_label):
		if category_path == "":
			current_path_label.visible = false
		else:
			current_path_label.visible = true

			# Create a breadcrumb trail for navigation
			var path_parts: Array = category_path.split("/", false)
			var breadcrumb_text: String = ""
			var full_path_so_far: String = ""  # Renamed to avoid conflict

			for i: int in range(path_parts.size()):
				var part: String = path_parts[i]

				if i > 0:
					full_path_so_far += "/"
				full_path_so_far += part

				if i > 0:
					breadcrumb_text += " > "

				# Make each breadcrumb part a button
				breadcrumb_text += "[url=" + full_path_so_far + "]" + part + "[/url]"

			current_path_label.text = breadcrumb_text

			# Handle breadcrumb clicks
			if not current_path_label.meta_clicked.is_connected(_on_breadcrumb_clicked):
				current_path_label.meta_clicked.connect(_on_breadcrumb_clicked)
	else:
		Log.warning("current_path_label is not valid", {}, ["debug_menu"])

	# Display category content
	_display_category_content(category_path)


## Handle breadcrumb navigation clicks
func _on_breadcrumb_clicked(meta_path: Variant) -> void:
	if meta_path is String:
		show_category(meta_path)


## Display the content of a specific category
func _display_category_content(category_path: String) -> void:
	if not is_instance_valid(ui_container):
		Log.warning("UI container not ready for displaying category content.", {}, ["debug_menu"])
		return

	# Clear existing UI elements
	_clear_active_ui_elements()

	if categories.has(category_path):
		var current_category: DebugCategory = categories[category_path]

		# Create a header for categories
		if not current_category.buttons.is_empty():
			var header_label = Label.new()
			header_label.text = "Categories"
			header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			ui_container.add_child(header_label)
			active_ui_elements.append(header_label)

			# Add category buttons
			var found_categories = false
			for button_data in current_category.buttons:
				if button_data.is_category:
					found_categories = true
					var button_ui = _create_button_ui(button_data)
					ui_container.add_child(button_ui)
					active_ui_elements.append(button_ui)

			# Add a separator if we found categories
			if found_categories:
				var separator = HSeparator.new()
				separator.set_custom_minimum_size(Vector2(0, 20))
				ui_container.add_child(separator)
				active_ui_elements.append(separator)

		# Create a header for buttons
		var header_label2 = Label.new()
		header_label2.text = "Actions"
		header_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ui_container.add_child(header_label2)
		active_ui_elements.append(header_label2)

		# Add action buttons
		var found_actions = false
		for button_data in current_category.buttons:
			if not button_data.is_category:
				found_actions = true
				var button_ui = _create_button_ui(button_data)
				ui_container.add_child(button_ui)
				active_ui_elements.append(button_ui)

		# If no actions found, show a message
		if not found_actions:
			var no_actions_label = Label.new()
			no_actions_label.text = "No actions available in this category."
			no_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui_container.add_child(no_actions_label)
			active_ui_elements.append(no_actions_label)
	else:
		# Category not found, show root categories
		if category_path != "":
			Log.warning("Category not found: " + category_path, {}, ["debug_menu"])
			show_category("")
			return

		# Display root categories
		var root_categories = []
		for cat_path in categories.keys():
			if not "/" in cat_path and cat_path != "":
				root_categories.append(cat_path)

		root_categories.sort()

		if root_categories.is_empty():
			var no_categories = Label.new()
			no_categories.text = "No categories available."
			no_categories.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui_container.add_child(no_categories)
			active_ui_elements.append(no_categories)
		else:
			for cat_name in root_categories:
				var button_data = DebugButton.new(cat_name, Callable())
				button_data.is_category = true
				button_data.category = cat_name

				var button_ui = _create_button_ui(button_data)
				ui_container.add_child(button_ui)
				active_ui_elements.append(button_ui)
