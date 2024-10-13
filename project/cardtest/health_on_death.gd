extends ability
class_name ability_health_on_death

var health_add = 1
func _init(_health_add = 1):
	health_add = _health_add

func condition(_tempus,_u_pos,_u_side,_context,_event):
	if _tempus == battle.TEMPUS.POST:
		return _event.type == battle.EVENT_TYPE.DEATH
	return false

func actions(_tempus,_u_pos,_u_side,_context,_event):
	_context.add_event({"type": battle.EVENT_TYPE.STAT_CHANGE,"stat" : "current_health","target" : _u_pos, "side" : _u_side ,"change" : health_add})
	pass
