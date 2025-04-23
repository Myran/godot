class_name AbilityDamage extends Ability

var damage_type: String

func _init(type: String) -> void:
	damage_type = type

func handle_battle_event(
	_phase: core.Tempus, 
	_unit_pos: int, 
	_is_allied: bool, 
	_battle_context: BattleContext, 
	_event: Context.Event
) -> void:
	pass

func handle_draft_event(
	_phase: core.Tempus, 
	_unit_pos: int, 
	_unit: Block,
	_draft_context: DraftContext, 
	_event: core.CoreEvent
) -> void:
	print("Draft action processing")