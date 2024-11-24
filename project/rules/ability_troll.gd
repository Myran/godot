class_name AbilityTroll extends Ability

var health_add: int
var attack_add: int


func _init(_health_add: int = 1, _attack_add: int = 1) -> void:
	health_add = _health_add
	attack_add = _attack_add


func draft_condition(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
) -> bool:
	if _tempus != core.Tempus.POST:
		return false
	if _event is not core.LineupAddCardEvent:
		return false

	var added_card: Card = _event.card
	if added_card == _u:
		return true
	return false


func draft_action(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
) -> void:
	var evil_count: int = 0
	for i_pos: int in _context.lineup:
		var lineup_card: Card = _context.lineup[i_pos]
		if lineup_card == _u:
			continue
		if lineup_card.card_info.tribe.match("evil"):
			evil_count = evil_count + 1

	_context.add_event(
		core.CardStatChangeEvent.new(_u, health_add * evil_count, attack_add * evil_count)
	)
	#ovanstående kanske inte funkar med "health" kanske ska vara "current_health" ? får se
	#det kanske ska vara healt och inte current eftersom det är i draft och det ska påverka maxhälsan?
