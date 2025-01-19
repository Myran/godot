class_name BattleContext extends Context

enum BattleState { PRE_BATTLE, BATTLE, POST_BATTLE }

var allies: Side = Side.new()
var enemies: Side = Side.new()
var battle_state: int = BattleState.BATTLE
var allied_turn: bool = true
var current_unit: UnitData = null
var solver


# Base Event class
class BaseEvent:
	extends Context.Event

	func _init() -> void:
		pass


class CombatEvent:
	extends BaseEvent
	var attacker: int
	var defender: int
	var allied_attack: bool

	func _init(attacker_pos: int, defender_pos: int, is_allied_attack: bool) -> void:
		attacker = attacker_pos
		defender = defender_pos
		allied_attack = is_allied_attack


class DeathEvent:
	extends BaseEvent
	var side: bool
	var pos: int

	func _init(allied_side: bool, position: int) -> void:
		side = allied_side
		pos = position


class AddLineupEvent:
	extends BaseEvent
	var allied_side: bool
	var lineup: Dictionary

	func _init(is_allied: bool, lineup_data: Dictionary) -> void:
		allied_side = is_allied
		lineup = lineup_data


class ShieldEvent:
	extends BaseEvent
	var target: int
	var side: bool
	var new_shield_state: bool

	func _init(_target: int, _side: bool, _new_shield_state: bool) -> void:
		target = _target
		side = _side
		new_shield_state = _new_shield_state


class DamageEvent:
	extends BaseEvent
	var effects: Array
	var damage_amount: int
	var target: int
	var side: bool

	func _init(amount: int, target_pos: int, target_side: bool) -> void:
		damage_amount = amount
		target = target_pos
		side = target_side


class StatChangeEvent:
	extends BaseEvent
	var stat: String
	var target: int
	var side: bool
	var value: int
	var new_stat: int

	func _init(
		stat_name: String, target_pos: int, target_side: bool, change_value: int, new_value: int = 0
	) -> void:
		stat = stat_name
		target = target_pos
		side = target_side
		value = change_value
		new_stat = new_value


class SelectActiveUnitEvent:
	extends BaseEvent
	var sel_unit_pos: int
	var allied_side: bool

	func _init(position: int, is_allied: bool) -> void:
		sel_unit_pos = position
		allied_side = is_allied


class FindNextUnitEvent:
	extends BaseEvent

	func _init() -> void:
		pass


class StartOfTurnEvent:
	extends BaseEvent

	func _init() -> void:
		pass


class EndOfTurnEvent:
	extends BaseEvent

	func _init() -> void:
		pass


func _init(_solver) -> void:
	solver = _solver


func solve_events() -> void:
	while unresolved_events.size():
		var event_stack := unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))

		while event_stack.size():
			var next_event = event_stack.pop_front()
			_process_event(next_event)


func _process_event(event) -> void:
	broadcast_event(UnitData.PRE_EVENT_RESPONSE, self, event)
	solve_events()
	solver.solve_event(event, self)
	broadcast_event(UnitData.POST_EVENT_RESPONSE, self, event)
	solve_events()


static func broadcast_event(responder: String, _context: BattleContext, _event: BaseEvent) -> void:
	for _side in [_context.allies, _context.enemies]:
		var is_allied: bool = _side == _context.allies
		for pos in _side.lineup:
			var unit: UnitData = _side.lineup[pos]
			unit.call(responder, pos, is_allied, _context, _event)


func get_side(is_allied: bool) -> Side:
	return allies if is_allied else enemies


func get_active_side() -> Side:
	return get_side(allied_turn)


func get_inactive_side() -> Side:
	return get_side(!allied_turn)


func add_unit_to_side(unit, position: int, is_allied: bool) -> void:
	get_side(is_allied).add_unit(position, unit)


func remove_unit(position: int, is_allied: bool) -> void:
	get_side(is_allied).remove_unit(position)


func mark_unit_activated(unit) -> void:
	get_active_side().activated_units.append(unit)


func is_unit_activated(unit) -> bool:
	return get_active_side().has_unit(unit)


func clear_activated_units() -> void:
	get_active_side().clear_activated()


func switch_turn() -> void:
	allied_turn = !allied_turn


func end_battle() -> void:
	battle_state = BattleState.POST_BATTLE


func is_battle_ongoing() -> bool:
	return battle_state == BattleState.BATTLE


func get_unit_at_position(position: int, is_allied: bool):
	return get_side(is_allied).lineup.get(position)


func is_side_empty(is_allied: bool) -> bool:
	return get_side(is_allied).is_empty()
