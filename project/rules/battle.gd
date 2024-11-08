class_name Battle extends Node

# Enums for battle system
enum BattleAction { ATTACK_REGULAR }
enum Tempus { PRE, POST }
enum EventType {
	COMBAT,
	DEATH,
	ADD_LINEUP,
	DAMAGE,
	STAT_CHANGE,
	SELECT_ACTIVE_UNIT,
	FIND_NEXT_UNIT,
	START_OF_TURN,
	END_OF_TURN
}


# Event creation helpers
static func create_event(type: EventType, data: Dictionary) -> Context.Event:
	return Context.Event.new(core.SOLVE_TYPE.BATTLE, type, data)


# Core battle flow
func battle_start(allies_lineup: Dictionary, enemies_lineup: Dictionary) -> Array:
	return battle_solver(allies_lineup, enemies_lineup)


func battle_solver(allied_lineup: Dictionary, enemies_lineup: Dictionary) -> Array:
	var context = BattleContext.new(self)
	_initialize_battle(context, allied_lineup, enemies_lineup)

	while context.is_battle_ongoing():
		solve_win_conditions(context)
		if context.is_battle_ongoing():
			process_turn(context)

	return context.event_list


func _initialize_battle(
	context: BattleContext, allied_lineup: Dictionary, enemies_lineup: Dictionary
) -> void:
	var allies_event = create_event(
		EventType.ADD_LINEUP, {"allied_side": true, "lineup": duplicate_resource(allied_lineup)}
	)
	var enemies_event = create_event(
		EventType.ADD_LINEUP, {"allied_side": false, "lineup": duplicate_resource(enemies_lineup)}
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
	match event.event_type:
		EventType.FIND_NEXT_UNIT:
			_solve_find_next_unit(context)
		EventType.ADD_LINEUP:
			_solve_add_lineup(event.data, context)
		EventType.SELECT_ACTIVE_UNIT:
			_solve_select_active_unit(event, context)
		EventType.COMBAT:
			_solve_combat(event.data, context)
		EventType.DAMAGE:
			_solve_damage(event, context)
		EventType.STAT_CHANGE:
			_solve_stat_change(event, context)
		EventType.DEATH:
			_solve_death(event.data, context)
		EventType.START_OF_TURN:
			print("Start of turn")
		EventType.END_OF_TURN:
			print("End of turn")



static func _solve_find_next_unit(context: BattleContext) -> void:
	var active_side = context.get_active_side()
	var sel_unit_pos = find_next_unactive_on_side(active_side)
	# If no unit available and units were activated, clear and try again
	if sel_unit_pos == -1:
		print("All units activated, clearing list!")
		active_side.clear_activated()
		sel_unit_pos = find_next_unactive_on_side(active_side)
	#var event = create_event(
		#EventType.SELECT_ACTIVE_UNIT,
		#{"sel_unit_pos": sel_unit_pos, "allied_side": context.allied_turn}
		#)
	var event = BattleContext.SelectActiveUnitEvent.new(sel_unit_pos,context.allied_turn)
	context.add_event(event)

static func _solve_select_active_unit(data: BattleContext.SelectActiveUnitEvent, context: BattleContext) -> void:
	# If no unit was found, we can't select anything
	if data.sel_unit_pos == -1:
		return
	var side = context.get_side(data.allied_side)
	if !side.lineup.has(data.sel_unit_pos):
		return

	var sel_unit = side.lineup[data.sel_unit_pos]
	context.mark_unit_activated(sel_unit)
	context.current_unit = sel_unit


static func find_next_unactive_on_side(side: Side) -> int:
	for pos in side.lineup:
		var unit = side.lineup[pos]
		if !side.has_unit(unit):
			return pos
	return -1  # Return -1 when no unactivated unit is found



static func _solve_add_lineup(data: Dictionary, context: BattleContext) -> void:
	var side = context.get_side(data.allied_side)
	side.lineup = data.lineup
	print("Lineup added", side.lineup)




static func _solve_combat(data: Dictionary, context: BattleContext) -> void:
	var attacking_side = context.get_side(data.allied_attack)
	var defending_side = context.get_side(!data.allied_attack)
	var attacker = attacking_side.lineup[data.attacker]
	var defender = defending_side.lineup[data.defender]
	
	var attacker_damage = BattleContext.DamageEvent.new(attacker.current_attack,data.defender,!data.allied_attack)
	#var attacker_damage = create_event(
		#EventType.DAMAGE,
		#{
			#"damage_amount": attacker.current_attack,
			#"target": data.defender,
			#"side": !data.allied_attack
		#}
	#)
	var defender_damage = BattleContext.DamageEvent.new(defender.current_attack,data.attacker,data.allied_attack)
	#var defender_damage = create_event(
		#EventType.DAMAGE,
		#{
			#"damage_amount": defender.current_attack,
			#"target": data.attacker,
			#"side": data.allied_attack
		#}
	#)

	context.add_event(attacker_damage)
	context.add_event(defender_damage)


static func _solve_damage(data: BattleContext.DamageEvent, context: BattleContext) -> void:
	var stat_change = BattleContext.StatChangeEvent.new("current_health",data.target,data.side,-data.damage_amount)
	#var stat_change = create_event(
		#EventType.STAT_CHANGE,
		#{
			#"stat": "current_health",
			#"target": data.target,
			#"side": data.side,
			#"value": -data.damage_amount  # Changed from "change"
			#}
			#)
	context.add_event(stat_change)

static func _solve_stat_change(data: BattleContext.StatChangeEvent, context: BattleContext) -> void:
	#if !data.has("value"):  # Changed from "change"
	#	return
	
	if data.value == 0 : return
	
	var side = context.get_side(data.side)
	if !side.lineup.has(data.target):
		print("target N/A , dead?", data)
		return

	var unit = side.lineup[data.target]
	var current_stat = unit.get(data.stat)
	if current_stat == null:
		push_warning(str("Stats change error", data))
		return
	# Update unit with the new value directly
	var new_value = current_stat + data.value
	unit.set(data.stat, new_value) 
	var follow_up_event = BattleContext.StatChangeEvent.new("current_health",data.target,data.side,0,new_value)
	#var follow_up_event = create_event(
		#EventType.STAT_CHANGE,
		#{
			#"stat": "current_health",
			#"new_stat": new_value,  # Using the new value
			#"target": data.target,
			#"side": data.side
			#}
	#)
	context.add_event(follow_up_event)


static func _solve_death(data: Dictionary, context: BattleContext) -> void:
	context.remove_unit(data.pos, data.side)


# Combat helpers
static func create_combat_event(attacker_unit, context: BattleContext) -> Context.Event:
	var target_lineup = context.get_inactive_side().lineup
	var attacker_lineup = context.get_active_side().lineup
	var opposing_unit = find_combat_target(target_lineup)

	return create_event(
		EventType.COMBAT,
		{
			"attacker": get_pos_for_unit(attacker_lineup, attacker_unit),
			"defender": get_pos_for_unit(target_lineup, opposing_unit),
			"allied_attack": context.allied_turn
		}
	)


# Turn phase helpers
static func start_of_turn(context: BattleContext) -> void:
	context.add_event(create_event(EventType.START_OF_TURN, {}))


static func end_of_turn(context: BattleContext) -> void:
	context.add_event(create_event(EventType.END_OF_TURN, {}))


static func find_next_unit(context: BattleContext) -> void:
	context.add_event(create_event(EventType.FIND_NEXT_UNIT, {}))


static func activate_current_unit(context: BattleContext) -> void:
	var selected_action = context.current_unit.select_action(context)
	var event

	match selected_action.action:
		BattleAction.ATTACK_REGULAR:
			event = create_combat_event(context.current_unit, context)
		_:
			push_warning("No action selected!")

	if event:
		context.add_event(event)


# Death handling
static func solve_death_test(context: BattleContext) -> void:
	for is_allied in [true, false]:
		var side = context.get_side(is_allied)
		for pos in side.lineup:
			var unit = side.lineup[pos]
			if unit.current_health <= 0:
				var event = create_event(EventType.DEATH, {"side": is_allied, "pos": pos})
				context.add_event(event)


# Win condition handling
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


static func prepare_lineup_from_holder(lineup: Dictionary) -> Dictionary:
	return abstract_lineup(lineup)


static func abstract_lineup(lineup: Dictionary) -> Dictionary:
	var abs_lineup := {}
	for pos in lineup.keys():
		abs_lineup[pos] = lineup[pos].unit_info
	return abs_lineup


static func find_combat_target(lineup: Dictionary):
	for pos in lineup:
		return lineup[pos]
	return null



static func get_pos_for_unit(lineup: Dictionary, unit) -> int:
	for pos in lineup:
		if lineup[pos] == unit:
			return pos
	return -1
