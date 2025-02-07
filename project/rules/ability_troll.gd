class_name AbilityTroll extends Ability

var health_add: int
var attack_add: int


func _init(_health_add: int = 1, _attack_add: int = 1) -> void:
	health_add = _health_add
	attack_add = _attack_add


func draft_action(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_draft_context: DraftContext,
	_event: core.CoreEvent,
) -> void:
	if _tempus != core.Tempus.POST:
		return
	if _event is not core.LineupAddCardEvent:
		return

	var added_card: Card = _event.card
	if added_card != _u:
		return

	var evil_count: int = 0
	for i_pos: int in _draft_context.lineup:
		var lineup_card: Card = _draft_context.lineup[i_pos]
		if lineup_card == _u:
			continue
		if lineup_card.card_info.tribe.match("evil"):
			evil_count = evil_count + 1
	var m_card: Card = _u
	_draft_context.add_event(
		core.CardStatChangeEvent.new(m_card, health_add * evil_count, attack_add * evil_count)
	)
	#ovanstående kanske inte funkar med "health" kanske ska vara "current_health" ? får se
	#det kanske ska vara healt och inte current eftersom det är i draft och det ska påverka maxhälsan?
