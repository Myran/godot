class_name Ability extends Resource

enum PersistenceType { PERMANENT, ACQUIRED, TEMPORARY }  # Inherent to card template, never removed  # Gained during gameplay, persist after battle  # Combat-only effects, cleared after battle

var persistence_type: PersistenceType = PersistenceType.PERMANENT


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


## Debug method to trigger this ability's effect for testing purposes
## @param target_card: The card that should receive the ability's effect
func debug_trigger_effect(_target_card: Card) -> bool:
	Log.warning(
		"debug_trigger_effect not implemented for ability type",
		{"ability_type": get_class()},
		["debug", "ability"]
	)
	return false
