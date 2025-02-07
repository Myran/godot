class_name DraftContext extends Context

# Typed member variables
var lineup: Dictionary = {}  # Dictionary[int, Card]
var draft_area: Array[Block] = []  
var solver: Node  # Reference to solver node


func _init(_solver: Node) -> void:
	solver = _solver


# Static method for broadcasting events with type safety
static func broadcast_event(
	responder: StringName, _context: DraftContext, _event: core.CoreEvent
) -> void:
	for pos: int in _context.lineup:
		var u: Card = _context.lineup[pos]
		if "unit_info" in u:
			u.unit_info.call(responder, pos, u, _context, _event)

	var draft_pos: int = 0
	for _u: Block in _context.draft_area:
		if "unit_info" in _u:
			_u.unit_info.call(responder, draft_pos, _u, _context, _event)
		draft_pos = draft_pos + 1


# Override solve_events with proper typing
func solve_events() -> void:
	while unresolved_events.size():
		var event_stack: Array = unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))

		while event_stack.size():
			var next_event: core.CoreEvent = event_stack.pop_front()
			broadcast_event(UnitData.DRAFT_PRE_EVENT_RESPONSE, self, next_event)
			solve_events()
			solver.solve_event(next_event, self)
			broadcast_event(UnitData.DRAFT_POST_EVENT_RESPONSE, self, next_event)
			solve_events()
