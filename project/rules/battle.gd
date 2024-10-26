extends Node
class_name battle
const TYPE = "type"
enum EVENT_TYPE{COMBAT,DEATH,ADD_LINEUP,DAMAGE,STAT_CHANGE,SELECT_ACTIVE_UNIT,FIND_NEXT_UNIT,START_OF_TURN,END_OF_TURN}
enum BATTLE_ACTION{ATTACK_REGULAR}
enum TEMPUS{PRE,POST}
var current_context

static func duplicate_resource(res):
	var new_string = var_to_str(res)
	return str_to_var(new_string)

static func prepare_lineup_from_holder(lineup):
	print("prepare",lineup)
	var abst = abstract_lineup(lineup)
	return abst

func battle_start(allies_lineup,enemies_lineup):
	var allies = allies_lineup
	var enemy = enemies_lineup
	return  battle_solver(allies,enemy)


func battle_solver(allied_lineup, enemies_lineup):
	current_context = battle_context.new(self)
	var dup_allies = duplicate_resource(allied_lineup)
	var dup_enemies = duplicate_resource(enemies_lineup)

	var event_allies = {TYPE: EVENT_TYPE.ADD_LINEUP, "allied_side" : true, "lineup" : dup_allies}
	var event_enemies = { TYPE: EVENT_TYPE.ADD_LINEUP, "allied_side" : false, "lineup" : dup_enemies}

	current_context.add_event(event_allies)
	current_context.add_event(event_enemies)

	current_context.solve_events()
	while current_context.battle_state == battle_context.BATTLE_STATE.BATTLE:
		current_context = solve_win_conditions(current_context)
		if current_context.battle_state == battle_context.BATTLE_STATE.BATTLE:
			current_context = start_of_turn(current_context)
			current_context = find_next_unit(current_context)
			current_context.solve_events()
			current_context = activate_current_unit(current_context)
			current_context.solve_events()
			current_context = solve_death_test(current_context)
			current_context.solve_events()
			current_context = switch_side(current_context)
			current_context = end_of_turn_(current_context)
	return current_context.event_list





static func start_of_turn(_context):
	_context.add_event({TYPE: EVENT_TYPE.START_OF_TURN})
	return _context

static func end_of_turn_(_context):
	_context.add_event({TYPE: EVENT_TYPE.END_OF_TURN})
	return _context

static func find_next_unit(_context):
	_context.add_event({TYPE: EVENT_TYPE.FIND_NEXT_UNIT})
	return _context

static func activate_current_unit(_context):
	var event
	var sel_action = _context.current_unit.select_action(_context)
	match sel_action.action:
		BATTLE_ACTION.ATTACK_REGULAR:
			event = create_event_attack_regular(_context.current_unit,_context)
		_:
			push_warning("No action selected!")
	_context.add_event(event)
	return _context



static func switch_side(_context):
	_context.allied_turn = !_context.allied_turn
	return _context

static func solve_win_conditions(_context):
	if (_context.allies.lineup.is_empty() and _context.enemies.lineup.is_empty()):
		print("Battle Draw!")
	elif _context.allies.lineup.is_empty():
		print("Allied lost!")
	elif _context.enemies.lineup.is_empty():
		print("Enemy lost")
	else:
		print("Win conditions not met, continue battle")
		return _context
	_context.battle_state = battle_context.BATTLE_STATE.POST_BATTLE
	return _context

static func solve_event(event,_context):
	var ret_context = _context
	match event.type:
		EVENT_TYPE.FIND_NEXT_UNIT:
			var active_side = _context.allies if _context.allied_turn else _context.enemies
			var sel_unit_pos = find_next_unactive_on_side(active_side)
			if sel_unit_pos == null:
				print("All units activated, clearing list!")
				active_side.activated_units.clear()
			sel_unit_pos = find_next_unactive_on_side(active_side)
			_context.add_event( {TYPE: EVENT_TYPE.SELECT_ACTIVE_UNIT, "sel_unit_pos" : sel_unit_pos, "allied_side" : _context.allied_turn })
		EVENT_TYPE.ADD_LINEUP:
			var side = _context.allies if event.allied_side else _context.enemies
			side.lineup = event.lineup
			print("Lineup added",side.lineup)
		EVENT_TYPE.SELECT_ACTIVE_UNIT:
			printt("Activated unit: ", event)
			var active_side = _context.allies if event.allied_side else _context.enemies
			var sel_unit = active_side.lineup[event.sel_unit_pos]
			active_side.activated_units.append(sel_unit)
			_context.current_unit = sel_unit
		EVENT_TYPE.COMBAT:
			var attacking_side = _context.allies if event.allied_attack else _context.enemies
			var defending_side = _context.enemies if event.allied_attack else _context.allies
			var attacking_unit = attacking_side.lineup[event.attacker]
			var defending_unit = defending_side.lineup[event.defender]
			print("Combat event",event)
			_context.add_event({TYPE: EVENT_TYPE.DAMAGE, "damage_amount" : attacking_unit.current_attack, "target" : event.defender, "side" : !event.allied_attack})
			_context.add_event({TYPE: EVENT_TYPE.DAMAGE, "damage_amount" : defending_unit.current_attack, "target" : event.attacker, "side" : event.allied_attack})
		EVENT_TYPE.DAMAGE:
			print("Damage event",event)
			var unit_side = _context.allies if event.side else _context.enemies
			var u = unit_side.lineup[event.target]
			var new_health = u.current_health - event.damage_amount
			var health_change = -event.damage_amount
			_context.add_event({TYPE: EVENT_TYPE.STAT_CHANGE,"stat" : "current_health","target" : event.target, "side" : event.side ,"change" : health_change})
			#u.current_health = new_health
		EVENT_TYPE.STAT_CHANGE:
			print("Stat_change",event)
			if !event.has("change"):
				return ret_context
			var unit_side = _context.allies if event.side else _context.enemies
			if !unit_side.lineup.has(event.target):
				print("target N/A , dead?",event)
				return ret_context
			var u = unit_side.lineup[event.target]
			var current_stat = u.get(event.stat)
			if current_stat == null:
				push_warning(str("Stats change error",event))
			var new_stat = current_stat+event.change
			u.set(event.stat,new_stat)
			_context.add_event({TYPE: EVENT_TYPE.STAT_CHANGE,"stat" : "current_health","new_stat" : new_stat,"target" : event.target, "side" : event.side})
		EVENT_TYPE.DEATH:
			var unit_side = _context.allies if event.side else _context.enemies
			var u = unit_side.lineup[event.pos]
			unit_side.dead_units[event.pos] = u
			unit_side.lineup.erase(event.pos)
			print("death event",event)
		EVENT_TYPE.START_OF_TURN:
			print("start of turn")
		EVENT_TYPE.END_OF_TURN:
			print("end of turn")
		_:
			#push_warning(str("unknown event!",event))
			pass
	return ret_context



static func create_event_attack_regular(attacker_unit,_context):
	var target_lineup = _context.enemies.lineup if _context.allied_turn else _context.allies.lineup
	var attacker_lineup = _context.allies.lineup if _context.allied_turn else _context.enemies.lineup
	var opposing_unit = find_combat_target(target_lineup)
	var event = {TYPE :EVENT_TYPE.COMBAT}
	event.attacker = get_pos_for_unit(attacker_lineup,attacker_unit)
	event.defender = get_pos_for_unit(target_lineup,opposing_unit)
	event.allied_attack = _context.allied_turn
	return event

static func solve_death_test(_context):
	for side in [_context.allies,_context.enemies]:
		for pos in side.lineup:
			var _u = side.lineup[pos]
			if _u.current_health <= 0:
				var event = {}
				event.type = EVENT_TYPE.DEATH
				event.side = true if side == _context.allies else false
				event.pos = pos
				_context.add_event(event)
	return _context


static func find_combat_target(lineup):
	for pos in lineup:
		return lineup[pos]
	return null

static func find_next_unactive_on_side(side):
	for pos in side.lineup:
		var _unit = side.lineup[pos]
		if !side.activated_units.has(_unit):
			return pos
	return null

static func abstract_lineup(lineup):
	var abs_lineup ={}
	for pos in lineup.keys():
		abs_lineup[pos] = lineup[pos].unit_info
	return abs_lineup

static func get_pos_for_unit(lineup,u):
	for pos in lineup:
		if lineup[pos] == u:
			return pos
	return null

static func active_side(_context):
	return _context.allies if _context.allied_turn else _context.enemies


static func inactive_side(_context):
	return _context.enemies if _context.allied_turn else _context.allies
