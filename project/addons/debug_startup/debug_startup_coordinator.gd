extends Node

# Enable verbose debug logging for troubleshooting
const VERBOSE_LOGGING := false

func _init() -> void:
	pass  # Logging not available in _init - Log autoload not ready yet


func _ready() -> void:
	Log.debug("DebugStartupCoordinator ready", {}, ["debug", "startup", "lifecycle"])


func _log_verbose(message: String, metadata: Dictionary = {}, tags: Array[String] = []) -> void:
	"""Helper method for verbose logging that can be toggled on/off"""
	if VERBOSE_LOGGING:
		Log.debug(message, metadata, tags + ["verbose"])

func startDebugCoordinator() -> void:
	Log.info("DebugStartupCoordinator initializing...", {}, ["debug", "startup"])

	# Fail fast on missing dependency - that's it
	if not has_node("/root/DebugRegistry"):
		Log.error("DebugRegistry missing", {"path": "/root/DebugRegistry"}, ["debug", "startup", "fatal"])
		return

	_log_verbose("DebugRegistry found, getting actions...", {}, ["debug", "startup"])

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
	_log_verbose("Waiting for game ready...", {}, ["debug", "startup"])
	await _wait_for_game_ready()

	# Wait for action registry to be fully initialized using proper signal-based approach
	_log_verbose("Waiting for action registry initialization...", {}, ["debug", "startup"])
	var registry := get_node("/root/DebugRegistry") as DebugActionRegistry
	await _wait_for_registry_ready(registry)

	# Wait for DataSource initialization to avoid RTDB/Database action failures
	_log_verbose("Waiting for DataSource initialization...", {}, ["debug", "startup"])
	await _wait_for_data_source_ready()

	Log.info("Executing debug startup actions", {"count": actions.size()}, ["debug", "startup"])

	# Execute actions with proper error handling
	var successful_actions := 0
	var failed_actions := 0

	for action_name in actions:
		_log_verbose("Searching for action", {"action": action_name}, ["debug", "startup"])
		var action := _get_action_by_name(registry, action_name)
		if action:
			Log.info("Executing action", {
				"action": action_name,
				"class_path": action.get_script().get_path()
			}, ["debug", "startup"])

			# Execute with error handling
			var execution_success := await _execute_action_safely(action, action_name)
			if execution_success:
				successful_actions += 1
				_log_verbose("Action completed", {"action": action_name}, ["debug", "startup"])
			else:
				failed_actions += 1
		else:
			Log.error("Action not found", {"action": action_name, "available_actions": _get_available_action_names(registry)}, ["debug", "startup", "error"])
			failed_actions += 1

	Log.info("Debug startup complete", {
		"total_actions": actions.size(),
		"successful": successful_actions,
		"failed": failed_actions
	}, ["debug", "startup"])

	# Clear test context if it was set - this emits DEBUG_TEST_COMPLETE signal
	if DebugAction.is_test_active():
		DebugAction.clear_test_context()

	# _cleanup_mobile_config()  # Disabled: Keep external config persistent for reuse


func _get_action_names() -> Array[String]:
	Log.debug("Getting action names", {"platform": "mobile" if OS.has_feature("mobile") else "desktop"}, ["debug", "startup"])
	# Inline platform differences - no abstraction needed for 2 conditions
	if OS.has_feature("mobile"):
		# Check user:// first (external config), then fallback to res:// (embedded config)
		var external_config_path := "user://debug_startup_actions.json"
		if FileAccess.file_exists(external_config_path):
			Log.info("Using external config", {"path": external_config_path}, ["debug", "startup"])
			var external_actions := _parse_config_file(external_config_path)
			return external_actions

		Log.info("Using embedded config", {"reason": "no_external_config"}, ["debug", "startup"])
		var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
		return embedded_actions
	else:
		# Desktop: try command line first, fallback to config
		var cmd_actions := _parse_command_line()
		return (
			cmd_actions
			if not cmd_actions.is_empty()
			else _parse_config_file("res://debug_startup_actions.json")
		)


func _execute_action_safely(action: DebugAction, action_name: String) -> bool:
	"""Execute an action with proper error handling and return success status"""
	# GDScript doesn't have try/catch, but we can check for signals or return values
	if not action:
		Log.error("Action is null", {"action": action_name}, ["debug", "startup", "error"])
		return false

	if not action.has_method("execute"):
		Log.error("Action missing execute method", {"action": action_name}, ["debug", "startup", "error"])
		return false

	# Execute the action - let it handle its own errors
	await action.execute()

	# Assume success if no exception was thrown
	return true


func _get_available_action_names(registry: DebugActionRegistry) -> Array[String]:
	"""Get list of available action names for error reporting"""
	var names: Array[String] = []
	var all_actions := registry.get_all_actions()
	for action in all_actions:
		names.append(action.action_name)
	return names


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
	Log.debug("Parsing config file", {"path": path}, ["debug", "startup"])

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		Log.warning("Config file not found", {
			"path": path,
			"resolved_path": ProjectSettings.globalize_path(path)
		}, ["debug", "startup"])
		return []

	# Trust Godot's RAII - file auto-closes when out of scope
	var json_text := file.get_as_text()
	var json := JSON.new()
	var result := json.parse(json_text)

	if result != OK:
		Log.error(
			"Invalid JSON config",
			{"path": path, "error": json.get_error_message()},
			["debug", "startup", "error"]
		)
		return []

	var data := json.data as Dictionary

	# Check for test metadata and set test context if present
	if data.has("test_metadata"):
		var test_metadata := data.test_metadata as Dictionary
		if test_metadata.has("test_id"):
			var test_id := str(test_metadata.test_id)
			DebugAction.set_test_context(test_id)
			Log.info("Test context set", {"test_id": test_id}, ["debug", "startup", "test"])

	if data.has("actions"):
		var raw_actions := data.actions as Array
		var actions: Array[String] = []
		for action in raw_actions:
			actions.append(str(action))
		Log.debug("Parsed actions from config", {"actions": actions, "count": actions.size()}, ["debug", "startup"])
		return actions

	Log.debug("No actions found in config", {"path": path}, ["debug", "startup"])
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

	var data_source_node: Node = get_node("/root/data_source")
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
		Log.info("Cleaning up external config file", {"path": external_config_path}, ["debug", "startup"])
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			var result: Error = dir.remove("debug_startup_actions.json")
			if result == OK:
				Log.debug("External config file cleaned up successfully", {}, ["debug", "startup"])
			else:
				Log.error("Failed to clean up external config file", {"error_code": result}, ["debug", "startup", "error"])
		else:
			Log.error("Could not access user:// directory for cleanup", {}, ["debug", "startup", "error"])
	else:
		Log.debug("No external config file to clean up", {}, ["debug", "startup"])
