class_name BattleContext extends Context

enum BattleState { PRE_BATTLE, BATTLE, POST_BATTLE }

# Typed member variables
var allied_side: Side = Side.new()
var enemy_side: Side = Side.new()
var battle_state: BattleState = BattleState.BATTLE
var is_allied_turn: bool = true
var active_unit: UnitData = null
var battle_solver: Node


# Base Event class for battle events
class BaseEvent:
	extends Context.Event

	func _init() -> void:
		pass


# Typed event classes
class CombatEvent:
	extends BaseEvent
	var attacker_position: int
	var defender_position: int
	var is_allied_attack: bool

	func _init(a_pos: int, d_pos: int, is_allied_a: bool) -> void:
		self.attacker_position = a_pos
		self.defender_position = d_pos
		self.is_allied_attack = is_allied_a


class DeathEvent:
	extends BaseEvent
	var is_allied_side: bool
	var unit_position: int

	func _init(allied_side: bool, position: int) -> void:
		self.is_allied_side = allied_side
		self.unit_position = position


class AddLineupEvent:
	extends BaseEvent
	var is_allied_side: bool
	var lineup_data: Dictionary  # Dictionary[int, UnitData]

	func _init(is_a: bool, lineup_d: Dictionary) -> void:
		self.is_allied_side = is_a
		self.lineup_data = lineup_d


class ShieldEvent:
	extends BaseEvent
	var target_position: int
	var is_allied_side: bool
	var shield_active: bool

	func _init(_target: int, _side: bool, _new_shield_state: bool) -> void:
		self.target_position = _target
		self.is_allied_side = _side
		self.shield_active = _new_shield_state


class DamageEvent:
	extends BaseEvent
	var damage_effects: Array[Dictionary] = []
	var damage_amount: int
	var target_position: int
	var is_allied_side: bool

	func _init(amount: int, target_pos: int, target_side: bool) -> void:
		self.damage_amount = amount
		self.target_position = target_pos
		self.is_allied_side = target_side


class StatChangeEvent:
	extends BaseEvent
	var stat_name: StringName
	var target_position: int
	var is_allied_side: bool
	var change_value: int
	var new_stat_value: int

	func _init(
		stat_n: StringName, target_pos: int, target_side: bool, change_v: int, new_value: int = 0
	) -> void:
		self.stat_name = stat_n
		self.target_position = target_pos
		self.is_allied_side = target_side
		self.change_value = change_v
		self.new_stat_value = new_value


class SelectActiveUnitEvent:
	extends BaseEvent
	var selected_unit_position: int
	var is_allied_side: bool

	func _init(position: int, is_allied: bool) -> void:
		self.selected_unit_position = position
		self.is_allied_side = is_allied


class FindNextUnitEvent:
	extends BaseEvent


class StartOfTurnEvent:
	extends BaseEvent


class EndOfTurnEvent:
	extends BaseEvent


func _init(_solver: Node) -> void:
	battle_solver = _solver


# Override solve_events with battle-specific logic
func solve_events() -> void:
	while unresolved_events.size():
		var event_stack: Array = unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))

		while event_stack.size():
			var next_event: BaseEvent = event_stack.pop_front()
			_process_event(next_event)


func _process_event(event: BaseEvent) -> void:
	broadcast_event(UnitData.PRE_EVENT_RESPONSE, self, event)
	solve_events()
	battle_solver.solve_event(event, self)
	broadcast_event(UnitData.POST_EVENT_RESPONSE, self, event)
	solve_events()


static func broadcast_event(
	responder: StringName, _context: BattleContext, _event: BaseEvent
) -> void:
	for _side: Side in [_context.allied_side, _context.enemy_side]:
		var is_allied: bool = _side == _context.allied_side
		for pos: int in _side.lineup:
			var unit: UnitData = _side.lineup[pos]
			unit.call(responder, pos, is_allied, _context, _event)


# Battle state management methods
func get_side(is_allied: bool) -> Side:
	return allied_side if is_allied else enemy_side


func get_active_side() -> Side:
	return get_side(is_allied_turn)


func get_inactive_side() -> Side:
	return get_side(!is_allied_turn)


func add_unit_to_side(unit: UnitData, position: int, is_allied: bool) -> void:
	get_side(is_allied).add_unit(position, unit)


func remove_unit(position: int, is_allied: bool) -> void:
	get_side(is_allied).remove_unit(position)


func mark_unit_activated(unit: UnitData) -> void:
	get_active_side().activated_units.append(unit)


func is_unit_activated(unit: UnitData) -> bool:
	return get_active_side().has_unit(unit)


func clear_activated_units() -> void:
	get_active_side().clear_activated()


func switch_turn() -> void:
	is_allied_turn = !is_allied_turn


func end_battle() -> void:
	battle_state = BattleState.POST_BATTLE


func is_battle_ongoing() -> bool:
	return battle_state == BattleState.BATTLE


func get_unit_at_position(position: int, is_allied: bool) -> UnitData:
	return get_side(is_allied).lineup.get(position)


func is_side_empty(is_allied: bool) -> bool:
	return get_side(is_allied).is_empty()
