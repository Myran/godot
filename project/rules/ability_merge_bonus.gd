class_name AbilityMergeBonus extends Ability
var health_add
var attack_add


func _init(_health_add = 1, _attack_add = 1):
	health_add = _health_add
	attack_add = _attack_add


func draft_condition(_tempus, _pos, _u, _draft_context, event):
	if _tempus != core.Tempus.POST:
		return false
	if event is not core.DraftMergeEvent:
		return false
	if not _u.block_context == Cards.CONTEXT.LINEUP:
		return false
	return true


func draft_action(_tempus, _pos, _u, _context, _event):
	_context.add_event(core.CardStatChangeEvent.new(_u, health_add, attack_add))
