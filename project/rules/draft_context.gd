extends context
class_name draft_context

var lineup = {}
var draft_area = {}
var solver
func _init(_solver):
	solver = _solver
	
static func broadcast_event(responder,_context,_event):
	for pos in _context.lineup:
		var _u = _context.lineup[pos]
		_u.unit_info.call(responder,{"lineup":pos},_context,_event,_u)
	var draft_pos = 0
	for _u in _context.draft_area:
		if _u.unit_info:
			_u.unit_info.call(responder,{"draft":draft_pos},_context,_event,_u)
		draft_pos = draft_pos + 1
	pass

func solve_events():
	while unresolved_events.size():
		var event_stack = unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))
		while event_stack.size():
			var next_event = event_stack.pop_front()
			broadcast_event("draft_pre_event_response",self,next_event)
			solve_events()
			solver.solve_event(next_event,self)
			broadcast_event("draft_post_event_response",self,next_event)
			solve_events()
