class_name AbilityMergeBonus extends Ability
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
	if _event is not core.DraftMergeEvent:
		return
	if not _u.block_context == Cards.CONTEXT.LINEUP:
		return
	var m_card : Card = _u
	_draft_context.add_event(core.CardStatChangeEvent.new(m_card, health_add, attack_add))
