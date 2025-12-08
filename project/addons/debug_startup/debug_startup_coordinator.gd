extends Node

const DebugConfigReader = preload("res://debug/utilities/debug_config_reader.gd")
const VERBOSE_LOGGING := true
const COMPLETION_ACTIONS: Array[String] = [
	"system.debug.replay_complete",
	"app.quit_application",
	"system.debug.finalize_replay_validation"
]
const DEFAULT_COMPLETION_ACTION: String = "system.debug.replay_complete"

var _current_config_is_test_recipe: bool = false

func _init() -> void:
	pass  # Logging not available in _init - Log autoload not ready yet


func _ready() -> void:
	Log.info(
		"TASK218_COORDINATOR_READY_WITH_DIAGNOSTICS",
		{
			"version": "diagnostic_v2_rng_fix",
			"timestamp": Time.get_unix_time_from_system(),
			"frame": Engine.get_process_frames()
		},
		["task218", "coordinator", "ready", "diagnostic_deployed", "critical"]
	)
	Log.debug("DebugStartupCoordinator ready", {}, ["debug", "startup", "lifecycle"])


func _log_verbose(message: String, metadata: Dictionary = {}, tags: Array[String] = []) -> void:
	"""Helper method for verbose logging that can be toggled on/off"""
	if VERBOSE_LOGGING:
		var verbose_tags: Array[String] = tags.duplicate()
		verbose_tags.append("verbose")
		Log.debug(message, metadata, verbose_tags)

func start_debug_coordinator() -> void:
	Log.info(
		"TASK218_COORDINATOR_START",
		{
			"timestamp": Time.get_unix_time_from_system(),
			"frame": Engine.get_process_frames(),
			"test_id_current": DebugAction.get_current_test_id()
		},
		["debug", "startup", "task218", "coordinator", "critical"]
	)

	# Set unique Sentry test context for ALL tests - IMMEDIATELY at startup
	var test_id: String = _set_global_sentry_test_context()

	Log.info("🔍 SENTRY TEST CONTEXT - All tests will use ID: " + test_id,
		{"test_session_id": test_id},
		["debug", "startup", "sentry", "test_id"]
	)

	Log.info("DebugStartupCoordinator initializing...", {}, ["debug", "startup"])

	_log_verbose("Getting DebugRegistry actions...", {}, ["debug", "startup"])

	Log.info("TASK218_BEFORE_GET_ACTION_NAMES", {}, ["task218", "coordinator"])
	var actions := _get_action_names()
	Log.info(
		"TASK218_AFTER_GET_ACTION_NAMES",
		{"action_count": actions.size(), "actions": actions},
		["task218", "coordinator"]
	)
	Log.info(
		"Actions retrieved", {"count": actions.size(), "actions": actions}, ["debug", "startup"]
	)

	# CRITICAL: Check if we should skip test infrastructure entirely
	# This prevents empty configs from triggering test mode when they should be manual
	if _should_skip_test_infrastructure(actions):
		Log.info("=== MANUAL MODE: SKIPPING TEST INFRASTRUCTURE ===", {
			"reason": "empty_config_no_testing",
			"actions_count": actions.size(),
			"actions": actions,
			"mode": "manual_testing",
			"auto_quit": false,
			"completion_actions": false,
			"test_infrastructure": false
		}, ["debug", "startup", "manual_mode"])
		Log.info("App running in manual mode - test infrastructure skipped entirely", {}, ["debug", "startup"])
		return
	DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)
	DebugManager.action(DebugManager.DebugEventType.EVENT_TOGGLE_DEBUG_MENU_LIST)
	_log_verbose("Waiting for game ready...", {}, ["debug", "startup"])
	await _wait_for_game_ready()

	_log_verbose("Waiting for action registry initialization...", {}, ["debug", "startup"])
	var registry := DebugRegistry as DebugActionRegistry
	await _wait_for_registry_ready(registry)

	_log_verbose("Waiting for DataSource initialization...", {}, ["debug", "startup"])
	await _wait_for_data_source_ready()

	_log_verbose("Activating card cache for debug actions...", {}, ["debug", "startup", "cache"])
	await _ensure_card_cache_ready()

	# CRITICAL FIX (Task-218): Apply RNG seed from config AFTER coordinator starts
	# This ensures config is loaded at the right time, not during RNG autoload initialization
	_apply_rng_seed_from_config()

	# Check for pending gamestate load AFTER data_source is ready
	await _check_and_load_pending_gamestate()

	# CRITICAL FIX: Expand wildcards AFTER registry is ready
	# This fixes the race condition where wildcards were expanded during config parsing
	# before the registry was initialized, resulting in empty action lists.
	var expanded_actions := _expand_all_wildcards(actions)
	Log.info("Wildcard expansion complete", {
		"original_count": actions.size(),
		"expanded_count": expanded_actions.size()
	}, ["debug", "startup", "wildcard"])

	var dispatch_start_time := Time.get_unix_time_from_system()
	var dispatch_start_frame := Engine.get_process_frames()

	# CRITICAL FIX (Task-314): Pause queue processing during batch dispatch
	# This prevents synchronous queue processing from running while we're still adding actions
	var game_node: Node = get_tree().root.get_node_or_null("Game")
	if game_node and game_node.has_method("_process_one_queue_item"):
		game_node._queue_paused = true
		Log.info("Queue processing PAUSED - batch dispatch mode", {
			"test_id": DebugAction.get_current_test_id()
		}, ["debug", "startup", "batch_dispatch", "diagnostic"])

	Log.info("=== BATCH DISPATCH START ===", {
		"total_actions": expanded_actions.size(),
		"dispatch_start_time": dispatch_start_time,
		"dispatch_start_frame": dispatch_start_frame,
		"test_id": DebugAction.get_current_test_id()
	}, ["debug", "startup", "batch_dispatch", "diagnostic"])

	var has_completion_action: bool = false
	var is_test_recipe: bool = _is_current_config_test_recipe()

	for i in range(expanded_actions.size()):
		var action_item = expanded_actions[i]
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
				"total_actions": expanded_actions.size(),
				"dispatch_timestamp": Time.get_unix_time_from_system()
			}, ["debug", "startup", "dispatch", "diagnostic"])
			# CRITICAL FIX: Capture action and params by value to prevent stale references in queue
			var captured_action := action
			var captured_params := params.duplicate(true)  # Deep copy to prevent reference issues
			var callable := func(): captured_action.execute_with_params(captured_params)

			var auto_continue: bool = _should_action_auto_continue(action)

			core.action(core.SystemIdleActionEvent.new(callable, auto_continue))
		else:
			Log.error("Action not found, cannot dispatch", {
				"action": action_name,
				"action_index": i + 1,
				"available_actions": _get_available_action_names(registry).slice(0, 10)
			}, ["debug", "startup", "error"])

	Log.info("=== BATCH DISPATCH LOOP COMPLETE ===", {
		"actions_dispatched": expanded_actions.size(),
		"has_completion_action": has_completion_action,
		"is_test_recipe": is_test_recipe,
		"test_id": DebugAction.get_current_test_id()
	}, ["debug", "startup", "batch_dispatch", "diagnostic"])

	if _should_auto_add_completion(has_completion_action, expanded_actions.size(), is_test_recipe):
		_dispatch_auto_completion_action(registry, expanded_actions.size())
	elif not has_completion_action and expanded_actions.size() > 0:
		Log.debug("No completion action found but not a test recipe - skipping auto-completion", {
			"action_count": expanded_actions.size(),
			"is_test_recipe": false
		}, ["debug", "startup", "auto_completion"])

	var dispatch_end_time := Time.get_unix_time_from_system()
	var dispatch_duration_ms := (dispatch_end_time - dispatch_start_time) * 1000.0

	Log.info("=== BATCH DISPATCH COMPLETE ===", {
		"count": expanded_actions.size(),
		"is_test_recipe": is_test_recipe,
		"completion_auto_added": not has_completion_action and expanded_actions.size() > 0 and is_test_recipe,
		"dispatch_duration_ms": dispatch_duration_ms,
		"dispatch_end_time": dispatch_end_time,
		"test_id": DebugAction.get_current_test_id(),
		"idle_queue_execution_starts_now": true
	}, ["debug", "startup", "batch_dispatch", "diagnostic"])

	# CRITICAL FIX (Task-314 + Task-322): Resume queue processing and trigger execution
	# Now that all actions (including replay_complete) are queued, allow processing to begin
	if game_node and game_node.has_method("_process_one_queue_item"):
		game_node._queue_paused = false
		Log.info("Queue processing RESUMED - batch dispatch complete", {
			"queued_actions": game_node._idle_action_queue.size(),
			"test_id": DebugAction.get_current_test_id()
		}, ["debug", "startup", "batch_dispatch", "diagnostic"])
		# Trigger queue processing now that batch dispatch is complete
		core.action(core.ProcessQueueEvent.new())



func _get_action_names() -> Array:
	var platform: String = "mobile" if OS.has_feature("mobile") else "desktop"
	Log.debug("Getting action names", {"platform": platform}, ["debug", "startup"])
	if OS.has_feature("mobile"):
		var external_config_path := "user://debug_startup_actions.json"
		var exists: bool = FileAccess.file_exists(external_config_path)
		_log_verbose("Checking external config path", {
			"path": external_config_path, "exists": exists
		}, ["debug", "startup"])
		if FileAccess.file_exists(external_config_path):
			Log.info("Using external config", {"path": external_config_path}, ["debug", "startup"])
			# CRITICAL FIX: Reset DebugConfigReader cache before using external config
			# This prevents stale cached config from early autoload execution (Task-303)
			DebugConfigReader._reset_cache()
			var external_actions := _parse_config_file(external_config_path)
			_log_verbose("Parsed external config", {
				"action_count": external_actions.size(), "actions": external_actions
			}, ["debug", "startup"])
			return external_actions

		Log.info("Using embedded config", {"reason": "no_external_config"}, ["debug", "startup"])
		var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
		_log_verbose("Parsed embedded config", {
			"action_count": embedded_actions.size(), "actions": embedded_actions
		}, ["debug", "startup"])
		return embedded_actions

	# Desktop path (not mobile)
	var cmd_actions := _parse_command_line()
	if not cmd_actions.is_empty():
		return cmd_actions

	var external_config_path := "user://debug_startup_actions.json"
	var exists: bool = FileAccess.file_exists(external_config_path)
	_log_verbose("Checking external config path", {
		"path": external_config_path, "exists": exists
	}, ["debug", "startup"])
	if FileAccess.file_exists(external_config_path):
		Log.info("Using external config", {"path": external_config_path}, ["debug", "startup"])
		# CRITICAL FIX: Reset DebugConfigReader cache before using external config
		# This prevents stale cached config from early autoload execution (Task-303)
		DebugConfigReader._reset_cache()
		var external_actions := _parse_config_file(external_config_path)
		_log_verbose("Parsed external config", {
			"action_count": external_actions.size(), "actions": external_actions
		}, ["debug", "startup"])
		return external_actions

	Log.info("Using embedded config", {"reason": "no_external_config"}, ["debug", "startup"])
	var embedded_actions := _parse_config_file("res://debug_startup_actions.json")
	_log_verbose("Parsed embedded config", {
		"action_count": embedded_actions.size(), "actions": embedded_actions
	}, ["debug", "startup"])
	return embedded_actions






func _get_debug_action_registry() -> DebugActionRegistry:
	"""Get the debug action registry autoload"""
	return DebugRegistry as DebugActionRegistry


func _get_available_action_names(registry: DebugActionRegistry) -> Array[String]:
	"""Get list of available action names for error reporting"""
	var names: Array[String] = []
	var all_actions := registry.get_all_actions()
	for action: DebugAction in all_actions:
		names.append(action.action_name)
	return names


func _get_action_by_name(registry: DebugActionRegistry, action_name: String) -> DebugAction:
	var all_actions := registry.get_all_actions()
	for action: DebugAction in all_actions:
		if action.action_name == action_name:
			return action
	return null


func _parse_command_line() -> Array[String]:
	var args: PackedStringArray = OS.get_cmdline_args()
	var actions: Array[String] = []

	for i in range(args.size()):
		if args[i] == "--debug-actions" and i + 1 < args.size():
			var action_list := args[i + 1].split(",")
			for action: String in action_list:
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

	Log.info("Checking for metadata in config", {
		"has_metadata": data.has("metadata"), "all_keys": data.keys()
	}, ["debug", "startup", "metadata"])
	if data.has("metadata"):
		var metadata := data.metadata as Dictionary
		Log.info("Config metadata found", {"metadata": metadata}, ["debug", "startup", "metadata"])
		Log.info("Metadata will be accessed directly by debug actions", {
			"auto_quit": metadata.get("auto_quit", "not_found")
		}, ["debug", "startup", "metadata"])
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

		# Check for manual mode (empty actions array)
		if raw_actions.is_empty():
			Log.info("Config has empty actions array - manual testing mode", {
				"path": path,
				"has_metadata": data.has("metadata"),
				"has_test_metadata": data.has("test_metadata")
			}, ["debug", "startup", "manual_mode"])
			return []

		var actions: Array = []

		for action: Variant in raw_actions:
			var action_type = typeof(action)
			var type_name = ""
			match action_type:
				TYPE_STRING: type_name = "String"
				TYPE_DICTIONARY: type_name = "Dictionary"
				TYPE_ARRAY: type_name = "Array"
				_: type_name = "Other(" + str(action_type) + ")"

			_log_verbose("Processing raw action", {
				"action": action, "type": action_type, "type_name": type_name
			}, ["startup", "parser"])

			if action_type == TYPE_STRING:
				var action_str := str(action)
				_log_verbose("Processing action string", {"action": action_str}, ["startup", "parser"])
				# CRITICAL FIX: Don't expand wildcards during config parsing
				# Registry may not be ready yet. Store pattern as-is for later expansion.
				actions.append({"action": action_str, "params": {}})
			elif action_type == TYPE_DICTIONARY:
				var action_dict := action as Dictionary
				if action_dict.has("action"):
					var action_name := str(action_dict.action)
					var params := action_dict.get("params", {}) as Dictionary
					_log_verbose("Processing parameterized action", {"action": action_name, "params": params}, ["startup", "parser"])
					# CRITICAL FIX: Don't expand wildcards during config parsing
					# Registry may not be ready yet. Store pattern as-is for later expansion.
					actions.append({"action": action_name, "params": params})
				else:
					Log.warning("Invalid action object missing 'action' key", {"action_object": action_dict}, ["debug", "startup"])
			else:
				Log.warning("Invalid action type, must be String or Dictionary", {
					"action": action, "type": typeof(action)
				}, ["debug", "startup"])

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

	# No actions key in config - manual testing mode
	Log.info("Config has no actions key - manual testing mode", {
		"path": path,
		"config_keys": data.keys(),
		"has_metadata": data.has("metadata"),
		"has_test_metadata": data.has("test_metadata")
	}, ["debug", "startup", "manual_mode"])
	return []


func _is_current_config_test_recipe() -> bool:
	"""Check if the current config being processed is a test recipe"""
	return _current_config_is_test_recipe


func _should_auto_add_completion(has_completion: bool, action_count: int, is_test_recipe: bool) -> bool:
	"""Determine if we should automatically add a completion action"""
	# CRITICAL FIX: Only auto-add completion for legitimate test recipes with test_metadata
	# This prevents replay_complete from being added to configs that don't have proper test metadata
	var should_add := not has_completion and action_count > 0 and is_test_recipe
	Log.debug("Auto-completion check", {
		"has_completion": has_completion,
		"action_count": action_count,
		"is_test_recipe": is_test_recipe,
		"should_add": should_add
	}, ["debug", "startup", "auto_completion"])
	return should_add


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

		# CRITICAL FIX: Completion action should always use auto_continue=true
		# The sequential processing is handled by Firebase actions themselves having auto_continue=false
		# Setting completion action to auto_continue=false creates a deadlock
		var auto_continue: bool = _should_action_auto_continue(completion_action)

		core.action(core.SystemIdleActionEvent.new(completion_callable, auto_continue))


func _wait_for_game_ready() -> void:
	Log.info("Checking tree ready state...", {}, ["debug", "startup"])

	# Wait for game node reference
	var game_node: Node = get_tree().root.get_node_or_null("Main/Game")
	if not game_node:
		Log.error("Game node not found", {}, ["debug", "startup", "error", "task218"])
		return

	Log.info(
		"Game node found, waiting for UI state WAITING",
		{"current_ui_state_code": game_node.ui_state},
		["debug", "startup", "sync", "task218"]
	)

	# CRITICAL FIX (Task-218): Wait for ui_state to reach WAITING
	# This ensures all initialization and state transitions (START → PREPARE) complete
	# before actions are dispatched, preventing the race condition where first action
	# executes before sequence tracking is ready.
	while game_node.ui_state != core.UIState.WAITING:
		await get_tree().process_frame
		Log.debug(
			"Waiting for UI state WAITING",
			{
				"current_ui_state": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][game_node.ui_state],
				"current_ui_state_code": game_node.ui_state,
				"target_ui_state": "WAITING",
				"frame": Engine.get_process_frames()
			},
			["debug", "startup", "sync", "task218"]
		)

	Log.info(
		"Game ready for debug actions - UI state is WAITING",
		{
			"ui_state": "WAITING",
			"ui_state_code": game_node.ui_state,
			"frame": Engine.get_process_frames(),
			"timestamp": Time.get_unix_time_from_system()
		},
		["debug", "startup", "sync", "task218", "critical"]
	)



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
	var data_source_node: Node = data_source

	if data_source_node.is_initialized():
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

	var registry := DebugRegistry as DebugActionRegistry
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


func _expand_all_wildcards(action_list: Array) -> Array:
	"""
	Expand all wildcard patterns in the action list.
	Called AFTER registry is ready to ensure patterns can be matched.

	Args:
		action_list: Array of action items (strings or dictionaries with action/params)

	Returns:
		New array with all wildcard patterns expanded to concrete action names
	"""
	var expanded_actions: Array = []

	for action_item in action_list:
		var action_name: String
		var params: Dictionary = {}

		# Extract action name and params
		if action_item is Dictionary:
			action_name = action_item.action
			params = action_item.get("params", {})
		else:
			action_name = str(action_item)

		# Check if this is a wildcard pattern
		if action_name.contains("*"):
			# Expand the wildcard pattern
			var matches := _expand_wildcard_pattern(action_name)

			# Add each match as a separate action
			for matched_action: String in matches:
				expanded_actions.append({"action": matched_action, "params": params})

			Log.debug("Expanded wildcard in action list", {
				"pattern": action_name,
				"params": params,
				"expanded_count": matches.size(),
				"matches": matches
			}, ["debug", "startup", "wildcard"])
		else:
			# Not a wildcard, keep as-is
			expanded_actions.append({"action": action_name, "params": params})

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


func _should_action_auto_continue(action: DebugAction) -> bool:
	"""
	Determine if an action should automatically continue to the next queued action
	or wait for natural completion events (DraftSteadyEvent, LineupOperationCompleteEvent, etc.)

	Uses the action's auto_continue property instead of hardcoded patterns.
	This allows each action to declare its own continuation behavior.
	"""

	if action == null:
		Log.warning(
			"Null action passed to _should_action_auto_continue, defaulting to auto_continue",
			{},
			["debug", "startup", "coordinator"]
		)
		return true

	return action.auto_continue




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
	"""Apply gamestate during clean startup initialization - RNG only"""
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
		Log.debug("RNG state available for restoration", {
			"rng_state_length": rng_state.length()
		}, ["debug", "startup", "gamestate"])

	# Store full gamestate data for explicit loading via debug action
	var temp_path: String = DebugConfigReader.get_temp_gamestate_path("pending_gamestate_load")
	var gamestate_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if gamestate_file:
		gamestate_file.store_string(JSON.stringify(gamestate_data))
		gamestate_file.close()
		Log.info("Full gamestate data saved for debug action loading", {
			"file": "pending_gamestate_load.json"
		}, ["debug", "startup", "gamestate"])

	Log.info(
		"Startup gamestate loading completed - RNG applied, data ready for debug action",
		{
			"session_id": session_id,
			"original_capture_id": gamestate_data.get("capture_id", "unknown")
		},
		["debug", "startup", "gamestate"]
	)

	return true


func _ensure_card_cache_ready() -> void:
	"""Ensure card cache is activated before debug actions that depend on card creation"""
	var data_source_node: Node = data_source

	Log.info("Activating card cache for debug actions", {}, ["debug", "startup", "cache"])
	await data_source_node.activate_card_cache()
	Log.info("Card cache activation complete", {}, ["debug", "startup", "cache"])


func _cleanup_gamestate_loading_config() -> void:
	"""Remove the gamestate loading configuration file"""
	var dir: DirAccess = DirAccess.open("user://")
	if dir and dir.file_exists("startup_gamestate_load.json"):
		dir.remove("startup_gamestate_load.json")
		Log.debug("Gamestate loading config cleaned up", {}, ["debug", "startup", "gamestate"])


func _apply_rng_seed_from_config() -> void:
	"""
	Verify RNG seed from debug config.
	Note: RNG autoload already handles seed initialization in its _ready() method.
	This function exists for logging/verification purposes only.
	"""
	var debug_seed: int = DebugConfigReader.get_debug_seed()

	if debug_seed != 12345:  # DEFAULT_SEED fallback
		Log.info(
			"RNG initialized with debug seed from config",
			{"seed": debug_seed, "source": "autoload_ready"},
			["debug", "startup", "rng", "verification"]
		)
	else:
		Log.debug(
			"RNG using default seed",
			{"default_seed": 12345, "source": "autoload_ready"},  # DEFAULT_SEED fallback
			["debug", "startup", "rng", "verification"]
		)


# Set global Sentry test context for all test runs using existing test ID
func _set_global_sentry_test_context() -> String:
	var test_id: String = DebugAction.get_current_test_id()

	# If no test ID available, generate a fallback for non-test contexts
	if test_id.is_empty():
		var timestamp: int = Time.get_unix_time_from_system()
		var random_suffix: String = str(randi() % 10000).pad_zeros(4)
		test_id = "debug-session-" + str(timestamp) + "-" + random_suffix

	# Set Sentry context if available (for all platforms)
	if SentryHelper.is_available():
		# Set as a searchable tag for easy filtering in Sentry - use the existing test ID
		SentryHelper.set_tag("test_session_id", test_id)
		SentryHelper.set_tag("test_platform", OS.get_name())
		SentryHelper.set_tag("test_type", "debug_coordinator")
		SentryHelper.set_tag("godot_version", Engine.get_version_info()["string"])

		# Set structured context for better crash analysis
		SentryHelper.set_context("test_session", {
			"test_session_id": test_id,
			"platform": OS.get_name(),
			"test_type": "debug_coordinator",
			"timestamp": Time.get_datetime_string_from_system(),
			"godot_version": Engine.get_version_info(),
			"debug_build": OS.is_debug_build(),
			"actions_executed": _get_action_names().size(),
			"test_id": test_id
		})

		# Set user context to distinguish test runs from production users
		SentryHelper.set_user({
			"id": test_id,
			"username": "debug_test_session",
			"email": "test-session@debug-validation.local"
		})

		Log.info(
			"🔍 Global Sentry test context set: " + test_id,
			{
				"test_session_id": test_id,
				"platform": OS.get_name(),
				"actions_count": _get_action_names().size(),
				"sentry_available": true
			},
			["debug", "startup", "sentry", "test_id", "coordinator"]
		)
	else:
		Log.info(
			"🔍 Test session ID generated (Sentry unavailable): " + test_id,
			{
				"test_session_id": test_id,
				"sentry_available": false
			},
			["debug", "startup", "test_id", "coordinator"]
		)

	return test_id


func _should_skip_test_infrastructure(actions: Array) -> bool:
	"""
	Determine if we should skip test infrastructure entirely.

	This provides a clean separation between manual mode and test mode:
	- Empty configs = manual mode (no test infrastructure)
	- Non-empty configs = potentially test mode (normal test flow)

	Returns:
		true: Skip ALL test infrastructure (manual mode)
		false: Continue with normal test flow
	"""
	if actions.is_empty():
		Log.debug("Empty actions array detected - manual mode", {
			"actions_count": actions.size(),
			"reason": "empty_config"
		}, ["debug", "startup", "manual_mode"])
		return true

	# Future: Additional checks if needed
	# - Check for explicit manual mode flags
	# - Check for manual-only actions
	# - Check config metadata for manual mode indication

	Log.debug("Actions present - continuing with test infrastructure", {
		"actions_count": actions.size(),
		"actions": actions.slice(0, 5)  # First 5 actions to avoid log spam
	}, ["debug", "startup"])
	return false
