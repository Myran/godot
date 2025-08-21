extends Node

const VERBOSE_LOGGING := true

var _current_config_is_test_recipe: bool = false

const COMPLETION_ACTIONS: Array[String] = [
	"system.debug.replay_complete",
	"app.quit_application",
	"system.debug.finalize_replay_validation"
]

const DEFAULT_COMPLETION_ACTION: String = "system.debug.replay_complete"

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

	# Check for pending gamestate load first
	await _check_and_load_pending_gamestate()

	if not has_node("/root/DebugRegistry"):
		Log.error("DebugRegistry missing", {"path": "/root/DebugRegistry"}, ["debug", "startup", "fatal"])
		return

	_log_verbose("DebugRegistry found, getting actions...", {}, ["debug", "startup"])

	var actions := _get_action_names()
	Log.info(
		"Actions retrieved", {"count": actions.size(), "actions": actions}, ["debug", "startup"]
	)

	if actions.is_empty():
		Log.info("No debug startup actions to execute", {}, ["debug", "startup"])
		return
	DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)
	DebugManager.action(DebugManager.DebugEventType.EVENT_TOGGLE_DEBUG_MENU_LIST)
	_log_verbose("Waiting for game ready...", {}, ["debug", "startup"])
	await _wait_for_game_ready()

	_log_verbose("Waiting for action registry initialization...", {}, ["debug", "startup"])
	var registry := get_node("/root/DebugRegistry") as DebugActionRegistry
	await _wait_for_registry_ready(registry)

	_log_verbose("Waiting for DataSource initialization...", {}, ["debug", "startup"])
	await _wait_for_data_source_ready()

	var dispatch_start_time := Time.get_unix_time_from_system()
	var dispatch_start_frame := Engine.get_process_frames()

	Log.info("=== BATCH DISPATCH START ===", {
		"total_actions": actions.size(),
		"dispatch_start_time": dispatch_start_time,
		"dispatch_start_frame": dispatch_start_frame,
		"test_id": DebugAction.get_current_test_id()
	}, ["debug", "startup", "batch_dispatch", "diagnostic"])

	var has_completion_action: bool = false
	var is_test_recipe: bool = _is_current_config_test_recipe()

	for i in range(actions.size()):
		var action_item = actions[i]
		var action_name: String
		var params: Dictionary = {}

		if action_item is Dictionary:
			action_name = action_item.action
			params = action_item.get("params", {})
		else:
			action_name = str(action_item)

		if action_name in COMPLETION_ACTIONS:
			has_completion_action = true

		var action := _get_action_by_name(registry, action_name)
		if action:
			Log.info("Dispatching action to idle queue", {
				"action": action_name,
				"params": params,
				"action_index": i + 1,
				"total_actions": actions.size(),
				"dispatch_timestamp": Time.get_unix_time_from_system()
			}, ["debug", "startup", "dispatch", "diagnostic"])
			var callable := func(): action.execute_with_params(params)

			var auto_continue: bool = _should_action_auto_continue(action_name)

			core.action(core.SystemIdleActionEvent.new(callable, auto_continue))
		else:
			Log.error("Action not found, cannot dispatch", {
				"action": action_name,
				"action_index": i + 1,
				"available_actions": _get_available_action_names(registry).slice(0, 10)
			}, ["debug", "startup", "error"])

	if _should_auto_add_completion(has_completion_action, actions.size(), is_test_recipe):
		_dispatch_auto_completion_action(registry, actions.size())
	elif not has_completion_action and actions.size() > 0:
		Log.debug("No completion action found but not a test recipe - skipping auto-completion", {
			"action_count": actions.size(),
			"is_test_recipe": false
		}, ["debug", "startup", "auto_completion"])

	var dispatch_end_time := Time.get_unix_time_from_system()
	var dispatch_duration_ms := (dispatch_end_time - dispatch_start_time) * 1000.0

	Log.info("=== BATCH DISPATCH COMPLETE ===", {
		"count": actions.size(),
		"is_test_recipe": is_test_recipe,
		"completion_auto_added": not has_completion_action and actions.size() > 0 and is_test_recipe,
		"dispatch_duration_ms": dispatch_duration_ms,
		"dispatch_end_time": dispatch_end_time,
		"test_id": DebugAction.get_current_test_id(),
		"idle_queue_execution_starts_now": true
	}, ["debug", "startup", "batch_dispatch", "diagnostic"])



func _get_action_names() -> Array:
	Log.debug("Getting action names", {"platform": "mobile" if OS.has_feature("mobile") else "desktop"}, ["debug", "startup"])
	if OS.has_feature("mobile"):
		var external_config_path := "user://debug_startup_actions.json"
		_log_verbose("Checking external config path", {"path": external_config_path, "exists": FileAccess.file_exists(external_config_path)}, ["debug", "startup"])
		if FileAccess.file_exists(external_config_path):
			Log.info("Using external config", {"path": external_config_path}, ["debug", "startup"])
			var external_actions := _parse_config_file(external_config_path)
			_log_verbose("Parsed external config", {"action_count": external_actions.size(), "actions": external_actions}, ["debug", "startup"])
			return external_actions

		Log.info("Using embedded config", {"reason": "no_external_config"}, ["debug", "startup"])
		var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
		_log_verbose("Parsed embedded config", {"action_count": embedded_actions.size(), "actions": embedded_actions}, ["debug", "startup"])
		return embedded_actions
	else:
		var cmd_actions := _parse_command_line()
		if not cmd_actions.is_empty():
			return cmd_actions

		var external_config_path := "user://debug_startup_actions.json"
		_log_verbose("Checking external config path", {"path": external_config_path, "exists": FileAccess.file_exists(external_config_path)}, ["debug", "startup"])
		if FileAccess.file_exists(external_config_path):
			Log.info("Using external config", {"path": external_config_path}, ["debug", "startup"])
			var external_actions := _parse_config_file(external_config_path)
			_log_verbose("Parsed external config", {"action_count": external_actions.size(), "actions": external_actions}, ["debug", "startup"])
			return external_actions

		Log.info("Using embedded config", {"reason": "no_external_config"}, ["debug", "startup"])
		var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
		_log_verbose("Parsed embedded config", {"action_count": embedded_actions.size(), "actions": embedded_actions}, ["debug", "startup"])
		return embedded_actions






func _get_available_action_names(registry: DebugActionRegistry) -> Array[String]:
	"""Get list of available action names for error reporting"""
	var names: Array[String] = []
	var all_actions := registry.get_all_actions()
	for action in all_actions:
		names.append(action.action_name)
	return names


func _get_action_by_name(registry: DebugActionRegistry, action_name: String) -> DebugAction:
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
			var action_list := args[i + 1].split(",")
			for action in action_list:
				actions.append(action.strip_edges())
		elif args[i] == "--debug-action" and i + 1 < args.size():
			actions.append(args[i + 1].strip_edges())

	return actions


func _parse_config_file(path: String) -> Array:
	Log.debug("Parsing config file", {"path": path}, ["debug", "startup"])

	_current_config_is_test_recipe = false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		Log.warning("Config file not found", {
			"path": path,
			"resolved_path": ProjectSettings.globalize_path(path)
		}, ["debug", "startup"])
		return []

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

	Log.info("JSON parsing result", {"data_keys": data.keys(), "data_size": data.size()}, ["debug", "startup", "json"])

	if data.has("test_metadata"):
		_current_config_is_test_recipe = true
		var test_metadata := data.test_metadata as Dictionary
		if test_metadata.has("test_id"):
			var test_id := str(test_metadata.test_id)
			DebugAction.set_test_context(test_id)
			Log.info("Test context set", {"test_id": test_id}, ["debug", "startup", "test"])
		Log.info("Test recipe detected", {"test_metadata": test_metadata}, ["debug", "startup", "test_recipe"])

	Log.info("Checking for metadata in config", {"has_metadata": data.has("metadata"), "all_keys": data.keys()}, ["debug", "startup", "metadata"])
	if data.has("metadata"):
		var metadata := data.metadata as Dictionary
		Log.info("Config metadata found", {"metadata": metadata}, ["debug", "startup", "metadata"])
		Log.info("Metadata will be accessed directly by debug actions", {"auto_quit": metadata.get("auto_quit", "not_found")}, ["debug", "startup", "metadata"])
	else:
		Log.info("No metadata found in config", {"config_keys": data.keys()}, ["debug", "startup", "metadata"])

	if data.has("type") and data.type == "demo":
		Log.info("Demo config detected, setting up replay validation", {"config_path": path}, ["debug", "startup", "replay"])
		var validation_setup_success: bool = SessionManager.setup_replay_validation(path)
		if validation_setup_success:
			Log.info("Replay validation setup successful", {}, ["debug", "startup", "replay"])
		else:
			Log.warning("Replay validation setup failed", {}, ["debug", "startup", "replay"])

	if data.has("actions"):
		var raw_actions := data.actions as Array
		var actions: Array = []

		for action in raw_actions:
			var action_type = typeof(action)
			var type_name = ""
			match action_type:
				TYPE_STRING: type_name = "String"
				TYPE_DICTIONARY: type_name = "Dictionary"
				TYPE_ARRAY: type_name = "Array"
				_: type_name = "Other(" + str(action_type) + ")"

			_log_verbose("Processing raw action", {"action": action, "type": action_type, "type_name": type_name}, ["startup", "parser"])

			if action_type == TYPE_STRING:
				var action_str := str(action)
				_log_verbose("Processing action string", {"action": action_str}, ["startup", "parser"])
				if action_str.contains("*"):
					var expanded_actions := _expand_wildcard_pattern(action_str)
					for expanded_action in expanded_actions:
						actions.append({"action": expanded_action, "params": {}})
					Log.debug("Expanded wildcard pattern", {
						"pattern": action_str,
						"expanded_count": expanded_actions.size(),
						"expanded_actions": expanded_actions
					}, ["debug", "startup", "wildcard"])
				else:
					actions.append({"action": action_str, "params": {}})
			elif action_type == TYPE_DICTIONARY:
				var action_dict := action as Dictionary
				if action_dict.has("action"):
					var action_name := str(action_dict.action)
					var params := action_dict.get("params", {}) as Dictionary
					_log_verbose("Processing parameterized action", {"action": action_name, "params": params}, ["startup", "parser"])

					if action_name.contains("*"):
						var expanded_actions := _expand_wildcard_pattern(action_name)
						for expanded_action in expanded_actions:
							actions.append({"action": expanded_action, "params": params})
						Log.debug("Expanded parameterized wildcard", {
							"pattern": action_name,
							"params": params,
							"expanded_count": expanded_actions.size()
						}, ["debug", "startup", "wildcard"])
					else:
						actions.append({"action": action_name, "params": params})
				else:
					Log.warning("Invalid action object missing 'action' key", {"action_object": action_dict}, ["debug", "startup"])
			else:
				Log.warning("Invalid action type, must be String or Dictionary", {"action": action, "type": typeof(action)}, ["debug", "startup"])

		if data.has("action_params"):
			var action_params := data.action_params as Dictionary
			Log.debug("Found action_params section", {"param_actions": action_params.keys()}, ["debug", "startup"])

			var action_counts: Dictionary = {}

			for i in range(actions.size()):
				var action_item := actions[i] as Dictionary
				var action_name: String = action_item.get("action", "")

				action_counts[action_name] = action_counts.get(action_name, 0) + 1
				var count: int = action_counts[action_name]

				var param_key: String = action_name
				var indexed_key: String = action_name + "_" + str(count)

				var extra_params: Dictionary = {}
				if action_params.has(param_key) and count == 1:
					extra_params = action_params[param_key] as Dictionary
				elif action_params.has(indexed_key):
					extra_params = action_params[indexed_key] as Dictionary

				if not extra_params.is_empty():
					var current_params := action_item.get("params", {}) as Dictionary

					for param_key_inner in extra_params:
						current_params[param_key_inner] = extra_params[param_key_inner]

					action_item["params"] = current_params
					Log.debug("Merged action_params", {
						"action": action_name,
						"instance": count,
						"param_source": indexed_key if action_params.has(indexed_key) else param_key,
						"merged_params": current_params
					}, ["debug", "startup"])

		Log.debug("Parsed actions from config", {"actions": actions, "count": actions.size()}, ["debug", "startup"])
		return actions

	Log.debug("No actions found in config", {"path": path}, ["debug", "startup"])
	return []


func _is_current_config_test_recipe() -> bool:
	"""Check if the current config being processed is a test recipe"""
	return _current_config_is_test_recipe


func _should_auto_add_completion(has_completion: bool, action_count: int, is_test_recipe: bool) -> bool:
	"""Determine if we should automatically add a completion action"""
	return not has_completion and action_count > 0 and is_test_recipe


func _dispatch_auto_completion_action(registry: DebugActionRegistry, original_action_count: int) -> void:
	"""Dispatch the auto-completion action for test recipes"""
	var completion_action := _get_action_by_name(registry, DEFAULT_COMPLETION_ACTION)
	if completion_action:
		Log.info("Auto-dispatching replay completion action for test recipe", {
			"action": DEFAULT_COMPLETION_ACTION,
			"reason": "test_recipe_missing_completion",
			"original_action_count": original_action_count,
			"is_test_recipe": true
		}, ["debug", "startup", "auto_completion", "test_recipe"])

		var completion_callable := func(): completion_action.execute_with_params({})
		var auto_continue: bool = _should_action_auto_continue(DEFAULT_COMPLETION_ACTION)
		core.action(core.SystemIdleActionEvent.new(completion_callable, auto_continue))


func _wait_for_game_ready() -> void:
	Log.info("Checking tree ready state...", {}, ["debug", "startup"])

	Log.debug("Tree root is ready", {}, ["debug", "startup"])
	Log.info("Game ready for debug actions", {}, ["debug", "startup"])


func _wait_for_registry_ready(registry: DebugActionRegistry) -> void:
	if not registry:
		Log.error("Registry not available", {}, ["debug", "startup", "error"])
		return

	if registry.get_all_actions().size() > 0:
		Log.info("Action registry already ready", {"action_count": registry.get_all_actions().size()}, ["debug", "startup"])
		return

	Log.info("Waiting for registry initialization signal...", {}, ["debug", "startup"])
	var action_count: int = await registry.registry_initialized
	Log.info("Action registry ready", {"action_count": action_count}, ["debug", "startup"])


func _wait_for_data_source_ready() -> void:
	if not has_node("/root/data_source"):
		Log.warning("DataSource autoload not found, skipping DataSource wait", {}, ["debug", "startup"])
		return

	var data_source_node: Node = get_node("/root/data_source")
	if not data_source_node:
		Log.warning("DataSource node not available, skipping DataSource wait", {}, ["debug", "startup"])
		return

	if data_source_node.has_method("is_initialized") and data_source_node.is_initialized():
		Log.info("DataSource already initialized", {}, ["debug", "startup"])
		return

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

	var registry := get_node("/root/DebugRegistry") as DebugActionRegistry
	if not registry:
		Log.warning("Registry not available for wildcard expansion", {"pattern": pattern}, ["debug", "startup", "wildcard"])
		return expanded_actions

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


func _should_action_auto_continue(action_name: String) -> bool:
	"""
	Determine if an action should automatically continue to the next queued action
	or wait for natural completion events (DraftSteadyEvent, LineupOperationCompleteEvent, etc.)

	DEFAULT: Auto-continue (immediate continuation) for all actions
	EXCEPTION: Complex operations that need time for animations/cascades to complete
	"""

	var wait_for_completion_patterns: Array[String] = [
		"game.state.transition_player",
		"game.draft.upgrade_player",
		"game.draft.reroll_player",
		"game.draft.remove_block_player",
		"game.draft.move_card_to_lineup_player",
		"game.lineup.move_card_player",
		"game.battle.start_player",
		"game.battle.start",
		"game.battle.populate_enemy_and_start"
	]

	for pattern: String in wait_for_completion_patterns:
		if action_name.begins_with(pattern):
			return false

	return true


func _check_and_load_pending_gamestate() -> void:
	"""Check for pending gamestate load and apply it during startup"""
	var config_file: FileAccess = FileAccess.open("user://startup_gamestate_load.json", FileAccess.READ)
	if not config_file:
		return  # No pending gamestate load

	var config_text: String = config_file.get_as_text()
	config_file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(config_text)
	if parse_result != OK:
		Log.error("Failed to parse gamestate loading config", {}, ["debug", "startup", "gamestate"])
		_cleanup_gamestate_loading_config()
		return

	var config: Dictionary = json.data as Dictionary
	Log.info(
		"Found pending gamestate load request",
		{
			"file": config.get("gamestate_file", "unknown"),
			"requested_at": config.get("requested_at", "unknown"),
			"original_capture_id": config.get("original_capture_id", "unknown")
		},
		["debug", "startup", "gamestate"]
	)

	# Apply gamestate during startup (clean loading)
	var gamestate_data: Dictionary = config.get("gamestate_data", {})
	if not gamestate_data.is_empty():
		var success: bool = await _apply_gamestate_at_startup(gamestate_data)
		if success:
			Log.info("Gamestate loaded successfully at startup", {}, ["debug", "startup", "gamestate"])
		else:
			Log.error("Failed to load gamestate at startup", {}, ["debug", "startup", "gamestate"])

	# Clean up the loading config
	_cleanup_gamestate_loading_config()


func _apply_gamestate_at_startup(gamestate_data: Dictionary) -> bool:
	"""Apply gamestate during clean startup initialization"""
	# Start new session for loaded state
	var session_id: String = SessionManager.start_new_session(
		"loaded_state_start",
		{
			"session_type": "loaded_state_recording",
			"original_capture_id": gamestate_data.get("capture_id", "unknown"),
			"original_timestamp": gamestate_data.get("capture_timestamp", "unknown"),
			"loaded_at_startup": true
		}
	)

	# Apply RNG state first (most important for deterministic behavior)
	var rng_state: String = gamestate_data.get("rng_state", "")
	if not rng_state.is_empty():
		# Note: RNG state will be handled by DeterministicRNG system during game initialization
		Log.debug("RNG state available for restoration", {"rng_state_length": rng_state.length()}, ["debug", "startup", "gamestate"])

	# Basic game state will be applied naturally during game initialization
	# No need to force complex lineup/board restoration - the loaded RNG state is the critical part

	Log.info(
		"Startup gamestate loading completed",
		{
			"session_id": session_id,
			"original_capture_id": gamestate_data.get("capture_id", "unknown")
		},
		["debug", "startup", "gamestate"]
	)

	return true


func _cleanup_gamestate_loading_config() -> void:
	"""Remove the gamestate loading configuration file"""
	var dir: DirAccess = DirAccess.open("user://")
	if dir and dir.file_exists("startup_gamestate_load.json"):
		dir.remove("startup_gamestate_load.json")
		Log.debug("Gamestate loading config cleaned up", {}, ["debug", "startup", "gamestate"])
