class_name DraftHandler extends Node

var current_draft_upgrade_level: int = 0


func _ready() -> void:
	DebugManager.debug_event.connect(_on_debug_event)


func hold_toggle(col: int, new_state: bool) -> void:
	core.action(core.DraftColumnStateEvent.new(col, new_state))


func reroll() -> void:
	var game_parent: Game = get_parent() as Game
	if game_parent:
		game_parent.ui_state = core.UIState.LOCKED

	core.action(core.RerollDraftEvent.new())


func upgrade() -> void:
	var game_parent: Game = get_parent() as Game
	if game_parent:
		game_parent.ui_state = core.UIState.LOCKED

	current_draft_upgrade_level += 1
	core.action(core.UpgradeEvent.new(current_draft_upgrade_level))


func _on_debug_event(event: DebugManager.DebugEventType, _data: Array) -> void:
	match event:
		DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL, DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL:
			current_draft_upgrade_level = 0
