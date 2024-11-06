class_name BattleContext extends Context

enum BATTLE_STATE { PRE_BATTLE, BATTLE, POST_BATTLE }

# Side class for managing unit lineups
#class Side:
#var lineup: Dictionary = {}
#var dead_units: Dictionary = {}
#var activated_units: Array = []
#
#func is_empty() -> bool:
#return lineup.is_empty()
#
#func clear_activated() -> void:
#activated_units.clear()
#
#func has_unit(unit) -> bool:
#return unit in activated_units
#
#func add_unit(position: int, unit) -> void:
#lineup[position] = unit
#
#func remove_unit(position: int) -> void:
#if lineup.has(position):
#dead_units[position] = lineup[position]
#lineup.erase(position)

# Battle state variables
var allies: Side = Side.new()
var enemies: Side = Side.new()
var battle_state: int = BATTLE_STATE.BATTLE
var allied_turn: bool = true
var current_unit = null
var solver


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


# Event creation helpers
func create_combat_event(attacker_pos: int, defender_pos: int, is_allied_attack: bool) -> Event:
	return Event.new(
		"combat",
		Battle.EventType.COMBAT,
		{"attacker": attacker_pos, "defender": defender_pos, "allied_attack": is_allied_attack}
	)


func create_damage_event(amount: int, target_pos: int, is_allied_target: bool) -> Event:
	return Event.new(
		"damage",
		Battle.EventType.DAMAGE,
		{"damage_amount": amount, "target": target_pos, "side": is_allied_target}
	)


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
