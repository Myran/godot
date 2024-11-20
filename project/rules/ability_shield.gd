class_name AbilityShield extends Ability

var shield_used: bool = false


func condition(_tempus, _u_pos, _u_side, _context, _event):
	if _tempus == core.Tempus.PRE:
		if _event is BattleContext.DamageEvent:
			if _event.side == _u_side:
				if _event.target == _u_pos:
					print("DAMAGED", _event)
					if not shield_used:
						_event.effects.append({"name": "shield", "ability": self})
						#shield_used = true
	return false
