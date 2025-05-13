class_name EvilSynergyAbility extends Ability

var health_per_evil: int
var attack_per_evil: int


func _init(health_bonus: int = 1, attack_bonus: int = 1) -> void:
	health_per_evil = health_bonus
	attack_per_evil = attack_bonus


func handle_battle_event(
	_phase: core.Tempus,
	_unit_position: int,
	_is_allied_unit: bool,
	_battle_context: BattleContext,
	_battle_event: Context.Event
) -> void:
	pass


func handle_draft_event(
	phase: core.Tempus,
	_unit_position: int,
	unit: Block,
	draft_context: DraftContext,
	draft_event: core.CoreEvent
) -> void:
	if phase != core.Tempus.POST:
		return

	if not draft_event is core.LineupAddCardEvent:
		return

	var add_event: core.LineupAddCardEvent = draft_event as core.LineupAddCardEvent
	var added_card: Card = add_event.card
	if added_card != unit:
		return

	var evil_unit_count: int = count_evil_units_in_lineup(draft_context.lineup, unit)
	if evil_unit_count > 0:
		var total_health_bonus: int = health_per_evil * evil_unit_count
		var total_attack_bonus: int = attack_per_evil * evil_unit_count
		var modified_card: Card = unit
		var stat_change_event: core.CardStatChangeEvent = core.CardStatChangeEvent.new(
			modified_card, total_health_bonus, total_attack_bonus
		)
		draft_context.add_event(stat_change_event)


func count_evil_units_in_lineup(lineup: Dictionary[int, Card], current_unit: Block) -> int:
	var evil_count: int = 0
	for unit_position: int in lineup:
		var card: Card = lineup[unit_position]
		if card == current_unit:
			continue
		if card.card_info.tribe.match("evil"):
			evil_count += 1
	return evil_count
