class_name AbilityMergeBonus extends Ability
var health_add
var attack_add


func _init(_health_add = 1, _attack_add = 1):
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
	_draft_context.add_event(core.CardStatChangeEvent.new(_u, health_add, attack_add))
