class_name GameActionCore
extends RefCounted


static func _reset_match_level() -> bool:
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)
		return true
	Log.error("DebugManager not available", {}, ["debug", "error"])
	return false


static func _load_match_level(level_num: int) -> bool:
	if DebugManager:
		DebugManager.action(
			DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_%02d" % level_num]
		)
		return true
	Log.error("DebugManager not available", {}, ["debug", "error"])
	return false


static func _populate_enemy_lineup() -> bool:
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error(
			"Cannot populate enemy lineup: core or card_controller missing", {}, ["debug", "error"]
		)
		return false

	if not _wait_for_game_systems_ready():
		return false

	core.action(core.LineupOperationStartEvent.new())

	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(typed_card, n))

	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(typed_card, n))

	var dwarf_card: Variant = await card_controller.create_unit_from_id(str(4), 1)
	if dwarf_card and is_instance_valid(dwarf_card):
		var typed_dwarf: Card = dwarf_card
		typed_dwarf.block_context = Cards.CONTEXT.LINEUP

		Log.info(
			"Dwarf initial stats",
			{
				"health": typed_dwarf.unit_info.current_health,
				"attack": typed_dwarf.unit_info.current_attack
			},
			["debug", "gameplay", "ability", "stats"]
		)

		var merge_ability: MergeBonusAbility = null
		for ability: Ability in typed_dwarf.unit_info.get_active_abilities():
			if ability is MergeBonusAbility:
				merge_ability = ability
				break

		if merge_ability:
			merge_ability.debug_trigger_effect(typed_dwarf)
			Log.info(
				"Dwarf enhanced via debug trigger",
				{
					"health": typed_dwarf.unit_info.current_health,
					"attack": typed_dwarf.unit_info.current_attack
				},
				["debug", "gameplay", "ability", "stats"]
			)
		else:
			Log.warning("MergeBonusAbility not found on dwarf", {}, ["debug", "gameplay"])
		core.action(core.DebugLineupAddCardEvent.new(typed_dwarf, 4))

	core.action(core.LineupOperationCompleteEvent.new())
	return true


static func _clear_card_cache() -> bool:
	if data_source and data_source.has_method("clear_card_cache"):
		data_source.clear_card_cache()
		return true
	Log.warning(
		"data_source not available or doesn't support clear_card_cache", {}, ["debug", "database"]
	)
	return false


static func _toggle_local_battle_db() -> bool:
	if DebugManager:
		DebugManager.use_local_battle_db = not DebugManager.use_local_battle_db
		return true
	Log.error("DebugManager not available", {}, ["debug", "error"])
	return false


static func _cycle_asset_variant() -> bool:
	if DebugManager:
		DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
		return true
	Log.error("DebugManager not available", {}, ["debug", "error"])
	return false


static func _print_debug_info() -> bool:
	if DebugManager:
		Log.info("Local DB: %s" % DebugManager.use_local_battle_db, {}, ["debug", "quick"])
		Log.info("Asset Variant: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
		Log.info("==================", {}, ["debug", "quick"])
		return true
	Log.warning("DebugManager not available", {}, ["debug", "quick"])
	Log.info("==================", {}, ["debug", "quick"])
	return false


static func _test_simple_player_events() -> bool:
	Log.info("Simple test function executed successfully", {}, ["debug", "test"])
	return true


static func _populate_enemy_lineup_as_player() -> bool:
	Log.info(
		"Populating enemy lineup with fake PLAYER events for testing",
		{},
		["debug", "test", "event_categorization"]
	)

	if not is_instance_valid(card_controller):
		Log.error("card_controller not available", {}, ["debug", "error"])
		return false

	if not is_instance_valid(core):
		Log.error("core not available", {}, ["debug", "error"])
		return false

	if not _wait_for_game_systems_ready():
		return false

	core.action(core.LineupOperationStartEvent.new())

	Log.info("Creating cards for enemy lineup (like working function)", {}, ["debug", "test"])

	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(typed_card, n))
			Log.info(
				"Added card to enemy lineup", {"card_id": str(n), "position": n}, ["debug", "test"]
			)

	var dwarf_card: Variant = await card_controller.create_unit_from_id(str(4), 1)
	if not dwarf_card:
		Log.error("Failed to create dwarf card", {}, ["debug", "error"])
		return false

	var typed_dwarf: Card = dwarf_card
	typed_dwarf.block_context = Cards.CONTEXT.LINEUP  # COPY FROM WORKING FUNCTION

	core.action(core.DebugLineupAddCardEvent.new(typed_dwarf, 4))
	Log.info(
		"Added dwarf to debug lineup for event testing",
		{"card_id": typed_dwarf.id},
		["debug", "test"]
	)

	var fake_player_event1: core.LineupAddCardEvent = core.LineupAddCardEvent.new(typed_dwarf)
	core.action(fake_player_event1)
	Log.info(
		"Generated fake PLAYER event: LineupAddCardEvent",
		{"source": fake_player_event1.source},
		["debug", "test", "event_categorization"]
	)

	var fake_player_event2: core.RerollDraftEvent = core.RerollDraftEvent.new()
	core.action(fake_player_event2)
	Log.info(
		"Generated fake PLAYER event: RerollDraftEvent",
		{"source": fake_player_event2.source},
		["debug", "test", "event_categorization"]
	)

	var fake_player_event3: core.UpgradeEvent = core.UpgradeEvent.new(2)
	core.action(fake_player_event3)
	Log.info(
		"Generated fake PLAYER event: UpgradeEvent",
		{"source": fake_player_event3.source, "level": 2},
		["debug", "test", "event_categorization"]
	)

	var debug_event: core.DebugLineupAddCardEvent = core.DebugLineupAddCardEvent.new(typed_dwarf, 0)
	core.action(debug_event)
	Log.info(
		"Generated real DEBUG_SETUP event for comparison",
		{"source": debug_event.source},
		["debug", "test", "event_categorization"]
	)

	Log.info(
		"FAKE_PLAYER_EVENTS_GENERATED",
		{"player_events": 3, "debug_events": 1, "enemy_cards": 3, "debug_cards": 1},
		["test", "event_categorization", "success"]
	)

	core.action(core.LineupOperationCompleteEvent.new())
	return true


static func _hide_debug_menu() -> bool:
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU)
		Log.info("Debug menu hidden", {}, ["debug", "ui"])
		return true
	Log.warning("DebugManager not available", {}, ["debug", "ui"])
	return false


static func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		var game_node: Game = root.find_child("Game", true, false) as Game
		return game_node
	return null


static func _wait_for_game_systems_ready() -> bool:
	Log.info("Waiting for game systems to be ready...", {}, ["debug", "battle", "initialization"])

	var game_node: Node = null
	var root: Node = Engine.get_main_loop().current_scene

	if root and root.has_method("find_child"):
		game_node = root.find_child("Game", true, false)

	if not game_node:
		Log.warning("Game node not found in scene tree", {}, ["debug", "battle", "initialization"])
		return false

	var clicker_node: Node = null
	if game_node.has_method("get") and game_node.get("clicker"):
		clicker_node = game_node.get("clicker")

		if clicker_node.has_method("get") and clicker_node.get("level"):
			Log.info(
				"Game systems ready - clicker initialized",
				{},
				["debug", "battle", "initialization"]
			)
			return true

	Log.info("Game systems not ready yet, waiting...", {}, ["debug", "battle", "initialization"])

	if clicker_node:
		Log.info(
			"Game systems available - proceeding without timing-based waits",
			{},
			["debug", "battle", "initialization"]
		)
		return true

	Log.error(
		"Game systems not available - clicker node not found",
		{},
		["debug", "battle", "initialization"]
	)
	return false


static func _start_battle() -> DebugAction.Result:
	var game: Game = _get_game_node()
	if not game:
		return DebugAction.Result.new_failure("Game node not available")

	core.action(core.SystemIdleActionEvent.new(Callable(GameActionCore, "_trigger_start_battle")))

	return DebugAction.Result.new_success({"battle_queued": true})


static func _trigger_start_battle() -> void:
	Log.info("Starting battle via idle action", {}, ["debug", "battle"])
	ui.action(ui.StartBattleEvent.new())


static func _populate_enemy_and_start_battle() -> DebugAction.Result:
	var game: Game = _get_game_node()
	if not game:
		return DebugAction.Result.new_failure("Game node not available")

	core.action(
		core.SystemIdleActionEvent.new(Callable(GameActionCore, "_trigger_populate_enemy_lineup"))
	)
	core.action(core.SystemIdleActionEvent.new(Callable(GameActionCore, "_trigger_start_battle")))

	return DebugAction.Result.new_success({"populate_and_battle_queued": true})


static func _trigger_populate_enemy_lineup() -> void:
	Log.info("Populating enemy lineup via idle action", {}, ["debug", "battle"])
	var populate_task: Callable = func() -> void: await _populate_enemy_lineup()
	populate_task.call()


static func _battle_test_determinism_logic_only() -> DebugAction.Result:
	if not is_instance_valid(rng):
		return DebugAction.Result.new_failure("RNG singleton not available")

	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"=== DETERMINISM TEST ENTRY ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"timestamp": Time.get_datetime_string_from_system(),
			"phase": "unknown"
		},
		["debug", "battle", "determinism", "pid", "phase"]
	)

	var config: Dictionary = _get_determinism_config()
	var current_seed: int = config.seed
	var expected_hash: String = config.expectedHash if config.expectedHash != null else ""
	var mode: String = config.mode

	Log.info(
		"Starting logic-only battle determinism test",
		{
			"seed": current_seed,
			"mode": mode,
			"pid": process_id,
			"test_id": current_test_id,
			"has_expected_hash": expected_hash != ""
		},
		["debug", "battle", "determinism", "pid"]
	)

	var logic_result: Dictionary = _battle_execute_logic_only()

	var duration: int

	if not logic_result.success:
		var error_msg: String = logic_result.error
		return DebugAction.Result.new_failure("Logic-only battle execution failed: " + error_msg)

	duration = logic_result.duration_ms
	Log.info(
		"Logic-only battle execution completed",
		{"duration_ms": duration, "event_count": logic_result.event_count},
		["debug", "battle", "determinism"]
	)

	var rng_sequence: Array = rng.seeded_rng._result_sequence
	var actual_hash: String = str(rng_sequence).md5_text()

	if mode == "validation":
		Log.info(
			"=== VALIDATION MODE ===",
			{
				"pid": process_id,
				"test_id": current_test_id,
				"expected_hash": expected_hash,
				"actual_hash": actual_hash,
				"match": expected_hash == actual_hash,
				"phase": "validation"
			},
			["debug", "battle", "determinism", "pid", "phase"]
		)

		if expected_hash == actual_hash:
			Log.info(
				"Logic-only battle determinism test PASSED",
				{
					"seed": current_seed,
					"hash": actual_hash,
					"duration_ms": duration,
					"pid": process_id,
					"test_id": current_test_id
				},
				["debug", "battle", "determinism", "pid"]
			)
			return DebugAction.Result.new_success(
				{
					"determinism_test": "PASSED",
					"seed": current_seed,
					"hash": actual_hash,
					"duration_ms": duration,
					"logic_only": true,
					"pid": process_id
				},
				duration,
				"determinism_logic_only_passed"
			)
		Log.error(
			"Logic-only battle determinism test FAILED",
			{
				"seed": current_seed,
				"expected": expected_hash,
				"actual": actual_hash,
				"pid": process_id,
				"test_id": current_test_id
			},
			["debug", "battle", "determinism", "pid"]
		)
		return DebugAction.Result.new_failure(
			"Logic-only determinism test failed - hash mismatch", "DETERMINISM_LOGIC_ONLY_FAILED"
		)
	Log.info(
		"=== RECORDING MODE ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"generated_hash": actual_hash,
			"seed": current_seed,
			"phase": "recording"
		},
		["debug", "battle", "determinism", "pid", "phase"]
	)

	var update_success: bool = _update_config_with_hash(actual_hash)

	if update_success:
		Log.info(
			"DEBUG_TEST_RESTART_NEEDED",
			{
				"test_id": current_test_id,
				"reason": "config_updated",
				"phase": "validation_needed",
				"seed": current_seed,
				"hash": actual_hash,
				"logic_only": true,
				"pid": process_id
			},
			["debug", "test", "restart", "pid"]
		)

		Log.info(
			"Logic-only battle determinism recorded and saved to config",
			{
				"seed": current_seed,
				"hash": actual_hash,
				"duration_ms": duration,
				"pid": process_id,
				"test_id": current_test_id
			},
			["debug", "battle", "determinism", "pid"]
		)
		return DebugAction.Result.new_restart_pending(
			{
				"determinism_test": "RECORDED",
				"seed": current_seed,
				"hash": actual_hash,
				"duration_ms": duration,
				"logic_only": true,
				"pid": process_id
			},
			duration,
			"hash_recorded_logic_only_restart_pending"
		)
	Log.info(
		"Hash recording had issues but continuing with restart",
		{
			"seed": current_seed,
			"hash": actual_hash,
			"duration_ms": duration,
			"pid": process_id,
			"test_id": current_test_id
		},
		["debug", "battle", "determinism", "pid"]
	)
	return DebugAction.Result.new_restart_pending(
		{
			"determinism_test": "RECORDED_PARTIAL",
			"seed": current_seed,
			"hash": actual_hash,
			"duration_ms": duration,
			"logic_only": true,
			"pid": process_id
		},
		duration,
		"hash_recorded_logic_only_partial_restart_pending"
	)


static func _battle_execute_logic_only() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		Log.error(
			"Cannot access scene tree for logic-only battle", {}, ["debug", "battle", "determinism"]
		)
		return {
			"success": false,
			"error": "Scene tree not available",
			"duration_ms": Time.get_ticks_msec() - start_time,
			"event_count": 0
		}

	var main_scene: Node = scene_tree.current_scene
	if not main_scene:
		Log.error(
			"Cannot access main scene for logic-only battle", {}, ["debug", "battle", "determinism"]
		)
		return {
			"success": false,
			"error": "Main scene not available",
			"duration_ms": Time.get_ticks_msec() - start_time,
			"event_count": 0
		}

	var game_node: Game = main_scene as Game
	if not game_node:
		game_node = main_scene.find_child("Game", true, false) as Game

	if not game_node:
		Log.error(
			"Cannot find Game node for logic-only battle", {}, ["debug", "battle", "determinism"]
		)
		return {
			"success": false,
			"error": "Game node not found",
			"duration_ms": Time.get_ticks_msec() - start_time,
			"event_count": 0
		}

	var battle_handler: BattleHandler = game_node.battle_handler
	if not battle_handler:
		Log.error(
			"Battle handler not available for logic-only battle",
			{},
			["debug", "battle", "determinism"]
		)
		return {
			"success": false,
			"error": "Battle handler not available",
			"duration_ms": Time.get_ticks_msec() - start_time,
			"event_count": 0
		}

	Log.info(
		"Executing logic-only battle (direct battle solver)", {}, ["debug", "battle", "determinism"]
	)

	var battle_result: Battle.BattleResult = battle_handler.create_battle()
	var events: Array[Context.Event] = battle_result.events
	var event_count: int = events.size()

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Logic-only battle execution completed successfully",
		{"duration_ms": duration, "event_count": event_count},
		["debug", "battle", "determinism"]
	)

	return {"success": true, "error": "", "duration_ms": duration, "event_count": event_count}


static func _get_determinism_config() -> Dictionary:
	var config_path: String = "user://debug_startup_actions.json"
	var default_config: Dictionary = {
		"seed": 55555, "expectedHash": null, "mode": "recording", "skip_animation": false
	}
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"=== CONFIG LOAD ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"path": config_path,
			"exists": FileAccess.file_exists(config_path),
			"timestamp": Time.get_datetime_string_from_system()
		},
		["debug", "battle", "determinism", "filesystem", "pid"]
	)

	if not FileAccess.file_exists(config_path):
		Log.warning(
			"No external config found, using defaults",
			{"default_config": default_config, "pid": process_id, "test_id": current_test_id},
			["debug", "battle", "determinism", "filesystem", "pid"]
		)
		return default_config

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Log.warning(
			"Could not read config file, using defaults",
			{"default_config": default_config, "pid": process_id, "test_id": current_test_id},
			["debug", "battle", "determinism", "pid"]
		)
		return default_config

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)

	if result != OK:
		Log.warning(
			"Invalid JSON in config, using defaults",
			{
				"default_config": default_config,
				"parse_error": result,
				"pid": process_id,
				"test_id": current_test_id
			},
			["debug", "battle", "determinism", "pid"]
		)
		return default_config

	var data: Dictionary = json.data
	var config: Dictionary = {}

	Log.info(
		"Raw config data",
		{
			"data": data,
			"pid": process_id,
			"test_id": current_test_id,
			"file_size": json_text.length()
		},
		["debug", "battle", "determinism", "pid"]
	)

	if data.has("seed"):
		var seed_value: int = data.seed
		config.seed = seed_value
	else:
		config.seed = default_config.seed

	Log.info(
		"Checking for expectedHash",
		{
			"has_key": data.has("expectedHash"),
			"value": data.get("expectedHash", "NOT_FOUND"),
			"pid": process_id,
			"test_id": current_test_id
		},
		["debug", "battle", "determinism", "pid"]
	)

	if data.has("expectedHash"):
		var hash_value: String = data.expectedHash
		config.expectedHash = hash_value
		config.mode = "validation"
		Log.info(
			"Set validation mode",
			{"hash": config.expectedHash, "pid": process_id, "test_id": current_test_id},
			["debug", "battle", "determinism", "pid"]
		)
	else:
		config.expectedHash = null
		config.mode = "recording"
		Log.info(
			"Set recording mode - no expectedHash found",
			{"pid": process_id, "test_id": current_test_id},
			["debug", "battle", "determinism", "pid"]
		)

	if data.has("skip_animation"):
		var skip_value: bool = data.skip_animation
		config.skip_animation = skip_value
	else:
		config.skip_animation = default_config.skip_animation

	Log.info(
		"Determinism config loaded",
		{
			"seed": config.seed,
			"mode": config.mode,
			"has_hash": config.expectedHash != null,
			"skip_animation": config.skip_animation
		},
		["debug", "battle", "determinism"]
	)
	return config


static func _update_config_with_hash(hash_value: String) -> bool:
	var config_path: String = "user://debug_startup_actions.json"
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"=== CONFIG UPDATE ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"path": config_path,
			"hash": hash_value,
			"exists_before": FileAccess.file_exists(config_path),
			"timestamp": Time.get_datetime_string_from_system()
		},
		["debug", "battle", "determinism", "filesystem", "pid"]
	)

	if not FileAccess.file_exists(config_path):
		Log.error(
			"Cannot update config - file does not exist",
			{"path": config_path},
			["debug", "battle", "determinism", "filesystem"]
		)
		return false

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot read config file for update",
			{"path": config_path},
			["debug", "battle", "determinism"]
		)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)

	if result != OK:
		Log.error(
			"Cannot parse config JSON for update",
			{"path": config_path},
			["debug", "battle", "determinism"]
		)
		return false

	var data: Dictionary = json.data
	data.expectedHash = hash_value

	var updated_json: String = JSON.stringify(data, "\t")
	file = FileAccess.open(config_path, FileAccess.WRITE)
	if not file:
		Log.error(
			"Cannot write updated config file",
			{"path": config_path},
			["debug", "battle", "determinism"]
		)
		return false

	file.store_string(updated_json)
	file.close()

	var exists_after: bool = FileAccess.file_exists(config_path)
	Log.info(
		"Config updated with expectedHash",
		{
			"hash": hash_value,
			"path": config_path,
			"exists_after": exists_after,
			"pid": process_id,
			"test_id": current_test_id
		},
		["debug", "battle", "determinism", "filesystem", "pid"]
	)

	if exists_after:
		var verification_file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
		if verification_file:
			var verification_content: String = verification_file.get_as_text()
			verification_file.close()
			Log.info(
				"Config verification read",
				{"content_preview": verification_content.substr(0, 200)},
				["debug", "battle", "determinism", "filesystem"]
			)
		else:
			Log.warning(
				"Could not verify written config",
				{"path": config_path},
				["debug", "battle", "determinism", "filesystem"]
			)

	return true


static func _battle_test_determinism() -> DebugAction.Result:
	if not is_instance_valid(ui) or not is_instance_valid(rng):
		return DebugAction.Result.new_failure("Required systems not available")

	var config: Dictionary = _get_determinism_config()
	var current_seed: int = config.seed
	var expected_hash: String = config.expectedHash if config.expectedHash != null else ""
	var mode: String = config.mode
	var skip_animation: bool = config.skip_animation

	Log.info(
		"Starting battle determinism test",
		{"seed": current_seed, "mode": mode, "skip_animation": skip_animation},
		["debug", "battle", "determinism"]
	)

	var duration: int

	if skip_animation:
		Log.info(
			"Executing battle in logic-only mode (no animation)",
			{},
			["debug", "battle", "determinism"]
		)
		var logic_result: Dictionary = _battle_execute_logic_only()

		if not logic_result.success:
			var error_msg: String = logic_result.error
			return DebugAction.Result.new_failure("Logic-only battle failed: " + error_msg)

		duration = logic_result.duration_ms
		Log.info(
			"Logic-only battle execution completed",
			{"duration_ms": duration, "event_count": logic_result.event_count},
			["debug", "battle", "determinism"]
		)
	else:
		var start_time: int = Time.get_ticks_msec()
		Log.info("Executing battle with full animation", {}, ["debug", "battle", "determinism"])

		var game: Game = _get_game_node()
		if not game:
			return DebugAction.Result.new_failure("Game node not available")

		var initial_state: core.GameState = game.game_handler.current_gamestate
		core.action(
			core.SystemIdleActionEvent.new(Callable(GameActionCore, "_trigger_start_battle"))
		)

		while game.game_handler.current_gamestate == initial_state:
			await Engine.get_main_loop().process_frame

		while game.game_handler.current_gamestate != core.GameState.POSTBATTLE:
			await Engine.get_main_loop().process_frame

		duration = Time.get_ticks_msec() - start_time
		Log.info(
			"Animated battle execution completed",
			{"duration_ms": duration},
			["debug", "battle", "determinism"]
		)

	var rng_sequence: Array = rng.seeded_rng._result_sequence
	var actual_hash: String = str(rng_sequence).md5_text()

	if mode == "validation":
		if expected_hash == actual_hash:
			Log.info(
				"Battle determinism test PASSED",
				{"seed": current_seed, "hash": actual_hash, "duration_ms": duration},
				["debug", "battle", "determinism"]
			)
			return DebugAction.Result.new_success(
				{
					"determinism_test": "PASSED",
					"seed": current_seed,
					"hash": actual_hash,
					"duration_ms": duration
				},
				duration,
				"determinism_passed"
			)
		Log.error(
			"Battle determinism test FAILED",
			{"seed": current_seed, "expected": expected_hash, "actual": actual_hash},
			["debug", "battle", "determinism"]
		)
		return DebugAction.Result.new_failure(
			"Determinism test failed - hash mismatch", "DETERMINISM_FAILED"
		)
	var update_success: bool = _update_config_with_hash(actual_hash)

	if update_success:
		Log.info(
			"Attempting to read back written hash for validation...",
			{},
			["debug", "battle", "determinism"]
		)
		var verification_config: Dictionary = _get_determinism_config()
		var read_back_hash: String = (
			verification_config.expectedHash if verification_config.expectedHash != null else ""
		)
		var read_back_mode: String = verification_config.mode

		if read_back_hash == actual_hash:
			Log.info(
				"VERIFICATION SUCCESS: Hash read back correctly",
				{"written_hash": actual_hash, "read_hash": read_back_hash, "mode": read_back_mode},
				["debug", "battle", "determinism"]
			)
		else:
			Log.error(
				"VERIFICATION FAILED: Hash not read back correctly",
				{"written_hash": actual_hash, "read_hash": read_back_hash, "mode": read_back_mode},
				["debug", "battle", "determinism"]
			)

	if update_success:
		var current_test_id: String = DebugAction.get_current_test_id()
		Log.info(
			"DEBUG_TEST_RESTART_NEEDED",
			{
				"test_id": current_test_id,
				"reason": "config_updated",
				"phase": "validation_needed",
				"seed": current_seed,
				"hash": actual_hash
			},
			["debug", "test", "restart"]
		)

		Log.info(
			"Battle determinism recorded and saved to config",
			{"seed": current_seed, "hash": actual_hash, "duration_ms": duration},
			["debug", "battle", "determinism"]
		)
		return DebugAction.Result.new_restart_pending(
			{
				"determinism_test": "RECORDED",
				"seed": current_seed,
				"hash": actual_hash,
				"duration_ms": duration
			},
			duration,
			"hash_recorded_restart_pending"
		)
	Log.warning(
		"Hash recorded but config update failed - test still passed",
		{"seed": current_seed, "hash": actual_hash, "duration_ms": duration},
		["debug", "battle", "determinism"]
	)
	return DebugAction.Result.new_restart_pending(
		{
			"determinism_test": "RECORDED_PARTIAL",
			"seed": current_seed,
			"hash": actual_hash,
			"duration_ms": duration
		},
		duration,
		"hash_recorded_partial_restart_pending"
	)


static func _reset_board_state() -> bool:
	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not found - cannot reset battle state", {}, ["debug", "board", "error"]
		)
		return false

	var reset_successful: bool = true

	if game.holder_allies:
		if game.holder_allies.has_method("clear_lineup"):
			game.holder_allies.clear_lineup()
		elif game.holder_allies.has_method("reset"):
			game.holder_allies.reset()
		elif game.holder_allies.has_method("clear"):
			game.holder_allies.clear()
		Log.info("Allied lineup reset", {}, ["debug", "board", "reset"])
	else:
		Log.warning("Allied lineup not found for reset", {}, ["debug", "board", "reset"])
		reset_successful = false

	if game.holder_enemy:
		if game.holder_enemy.has_method("clear_lineup"):
			game.holder_enemy.clear_lineup()
		elif game.holder_enemy.has_method("reset"):
			game.holder_enemy.reset()
		elif game.holder_enemy.has_method("clear"):
			game.holder_enemy.clear()
		Log.info("Enemy lineup reset", {}, ["debug", "board", "reset"])
	else:
		Log.warning("Enemy lineup not found for reset", {}, ["debug", "board", "reset"])
		reset_successful = false

	if game.game_handler:
		game.game_handler.set_gamestate(core.GameState.PREPARE)
		Log.info("Game state reset to PREPARE", {}, ["debug", "board", "reset"])

	game.ui_state = core.UIState.WAITING
	Log.info("UI state reset to WAITING", {}, ["debug", "board", "reset"])

	if reset_successful:
		Log.info("Battle state reset completed successfully", {}, ["debug", "board", "reset"])
	else:
		Log.warning("Battle state reset completed with warnings", {}, ["debug", "board", "reset"])

	return reset_successful
