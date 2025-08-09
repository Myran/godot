class_name GameDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_gameplay_actions(registry)
	_register_match_level_actions(registry)
	_register_lineup_actions(registry)
	_register_battle_actions(registry)
	_register_database_actions(registry)
	_register_quick_actions(registry)

	Log.info("Game debug actions registered", {}, ["debug", "game"])


static func _register_gameplay_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.match.reset_level", _reset_match_level)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)


static func _register_match_level_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_1", func() -> bool: return _load_match_level(1))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 1")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_2", func() -> bool: return _load_match_level(2))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 2")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_3", func() -> bool: return _load_match_level(3))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 3")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_4", func() -> bool: return _load_match_level(4))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 4")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_5", func() -> bool: return _load_match_level(5))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 5")
		)
	)


static func _register_lineup_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.lineup.populate_enemy", _populate_enemy_lineup)
			. set_category("Gameplay")
			. set_group("Preset Lineups")
			. set_description("Add test cards to enemy lineup")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.test.simple_player_events", _test_simple_player_events)
			. set_category("Gameplay")
			. set_group("Test")
			. set_description("Simple test to validate action registration")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.lineup.populate_enemy_as_player", _populate_enemy_lineup_as_player)
			. set_category("Gameplay")
			. set_group("Test")
			. set_description("Populate enemy lineup using fake PLAYER events to test recording")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.board.reset_state", _reset_board_state)
			. set_category("Gameplay")
			. set_group("Board State")
			. set_description("Reset board to initial state for deterministic testing")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.draft.reroll_player", _reroll_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player reroll action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.draft.upgrade_player", _upgrade_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player upgrade action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.draft.toggle_column_player", _toggle_column_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player column toggle action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.lineup.move_card_player", _move_card_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player card move action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.draft.move_card_to_lineup_player", _move_card_to_lineup_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Atomic draft-to-lineup move operation")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.state.transition_player", _transition_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player state transition action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.battle.start_player", _start_battle_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player battle start action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.draft.remove_block_player", _remove_block_player)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player block removal action")
		)
	)


static func _register_battle_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.battle.start", _start_battle)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Start battle and wait for completion")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.battle.populate_enemy_and_start", _populate_enemy_and_start_battle)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Populate enemy lineup then start battle")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.battle.test_determinism_animated", _battle_test_determinism)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Test battle determinism with full animation (comprehensive)")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.battle.test_determinism_logic_only", _battle_test_determinism_logic_only)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Test battle determinism with logic-only execution (fast)")
		)
	)


static func _register_database_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.cache.clear_cards", _clear_card_cache)
			. set_category("Database")
			. set_group("Cache")
			. set_description("Clear the card data cache")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.database.toggle_local_battle", _toggle_local_battle_db)
			. set_category("Database")
			. set_description("Toggle between local and remote battle database")
		)
	)


static func _register_quick_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create("game.debug.cycle_asset_variant", _cycle_asset_variant)
			. set_category("Quick Actions")
			. set_description("Cycle through asset variants (1-3)")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.debug.print_info", _print_debug_info)
			. set_category("Quick Actions")
			. set_description("Print current debug settings")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("game.debug.hide_debug_menu", _hide_debug_menu)
			. set_category("Quick Actions")
			. set_description("Hide the debug menu interface")
		)
	)


static func _reset_match_level() -> bool:
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)
		Log.info("Match level reset", {}, ["debug", "gameplay"])
		return true
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])
		return false


static func _load_match_level(level_num: int) -> bool:
	if DebugManager:
		DebugManager.action(
			DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_%02d" % level_num]
		)
		Log.info("Loading match level %d" % level_num, {}, ["debug", "gameplay"])
		return true
	else:
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

	Log.info("Populating enemy lineup with test cards", {}, ["debug", "gameplay"])

	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(typed_card, n))

	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(typed_card, n))

	var dwarf_card: Variant = await card_controller.create_unit_from_id(str(4), 1)
	if dwarf_card and is_instance_valid(dwarf_card):
		var typed_dwarf: Card = dwarf_card  # Fail fast if not actually a Card
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
		Log.info("Enemy lineup populated", {}, ["debug", "gameplay"])

	core.action(core.LineupOperationCompleteEvent.new())
	return true


static func _clear_card_cache() -> bool:
	if data_source and data_source.has_method("clear_card_cache"):
		data_source.clear_card_cache()
		Log.info("Card cache cleared", {}, ["debug", "database"])
		return true
	else:
		Log.warning(
			"data_source not available or doesn't support clear_card_cache",
			{},
			["debug", "database"]
		)
		return false


static func _toggle_local_battle_db() -> bool:
	if DebugManager:
		DebugManager.use_local_battle_db = not DebugManager.use_local_battle_db
		Log.info(
			"Local battle DB: %s" % DebugManager.use_local_battle_db, {}, ["debug", "database"]
		)
		return true
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])
		return false


static func _cycle_asset_variant() -> bool:
	if DebugManager:
		DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
		Log.info("Asset variant set to: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
		return true
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])
		return false


static func _print_debug_info() -> bool:
	Log.info("=== Debug Info ===", {}, ["debug", "quick"])
	if DebugManager:
		Log.info("Local DB: %s" % DebugManager.use_local_battle_db, {}, ["debug", "quick"])
		Log.info("Asset Variant: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
		Log.info("==================", {}, ["debug", "quick"])
		return true
	else:
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
			var typed_card: Card = new_card  # Fail fast if not actually a Card
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
	else:
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

	core.action(core.SystemIdleActionEvent.new(Callable(GameDebugActions, "_trigger_start_battle")))

	return DebugAction.Result.new_success({"battle_queued": true})


static func _trigger_start_battle() -> void:
	Log.info("Starting battle via idle action", {}, ["debug", "battle"])
	ui.action(ui.StartBattleEvent.new())


static func _populate_enemy_and_start_battle() -> DebugAction.Result:
	var game: Game = _get_game_node()
	if not game:
		return DebugAction.Result.new_failure("Game node not available")

	core.action(
		core.SystemIdleActionEvent.new(Callable(GameDebugActions, "_trigger_populate_enemy_lineup"))
	)
	core.action(core.SystemIdleActionEvent.new(Callable(GameDebugActions, "_trigger_start_battle")))

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
		else:
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
				"Logic-only determinism test failed - hash mismatch",
				"DETERMINISM_LOGIC_ONLY_FAILED"
			)
	else:
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
		else:
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
			core.SystemIdleActionEvent.new(Callable(GameDebugActions, "_trigger_start_battle"))
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
		else:
			Log.error(
				"Battle determinism test FAILED",
				{"seed": current_seed, "expected": expected_hash, "actual": actual_hash},
				["debug", "battle", "determinism"]
			)
			return DebugAction.Result.new_failure(
				"Determinism test failed - hash mismatch", "DETERMINISM_FAILED"
			)
	else:
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
					{
						"written_hash": actual_hash,
						"read_hash": read_back_hash,
						"mode": read_back_mode
					},
					["debug", "battle", "determinism"]
				)
			else:
				Log.error(
					"VERIFICATION FAILED: Hash not read back correctly",
					{
						"written_hash": actual_hash,
						"read_hash": read_back_hash,
						"mode": read_back_mode
					},
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
		else:
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

	Log.debug(
		"Board state reset - RNG already deterministically initialized",
		{"rng_available": rng != null and rng.seeded_rng != null},
		["debug", "board", "reset"]
	)

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


static func _reroll_player(params: Dictionary = {}) -> bool:
	"""Simulate player reroll action with parameters"""

	var cost: int = params.get("cost", 0)
	if cost < 0:
		Log.error("Invalid cost parameter", {"cost": cost}, ["debug", "replay", "player", "error"])
		assert(false, "reroll_player: cost cannot be negative")
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available for reroll", {}, ["debug", "replay", "player", "error"])
		assert(false, "reroll_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot reroll outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "reroll_player: can only reroll in DRAFT state, current: " + current_state)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for reroll", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "reroll_player: draft system not available")
		return false

	Log.info(
		"Simulating player reroll action",
		{"cost": cost, "params": params},
		["debug", "replay", "player"]
	)

	game.draft_handler.reroll()

	return true


static func _upgrade_player(params: Dictionary = {}) -> bool:
	"""Simulate player upgrade action with parameters"""

	var level: int = params.get("level", 1)
	var level_error: String = _validate_range(level, 1, 5, "level")
	if not level_error.is_empty():
		Log.error(
			"Invalid level parameter",
			{"level": level, "error": level_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: " + level_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available for upgrade", {}, ["debug", "replay", "player", "error"])
		assert(false, "upgrade_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot upgrade outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: can only upgrade in DRAFT state, current: " + current_state)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for upgrade", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: draft system not available")
		return false

	Log.info(
		"Simulating player upgrade action",
		{"level": level, "params": params},
		["debug", "replay", "player"]
	)

	game.draft_handler.upgrade()

	return true


static func _toggle_column_player(params: Dictionary = {}) -> bool:
	"""Simulate player column toggle action with parameters"""

	var required_params: Array[String] = ["column_index", "new_state"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: " + param_error)
		return false

	var column_index: int = params.get("column_index", -1)
	var new_state: bool = params.get("new_state", false)

	var column_error: String = _validate_range(column_index, 0, 4, "column_index")
	if not column_error.is_empty():
		Log.error(
			"Invalid column_index parameter",
			{"column_index": column_index, "error": column_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: " + column_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for column toggle", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot toggle column outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false, "toggle_column_player: can only toggle in DRAFT state, current: " + current_state
		)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for column toggle",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: draft system not available")
		return false

	Log.info(
		"Simulating player column toggle action",
		{"column_index": column_index, "new_state": new_state, "params": params},
		["debug", "replay", "player"]
	)

	var event: core.DraftColumnStateEvent = core.DraftColumnStateEvent.new(column_index, new_state)
	event.source = core.EventSource.PLAYER
	core.action(event)

	return true


static func _remove_block_player(params: Dictionary = {}) -> bool:
	"""Simulate player block removal action with parameters - mirrors normal UI flow"""

	var required_params: Array[String] = ["position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var position: Dictionary = params.get("position", {})

	var validation_error: String = _can_remove_block(card_id, position)
	if not validation_error.is_empty():
		Log.error(
			"Invalid parameters for block removal",
			{"error": validation_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: " + validation_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for block removal", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot remove blocks outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			"remove_block_player: can only remove blocks in DRAFT state, current: " + current_state
		)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for block removal",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: draft system not available")
		return false

	var pos_x: int = position.get("x", -1)
	var pos_y: int = position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(pos_x, pos_y)
	var actual_block: Block = Clicker.find_block_at_position(game.clicker, grid_pos)

	if not actual_block:
		Log.error(
			"No block found at specified position",
			{"position": position, "grid_pos": grid_pos},
			["debug", "replay", "player", "warning", "error"]
		)
		assert(false, "block not found at expeected position")
		return false

	if actual_block.object_type == core.ObjectType.CARD:
		var actual_card_id: String = actual_block.card_info.id
		if actual_card_id != card_id:
			Log.error(
				"Card ID mismatch at position",
				{"expected": card_id, "actual": actual_card_id, "position": position},
				["debug", "replay", "player", "error"]
			)
			assert(false, "remove_block_player: Card ID mismatch")
			return false
	elif actual_block.object_type == core.ObjectType.BLOCK_LOCKED:
		if not card_id.is_empty():
			Log.error(
				"Card ID should be empty for locked blocks",
				{"card_id": card_id, "position": position, "block_type": actual_block.object_type},
				["debug", "replay", "player", "error"]
			)
			assert(false, "remove_block_player: Card ID should be empty for locked blocks")
			return false
	else:
		Log.error(
			"Block at position is not removable",
			{"position": position, "block_type": actual_block.object_type},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: Block is not removable")
		return false

	Log.info(
		"Performing block removal action",
		{"card_id": card_id, "position": position, "block_type": actual_block.object_type},
		["debug", "replay", "player"]
	)

	core.action(core.RemoveBlockFromDraft.new(actual_block, true))

	Log.info(
		"Block removal completed",
		{"card_id": card_id, "position": position},
		["debug", "replay", "player"]
	)

	return true


static func _move_card_player(params: Dictionary = {}) -> bool:
	"""Simulate player card move action with parameters"""

	var required_params: Array[String] = ["card_id", "from_position", "to_position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var from_position: int = params.get("from_position", -1)
	var to_position: int = params.get("to_position", -1)

	var from_error: String = _validate_range(from_position, 0, 9, "from_position")
	if not from_error.is_empty():
		Log.error(
			"Invalid from_position parameter",
			{"error": from_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + from_error)
		return false

	var to_error: String = _validate_range(to_position, 0, 9, "to_position")
	if not to_error.is_empty():
		Log.error(
			"Invalid to_position parameter",
			{"error": to_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + to_error)
		return false

	var move_error: String = _can_move_card(card_id, from_position)
	if not move_error.is_empty():
		Log.error("Cannot move card", {"error": move_error}, ["debug", "replay", "player", "error"])
		assert(false, "move_card_player: " + move_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for card move", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT" and current_state != "PREPARE":
		Log.error(
			"Cannot move cards in current state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			(
				"move_card_player: can only move cards in DRAFT or PREPARE state, current: "
				+ current_state
			)
		)
		return false

	if not core:
		Log.error(
			"Core system not available for card move", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: core system not available")
		return false

	Log.info(
		"Simulating player card move action",
		{
			"card_id": card_id,
			"from_position": from_position,
			"to_position": to_position,
			"params": params
		},
		["debug", "replay", "player"]
	)

	if not is_instance_valid(card_controller):
		Log.error(
			"card_controller not available for card move",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: card_controller not available")
		return false

	var card: Variant = await card_controller.create_unit_from_id(card_id, 1)
	if not card:
		Log.error(
			"Failed to create card for move",
			{"card_id": card_id},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: Failed to create card")
		return false

	var typed_card: Card = card
	typed_card.block_context = Cards.CONTEXT.LINEUP

	var move_event: core.MoveLineupCardEvent = core.MoveLineupCardEvent.new(
		typed_card, from_position, to_position
	)
	core.action(move_event)

	return true


static func _move_card_to_lineup_player(params: Dictionary = {}) -> bool:
	"""Atomic draft-to-lineup move operation using LineupAddCardFromDraftEvent"""
	var required_params: Array[String] = ["card_id", "from_position", "to_position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var from_position: Dictionary = params.get("from_position", {})
	var to_position: int = params.get("to_position", -1)
	var from_x: int = from_position.get("x", -1)
	var from_y: int = from_position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(from_x, from_y)

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available", {}, ["debug", "replay", "player", "error"])
		assert(false, "move_card_to_lineup_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot move cards outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: invalid game state")
		return false

	var card_to_move: Card = Clicker.find_block_at_position(game.clicker, grid_pos) as Card
	if not card_to_move:
		Log.error(
			"No card found at position",
			{"position": from_position},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: card not found")
		return false

	var target_holder: Holder = game.lineup_handler.holder_container.get_holder(to_position)
	if not target_holder.can_set_card(card_to_move):
		Log.error(
			"Target lineup position occupied",
			{"position": to_position, "card_id": card_id},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: target position occupied")
		return false

	Log.info(
		"Executing draft-to-lineup move via LineupAddCardFromDraftEvent",
		{"card_id": card_id, "from": from_position, "to": to_position},
		["debug", "replay", "player", "move"]
	)

	core.action(core.LineupAddCardFromDraftEvent.new(card_to_move, grid_pos, to_position))

	Log.info(
		"Draft-to-lineup move completed successfully",
		{"card_id": card_id, "from": from_position, "to": to_position},
		["debug", "replay", "player", "move"]
	)
	return true


static func _transition_player(params: Dictionary = {}) -> bool:
	"""Simulate player state transition action with parameters"""
	var from_state: String = params.get("from_state", "")  # Expected starting state (empty = skip validation)
	var to_state: String = params.get("to_state", "PREPARE")  # Target state

	if to_state.is_empty():
		Log.error(
			"to_state parameter is required",
			{"params": params},
			["debug", "replay", "player", "error"]
		)
		assert(false, "transition_player: to_state parameter is required")
		return false

	if not from_state.is_empty():
		var game: Game = _get_game_node()
		if not game:
			Log.error(
				"Cannot validate state transition - game node not available",
				{"expected_from_state": from_state, "target_state": to_state},
				["debug", "replay", "player", "error"]
			)
			assert(false, "transition_player: game node not available")
			return false

		var current_state_name: String = core.GameState.keys()[game.game_handler.current_gamestate]
		if current_state_name != from_state:
			(
				Log
				. error(
					"State transition validation failed - current state doesn't match expected from_state",
					{
						"expected_from_state": from_state,
						"actual_current_state": current_state_name,
						"target_state": to_state,
						"params": params
					},
					["debug", "replay", "player", "error"]
				)
			)
			assert(
				false,
				(
					"transition_player: expected state "
					+ from_state
					+ " but current is "
					+ current_state_name
				)
			)
			return false

	Log.info(
		"Simulating player state transition action",
		{"from_state": from_state, "to_state": to_state, "params": params},
		["debug", "replay", "player"]
	)

	var target_state: core.GameState

	match to_state:
		"START":
			target_state = core.GameState.START
		"PREPARE":
			target_state = core.GameState.PREPARE
		"DRAFT":
			target_state = core.GameState.DRAFT
		"PREBATTLE":
			target_state = core.GameState.PREBATTLE
		"BATTLE":
			target_state = core.GameState.BATTLE
		"POSTBATTLE":
			target_state = core.GameState.POSTBATTLE
		_:
			Log.error(
				"Unknown target state for replay",
				{"to_state": to_state},
				["debug", "replay", "player", "error"]
			)
			assert(false, "transition_player: unknown target state: " + to_state)
			return false

	var event: core.TransitionEvent = core.TransitionEvent.new(target_state)
	event.source = core.EventSource.PLAYER
	core.action(event)

	return true


static func _start_battle_player(params: Dictionary = {}) -> bool:
	"""Simulate player battle start action with parameters"""

	var player_lineup_count: int = params.get("player_lineup_count", 3)
	var enemy_lineup_count: int = params.get("enemy_lineup_count", 3)

	var player_error: String = _validate_range(player_lineup_count, 1, 10, "player_lineup_count")
	if not player_error.is_empty():
		Log.error(
			"Invalid player_lineup_count parameter",
			{"error": player_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: " + player_error)
		return false

	var enemy_error: String = _validate_range(enemy_lineup_count, 1, 10, "enemy_lineup_count")
	if not enemy_error.is_empty():
		Log.error(
			"Invalid enemy_lineup_count parameter",
			{"error": enemy_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: " + enemy_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for battle start", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "PREPARE":
		Log.error(
			"Cannot start battle from current state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			(
				"start_battle_player: can only start battle from PREPARE state, current: "
				+ current_state
			)
		)
		return false

	if not ui:
		Log.error(
			"UI system not available for battle start", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: UI system not available")
		return false

	Log.info(
		"Simulating player battle start action",
		{
			"player_lineup_count": player_lineup_count,
			"enemy_lineup_count": enemy_lineup_count,
			"params": params
		},
		["debug", "replay", "player"]
	)

	ui.action(ui.StartBattleEvent.new())

	return true


static func _validate_required_params(params: Dictionary, required_keys: Array[String]) -> String:
	"""Validate that all required parameters are present. Returns empty string if valid, error message if invalid."""
	for key: String in required_keys:
		if not params.has(key):
			return "Missing required parameter: " + key
		var value: Variant = params[key]
		if value == null:
			return "Parameter '" + key + "' cannot be null"
	return ""


static func _validate_range(value: int, min_val: int, max_val: int, param_name: String) -> String:
	"""Validate integer is within range. Returns empty string if valid, error message if invalid."""
	if value < min_val or value > max_val:
		return (
			param_name
			+ " must be between "
			+ str(min_val)
			+ " and "
			+ str(max_val)
			+ " (got "
			+ str(value)
			+ ")"
		)
	return ""


static func _validate_position_dict(position: Dictionary, param_name: String) -> String:
	"""Validate position dictionary has x,y coordinates within clicker bounds. Returns empty string if valid."""
	if not position.has("x") or not position.has("y"):
		return param_name + " must have 'x' and 'y' coordinates"

	var x: int = position.get("x", -1)
	var y: int = position.get("y", -1)

	var x_error: String = _validate_range(x, 0, 4, param_name + ".x")
	if not x_error.is_empty():
		return x_error

	var y_error: String = _validate_range(y, 0, 3, param_name + ".y")
	if not y_error.is_empty():
		return y_error

	return ""


static func _can_move_card(card_id: String, from_position: int) -> String:
	"""Check if card can be moved from position. Returns empty string if valid."""
	if card_id.is_empty():
		return "card_id cannot be empty"

	var range_error: String = _validate_range(from_position, 0, 9, "from_position")
	if not range_error.is_empty():
		return range_error

	var game: Game = _get_game_node()
	if not game or not game.lineup_handler:
		return "lineup not available for validation"

	if from_position >= game.lineup_handler.get_card_count():
		return "from_position " + str(from_position) + " exceeds lineup size"

	var card_at_position: Card = game.lineup_handler.get_card_at_position(from_position)
	if not card_at_position:
		return "no card found at from_position " + str(from_position)

	if card_at_position.card_info.id != card_id:
		return "card_id mismatch: expected " + card_id + ", found " + card_at_position.card_info.id

	return ""


static func _can_remove_block(card_id: String, position: Dictionary) -> String:
	"""Check if block can be removed from card at position. Returns empty string if valid."""
	var pos_error: String = _validate_position_dict(position, "position")
	if not pos_error.is_empty():
		return pos_error

	var game: Game = _get_game_node()
	if not game or not game.clicker:
		return "draft system not available for validation"

	var pos_x: int = position.get("x", -1)
	var pos_y: int = position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(pos_x, pos_y)

	var block_at_position: Block = Clicker.find_block_at_position(game.clicker, grid_pos)
	if not block_at_position:
		return "no block found at position (" + str(grid_pos.x) + "," + str(grid_pos.y) + ")"

	if block_at_position.object_type == core.ObjectType.BLOCK_LOCKED:
		if not card_id.is_empty():
			return "card_id should be empty for locked blocks, got: " + card_id
	elif block_at_position.object_type == core.ObjectType.CARD:
		if not card_id.is_empty():
			if block_at_position.card_info.id != card_id:
				return (
					"card_id mismatch: expected "
					+ card_id
					+ ", found "
					+ block_at_position.card_info.id
				)
	else:
		return (
			"block at position is not removable (type: " + str(block_at_position.object_type) + ")"
		)

	return ""
