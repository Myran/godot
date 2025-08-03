class_name Ability extends Resource

enum PersistenceType { TEMPLATE, ACQUIRED, TEMPORARY, ENHANCEMENT }  # Inherent to card template, never removed  # Gained during combat, converted to ENHANCEMENT post-battle  # Combat-only effects, cleared after battle  # Permanent effects from any source, transferable in merges

var persistence_type: PersistenceType = PersistenceType.TEMPLATE


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


## Create a deep copy of this ability with proper state isolation
## Override in subclasses that have mutable state requiring deep copying
func deep_duplicate() -> Ability:
	# Base implementation uses Godot's duplicate with deep copy
	var copy: Ability = self.duplicate(true)
	copy.persistence_type = self.persistence_type
	return copy


## Debug method to trigger this ability's effect for testing purposes
## @param target_card: The card that should receive the ability's effect
func debug_trigger_effect(_target_card: Card) -> bool:
	Log.warning(
		"debug_trigger_effect not implemented for ability type",
		{"ability_type": get_class()},
		["debug", "ability"]
	)
	return false
