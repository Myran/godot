# project/debug/actions/registrations/game_actions.gd
# GameTwo-specific debug actions for gameplay, content, and domain logic

class_name GameDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_gameplay_actions(registry)
	_register_match_level_actions(registry)
	_register_lineup_actions(registry)
	_register_battle_actions(registry)
	#_register_card_actions(registry)
	_register_database_actions(registry)
	_register_quick_actions(registry)

	Log.info("Game debug actions registered", {}, ["debug", "game"])


static func _register_gameplay_actions(registry: DebugActionRegistry) -> void:
	# Core gameplay actions
	registry.register_action(
		(
			DebugAction
			. create("game.match.reset_level", _reset_match_level)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)


static func _register_match_level_actions(registry: DebugActionRegistry) -> void:
	# Match Level Actions
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
	# Enemy/Debug Lineup Actions
	registry.register_action(
		(
			DebugAction
			. create("game.lineup.populate_enemy", _populate_enemy_lineup)
			. set_category("Gameplay")
			. set_group("Preset Lineups")
			. set_description("Add test cards to enemy lineup")
		)
	)


static func _register_battle_actions(registry: DebugActionRegistry) -> void:
	# Battle actions using GameStateMonitor
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
			. create("game.battle.set_seed", _battle_set_seed)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Set RNG seed for deterministic testing")
		)
	)
	
	registry.register_action(
		(
			DebugAction
			. create("game.battle.test_determinism", _battle_test_determinism)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Test battle determinism with automatic baseline recording/validation")
		)
	)


#static func _register_card_actions(registry: DebugActionRegistry) -> void:
## Player Card Actions
#registry.register_action(
#(
#DebugAction
#. create("Spawn Test Cards", _spawn_test_cards)
#. set_category("Gameplay")
#. set_group("Cards")
#. set_description("Spawns 3 random test cards for the player")
#)
#)


static func _register_database_actions(registry: DebugActionRegistry) -> void:
	# GameTwo database actions
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
	# Quick utility actions for GameTwo
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


# Game action implementations
static func _reset_match_level() -> bool:
	# Reset the current match level
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)
		Log.info("Match level reset", {}, ["debug", "gameplay"])
		return true
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])
		return false


static func _load_match_level(level_num: int) -> bool:
	# Load a specific match level
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
	# Add test cards to enemy lineup
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error(
			"Cannot populate enemy lineup: core or card_controller missing", {}, ["debug", "error"]
		)
		return false

	# Ensure game systems are ready before starting operation
	if not await _wait_for_game_systems_ready():
		return false

	# Signal operation start (locks UI like clicker does)
	core.action(core.LineupOperationStartEvent.new())
	
	Log.info("Populating enemy lineup with test cards", {}, ["debug", "gameplay"])

	# Create enemy cards
	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(typed_card, n))

	# Create debug cards
	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(typed_card, n))

	# Signal operation complete (unlocks UI like DraftSteadyEvent does)
	core.action(core.LineupOperationCompleteEvent.new())
	
	Log.info("Enemy lineup populated", {}, ["debug", "gameplay"])
	return true


#static func _spawn_test_cards() -> void:
## Spawn 3 random test cards for the player
#if not is_instance_valid(card_controller) or not is_instance_valid(core):
#Log.error("Cannot spawn cards: Missing card_controller or core", {}, ["debug", "error"])
#return
#
#Log.info("Spawning 3 test cards for player...", {}, ["debug", "gameplay"])
#
#for i: int in 3:
#var card: Variant = await card_controller.get_card_from_pool()
#if card:
#var typed_card: Card = card  # Fail fast if not actually a Card
## Add to player's hand or appropriate location
#core.action(core.DrawCardEvent.new(typed_card))
#var card_id: String = str(typed_card.get("id")) if typed_card.has("id") else "unknown"
#Log.debug("Spawned card: %s" % card_id, {"card_id": card_id}, ["debug", "gameplay"])
#
#Log.info("Test cards spawned successfully", {}, ["debug", "gameplay"])


static func _clear_card_cache() -> bool:
	# Clear the card data cache
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
	# Toggle between local and remote battle database
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
	# Cycle through asset variants (1-3)
	if DebugManager:
		DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
		Log.info("Asset variant set to: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
		return true
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])
		return false


static func _print_debug_info() -> bool:
	# Print current debug settings
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


static func _hide_debug_menu() -> bool:
	# Hide the debug menu interface
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU)
		Log.info("Debug menu hidden", {}, ["debug", "ui"])
		return true
	else:
		Log.warning("DebugManager not available", {}, ["debug", "ui"])
		return false


# Helper function to wait for game systems to be ready
static func _wait_for_game_systems_ready() -> bool:
	Log.info("Waiting for game systems to be ready...", {}, ["debug", "battle", "initialization"])
	
	# Try to find the game node in the scene tree
	var game_node: Node = null
	var root: Node = Engine.get_main_loop().current_scene
	
	# Search for Game node (could be child of main or direct scene)
	if root and root.has_method("find_child"):
		game_node = root.find_child("Game", true, false)
	
	if not game_node:
		Log.warning("Game node not found in scene tree", {}, ["debug", "battle", "initialization"])
		return false
	
	# Check if the game has a clicker that's properly initialized
	var clicker_node: Node = null
	if game_node.has_method("get") and game_node.get("clicker"):
		clicker_node = game_node.get("clicker")
		
		# Check if clicker has a level (indicating it's been set up)
		if clicker_node.has_method("get") and clicker_node.get("level"):
			Log.info("Game systems ready - clicker initialized", {}, ["debug", "battle", "initialization"])
			return true
	
	# If not ready yet, wait a few frames and check again
	Log.info("Game systems not ready yet, waiting...", {}, ["debug", "battle", "initialization"])
	
	# Wait up to 5 seconds for systems to be ready
	var max_attempts: int = 50  # 50 attempts * 100ms = 5 seconds
	var attempts: int = 0
	
	while attempts < max_attempts:
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().create_timer(0.1).timeout  # Wait 100ms between checks
		
		# Re-check clicker initialization
		if clicker_node and clicker_node.has_method("get") and clicker_node.get("level"):
			Log.info("Game systems ready after waiting", {"attempts": attempts}, ["debug", "battle", "initialization"])
			return true
		
		attempts += 1
	
	Log.error("Game systems failed to initialize within timeout", {"max_attempts": max_attempts}, ["debug", "battle", "initialization"])
	return false


# Battle action implementations using GameStateMonitor
static func _start_battle() -> DebugAction.Result:
	# Start battle and wait for system to return to idle state
	if not is_instance_valid(ui) or not is_instance_valid(GameStateMonitor):
		return DebugAction.Result.new_failure("Required systems not available")
	
	# Ensure game systems are fully initialized before proceeding
	if not await _wait_for_game_systems_ready():
		return DebugAction.Result.new_failure("Game systems not ready for battle")
	
	var start_time: int = Time.get_ticks_msec()
	
	Log.info("Starting battle", {}, ["debug", "battle"])
	
	# Trigger battle start
	ui.action(ui.StartBattleEvent.new())
	
	# Wait for system to return to idle state
	await GameStateMonitor.await_system_idle()
	
	var duration: int = Time.get_ticks_msec() - start_time
	
	Log.info("Battle completed", {"duration_ms": duration}, ["debug", "battle"])
	
	return DebugAction.Result.new_success(
		{"battle_duration_ms": duration},
		duration,
		"battle_complete"
	)


static func _populate_enemy_and_start_battle() -> DebugAction.Result:
	# Chain: populate enemy lineup then start battle
	if not is_instance_valid(GameStateMonitor):
		return DebugAction.Result.new_failure("GameStateMonitor not available")
	
	# Ensure game systems are fully initialized before proceeding
	if not await _wait_for_game_systems_ready():
		return DebugAction.Result.new_failure("Game systems not ready for battle chain")
	
	var start_time: int = Time.get_ticks_msec()
	
	Log.info("Starting battle chain: populate enemy + battle", {}, ["debug", "battle", "chain"])
	
	# Step 1: Populate enemy lineup
	var populate_result: bool = await _populate_enemy_lineup()
	if not populate_result:
		return DebugAction.Result.new_failure("Failed to populate enemy lineup")
	
	# Wait for system to be ready after population
	await GameStateMonitor.await_system_idle()
	
	# Step 2: Start battle  
	var battle_result: DebugAction.Result = await _start_battle()
	
	var total_duration: int = Time.get_ticks_msec() - start_time
	
	if battle_result.is_success():
		Log.info(
			"Battle chain completed successfully", 
			{"total_duration_ms": total_duration}, 
			["debug", "battle", "chain"]
		)
		return DebugAction.Result.new_success(
			{
				"chain_completed": true,
				"total_duration_ms": total_duration,
				"battle_duration_ms": battle_result.get_payload().get("battle_duration_ms", 0)
			},
			total_duration,
			"battle_chain_complete"
		)
	else:
		Log.error(
			"Battle chain failed at battle start", 
			{"error": battle_result.get_error_message()}, 
			["debug", "battle", "chain"]
		)
		return DebugAction.Result.new_failure(
			"Battle chain failed: " + battle_result.get_error_message(),
			"BATTLE_CHAIN_FAILED"
		)


static func _battle_set_seed() -> DebugAction.Result:
	# Set RNG seed for deterministic testing
	if not is_instance_valid(rng):
		return DebugAction.Result.new_failure("RNG singleton not available")
	
	# Try to read seed from config file, fallback to default
	var test_seed: int = _get_seed_from_config()
	rng.seeded_rng.reset(test_seed)
	
	Log.info("RNG seed set for deterministic testing", {"seed": test_seed}, ["debug", "battle", "determinism"])
	
	return DebugAction.Result.new_success(
		{"seed": test_seed},
		0,
		"seed_set"
	)


static func _get_seed_from_config() -> int:
	# Try to read seed from external config file (same path as debug startup uses)
	var config_path: String = "user://debug_startup_actions.json"
	var default_seed: int = 12345
	
	if not FileAccess.file_exists(config_path):
		Log.debug("No external config found, using default seed", {"seed": default_seed}, ["debug", "battle", "determinism"])
		return default_seed
	
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Log.warning("Could not read config file, using default seed", {"seed": default_seed}, ["debug", "battle", "determinism"])
		return default_seed
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)
	
	if result != OK:
		Log.warning("Invalid JSON in config, using default seed", {"seed": default_seed}, ["debug", "battle", "determinism"])
		return default_seed
	
	var data: Dictionary = json.data as Dictionary
	if data.has("seed"):
		var config_seed: int = int(data.seed)
		Log.info("Using seed from config file", {"seed": config_seed}, ["debug", "battle", "determinism"])
		return config_seed
	else:
		Log.debug("No seed in config file, using default", {"seed": default_seed}, ["debug", "battle", "determinism"])
		return default_seed


static func _battle_test_determinism() -> DebugAction.Result:
	# Test battle determinism with automatic baseline recording/validation
	if not is_instance_valid(ui) or not is_instance_valid(GameStateMonitor) or not is_instance_valid(rng):
		return DebugAction.Result.new_failure("Required systems not available")
	
	# Ensure game systems are fully initialized before proceeding
	if not await _wait_for_game_systems_ready():
		return DebugAction.Result.new_failure("Game systems not ready for determinism test")
	
	var start_time: int = Time.get_ticks_msec()
	
	# Generate start checksum (seed + basic state)
	var current_seed: int = _get_seed_from_config()
	var start_checksum: String = str(current_seed) + "_lineup"  # Simple for now
	
	Log.info("Starting battle determinism test", {"seed": current_seed, "start_checksum": start_checksum}, ["debug", "battle", "determinism"])
	
	# Trigger battle start (same as existing _start_battle)
	ui.action(ui.StartBattleEvent.new())
	
	# Wait for system to return to idle state
	await GameStateMonitor.await_system_idle()
	
	var duration: int = Time.get_ticks_msec() - start_time
	
	# Generate end checksum from RNG sequence (simple approach)
	var rng_sequence: Array = rng.seeded_rng._result_sequence
	var end_checksum: String = str(rng_sequence).md5_text()
	
	# Check for existing baseline file
	var filename: String = "user://battle_" + start_checksum + ".txt"
	
	if FileAccess.file_exists(filename):
		# Validation mode
		var file: FileAccess = FileAccess.open(filename, FileAccess.READ)
		if file:
			var saved_hash: String = file.get_as_text().strip_edges()
			file.close()
			
			if saved_hash == end_checksum:
				Log.info("Battle determinism test PASSED", 
					{"seed": current_seed, "hash": end_checksum, "duration_ms": duration}, 
					["debug", "battle", "determinism"]
				)
				return DebugAction.Result.new_success(
					{"determinism_test": "PASSED", "seed": current_seed, "hash": end_checksum, "duration_ms": duration},
					duration,
					"determinism_passed"
				)
			else:
				Log.error("Battle determinism test FAILED", 
					{"seed": current_seed, "expected": saved_hash, "actual": end_checksum}, 
					["debug", "battle", "determinism"]
				)
				return DebugAction.Result.new_failure(
					"Determinism test failed - hash mismatch",
					"DETERMINISM_FAILED"
				)
		else:
			return DebugAction.Result.new_failure("Could not read baseline file")
	else:
		# Recording mode
		var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
		if file:
			file.store_string(end_checksum)
			file.close()
			
			Log.info("Battle baseline recorded", 
				{"file": filename, "seed": current_seed, "hash": end_checksum, "duration_ms": duration}, 
				["debug", "battle", "determinism"]
			)
			return DebugAction.Result.new_success(
				{"determinism_test": "RECORDED", "seed": current_seed, "hash": end_checksum, "file": filename, "duration_ms": duration},
				duration,
				"baseline_recorded"
			)
		else:
			return DebugAction.Result.new_failure("Could not create baseline file")
