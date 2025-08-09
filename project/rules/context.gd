class_name Context extends Resource

var events: Array[Event] = []
var unresolved_events: Array[Event] = []
var event_list: Array[Event] = []


class Event:
	extends Resource

	var source: core.EventSource = core.EventSource.SYSTEM_CASCADE

	func get_recording_data() -> Dictionary:
		return {"source": source}


func solve_events() -> void:
	pass


func add_event(event: Event) -> void:
	unresolved_events.append(event)
