class_name Battle extends Node

enum BattleAction { ATTACK_REGULAR }

const UNIT_HEALTH: String = "current_health"
const NO_UNIT_FOUND: int = -1


func battle_start(allies_lineup: Dictionary[int, UnitData], enemies_lineup: Dictionary[int, UnitData]) -> Array[Context.Event]:
	return battle_solver(allies_lineup, enemies_lineup)


func battle_solver(allied_lineup: Dictionary[int, UnitData], enemies_lineup: Dictionary[int, UnitData]) -> Array[Context.Event]:
	var context: BattleContext = BattleContext.new(self)
	_initialize_battle(context, allied_lineup, enemies_lineup)

	while context.is_battle_ongoing():
		solve_win_conditions(context)
		if context.is_battle_ongoing():
			process_turn(context)

	return context.event_list


static func _initialize_battle(
	context: BattleContext, allied_lineup: Dictionary[int, UnitData], enemies_lineup: Dictionary[int, UnitData]
) -> void:
	var dup_allies: Dictionary[int, UnitData] = duplicate_resource(allied_lineup)
	var allies_event: BattleContext.AddLineupEvent = BattleContext.AddLineupEvent.new(
		true, dup_allies
	)
	var dup_enemies: Dictionary[int, UnitData] = duplicate_resource(enemies_lineup)
	var enemies_event: BattleContext.AddLineupEvent = BattleContext.AddLineupEvent.new(
		false, dup_enemies
	)
	context.add_event(allies_event)
	context.add_event(enemies_event)
	context.solve_events()


# Turn processing
static func process_turn(context: BattleContext) -> void:
	start_of_turn(context)
	find_next_unit(context)
	context.solve_events()
	activate_current_unit(context)
	context.solve_events()
	solve_death_test(context)
	context.solve_events()
	context.switch_turn()
	end_of_turn(context)


# Event solvers
static func solve_event(event: Context.Event, context: BattleContext) -> void:
	if event is BattleContext.FindNextUnitEvent:
		var active_side: Side = context.get_active_side()
		var sel_unit_pos: int = find_next_unactive_on_side(active_side)
		if sel_unit_pos == NO_UNIT_FOUND:
			print("All units activated, clearing list!")
			active_side.clear_activated()
			sel_unit_pos = find_next_unactive_on_side(active_side)
		var select_event: BattleContext.SelectActiveUnitEvent = (
			BattleContext.SelectActiveUnitEvent.new(sel_unit_pos, context.is_allied_turn)
		)
		context.add_event(select_event)

	elif event is BattleContext.AddLineupEvent:
		var allied_side: bool = event.is_allied_side
		var side: Side = context.get_side(allied_side)
		side.lineup = event.lineup_data
		print("Lineup added", side.lineup)

	elif event is BattleContext.SelectActiveUnitEvent:
		var data: BattleContext.SelectActiveUnitEvent = event as BattleContext.SelectActiveUnitEvent
		if data.selected_unit_position == NO_UNIT_FOUND:
			return
		var side: Side = context.get_side(data.is_allied_side)
		if !side.lineup.has(data.selected_unit_position):
			return
		var sel_unit: UnitData = side.lineup[data.selected_unit_position]
		context.mark_unit_activated(sel_unit)
		print("unit active", sel_unit)
		context.active_unit = sel_unit

	elif event is BattleContext.CombatEvent:
		var allied_attack: bool = event.is_allied_attack
		var attacking_side: Side = context.get_side(allied_attack)
		var defending_side: Side = context.get_side(!allied_attack)
		var attacker: UnitData = attacking_side.lineup[event.attacker_position]
		var defender: UnitData = defending_side.lineup[event.defender_position]
		var attacker_current_attack: int = attacker.current_attack
		var event_defender: int = event.defender_position
		var event_attacker: int = event.attacker_position
		var defender_current_attack: int = defender.current_attack
		var attacker_damage: BattleContext.DamageEvent = BattleContext.DamageEvent.new(
			attacker_current_attack, event_defender, !allied_attack
		)
		var defender_damage: BattleContext.DamageEvent = BattleContext.DamageEvent.new(
			defender_current_attack, event_attacker, allied_attack
		)
		print("damage from combat", attacker_damage, defender_damage)
		context.add_event(attacker_damage)
		context.add_event(defender_damage)

	elif event is BattleContext.DamageEvent:
		var target: int = event.target_position
		var side: bool = event.is_allied_side
		var damage_amount: int = event.damage_amount
		if event.damage_effects.size():
			for effect: Dictionary in event.damage_effects:
				match effect.effect_type:
					"shield":
						var shield_ability: DamageShieldAbility = effect.ability
						if shield_ability.shield_used == false:
							context.add_event(BattleContext.ShieldEvent.new(target, side, false))
							shield_ability.shield_used = true
							print("shield found,damage prevented")
							return

		var stat_change: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			UNIT_HEALTH, target, side, -damage_amount
		)
		context.add_event(stat_change)

	elif event is BattleContext.StatChangeEvent:
		if event.change_value == 0:
			return
		var event_side: bool = event.is_allied_side
		var side: Side = context.get_side(event_side)
		var stat: StringName = event.stat_name
		if !side.lineup.has(event.target_position):
			print("target N/A , dead?", event)
			return
		var unit: UnitData = side.lineup[event.target_position]
		var current_stat: int = unit.get(stat)
		if current_stat == null:
			push_warning(str("Stats change error", event))
			return
		var new_value: int = current_stat + event.change_value
		unit.set(stat, new_value)
		var target: int = event.target_position
		var follow_up_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			UNIT_HEALTH, target, event_side, 0, new_value
		)
		context.add_event(follow_up_event)

	elif event is BattleContext.DeathEvent:
		var pos: int = event.unit_position
		var side: bool = event.is_allied_side
		context.remove_unit(pos, side)
	elif event is BattleContext.StartOfTurnEvent:
		print("Start of turn")
	elif event is BattleContext.EndOfTurnEvent:
		print("End of turn")


static func find_next_unactive_on_side(side: Side) -> int:
	for pos: int in side.lineup:
		var unit: UnitData = side.lineup[pos]
		if !side.has_unit(unit):
			return pos
	return NO_UNIT_FOUND


# Combat helpers
static func create_combat_event(attacker_unit: UnitData, context: BattleContext) -> Context.Event:
	var target_lineup: Dictionary[int, UnitData] = context.get_inactive_side().lineup
	var attacker_lineup: Dictionary[int, UnitData] = context.get_active_side().lineup
	var opposing_unit: UnitData = find_combat_target(target_lineup)

	return BattleContext.CombatEvent.new(
		get_pos_for_unit(attacker_lineup, attacker_unit),
		get_pos_for_unit(target_lineup, opposing_unit),
		context.is_allied_turn
	)


static func start_of_turn(context: BattleContext) -> void:
	context.add_event(BattleContext.StartOfTurnEvent.new())


static func end_of_turn(context: BattleContext) -> void:
	context.add_event(BattleContext.EndOfTurnEvent.new())


static func find_next_unit(context: BattleContext) -> void:
	context.add_event(BattleContext.FindNextUnitEvent.new())


static func activate_current_unit(context: BattleContext) -> void:
	var selected_action: Dictionary = context.active_unit.select_action(context)
	var event: Context.Event

	match selected_action.action:
		BattleAction.ATTACK_REGULAR:
			event = create_combat_event(context.active_unit, context)
		_:
			push_warning("No action selected!")

	if event:
		context.add_event(event)


# Death handling
static func solve_death_test(context: BattleContext) -> void:
	for is_allied: bool in [true, false]:
		var side: Side = context.get_side(is_allied)
		for pos: int in side.lineup:
			var unit: UnitData = side.lineup[pos]
			if unit.current_health <= 0:
				var event: BattleContext.DeathEvent = BattleContext.DeathEvent.new(is_allied, pos)
				context.add_event(event)


static func solve_win_conditions(context: BattleContext) -> void:
	if context.is_side_empty(true) and context.is_side_empty(false):
		print("Battle Draw!")
		context.end_battle()
	elif context.is_side_empty(true):
		print("Allied lost!")
		context.end_battle()
	elif context.is_side_empty(false):
		print("Enemy lost")
		context.end_battle()
	else:
		print("Win conditions not met, continue battle")


# Utility functions
static func duplicate_resource(res: Variant) -> Variant:
	return str_to_var(var_to_str(res))


static func find_combat_target(lineup: Dictionary[int, UnitData]) -> UnitData:
	for pos: int in lineup:
		return lineup[pos]
	return null


static func get_pos_for_unit(lineup: Dictionary[int, UnitData], unit: UnitData) -> int:
	for pos: int in lineup:
		if lineup[pos] == unit:
			return pos
	return NO_UNIT_FOUND


static func prepare_lineup_from_holder(lineup: Dictionary) -> Dictionary[int, UnitData]:
	return abstract_lineup(lineup)


static func abstract_lineup(lineup: Dictionary) -> Dictionary[int, UnitData]:
	var abs_lineup: Dictionary[int, UnitData] = {}
	for pos: int in lineup.keys():
		abs_lineup[pos] = lineup[pos].unit_info
	return abs_lineup
