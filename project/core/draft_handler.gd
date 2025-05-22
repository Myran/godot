class_name DraftHandler extends Node

var current_draft_upgrade_level: int = 0


func _ready() -> void:
	DebugManager.debug_event.connect(_on_debug_event)


func hold_toggle(col: int, new_state: bool) -> void:
	if new_state:
		core.action(core.DraftColumnLocked.new(col))
	else:
		core.action(core.DraftColumnUnlocked.new(col))


func reroll() -> void:
	core.action(core.RerollDraftEvent.new())


func upgrade() -> void:
	current_draft_upgrade_level += 1
	core.action(core.UpgradeEvent.new(current_draft_upgrade_level))


func _on_debug_event(event: DebugManager.DebugEventType, _data: Array) -> void:
	match event:
		DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL, DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL:
			current_draft_upgrade_level = 0
