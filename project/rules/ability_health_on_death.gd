class_name AbilityHealthOnDeath extends Ability
var health_add = 1

func _init(_health_add = 1):
	health_add = _health_add

func condition(_tempus, _u_pos, _u_side, _context, _event):
	if _tempus == Battle.Tempus.POST:
		# Events are Context.Event objects
		return _event.event_type == Battle.EventType.DEATH
	return false

func actions(_tempus, _u_pos, _u_side, _context, _event):
	# Create event using Event class
	var new_event = Context.Event.new(
		"stat_change",  # solve_type
		Battle.EventType.STAT_CHANGE,  # event_type
		{  # data
			"stat": "current_health",
			"target": _u_pos,
			"side": _u_side,
			"value": health_add
		}
	)
	_context.add_event(new_event)
