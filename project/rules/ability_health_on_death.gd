class_name AbilityHealthOnDeath extends Ability
var health_add = 1


func _init(_health_add = 1):
	health_add = _health_add


func condition(_tempus, _u_pos, _u_side, _context, _event):
	if _tempus == core.Tempus.POST:
		return _event is BattleContext.DeathEvent
	return false


func action(_tempus, _u_pos, _u_side, _context, _event):
	var new_event = BattleContext.StatChangeEvent.new("current_health", _u_pos, _u_side, health_add)
	_context.add_event(new_event)
