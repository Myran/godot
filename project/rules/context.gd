class_name Context extends Resource

var events = []
var unresolved_events = []
var event_list = []

func add_event(_event):
	unresolved_events.append(_event)
	return self

class Event:
	var event_type
	var solve_type
	var data
	func _init(_solve_type,_event_type,_data):
		event_type = _event_type
		solve_type = _solve_type
		data = _data
