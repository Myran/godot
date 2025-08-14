class_name Ability extends Resource

enum PersistenceType { TEMPLATE, ACQUIRED, TEMPORARY, ENHANCEMENT }  # Inherent to card template, never removed  # Gained during combat, converted to ENHANCEMENT post-battle  # Combat-only effects, cleared after battle  # Permanent effects from any source, transferable in merges

var persistence_type: PersistenceType = PersistenceType.TEMPLATE


func handle_battle_event(event: BattleAbilityEvent) -> void:
	pass


func handle_draft_event(event: DraftAbilityEvent) -> void:
	pass


func deep_duplicate() -> Ability:
	var copy: Ability = self.duplicate(true)
	copy.persistence_type = self.persistence_type
	return copy


func debug_trigger_effect(_target_card: Card) -> bool:
	Log.warning(
		"debug_trigger_effect not implemented for ability type",
		{"ability_type": get_class()},
		["debug", "ability"]
	)
	return false
