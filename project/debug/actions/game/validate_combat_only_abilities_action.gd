extends RefCounted

## Validates that combat-only abilities (TEMPORARY persistence) don't persist between battles
## Explicit stat verification to ensure reconciliation system correctly filters TEMPORARY abilities


static func execute() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"Starting combat-only ability validation",
		{
			"test_id": current_test_id,
			"pid": process_id,
			"timestamp": Time.get_datetime_string_from_system()
		},
		["debug", "test", "validation", "combat_ability", "pid"]
	)

	# Get game node and battle handler
	var game: Game = _get_game_node()
	if not game:
		return DebugActionResult.new_failure("Game node not available")

	if not game.holder_allies or not game.holder_allies.has_method("get_current_lineup"):
		return DebugActionResult.new_failure("Allied lineup holder not available")

	if not game.holder_enemy or not game.holder_enemy.has_method("get_current_lineup"):
		return DebugActionResult.new_failure("Enemy lineup holder not available")

	# Capture pre-battle stats for all units
	var pre_battle_stats: Dictionary = _capture_lineup_stats(game)
	if pre_battle_stats.is_empty():
		return DebugActionResult.new_failure("Failed to capture pre-battle stats - no units in lineup")

	Log.info(
		"Captured pre-battle stats",
		{
			"allied_units": pre_battle_stats.allied_units.size(),
			"enemy_units": pre_battle_stats.enemy_units.size(),
			"total_units": pre_battle_stats.allied_units.size() + pre_battle_stats.enemy_units.size()
		},
		["debug", "test", "validation", "combat_ability"]
	)

	# Execute battle (logic-only for speed)
	var battle_result: Dictionary = _execute_battle_logic_only(game)
	if not battle_result.success:
		return DebugActionResult.new_failure(
			"Battle execution failed: " + battle_result.error, "BATTLE_EXECUTION_FAILED"
		)

	Log.info(
		"Battle executed successfully",
		{
			"duration_ms": battle_result.duration_ms, "event_count": battle_result.event_count
		},
		["debug", "test", "validation", "combat_ability"]
	)

	# Capture post-battle stats
	var post_battle_stats: Dictionary = _capture_lineup_stats(game)
	if post_battle_stats.is_empty():
		return DebugActionResult.new_failure("Failed to capture post-battle stats")

	# Validate that combat-only abilities didn't persist
	var validation_result: Dictionary = _validate_stats_unchanged(
		pre_battle_stats, post_battle_stats
	)

	var duration: int = Time.get_ticks_msec() - start_time

	if not validation_result.success:
		Log.error(
			"Combat-only ability validation FAILED",
			{
				"failures": validation_result.failures,
				"test_id": current_test_id,
				"pid": process_id,
				"duration_ms": duration
			},
			["debug", "test", "validation", "combat_ability", "pid"]
		)
		return DebugActionResult.new_failure(
			"Combat-only abilities persisted between battles", "VALIDATION_FAILED"
		)

	Log.info(
		"Combat-only ability validation PASSED",
		{
			"units_validated": validation_result.units_validated,
			"test_id": current_test_id,
			"pid": process_id,
			"duration_ms": duration
		},
		["debug", "test", "validation", "combat_ability", "pid", "success"]
	)

	return DebugActionResult.new_success(
		{
			"validation": "PASSED",
			"units_validated": validation_result.units_validated,
			"duration_ms": duration
		},
		duration,
		"combat_only_validation_passed"
	)


static func _capture_lineup_stats(game: Game) -> Dictionary:
	var allied_stats: Array[Dictionary] = []
	var enemy_stats: Array[Dictionary] = []

	# Capture allied unit stats
	var allied_lineup: Dictionary[int, Card] = game.holder_allies.get_current_lineup()
	for position: int in allied_lineup:
		var card: Card = allied_lineup[position]
		if card and card.unit_info:
			allied_stats.append(_capture_unit_stats(card.unit_info, "allied"))

	# Capture enemy unit stats
	var enemy_lineup: Dictionary[int, Card] = game.holder_enemy.get_current_lineup()
	for position: int in enemy_lineup:
		var card: Card = enemy_lineup[position]
		if card and card.unit_info:
			enemy_stats.append(_capture_unit_stats(card.unit_info, "enemy"))

	return {"allied_units": allied_stats, "enemy_units": enemy_stats}


static func _capture_unit_stats(unit: UnitData, side: String) -> Dictionary:
	var card_id: String = unit.card_info.get("id", "unknown")
	var has_temporary_ability: bool = false
	var temporary_abilities: Array[String] = []

	# Check for TEMPORARY persistence type abilities
	for ability: Ability in unit.abilities:
		if ability.persistence_type == Ability.PersistenceType.TEMPORARY:
			has_temporary_ability = true
			temporary_abilities.append(Utils.get_type(ability))

	return {
		"card_id": card_id,
		"side": side,
		"base_attack": unit.base_attack,
		"base_health": unit.base_health,
		"current_attack": unit.current_attack,
		"current_health": unit.current_health,
		"max_attack": unit.max_attack,
		"max_health": unit.max_health,
		"effects_perm_count": unit.effects_perm.size(),
		"effects_temp_count": unit.effects_temp.size(),
		"has_temporary_ability": has_temporary_ability,
		"temporary_abilities": temporary_abilities,
		"level": unit.level
	}


static func _execute_battle_logic_only(game: Game) -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	if not game.battle_handler:
		return {
			"success": false,
			"error": "Battle handler not available",
			"duration_ms": Time.get_ticks_msec() - start_time,
			"event_count": 0
		}

	var battle_result: Battle.BattleResult = game.battle_handler.create_battle()
	var events: Array[Context.Event] = battle_result.events
	var event_count: int = events.size()
	var duration: int = Time.get_ticks_msec() - start_time

	return {
		"success": true, "error": "", "duration_ms": duration, "event_count": event_count
	}


static func _validate_stats_unchanged(
	pre_stats: Dictionary, post_stats: Dictionary
) -> Dictionary:
	var failures: Array[Dictionary] = []
	var units_validated: int = 0

	# Validate allied units
	for i: int in range(pre_stats.allied_units.size()):
		if i >= post_stats.allied_units.size():
			failures.append(
				{
					"reason": "Allied unit missing after battle",
					"unit_index": i,
					"side": "allied"
				}
			)
			continue

		var pre_unit: Dictionary = pre_stats.allied_units[i]
		var post_unit: Dictionary = post_stats.allied_units[i]

		_validate_single_unit(pre_unit, post_unit, failures)
		units_validated += 1

	# Validate enemy units
	for i: int in range(pre_stats.enemy_units.size()):
		if i >= post_stats.enemy_units.size():
			failures.append(
				{"reason": "Enemy unit missing after battle", "unit_index": i, "side": "enemy"}
			)
			continue

		var pre_unit: Dictionary = pre_stats.enemy_units[i]
		var post_unit: Dictionary = post_stats.enemy_units[i]

		_validate_single_unit(pre_unit, post_unit, failures)
		units_validated += 1

	return {"success": failures.is_empty(), "failures": failures, "units_validated": units_validated}


static func _validate_single_unit(
	pre_unit: Dictionary, post_unit: Dictionary, failures: Array[Dictionary]
) -> void:
	# Only validate units that had TEMPORARY abilities
	if not pre_unit.has_temporary_ability:
		return

	# Validate base stats haven't changed
	if pre_unit.base_attack != post_unit.base_attack:
		failures.append(
			{
				"reason": "Base attack changed",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"before": pre_unit.base_attack,
				"after": post_unit.base_attack,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	if pre_unit.base_health != post_unit.base_health:
		failures.append(
			{
				"reason": "Base health changed",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"before": pre_unit.base_health,
				"after": post_unit.base_health,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	# Validate max stats haven't changed (these should reset after battle)
	if pre_unit.max_attack != post_unit.max_attack:
		failures.append(
			{
				"reason": "Max attack changed",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"before": pre_unit.max_attack,
				"after": post_unit.max_attack,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	if pre_unit.max_health != post_unit.max_health:
		failures.append(
			{
				"reason": "Max health changed",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"before": pre_unit.max_health,
				"after": post_unit.max_health,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	# Validate current stats are reset to max stats (reconciliation behavior)
	if post_unit.current_attack != post_unit.max_attack:
		failures.append(
			{
				"reason": "Current attack not reset to max attack",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"current_attack": post_unit.current_attack,
				"max_attack": post_unit.max_attack,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	if post_unit.current_health != post_unit.max_health:
		failures.append(
			{
				"reason": "Current health not reset to max health",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"current_health": post_unit.current_health,
				"max_health": post_unit.max_health,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	# Validate permanent effects haven't increased
	if post_unit.effects_perm_count > pre_unit.effects_perm_count:
		failures.append(
			{
				"reason": "Permanent effects increased",
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"before_count": pre_unit.effects_perm_count,
				"after_count": post_unit.effects_perm_count,
				"temporary_abilities": pre_unit.temporary_abilities
			}
		)

	# Success case - log for debugging
	if failures.is_empty():
		Log.debug(
			"Unit with TEMPORARY abilities validated successfully",
			{
				"card_id": pre_unit.card_id,
				"side": pre_unit.side,
				"temporary_abilities": pre_unit.temporary_abilities,
				"base_attack": pre_unit.base_attack,
				"base_health": pre_unit.base_health,
				"max_attack_before": pre_unit.max_attack,
				"max_attack_after": post_unit.max_attack,
				"max_health_before": pre_unit.max_health,
				"max_health_after": post_unit.max_health,
				"current_attack_reset": post_unit.current_attack == post_unit.max_attack,
				"current_health_reset": post_unit.current_health == post_unit.max_health
			},
			["debug", "test", "validation", "combat_ability", "success"]
		)


static func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		var found_node: Node = root.find_child("Game", true, false)
		if found_node is Game:
			return found_node as Game
	return null
