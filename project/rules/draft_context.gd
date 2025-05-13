class_name DraftContext extends Context

var lineup: Dictionary = {}  # Dictionary[int, Card]
var draft_area: Array[Block] = []
var draft_solver: Node


func _init(solver: Node) -> void:
	draft_solver = solver


static func broadcast_event(
	responder: StringName, draft_context: DraftContext, draft_event: core.CoreEvent
) -> void:
	for position: int in draft_context.lineup:
		var unit: Card = draft_context.lineup[position]
		if "unit_info" in unit:
			unit.unit_info.call(responder, position, unit, draft_context, draft_event)

	var draft_position: int = 0
	for unit: Block in draft_context.draft_area:
		if "unit_info" in unit:
			unit.unit_info.call(responder, draft_position, unit, draft_context, draft_event)
		draft_position += 1


func solve_events() -> void:
	while unresolved_events.size():
		var event_stack: Array = unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))

		while event_stack.size():
			var next_event: core.CoreEvent = event_stack.pop_front()
			broadcast_event(UnitData.DRAFT_PRE_EVENT_RESPONSE, self, next_event)
			solve_events()
			draft_solver.solve_event(next_event, self)
			broadcast_event(UnitData.DRAFT_POST_EVENT_RESPONSE, self, next_event)
			solve_events()
