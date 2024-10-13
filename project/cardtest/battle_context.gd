extends context
class_name battle_context
enum BATTLE_STATE{PRE_BATTLE,BATTLE,POST_BATTLE}

var allies = side.new()
var enemies = side.new()

var battle_state = BATTLE_STATE.BATTLE
var allied_turn = true
var current_unit = null
var solver

func _init(_solver):
	solver = _solver

func solve_events():
	while unresolved_events.size():
		var event_stack = unresolved_events.duplicate(true)
		unresolved_events.clear()
		event_list.append_array(event_stack.duplicate(true))
		while event_stack.size():
			var next_event = event_stack.pop_front()
			broadcast_event("pre_event_response",self,next_event)
			solve_events()
			solver.solve_event(next_event,self)
			broadcast_event("post_event_response",self,next_event)
			solve_events()


static func broadcast_event(responder,_context,event):
	for side in [_context.allies,_context.enemies]:
		for pos in side.lineup:
			var _u = side.lineup[pos]
			var _u_side = true if side == _context.allies else false
			_u.call(responder,pos,_u_side,_context,event)

class side:
	var lineup = {}
	var dead_units = {}
	var activated_units = []
