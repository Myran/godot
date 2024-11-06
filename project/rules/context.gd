class_name Context extends Resource

# Event tracking arrays
var events: Array = []
var unresolved_events: Array = []
var event_list: Array = []


# Event class for structured event data
class Event:
	var event_type
	var solve_type
	var data

	func _init(_solve_type, _event_type, _data) -> void:
		event_type = _event_type
		solve_type = _solve_type
		data = _data


func add_event(_event : ) -> Context:
	unresolved_events.append(_event)
	return self
