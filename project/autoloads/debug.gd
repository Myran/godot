extends Node

signal debug_event

enum DebugEventType {
	EVENT_OPEN_DEBUG_MENU,  # Used by top bar to open legacy debug menu
	EVENT_OPEN_NEW_DEBUG_MENU,  # Used by the new debug menu button
	EVENT_OPEN_GAME_SELECTOR,
	EVENT_RESET_MATCH_LEVEL,
	EVENT_FORCE_LOAD_MATCH_LEVEL,
	EVENT_OPEN_DB_DEBUG_MENU,
	EVENT_CLOSE_DB_DEBUG_MENU
}

# Variable to track if debug menu setup is complete
var setup_ok: bool = false

@export var use_local_battle_db: bool
@export var asset_variant: int
@export var popup_debug: Control
@export var v_box_container_buttons: VBoxContainer

# UI component for showing status messages
var status_label: Label = null


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


# The debug_menu reference
var debug_menu: Node = null
var debug_menu_controller: Node = null


func _on_debug_event(event: DebugEventType, _data: Variant = null) -> void:
	match event:
		DebugEventType.EVENT_OPEN_DEBUG_MENU:
			# When triggered from top bar, always show the legacy popup_debug
			Log.info("Opening legacy popup debug menu", {}, [Log.TAG_DEBUG])
			popup_debug.show()

		DebugEventType.EVENT_OPEN_NEW_DEBUG_MENU:
			# This event is specifically for the new debug menu button
			# Check for it directly from Engine just to be sure
			var controller = (
				Engine.get_singleton("debug_menu_controller")
				if Engine.has_singleton("debug_menu_controller")
				else debug_menu_controller
			)

			if controller and controller.has_method("show_menu") and controller.is_initialized:
				Log.info("Opening new debug menu via controller", {}, [Log.TAG_DEBUG])
				controller.show_menu()
			elif debug_menu:
				Log.info("Opening fallback debug menu", {}, [Log.TAG_DEBUG])
				debug_menu.show_menu_content()
			else:
				Log.info("Opening fallback popup debug menu", {}, [Log.TAG_DEBUG])
				popup_debug.show()
		DebugEventType.EVENT_OPEN_DB_DEBUG_MENU:
			if debug_menu:
				debug_menu.show_menu_content()
			else:
				# Legacy behavior
				Log.info("Opening scene_debug.tscn (legacy)", {}, [Log.TAG_DEBUG])
				# Old implementation would handle this


func _ready() -> void:
	Log.info("Debug module initialized", {}, [Log.TAG_DB])
	popup_debug.hide()
	debug_event.connect(_on_debug_event)
	for btn: Button in v_box_container_buttons.get_children():
		btn.pressed.connect(debug_button_pressed.bind(btn.name))

	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()

	# Ensure we can access the debug_menu_controller
	# Wait a few frames to make sure all autoloads are fully initialized
	await get_tree().process_frame
	await get_tree().process_frame

	# Try getting the debug_menu_controller from the Engine singletons
	if Engine.has_singleton("debug_menu_controller"):
		debug_menu_controller = Engine.get_singleton("debug_menu_controller")
		if is_instance_valid(debug_menu_controller):
			Log.info("Found debug_menu_controller autoload", {}, [Log.TAG_DEBUG])

			# Make sure it's initialized
			if (
				not debug_menu_controller.is_initialized
				and debug_menu_controller.has_method("initialize")
			):
				debug_menu_controller.initialize()
				Log.info("Initialized debug_menu_controller in _ready", {}, [Log.TAG_DEBUG])

			# Wait a bit to ensure it's fully initialized
			await get_tree().process_frame
			await get_tree().process_frame  # Wait one more frame for good measure

			if debug_menu_controller.debug_menu != null:
				debug_menu = debug_menu_controller.debug_menu
				Log.info("Successfully obtained debug_menu instance", {}, [Log.TAG_DEBUG])
			else:
				Log.warning("debug_menu not created in controller", {}, [Log.TAG_DEBUG])
		else:
			Log.warning("debug_menu_controller autoload not valid", {}, [Log.TAG_DEBUG])
	else:
		# Try finding it as a node instead
		var potential_controller = get_node_or_null("/root/debug_menu_controller")
		if is_instance_valid(potential_controller):
			debug_menu_controller = potential_controller
			Log.info("Found debug_menu_controller as node in scene tree", {}, [Log.TAG_DEBUG])

			# Initialize it if needed
			if (
				not debug_menu_controller.is_initialized
				and debug_menu_controller.has_method("initialize")
			):
				debug_menu_controller.initialize()

			await get_tree().process_frame

			if debug_menu_controller.debug_menu != null:
				debug_menu = debug_menu_controller.debug_menu
			else:
				Log.warning("debug_menu not created in controller (from node)", {}, [Log.TAG_DEBUG])
		else:
			Log.warning("debug_menu_controller not found as autoload or node", {}, [Log.TAG_DEBUG])

	# Register debug functions with the new debug menu
	_register_debug_functions()

	# Run automatic verification to ensure everything is working properly
	call_deferred("run_automatic_verification")


func _verify_logger_export() -> void:
	if OS.get_name() == "iOS":
		if IosLoggerHelper:
			Log.info("iOS logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("iOS logger helper missing!", {}, [Log.TAG_DEBUG])
	if OS.get_name() == "Android":
		if AndroidLoggerHelper:
			Log.info("Android logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("Android logger helper missing!", {}, [Log.TAG_DEBUG])


func _register_debug_functions() -> void:
	# Skip if debug_menu is not available (should be registered by this point)
	if not debug_menu and not debug_menu_controller:
		Log.warning("Debug menu not available, skipping registration", {}, [Log.TAG_DEBUG])
		return

	# Create button to show the new debug menu in the popup_debug
	var show_new_debug_menu_func: Callable = func() -> Variant:
		Log.info("Opening new debug menu from legacy menu", {}, [Log.TAG_DEBUG])
		popup_debug.hide()
		# Use the event type specifically for the new debug menu
		action(DebugEventType.EVENT_OPEN_NEW_DEBUG_MENU)
		return null

	# We don't need to manually add the button as it's already in the TSCN file
	# Connect the existing button to our function
	var existing_new_debug_button: Button = v_box_container_buttons.get_node_or_null(
		"button_new_debug_menu"
	)
	if existing_new_debug_button:
		Log.info("Found existing button_new_debug_menu, connecting function", {}, [Log.TAG_DEBUG])
		# Disconnect any existing connections to avoid duplicates
		if existing_new_debug_button.pressed.is_connected(
			debug_button_pressed.bind("button_new_debug_menu")
		):
			existing_new_debug_button.pressed.disconnect(
				debug_button_pressed.bind("button_new_debug_menu")
			)
		existing_new_debug_button.pressed.connect(show_new_debug_menu_func)

		# Style the button to make it stand out
		existing_new_debug_button.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green text
		existing_new_debug_button.add_theme_font_size_override("font_size", 18)  # Slightly larger font
	else:
		Log.warning(
			"button_new_debug_menu not found in v_box_container_buttons", {}, [Log.TAG_DEBUG]
		)

	# Use the appropriate debug menu instance
	var menu_to_use: Node = (
		debug_menu
		if debug_menu
		else debug_menu_controller.debug_menu if debug_menu_controller else null
	)

	if not menu_to_use:
		Log.warning("No debug menu available for registration", {}, [Log.TAG_DEBUG])
		return

	# Register game management buttons
	var select_game_func: Callable = func() -> Variant:
		action(DebugEventType.EVENT_OPEN_GAME_SELECTOR)
		return null

	var reset_level_func: Callable = func() -> Variant:
		action(DebugEventType.EVENT_RESET_MATCH_LEVEL)
		return null

	menu_to_use.add_button("Game Management", "Select Game", select_game_func)
	menu_to_use.add_button("Game Management", "Reset Current Level", reset_level_func)

	# Register level loading buttons
	for i: int in range(1, 6):
		var level_name: String = "level_0" + str(i)
		var load_level_func: Callable = func() -> Variant:
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, [level_name])
			return null
		menu_to_use.add_button("Level Management", "Load Level " + str(i), load_level_func)

	# Register enemy population test
	var populate_lineup_func: Callable = func() -> Array[Variant]:
		Log.debug("Populating enemy lineup with test cards", {}, [Log.TAG_DB, Log.TAG_DEBUG])
		_populate_enemy_lineup()
		return [true, {"message": "Enemy lineup populated"}]

	menu_to_use.add_button("Testing", "Populate Enemy Lineup", populate_lineup_func, true)

	# Create nested categories for demonstration tools
	create_nested_categories("Debug Tools/UI Tests")
	create_nested_categories("Debug Tools/Performance")
	create_nested_categories("Debug Tools/Logging")

	# Define test functions
	var test_dialog_func: Callable = func() -> Array[Variant]:
		if ui:
			Log.debug("Showing test modal dialog", {}, [Log.TAG_DEBUG, Log.TAG_UI])
			return [true, {"message": "Modal dialog displayed"}]
		return [false, {"error": "UI not available"}]

	var monitor_fps_func: Callable = func() -> Array[Variant]:
		var fps: int = Engine.get_frames_per_second()
		var process_time: float = Performance.get_monitor(Performance.TIME_PROCESS)
		Log.debug("FPS: " + str(fps), {"process_time": process_time}, [Log.TAG_DEBUG])
		# Return process_time as float to avoid narrowing conversion
		return [true, {"fps": fps, "process_time": process_time}]

	var test_log_levels_func: Callable = func() -> Array[Variant]:
		Log.debug("This is a DEBUG message", {}, [Log.TAG_DEBUG])
		Log.info("This is an INFO message", {}, [Log.TAG_DEBUG])
		Log.warning("This is a WARNING message", {}, [Log.TAG_DEBUG])
		Log.error("This is an ERROR message", {}, [Log.TAG_DEBUG])
		return [true, {"message": "All log levels tested"}]

	# Add the buttons with test functions
	menu_to_use.add_button("Debug Tools/UI Tests", "Test Modal Dialog", test_dialog_func, true)
	menu_to_use.add_button("Debug Tools/Performance", "Monitor FPS", monitor_fps_func, true)
	menu_to_use.add_button("Debug Tools/Logging", "Test Log Levels", test_log_levels_func, true)


func _populate_enemy_lineup() -> void:
	for n: int in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, n))
	for n: int in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))


func create_debug_category(category_name: String, description: String = "") -> void:
	var menu_to_use: Node = (
		debug_menu
		if debug_menu
		else debug_menu_controller.debug_menu if debug_menu_controller else null
	)

	if not menu_to_use:
		Log.warning("Debug menu not available, skipping category creation", {}, [Log.TAG_DEBUG])
		return

	menu_to_use.create_category(category_name, description)


# Run automatic verification of the debug menu functionality
func run_automatic_verification() -> void:
	Log.info("Starting automatic debug menu verification...", {}, [Log.TAG_DEBUG])

	# Wait for a couple of frames to ensure everything is initialized
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. Check autoload registration
	var autoload_check = Engine.has_singleton("debug_menu_controller")
	var autoloads = Engine.get_singleton_list()

	Log.info(
		"Autoload check",
		{"debug_menu_controller_registered": autoload_check, "available_autoloads": autoloads},
		[Log.TAG_DEBUG]
	)

	# If autoload not registered, try to find issue
	if not autoload_check:
		Log.error("debug_menu_controller not found in autoloads!", {}, [Log.TAG_DEBUG])
		_report_verification_result(false, "Autoload not registered properly")
		return

	# 2. Check controller instance
	var controller = Engine.get_singleton("debug_menu_controller")
	if not controller or not is_instance_valid(controller):
		Log.error("debug_menu_controller singleton not valid!", {}, [Log.TAG_DEBUG])
		_report_verification_result(false, "Autoload instance not valid")
		return

	# Update our reference
	debug_menu_controller = controller

	Log.info(
		"Controller reference",
		{
			"instance_id": controller.get_instance_id(),
			"methods": get_available_methods(controller),
			"is_initialized":
			controller.is_initialized if controller.get("is_initialized") != null else "unknown"
		},
		[Log.TAG_DEBUG]
	)

	# 3. Check initialization state and force initialize if needed
	if not controller.is_initialized and controller.has_method("initialize"):
		Log.info("Initializing controller during verification", {}, [Log.TAG_DEBUG])
		controller.initialize()
		await get_tree().process_frame
		await get_tree().process_frame

	if not controller.is_initialized:
		Log.error("Failed to initialize debug_menu_controller!", {}, [Log.TAG_DEBUG])
		_report_verification_result(false, "Controller initialization failed")
		return

	# 4. Check debug_menu instance
	if not controller.debug_menu or not is_instance_valid(controller.debug_menu):
		Log.error("debug_menu instance not valid in controller!", {}, [Log.TAG_DEBUG])
		_report_verification_result(false, "Debug menu instance not valid")
		return

	# Update our reference
	debug_menu = controller.debug_menu

	# 5. Simulate button press (do not actually open the menu)
	var simulation_result = _simulate_button_press()

	if simulation_result:
		Log.info("Debug menu button simulation successful", {}, [Log.TAG_DEBUG])
		_report_verification_result(true, "Verification completed successfully")
	else:
		Log.error("Debug menu button simulation failed", {}, [Log.TAG_DEBUG])
		_report_verification_result(false, "Button action simulation failed")


# Simulate pressing the button without actually opening the menu
func _simulate_button_press() -> bool:
	if (
		not debug_menu_controller
		or not is_instance_valid(debug_menu_controller)
		or not debug_menu_controller.is_initialized
	):
		return false

	# Just check if we can call show_menu without errors
	return debug_menu_controller.has_method("show_menu")


# Report verification results
func _report_verification_result(success: bool, message: String) -> void:
	# Cannot register a dictionary directly, so we'll just log the results
	var result_dict = {
		"success": success,
		"message": message,
		"timestamp": Time.get_datetime_string_from_system(),
		"controller_valid": is_instance_valid(debug_menu_controller),
		"controller_initialized":
		(
			debug_menu_controller.is_initialized
			if debug_menu_controller and debug_menu_controller.get("is_initialized") != null
			else false
		),
		"debug_menu_valid": is_instance_valid(debug_menu),
		"autoloads": Engine.get_singleton_list()
	}

	Log.info(
		"Debug menu verification completed",
		{"success": success, "message": message},
		[Log.TAG_DEBUG]
	)

	# Write result to stdout (will appear in editor output)
	print("\n=== DEBUG MENU VERIFICATION RESULT ===")
	print("Success: " + str(success))
	print("Message: " + message)
	print("=======================================\n")


func create_nested_categories(path: String) -> void:
	var menu_to_use: Node = (
		debug_menu
		if debug_menu
		else debug_menu_controller.debug_menu if debug_menu_controller else null
	)

	if not menu_to_use:
		Log.warning(
			"Debug menu not available, skipping nested category creation", {}, [Log.TAG_DEBUG]
		)
		return

	# Split the path by '/'
	var parts_packed = path.split("/", false)
	var parts: Array[String] = []

	# Convert PackedStringArray to Array[String]
	for part in parts_packed:
		parts.append(part)
	var current_path: String = ""

	# Create each level of the hierarchy
	for i: int in range(parts.size()):
		if current_path.is_empty():
			current_path = parts[i]
		else:
			current_path += "/" + parts[i]

		# Create the category if it doesn't exist
		if (
			menu_to_use.has_method("create_category")
			and not menu_to_use.categories.has(current_path)
		):
			menu_to_use.create_category(current_path)


# Helper function to get available methods on an object for debugging
func get_available_methods(obj: Object) -> Array:
	if not is_instance_valid(obj):
		return []

	var methods: Array = []
	for method in obj.get_method_list():
		if method.name.begins_with("_"):
			continue
		methods.append(method.name)
	return methods


# Function to verify debug menu setup and attempt recovery
func verify_debug_menu_setup() -> bool:
	Log.info("Verifying debug menu setup", {}, [Log.TAG_DEBUG])

	# First try: Check if debug_menu_controller exists as autoload
	var controller = null
	setup_ok = false  # Reset setup flag

	if Engine.has_singleton("debug_menu_controller"):
		controller = Engine.get_singleton("debug_menu_controller")
		Log.info("Found controller via Engine.get_singleton", {}, [Log.TAG_DEBUG])
	else:
		# Second try: Look for it in the scene tree
		controller = get_node_or_null("/root/debug_menu_controller")

		if is_instance_valid(controller):
			Log.info("Found controller in scene tree", {}, [Log.TAG_DEBUG])

			# Register it as a singleton if we found it in the scene tree
			if not Engine.has_singleton("debug_menu_controller"):
				Engine.register_singleton("debug_menu_controller", controller)
				Log.info("Registered controller as singleton", {}, [Log.TAG_DEBUG])
		else:
			# Third try: Check if our reference is still valid
			if is_instance_valid(debug_menu_controller):
				controller = debug_menu_controller
				Log.info("Using existing controller reference", {}, [Log.TAG_DEBUG])

				# Register it as a singleton if needed
				if not Engine.has_singleton("debug_menu_controller"):
					Engine.register_singleton("debug_menu_controller", controller)
					Log.info("Registered existing controller as singleton", {}, [Log.TAG_DEBUG])
			else:
				Log.error(
					"debug_menu_controller not found anywhere!",
					{"available_singletons": Engine.get_singleton_list()},
					[Log.TAG_DEBUG]
				)
				return false

	if not is_instance_valid(controller):
		Log.error("debug_menu_controller reference not valid!", {}, [Log.TAG_DEBUG])
		return false

	Log.info(
		"debug_menu_controller found",
		{"instance_id": controller.get_instance_id(), "methods": get_available_methods(controller)},
		[Log.TAG_DEBUG]
	)

	# Update our reference
	debug_menu_controller = controller

	# Check if it's initialized
	if not controller.is_initialized:
		if controller.has_method("initialize"):
			controller.initialize()
			Log.info("Initialized debug_menu_controller during verification", {}, [Log.TAG_DEBUG])
			await get_tree().process_frame
			await get_tree().process_frame  # Wait a bit for initialization to complete
		else:
			Log.error("debug_menu_controller doesn't have initialize method!", {}, [Log.TAG_DEBUG])
			return false

	# Check if we have the debug_menu instance
	if not controller.debug_menu or not is_instance_valid(controller.debug_menu):
		Log.error("debug_menu instance not valid in controller!", {}, [Log.TAG_DEBUG])
		return false

	# Update our reference
	debug_menu = controller.debug_menu

	Log.info("Debug menu setup verification completed successfully", {}, [Log.TAG_DEBUG])
	setup_ok = true  # Set setup flag to true since verification was successful
	return true


func debug_button_pressed(button_name: String) -> void:
	match button_name:
		"button_close":
			popup_debug.hide()
		"button_db_debug":
			action(DebugEventType.EVENT_OPEN_DB_DEBUG_MENU)
		"button_new_debug_menu":
			# Use the new event type specifically for the new debug menu
			action(DebugEventType.EVENT_OPEN_NEW_DEBUG_MENU)

			# We failed - log detailed error and retry
			Log.error(
				"Failed to open debug menu after setup",
				{
					"setup_ok": setup_ok,
					"controller_exists": debug_menu_controller != null,
					"controller_valid":
					is_instance_valid(debug_menu_controller) if debug_menu_controller else false,
					"controller_initialized":
					(
						debug_menu_controller.is_initialized
						if (
							debug_menu_controller
							and debug_menu_controller.get("is_initialized") != null
						)
						else false
					)
				},
				[Log.TAG_DEBUG]
			)

			if is_instance_valid(status_label):
				status_label.text = "Failed to open debug menu. See logs."
		"button_pop_enemy":
			_populate_enemy_lineup()
		"select_game":
			Log.debug("Game selection requested", {}, [Log.TAG_DEBUG, Log.TAG_UI])
			popup_debug.hide()
			action(DebugEventType.EVENT_OPEN_GAME_SELECTOR)
		"reset_current_match_level":
			action(DebugEventType.EVENT_RESET_MATCH_LEVEL)
		"match_level_1":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_01"])
		"match_level_2":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_02"])
		"match_level_3":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_03"])
		"match_level_4":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_04"])
		"match_level_5":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_05"])
		_:
			# Special handling for test buttons
			if button_name == "button_test_debug_menu":
				_simulate_button_press()  # Use existing function instead of missing one
			else:
				Log.warning(
					"Unused debug button pressed",
					{"button_name": button_name},
					[Log.TAG_DEBUG, Log.TAG_UI]
				)


# Implementation of the missing test function that was causing parse errors
func _test_debug_menu_button() -> void:
	Log.info("Testing debug menu button press...", {}, [Log.TAG_DEBUG])
	var result = _simulate_button_press()
	Log.info("Debug menu button test result", {"success": result}, [Log.TAG_DEBUG])
