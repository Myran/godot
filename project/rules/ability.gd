class_name Ability extends Resource

# Base class marks all parameters as unused since they're meant for subclasses
func handle_battle_event(
	_phase: core.Tempus,
	_unit_position: int,
	_is_allied_unit: bool,
	_battle_context: BattleContext,
	_battle_event: Context.Event
) -> void:
	pass

func handle_draft_event(
	_phase: core.Tempus,
	_unit_position: int,
	_unit: Block,
	_draft_context: DraftContext,
	_draft_event: core.CoreEvent
) -> void:
	pass
