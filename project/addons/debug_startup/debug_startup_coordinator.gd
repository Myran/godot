extends Node


func _init() -> void:
	print("DebugStartupCoordinator _init() called")


func _ready() -> void:
	print("DebugStartupCoordinator _ready() called")

func startDebugCoordinator()->void:
	Log.info("DebugStartupCoordinator initializing...", {}, ["debug", "startup"])

	# Fail fast on missing dependency - that's it
	if not has_node("/root/DebugRegistry"):
		Log.error("DebugRegistry missing", {}, ["debug", "startup", "fatal"])
		print("ERROR: DebugRegistry not found at /root/DebugRegistry")
		return

	Log.info("DebugRegistry found, getting actions...", {}, ["debug", "startup"])

	# Get actions from command line or config (inline platform logic)
	var actions := _get_action_names()
	Log.info(
		"Actions retrieved", {"count": actions.size(), "actions": actions}, ["debug", "startup"]
	)

	if actions.is_empty():
		Log.info("No debug startup actions to execute", {}, ["debug", "startup"])
		return
	DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)
	DebugManager.action(DebugManager.DebugEventType.EVENT_TOGGLE_DEBUG_MENU_LIST)
	# Wait for game ready then execute
	Log.info("Waiting for game ready...", {}, ["debug", "startup"])
	await _wait_for_game_ready()

	# Wait for action registry to be fully initialized using proper signal-based approach
	Log.info("Waiting for action registry initialization...", {}, ["debug", "startup"])
	var registry := get_node("/root/DebugRegistry") as DebugActionRegistry
	await _wait_for_registry_ready(registry)

	# Wait for DataSource initialization to avoid RTDB/Database action failures
	Log.info("Waiting for DataSource initialization...", {}, ["debug", "startup"])
	await _wait_for_data_source_ready()

	Log.info("Executing debug startup actions", {"count": actions.size()}, ["debug", "startup"])

	# Simple execution loop - trust the registry to handle its own errors
	for action_name in actions:
		Log.info("Searching for action", {"action": action_name}, ["debug", "startup"])
		var action := _get_action_by_name(registry, action_name)
		if action:
			Log.info("Executing action", {"action": action_name}, ["debug", "startup"])
			# DEBUG: Log the exact class being executed
			print("🔥 EXECUTING ACTION CLASS: ", action.get_script().get_path(), " name=", action_name)
			# FIX: Await the execute method directly instead of the signal to avoid race condition
			await action.execute()
			Log.info("Action completed", {"action": action_name}, ["debug", "startup"])
		else:
			Log.error("Action not found", {"action": action_name}, ["debug", "startup", "error"])

	Log.info("Debug startup complete", {}, ["debug", "startup"])

	# Clear test context if it was set - this emits DEBUG_TEST_COMPLETE signal
	if DebugAction.is_test_active():
		DebugAction.clear_test_context()

	# _cleanup_mobile_config()  # Disabled: Keep external config persistent for reuse


func _get_action_names() -> Array[String]:
	print("Getting action names, mobile feature: ", OS.has_feature("mobile"))
	# Inline platform differences - no abstraction needed for 2 conditions
	if OS.has_feature("mobile"):
		# Check user:// first (external config), then fallback to res:// (embedded config)
		print("Checking for external config in user:// directory...")

		# FIXED: Check if external config file EXISTS, not if actions array is empty
		var external_config_path := "user://debug_startup_actions.json"
		if FileAccess.file_exists(external_config_path):
			print("External config file found, parsing...")
			var external_actions := _parse_config_file(external_config_path)
			print("External config found in user:// with actions: ", external_actions)
			print("Using external config (even if empty - respecting user choice)")
			return external_actions

		print("No external config file found, using embedded config...")
		var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
		print("Embedded config parsed, actions: ", embedded_actions)
		return embedded_actions
	else:
		# Desktop: try command line first, fallback to config
		var cmd_actions := _parse_command_line()
		return (
			cmd_actions
			if not cmd_actions.is_empty()
			else _parse_config_file("res://debug_startup_actions.json")
		)


func _get_action_by_name(registry: DebugActionRegistry, action_name: String) -> DebugAction:
	# Search through all actions since registry doesn't provide get_action(name)
	var all_actions := registry.get_all_actions()
	for action in all_actions:
		if action.action_name == action_name:
			return action
	return null


func _parse_command_line() -> Array[String]:
	var args: PackedStringArray = OS.get_cmdline_args()
	var actions: Array[String] = []

	for i in range(args.size()):
		if args[i] == "--debug-actions" and i + 1 < args.size():
			# Split comma-separated actions
			var action_list := args[i + 1].split(",")
			for action in action_list:
				actions.append(action.strip_edges())
		elif args[i] == "--debug-action" and i + 1 < args.size():
			# Single action
			actions.append(args[i + 1].strip_edges())

	return actions


func _parse_config_file(path: String) -> Array[String]:
	print("Parsing config file: ", path)

	# Debug: Show the actual resolved path BEFORE trying to open
	var resolved_path = ProjectSettings.globalize_path(path)
	print("Resolved path: ", resolved_path)

	# Debug: Show user:// directory path and contents BEFORE trying to open
	var user_dir_path = ProjectSettings.globalize_path("user://")
	print("User directory resolves to: ", user_dir_path)

	# Debug: Check if directory exists and list contents
	var dir = DirAccess.open("user://")
	if dir:
		print("User directory exists. Contents:")
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var file_count = 0
		while file_name != "":
			print("  - ", file_name)
			file_name = dir.get_next()
			file_count += 1
		dir.list_dir_end()
		if file_count == 0:
			print("  (directory is empty)")
	else:
		print("Could not open user:// directory")

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Config file not found: ", path)
		print("Resolved path not found: ", resolved_path)

		# Check if we can create a test file to verify write access
		print("Testing write access to user:// directory...")
		var test_file = FileAccess.open("user://test_write.txt", FileAccess.WRITE)
		if test_file:
			test_file.store_string("test")
			test_file.close()
			print("Write test successful - directory is writable")
			# Clean up test file
			var test_dir = DirAccess.open("user://")
			if test_dir:
				test_dir.remove("test_write.txt")
		else:
			print("Write test failed - directory not writable")

		return []

	print("Config file found, reading content...")
	# Trust Godot's RAII - file auto-closes when out of scope
	var json_text := file.get_as_text()
	print("JSON content: ", json_text)
	var json := JSON.new()
	var result := json.parse(json_text)

	if result != OK:
		Log.error(
			"Invalid JSON config",
			{"path": path, "error": json.get_error_message()},
			["debug", "startup", "error"]
		)
		print("JSON parse error: ", json.get_error_message())
		return []

	var data := json.data as Dictionary

	# Check for test metadata and set test context if present
	if data.has("test_metadata"):
		var test_metadata := data.test_metadata as Dictionary
		if test_metadata.has("test_id"):
			var test_id := str(test_metadata.test_id)
			print("Test metadata found, setting test context: ", test_id)
			DebugAction.set_test_context(test_id)
			Log.info("Test context set", {"test_id": test_id}, ["debug", "startup", "test"])

	if data.has("actions"):
		var raw_actions := data.actions as Array
		var actions: Array[String] = []
		for action in raw_actions:
			actions.append(str(action))
		print("Parsed actions: ", actions)
		return actions

	print("No actions found in config")
	return []


func _wait_for_game_ready() -> void:
	Log.info("Waiting for tree ready...", {}, ["debug", "startup"])
	await get_tree().get_root().ready

	# Wait a few frames to ensure autoloads are initialized
	for i in range(3):
		await get_tree().process_frame

	Log.info("Game ready for debug actions", {}, ["debug", "startup"])


func _wait_for_registry_ready(registry: DebugActionRegistry) -> void:
	# Proper event-driven approach: wait for the registry's initialization signal
	if not registry:
		Log.error("Registry not available", {}, ["debug", "startup", "error"])
		return

	# Check if already initialized
	if registry.get_all_actions().size() > 0:
		Log.info("Action registry already ready", {"action_count": registry.get_all_actions().size()}, ["debug", "startup"])
		return

	# Wait for the registry_initialized signal
	Log.info("Waiting for registry initialization signal...", {}, ["debug", "startup"])
	var action_count: int = await registry.registry_initialized
	Log.info("Action registry ready", {"action_count": action_count}, ["debug", "startup"])


func _wait_for_data_source_ready() -> void:
	# Wait for DataSource initialization to prevent RTDB/Database action failures
	if not has_node("/root/data_source"):
		Log.warning("DataSource autoload not found, skipping DataSource wait", {}, ["debug", "startup"])
		return

	var data_source_node = get_node("/root/data_source")
	if not data_source_node:
		Log.warning("DataSource node not available, skipping DataSource wait", {}, ["debug", "startup"])
		return

	# Check if already initialized
	if data_source_node.has_method("is_initialized") and data_source_node.is_initialized():
		Log.info("DataSource already initialized", {}, ["debug", "startup"])
		return

	# Wait for startup_completed signal
	if data_source_node.has_signal("startup_completed"):
		Log.info("Waiting for DataSource startup_completed signal...", {}, ["debug", "startup"])
		await data_source_node.startup_completed
		Log.info("DataSource initialization complete", {}, ["debug", "startup"])
	else:
		Log.warning("DataSource doesn't have startup_completed signal, continuing without wait", {}, ["debug", "startup"])


func _cleanup_mobile_config() -> void:
	if not OS.has_feature("mobile"):
		return

	# Clean up external config file if it exists
	var external_config_path := "user://debug_startup_actions.json"
	if FileAccess.file_exists(external_config_path):
		print("Cleaning up external config file: ", external_config_path)
		var dir := DirAccess.open("user://")
		if dir:
			var result := dir.remove("debug_startup_actions.json")
			if result == OK:
				print("External config file cleaned up successfully")
			else:
				print("Failed to clean up external config file: ", result)
		else:
			print("Could not access user:// directory for cleanup")
	else:
		print("No external config file to clean up")
