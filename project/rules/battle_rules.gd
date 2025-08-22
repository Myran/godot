class_name BattleRules extends RefCounted

# Core game rules and mechanics - handles "how the game works"
# All methods are STATIC to ensure consistent rule application
# and eliminate state management complexity

# ===== POSITION & TARGETING RULES =====


static func get_ally_positions(context: BattleContext, is_allied: bool) -> Array[int]:
	var side: Side = context.allied_side if is_allied else context.enemy_side
	var positions: Array[int] = []
	for pos: int in side.lineup:
		if side.lineup[pos] != null:
			positions.append(pos)
	return positions


static func get_enemy_positions(context: BattleContext, is_allied: bool) -> Array[int]:
	var side: Side = context.enemy_side if is_allied else context.allied_side
	var positions: Array[int] = []
	for pos: int in side.lineup:
		if side.lineup[pos] != null:
			positions.append(pos)
	return positions


static func count_allies_alive(context: BattleContext, is_allied: bool) -> int:
	return get_ally_positions(context, is_allied).size()


static func count_enemies_alive(context: BattleContext, is_allied: bool) -> int:
	return get_enemy_positions(context, is_allied).size()


# ===== MULTI-TARGET RULES =====


static func deal_damage_to_random_enemies(
	context: BattleContext, source_allied: bool, damage: int, count: int
) -> void:
	var enemy_positions: Array[int] = get_enemy_positions(context, source_allied)
	if enemy_positions.is_empty():
		return

	for i: int in range(min(count, enemy_positions.size())):
		var target_pos: int = enemy_positions[rng.seeded_rng.next() % enemy_positions.size()]
		var event: BattleContext.DamageEvent = BattleContext.DamageEvent.new(damage, target_pos, not source_allied)
		context.add_event(event)


static func grant_bonuses_to_all_allies(
	context: BattleContext,
	source_pos: int,
	source_allied: bool,
	health_bonus: int,
	attack_bonus: int
) -> void:
	var ally_positions: Array[int] = get_ally_positions(context, source_allied)
	for pos: int in ally_positions:
		if pos != source_pos:  # Exclude self
			if health_bonus > 0:
				var health_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
					Battle.UNIT_HEALTH, pos, source_allied, health_bonus
				)
				context.add_event(health_event)
			if attack_bonus > 0:
				var attack_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
					Battle.UNIT_ATTACK, pos, source_allied, attack_bonus
				)
				context.add_event(attack_event)


# ===== UTILITY RULES =====


static func get_random_enemy_position(context: BattleContext, source_allied: bool) -> int:
	var enemy_positions: Array[int] = get_enemy_positions(context, source_allied)
	if enemy_positions.is_empty():
		return Battle.NO_UNIT_FOUND
	return enemy_positions[rng.seeded_rng.next() % enemy_positions.size()]


static func get_random_ally_position(
	context: BattleContext, source_allied: bool, exclude_self_pos: int = -1
) -> int:
	var ally_positions: Array[int] = get_ally_positions(context, source_allied)
	if exclude_self_pos != -1:
		ally_positions = ally_positions.filter(func(pos: int) -> bool: return pos != exclude_self_pos)
	if ally_positions.is_empty():
		return Battle.NO_UNIT_FOUND
	return ally_positions[rng.seeded_rng.next() % ally_positions.size()]


static func is_position_valid(context: BattleContext, position: int, is_allied: bool) -> bool:
	var side: Side = context.allied_side if is_allied else context.enemy_side
	return side.lineup.has(position) and side.lineup[position] != null
