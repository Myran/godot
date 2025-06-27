class_name Context extends Resource

# Typed event arrays for better code organization
var events: Array[Event] = []
var unresolved_events: Array[Event] = []
var event_list: Array[Event] = []


# Base Event class for structured event data
class Event:
	extends Resource

	var source: core.EventSource = core.EventSource.SYSTEM_CASCADE

	func get_recording_data() -> Dictionary:
		return {"source": source}


# Virtual method for event processing
func solve_events() -> void:
	pass


# Add event with type checking
func add_event(event: Event) -> void:
	unresolved_events.append(event)
