extends ability
class_name ability_damage


var damagetype
func _init(_damagetype):
	damagetype = _damagetype
	
func condition(_tempus,_u_pos,_u_side,_battle_context,_event):
	return false
func actions(_tempus,_u_pos,_u_side,_battle_context,_event):
	pass

func draft_condition(tempus,pos,draft_context,event,_u):
	if event.solve_type == draft.SOLVE_TYPE.CORE:
		if event.event_type == core.EVENT_TYPE.LINEUP_ADD_CARD:
			print("add card event")
			return true
	return false
func draft_action(tempus,pos,draft_context,event,_u):
	print("draft action happening")
	pass
