class_name AbilityShield extends Ability

var shield_used: bool = false


func condition(_tempus : core.Tempus, u_pos : int , u_side : bool, _context : BattleContext, event : BattleContext.BaseEvent) -> bool:
	
	if not ( _tempus == core.Tempus.PRE and event is BattleContext.DamageEvent): 
		return false	
	
	var valid_target : bool = event.side == u_side and event.target == u_pos
	
	return valid_target and not shield_used

func action(_tempus, _pos,_side, _context, _event,):
	_event.effects.append({"name": "shield", "ability": self})
