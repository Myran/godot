class_name AbilityTroll extends Ability

var health_add
var attack_add


func _init(_health_add = 1, _attack_add = 1):
	health_add = _health_add
	attack_add = _attack_add


func condition(_tempus, _u_pos, _u_side, _battle_context, _event):
	return false


func actions(_tempus, _u_pos, _u_side, _battle_context, _event):
	pass


func draft_condition(_tempus, _pos, _draft_context, event, _u):
	if _tempus != core.Tempus.POST:
		return false
#	if event.solve_type != core.SOLVE_TYPE.CORE:
#		return false
	if event is not core.LineupAddCardEvent:
		return false
#	if event.event_type != core.EVENT_TYPE.LINEUP_ADD_CARD:
#		return false

	var added_card = event.card
	if added_card == _u:
		return true
	return false


func draft_action(_tempus, _pos, _context, _event, _u):
	var evil_count = 0
	for i_pos in _context.lineup:
		var lineup_card = _context.lineup[i_pos]
		if lineup_card == _u:
			continue
		if lineup_card.card_info.tribe.match("evil"):
			evil_count = evil_count + 1
	#_context.add_event(DraftContext.Event.new(core.SOLVE_TYPE.CORE,core.EVENT_TYPE.CARD_STAT_CHANGE,{"card" : _u, "health" : health_add * evil_count,"attack" : attack_add * evil_count}))
	_context.add_event(
		core.CardStatChangeEvent.new(_u, health_add * evil_count, attack_add * evil_count)
	)
	#ovanstående kanske inte funkar med "health" kanske ska vara "current_health" ? får se
	#det kanske ska vara healt och inte current eftersom det är i draft och det ska påverka maxhälsan?
