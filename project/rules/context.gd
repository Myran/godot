class_name Context extends Resource

# Event tracking arrays
var events: Array = []
var unresolved_events: Array = []
var event_list: Array = []


# Event class for structured event data
class Event:
	pass


func solve_events() -> void:
	pass


func add_event(_event: Event) -> void:
	unresolved_events.append(_event)
	#return self
