class_name BattleContext extends Context

enum BATTLE_STATE { PRE_BATTLE, BATTLE, POST_BATTLE }
#enum EventType {
	#COMBAT,
	#DEATH,
	#ADD_LINEUP,
	#DAMAGE,
	#STAT_CHANGE,
	#SELECT_ACTIVE_UNIT,
	#FIND_NEXT_UNIT,
	#START_OF_TURN,
	#END_OF_TURN
#}

var allies: Side = Side.new()
var enemies: Side = Side.new()
var battle_state: int = BATTLE_STATE.BATTLE
var allied_turn: bool = true
var current_unit = null
var solver


# Base Event class
class BaseEvent:
	extends Context.Event
	#var event_type: EventType

	func _init() -> void:
		pass
	#	event_type = type


# Event classes for each type
class CombatEvent:
	extends BaseEvent
	var attacker: int
	var defender: int
	var allied_attack: bool

	func _init(attacker_pos: int, defender_pos: int, is_allied_attack: bool) -> void:
		#super(EventType.COMBAT)
		attacker = attacker_pos
		defender = defender_pos
		allied_attack = is_allied_attack


class DeathEvent:
	extends BaseEvent
	var side: bool
	var pos: int

	func _init(allied_side: bool, position: int) -> void:
		#super(EventType.DEATH)
		side = allied_side
		pos = position


class AddLineupEvent:
	extends BaseEvent
	var allied_side: bool
	var lineup: Dictionary

	func _init(is_allied: bool, lineup_data: Dictionary) -> void:
		#super(EventType.ADD_LINEUP)
		allied_side = is_allied
		lineup = lineup_data


class DamageEvent:
	extends BaseEvent
	var damage_amount: int
	var target: int
	var side: bool

	func _init(amount: int, target_pos: int, target_side: bool) -> void:
		#super(EventType.DAMAGE)
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
		#super(EventType.STAT_CHANGE)
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
		#super(EventType.SELECT_ACTIVE_UNIT)
		sel_unit_pos = position
		allied_side = is_allied


class FindNextUnitEvent:
	extends BaseEvent

	func _init() -> void:
		#super(EventType.FIND_NEXT_UNIT)
		pass

class StartOfTurnEvent:
	extends BaseEvent

	func _init() -> void:
		#super(EventType.START_OF_TURN)
		pass

class EndOfTurnEvent:
	extends BaseEvent

	func _init() -> void:
		#super(EventType.END_OF_TURN)
		pass

func _init(_solver) -> void:
	solver = _solver


# Event handling - extends base Context functionality
func solve_events() -> void:
	while unresolved_events.size():
		var event_stack := unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))

		while event_stack.size():
			var next_event = event_stack.pop_front()
			_process_event(next_event)


func _process_event(event) -> void:
	broadcast_event("pre_event_response", self, event)
	solve_events()  # Handle any events generated during pre-response
	solver.solve_event(event, self)
	broadcast_event("post_event_response", self, event)
	solve_events()  # Handle any events generated during post-response




# Event broadcasting
static func broadcast_event(responder: String, _context: BattleContext, _event) -> void:
	for _side in [_context.allies, _context.enemies]:
		var is_allied: bool = _side == _context.allies
		for pos in _side.lineup:
			var unit = _side.lineup[pos]
			unit.call(responder, pos, is_allied, _context, _event)


# Side management
func get_side(is_allied: bool) -> Side:
	return allies if is_allied else enemies


func get_active_side() -> Side:
	return get_side(allied_turn)


func get_inactive_side() -> Side:
	return get_side(!allied_turn)


# Unit management
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


# Battle state management
func switch_turn() -> void:
	allied_turn = !allied_turn


func end_battle() -> void:
	battle_state = BATTLE_STATE.POST_BATTLE


func is_battle_ongoing() -> bool:
	return battle_state == BATTLE_STATE.BATTLE


# Utility methods
func get_unit_at_position(position: int, is_allied: bool):
	return get_side(is_allied).lineup.get(position)


func is_side_empty(is_allied: bool) -> bool:
	return get_side(is_allied).is_empty()
