extends Node

# Enable verbose debug logging for troubleshooting
const VERBOSE_LOGGING := true

func _init() -> void:
	pass  # Logging not available in _init - Log autoload not ready yet


func _ready() -> void:
	Log.debug("DebugStartupCoordinator ready", {}, ["debug", "startup", "lifecycle"])


func _log_verbose(message: String, metadata: Dictionary = {}, tags: Array[String] = []) -> void:
	"""Helper method for verbose logging that can be toggled on/off"""
	if VERBOSE_LOGGING:
		var verbose_tags: Array[String] = tags.duplicate()
		verbose_tags.append("verbose")
		Log.debug(message, metadata, verbose_tags)

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

	# All actions are now queued in the game's idle action system.
	# The coordinator's job is to simply dispatch them.
	for action_name in actions:
		var action := _get_action_by_name(registry, action_name)
		if action:
			Log.info("Dispatching action to idle queue", {"action": action_name}, ["debug", "startup"])
			var callable := Callable(action, "execute")
			core.action(core.SystemIdleActionEvent.new(callable))
		else:
			Log.error("Action not found, cannot dispatch", {"action": action_name}, ["debug", "startup", "error"])

	Log.info("All debug startup actions have been dispatched to the idle queue.", {"count": actions.size()}, ["debug", "startup"])

	# The coordinator's primary job is now complete.
	# The idle action queue in game.gd will handle execution when the system is ready.


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


func _queue_action_for_idle_execution(action: DebugAction, action_name: String) -> bool:
	"""Queue an action for idle execution using SystemIdleActionEvent and wait for completion"""
	if not action:
		Log.error("Action is null", {"action": action_name}, ["debug", "startup", "error"])
		return false

	if not action.has_method("execute"):
		Log.error("Action missing execute method", {"action": action_name}, ["debug", "startup", "error"])
		return false

	# Create a signal to wait for action completion
	var action_completed := false
	var action_success := false

	Log.info("Creating idle action callable", {"action": action_name}, ["debug", "startup", "idle", "callable"])

	# Create a callable that wraps the action execution
	var action_callable := func():
		Log.info("=== IDLE ACTION EXECUTION START ===", {"action": action_name}, ["debug", "startup", "idle", "execution"])
		# Execute the action and handle any potential errors
		await action.execute()
		action_success = true
		action_completed = true
		Log.info("=== IDLE ACTION EXECUTION COMPLETE ===", {"action": action_name, "success": action_success}, ["debug", "startup", "idle", "execution"])

	# Queue the action using SystemIdleActionEvent
	Log.info("Creating SystemIdleActionEvent", {"action": action_name}, ["debug", "startup", "idle", "event"])
	var idle_event := core.SystemIdleActionEvent.new(action_callable)

	Log.info("Dispatching SystemIdleActionEvent", {"action": action_name}, ["debug", "startup", "idle", "dispatch"])
	core.action(idle_event)

	Log.info("SystemIdleActionEvent dispatched, waiting for completion", {"action": action_name}, ["debug", "startup", "idle", "wait"])

	# Wait for action completion with detailed logging
	var wait_cycles := 0
	while not action_completed:
		wait_cycles += 1
		if wait_cycles % 60 == 0:  # Log every 60 frames (roughly 1 second)
			Log.debug("Still waiting for action completion", {
				"action": action_name,
				"wait_cycles": wait_cycles,
				"action_completed": action_completed,
				"action_success": action_success
			}, ["debug", "startup", "idle", "wait"])
		await get_tree().process_frame

	Log.info("Action wait loop completed", {
		"action": action_name,
		"success": action_success,
		"wait_cycles": wait_cycles
	}, ["debug", "startup", "idle", "completion"])
	return action_success




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

		# Expand wildcard patterns in actions
		for action in raw_actions:
			var action_str := str(action)
			_log_verbose("Processing action string", {"action": action_str}, ["startup", "parser"])
			if action_str.contains("*"):
				# This is a wildcard pattern - expand it
				var expanded_actions := _expand_wildcard_pattern(action_str)
				actions.append_array(expanded_actions)
				Log.debug("Expanded wildcard pattern", {
					"pattern": action_str,
					"expanded_count": expanded_actions.size(),
					"expanded_actions": expanded_actions
				}, ["debug", "startup", "wildcard"])
			else:
				# Regular action name
				actions.append(action_str)

		Log.debug("Parsed actions from config", {"actions": actions, "count": actions.size()}, ["debug", "startup"])
		return actions

	Log.debug("No actions found in config", {"path": path}, ["debug", "startup"])
	return []


func _wait_for_game_ready() -> void:
	Log.info("Checking tree ready state...", {}, ["debug", "startup"])

	# Since DebugStartupCoordinator now starts AFTER game initialization_complete signal,
	# the game is guaranteed to be ready. No need to wait for frames.
	Log.debug("Tree root is ready", {}, ["debug", "startup"])
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


func _expand_wildcard_pattern(pattern: String) -> Array[String]:
	"""
	Expand a wildcard pattern to matching action names using the registry.
	Returns empty array if registry is not available or pattern matches nothing.
	"""
	var expanded_actions: Array[String] = []

	# Get registry - it should be available since we wait for it in startDebugCoordinator
	var registry := get_node("/root/DebugRegistry") as DebugActionRegistry
	if not registry:
		Log.warning("Registry not available for wildcard expansion", {"pattern": pattern}, ["debug", "startup", "wildcard"])
		return expanded_actions

	# Use the registry's wildcard matching
	expanded_actions = registry.find_actions_matching(pattern)

	Log.debug("Wildcard pattern expanded", {
		"pattern": pattern,
		"match_count": expanded_actions.size(),
		"matches": expanded_actions
	}, ["debug", "startup", "wildcard"])

	return expanded_actions


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
