class_name BattleAbilityEvent extends RefCounted

# Standalone context class encapsulating all unit-related battle event data
# Simple instance-based implementation for clean, testable code

var position: int
var is_allied: bool
var battle_context: BattleContext
var event: Context.Event
var phase: core.Tempus


func _init(
	pos: int = -1,
	allied: bool = false,
	context: BattleContext = null,
	evt: Context.Event = null,
	ph: core.Tempus = core.Tempus.PRE
) -> void:
	position = pos
	is_allied = allied
	battle_context = context
	event = evt
	phase = ph


static func create(
	pos: int, allied: bool, context: BattleContext, evt: Context.Event, ph: core.Tempus
) -> BattleAbilityEvent:
	"""Factory method for creating BattleAbilityEvent instances"""
	return BattleAbilityEvent.new(pos, allied, context, evt, ph)


# ===== INTELLIGENT TARGETING METHODS =====


func is_event_targeting_this_unit() -> bool:
	"""Check if the current event is targeting this specific unit"""
	if event is BattleContext.DamageEvent:
		var dmg_event: BattleContext.DamageEvent = event as BattleContext.DamageEvent
		return dmg_event.target_position == position and dmg_event.is_allied_side == is_allied

	if event is BattleContext.StatChangeEvent:
		var stat_event: BattleContext.StatChangeEvent = event as BattleContext.StatChangeEvent
		return stat_event.target_position == position and stat_event.is_allied_side == is_allied

	if event is BattleContext.ShieldEvent:
		var shield_event: BattleContext.ShieldEvent = event as BattleContext.ShieldEvent
		return shield_event.target_position == position and shield_event.is_allied_side == is_allied

	if event is BattleContext.DeathEvent:
		var death_event: BattleContext.DeathEvent = event as BattleContext.DeathEvent
		return death_event.unit_position == position and death_event.is_allied_side == is_allied
	return false


func is_event_from_this_unit() -> bool:
	"""Check if the current event originated from this specific unit"""
	if event is BattleContext.CombatEvent:
		var combat_event: BattleContext.CombatEvent = event as BattleContext.CombatEvent
		return (
			combat_event.attacker_position == position
			and combat_event.is_allied_attack == is_allied
		)

	if event is BattleContext.SelectActiveUnitEvent:
		var select_event: BattleContext.SelectActiveUnitEvent = event as BattleContext.SelectActiveUnitEvent
		return (
			select_event.selected_unit_position == position
			and select_event.is_allied_side == is_allied
		)
	return false


# ===== GAME RULES DELEGATION =====
# These methods automatically delegate to BattleRules with proper context


func get_ally_positions() -> Array[int]:
	"""Get positions of all allied units (delegates to BattleRules)"""
	return BattleRules.get_ally_positions(battle_context, is_allied)


func get_enemy_positions() -> Array[int]:
	"""Get positions of all enemy units (delegates to BattleRules)"""
	return BattleRules.get_enemy_positions(battle_context, is_allied)


func count_allies_alive() -> int:
	"""Count number of living allied units (delegates to BattleRules)"""
	return BattleRules.count_allies_alive(battle_context, is_allied)


func count_enemies_alive() -> int:
	"""Count number of living enemy units (delegates to BattleRules)"""
	return BattleRules.count_enemies_alive(battle_context, is_allied)


func get_random_enemy_position() -> int:
	"""Get a random enemy position (delegates to BattleRules)"""
	return BattleRules.get_random_enemy_position(battle_context, is_allied)


func get_random_ally_position(exclude_self: bool = true) -> int:
	"""Get a random ally position, optionally excluding self (delegates to BattleRules)"""
	var exclude_pos: int = position if exclude_self else -1
	return BattleRules.get_random_ally_position(battle_context, is_allied, exclude_pos)


func is_position_valid(pos: int, allied: bool) -> bool:
	"""Check if a position is valid and occupied (delegates to BattleRules)"""
	return BattleRules.is_position_valid(battle_context, pos, allied)


# ===== CONVENIENCE METHODS =====


func get_unit_at_position(pos: int, allied: bool) -> UnitData:
	"""Get the unit at a specific position"""
	return battle_context.get_unit_at_position(pos, allied)


func get_self_unit() -> UnitData:
	"""Get the UnitData for this context's unit"""
	return get_unit_at_position(position, is_allied)


func is_battle_ongoing() -> bool:
	"""Check if the battle is still ongoing"""
	return battle_context.is_battle_ongoing()


func add_event(new_event: BattleContext.BaseEvent) -> void:
	"""Add an event to the battle context"""
	battle_context.add_event(new_event)


# ===== DEBUGGING AND VALIDATION =====


func is_valid() -> bool:
	"""Check if this context is in a valid state"""
	return battle_context != null and event != null and position >= 0


func get_debug_info() -> Dictionary:
	"""Get debug information about this context"""
	return {
		"position": position,
		"is_allied": is_allied,
		"phase": phase,
		"event_type": event.get_script().get_global_name() if event else "null",
		"battle_context_valid": battle_context != null,
		"is_valid": is_valid()
	}
