extends Node

## Autoload for managing the debug menu

# Reference to the main debug menu instance
var debug_menu: Node = null

# Packed scene for the debug menu UI
var debug_menu_scene: PackedScene = preload("res://debug/debug_menu.tscn")

# Initialization flag
var is_initialized: bool = false

# Instead of trying to use class_name directly, we'll use a more robust approach
# to create debug menu instances
var DebugMenuScript = null  # Will be loaded in _ready


func _ready() -> void:
	Log.info("debug_menu_controller _ready called", {}, ["debug"])

	# Load the debug menu script - using runtime loading to avoid circular dependencies
	DebugMenuScript = load("res://debug/debug_menu.gd")
	if not DebugMenuScript:
		Log.error("Could not load debug_menu.gd script!", {}, ["debug"])

	# Register ourselves as a singleton for access by other scripts
	if not Engine.has_singleton("debug_menu_controller"):
		# This shouldn't be necessary since it's in project.godot, but just to be safe
		Engine.register_singleton("debug_menu_controller", self)

	Log.info("debug_menu_controller instance ready", {"instance_id": get_instance_id()}, ["debug"])

	# Defer initialization to ensure other autoloads are ready
	# We initialize regardless of debug build status to ensure the debug menu is always available
	call_deferred("initialize")

	# Output verification info
	print("Debug Menu Controller ready, instance ID: " + str(get_instance_id()))


## Initialize the debug menu
func initialize() -> void:
	if is_initialized:
		Log.info("Debug menu controller already initialized, skipping", {}, ["debug"])
		return

	Log.info("Initializing debug menu controller", {}, ["debug"])

	# Create the debug menu instance using the loaded script
	if DebugMenuScript:
		debug_menu = DebugMenuScript.new()
	else:
		Log.error("Cannot create debug_menu - script not loaded!", {}, ["debug"])
		return

	# Cannot set dictionary as singleton, log instead
	Log.info(
		"Debug menu instance created",
		{"instance_id": debug_menu.get_instance_id() if debug_menu else 0},
		["debug"]
	)

	# Instance the debug menu scene
	var debug_ui = debug_menu_scene.instantiate()
	debug_ui.name = "DebugMenuUI"
	add_child(debug_ui)

	# Get the Control node from the instanced scene
	var control_node = debug_ui.get_node("Control")
	if control_node:
		# Add our debug menu instance to the scene
		var content_container = control_node.get_node_or_null("SafeArea/Panel/MarginContainer/VBoxContainer/ScrollContainer/ContentContainer")
		if content_container:
			debug_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			debug_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content_container.add_child(debug_menu)

		# Connect the close button
		var close_button = control_node.get_node_or_null("%CloseButton")
		if close_button:
			close_button.pressed.connect(hide_menu)

	# Hide by default
	debug_ui.visible = false

	# Debug menu UI info
	var menu_ref = get_node_or_null("DebugMenuUI")
	Log.info("Debug menu UI setup", {
		"debug_ui_valid": is_instance_valid(menu_ref),
		"debug_ui_name": menu_ref.name if menu_ref else "none",
		"debug_menu_valid": is_instance_valid(debug_menu)
	}, ["debug"])

	# Register system debug functions
	_register_system_debug_functions()

	# Register settings options
	register_settings_options()

	is_initialized = true

	# Add verification button to debug menu itself
	if debug_menu:
		# Add a verification button
		var verify_func: Callable = func() -> Array[Variant]:
			var menu_ui = get_node_or_null("DebugMenuUI")
			return [
				true,
				{
					"controller_initialized": is_initialized,
					"debug_menu_valid": is_instance_valid(debug_menu),
					"debug_ui_visible": menu_ui.visible if menu_ui else false,
					"singleton_found": Engine.has_singleton("debug_menu_controller"),
					"engine_singleton_matches":
					Engine.get_singleton("debug_menu_controller") == self
				}
			]

		debug_menu.add_button(
			"System",
			"Verify Debug Menu Controller",
			verify_func,
			true,
			"Verify debug menu controller is properly initialized"
		)

	Log.info(
		"Debug menu controller initialized",
		{
			"controller_ref": self.get_instance_id(),
			"debug_menu_ref": debug_menu.get_instance_id() if debug_menu else 0,
			"debug_menu_ui_valid": is_instance_valid(get_node_or_null("DebugMenuUI"))
		},
		["debug"]
	)


## Show the debug menu
func show_menu() -> void:
	if not is_initialized:
		initialize()

	var debug_ui = get_node_or_null("DebugMenuUI")
	if debug_ui:
		# Show the menu UI
		debug_ui.visible = true

		# Force a refresh of the menu content
		if debug_menu:
			# Reset any search terms or filters
			if debug_menu.has_method("_on_search_clear_pressed"):
				debug_menu._on_search_clear_pressed()

			# Force showing the root category to ensure all items are visible
			debug_menu.show_menu_content()

			# Log detailed debug info
			Log.info("Showing debug menu", {
				"debug_ui_visible": debug_ui.visible,
				"categories_count": debug_menu.categories.size(),
				"categories": debug_menu.categories.keys()
			}, ["debug"])
	else:
		Log.error("Debug menu UI not found", {}, ["debug"])


## Hide the debug menu
func hide_menu() -> void:
	var debug_ui = get_node_or_null("DebugMenuUI")
	if debug_ui:
		debug_ui.visible = false
	else:
		Log.error("Debug menu UI not found", {}, ["debug"])


## Register a button with the debug menu
func register_button(
	category: String,
	label: String,
	callback: Callable,
	is_test: bool = false,
	p_description: String = ""
) -> void:
	if not is_initialized:
		initialize()

	if debug_menu:
		debug_menu.add_button(category, label, callback, is_test, p_description)


## Register system debug functions
func _register_system_debug_functions() -> void:
	if not debug_menu:
		return

	# Create system categories
	debug_menu.create_nested_categories("System/Hardware")
	debug_menu.create_nested_categories("System/Performance")
	debug_menu.create_nested_categories("System/Input")

	# System information function
	var system_info_func: Callable = func() -> Array[Variant]:
		var info = {
			"platform": OS.get_name(),
			"model": OS.get_model_name(),
			"processor_count": OS.get_processor_count(),
			"device_unique_id": OS.get_unique_id(),
			"screen_size": DisplayServer.screen_get_size(),
			"screen_dpi": DisplayServer.screen_get_dpi(),
			"executable_path": OS.get_executable_path(),
			"user_data_dir": OS.get_user_data_dir()
		}
		return [true, info]

	debug_menu.add_button(
		"System/Hardware",
		"System Information",
		system_info_func,
		true,
		"Get detailed system information"
	)

	# Performance monitor function
	var performance_func: Callable = func() -> Array[Variant]:
		var perf_info = {
			"fps": Engine.get_frames_per_second(),
			"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"rendering_time": Performance.get_monitor(Performance.TIME_FPS),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
			"memory_dynamic": 0,  # Performance.MEMORY_DYNAMIC is not available in this Godot version
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		}
		return [true, perf_info]

	debug_menu.add_button(
		"System/Performance",
		"Performance Metrics",
		performance_func,
		true,
		"Get real-time performance metrics"
	)

	# Input devices function
	var input_devices_func: Callable = func() -> Array[Variant]:
		var input_info = {
			"connected_joypads": Input.get_connected_joypads(),
			"joy_connection_count": Input.get_connected_joypads().size(),  # Instead of get_joy_name_count()
			"touch_supported": DisplayServer.is_touchscreen_available(),
			"gravity_supported": false,  # Input.is_gravity_sensor_available() is not available in this Godot version
			"gyroscope_supported": false,  # Input.is_gyroscope_available() is not available in this Godot version
			"acceleration_supported": false,  # Input.is_accelerometer_available() is not available in this Godot version
			"magnetometer_supported": false  # Input.is_magnetometer_available() is not available in this Godot version
		}
		return [true, input_info]

	debug_menu.add_button(
		"System/Input",
		"Input Devices",
		input_devices_func,
		true,
		"Get information about input devices"
	)


## Toggle the debug menu visibility
func toggle_menu() -> void:
	if not is_initialized:
		initialize()
		show_menu()
	elif is_instance_valid(get_node_or_null("DebugMenuUI")) and get_node_or_null("DebugMenuUI").visible:
		hide_menu()
	else:
		show_menu()


## Input handling for debug menu toggling
func _input(event: InputEvent) -> void:
	# Only in debug builds
	if not OS.is_debug_build():
		return

	# Toggle menu on specific key combination (Shift+F1) or four-finger tap for mobile
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and event.shift_pressed:
			toggle_menu()

	# Check for multi-touch (for mobile)
	if event is InputEventScreenTouch and event.pressed:
		# In Godot 4.5, we need to use a different approach for touch detection
		# We'll rely on a debug pattern: 3 quick taps in the corner
		if event.position.x < 100 and event.position.y < 100:
			# Store the last tap time and count consecutive taps
			var current_time: int = Time.get_ticks_msec()
			var tap_interval: int = 500  # ms between taps

			if not Engine.has_meta("last_debug_tap_time"):
				Engine.set_meta("last_debug_tap_time", current_time)
				Engine.set_meta("debug_tap_count", 1)
			else:
				var last_time: int = Engine.get_meta("last_debug_tap_time") as int
				if current_time - last_time < tap_interval:
					var tap_count: int = Engine.get_meta("debug_tap_count") as int + 1
					Engine.set_meta("debug_tap_count", tap_count)

					if tap_count >= 3:
						Engine.set_meta("debug_tap_count", 0)
						toggle_menu()
				else:
					Engine.set_meta("debug_tap_count", 1)

				Engine.set_meta("last_debug_tap_time", current_time)


## Add a function as a testable button
func add_test(
	category: String, label: String, callback: Callable, p_description: String = ""
) -> void:
	register_button(category, label, callback, true, p_description)


## Add a simple button
func add_button(
	category: String, label: String, callback: Callable, p_description: String = ""
) -> void:
	register_button(category, label, callback, false, p_description)


## Register debug menu settings
func register_settings_options() -> void:
	if not debug_menu:
		return

	# Create a Settings category - simplified to avoid indentation issues
	var about_debug_menu_func: Callable = func() -> Array[Variant]:
		return [
			true,
			{
				"version": "1.2.0",
				"description": "A comprehensive debug menu system for GameTwo project",
				"updated": "May 2025",
				"features":
				[
					"Hierarchical categories",
					"Test execution and reporting",
					"Search functionality",
					"Theme customization",
					"Navigation history"
				]
			}
		]

	debug_menu.add_button(
		"Settings",
		"About Debug Menu",
		about_debug_menu_func,
		true,
		"View information about the debug menu system"
	)

	# Register theme options
	debug_menu.create_nested_categories("Settings/Appearance")

	# Get available themes
	var available_themes: Array[String]
	available_themes.assign(debug_menu.themes.keys())
	for theme_name: String in available_themes:
		# Create a button for each theme - using closure to capture the theme_name
		var apply_theme_func: Callable = func() -> Array[Variant]:
			debug_menu._apply_theme(theme_name)
			debug_menu._save_settings()
			return [true, {"message": "Applied theme: " + theme_name}]

		debug_menu.add_button(
			"Settings/Appearance",
			"Theme: " + theme_name.capitalize(),
			apply_theme_func,
			true,
			"Apply the " + theme_name + " theme to the debug menu"
		)

	# Add system configuration options
	debug_menu.create_nested_categories("Settings/System")

	# Clear settings function - simplified to avoid indentation issues
	var clear_settings_func: Callable = func() -> Array[Variant]:
		var dir: DirAccess = DirAccess.open("user://")
		if dir and dir.file_exists(debug_menu.SETTINGS_PATH.get_file()):
			var err: Error = dir.remove(debug_menu.SETTINGS_PATH.get_file())
			if err == OK:
				return [true, {"message": "Settings cleared successfully"}]
			else:
				return [false, {"error": "Failed to clear settings", "code": err}]
		return [false, {"error": "Settings file not found"}]

	debug_menu.add_button(
		"Settings/System",
		"Clear Settings",
		clear_settings_func,
		true,
		"Clear all debug menu settings and restore defaults"
	)

	# Reload debug menu function - simplified to avoid indentation issues
	var reload_debug_menu_func: Callable = func() -> Array[Variant]:
		hide_menu()
		debug_menu = null
		initialize()
		show_menu()
		return [true, {"message": "Debug menu reloaded successfully"}]

	debug_menu.add_button(
		"Settings/System",
		"Reload Debug Menu",
		reload_debug_menu_func,
		false,
		"Reload the debug menu system"
	)
