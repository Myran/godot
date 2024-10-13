extends Resource
class_name ability


func condition(_tempus,_u_pos,_u_side,_battle_context,_event):
	return false
func actions(_tempus,_u_pos,_u_side,_battle_context,_event):
	pass

func draft_condition(_tempus,_pos,_context,_event,_u):
	return false
func draft_action(_tempus,_pos,_context,_event,_u):
	pass
