class_name DraftHandler extends Node

var current_draft_upgrade_level: int = 0


func _ready() -> void:
	DebugManager.debug_event.connect(_on_debug_event)


func hold_toggle(col: int, new_state: bool) -> void:
	# Enhanced semantic logging handled in clicker.gd on_core_event
	core.action(core.DraftColumnStateEvent.new(col, new_state))


func reroll() -> void:
	# Handle UI locking consistently for all callers
	var game_parent = get_parent() as Game
	if game_parent:
		game_parent.ui_state = core.UIState.LOCKED

	# Enhanced semantic logging handled in clicker.gd on_core_event
	core.action(core.RerollDraftEvent.new())


func upgrade() -> void:
	# Handle UI locking consistently for all callers
	var game_parent = get_parent() as Game
	if game_parent:
		game_parent.ui_state = core.UIState.LOCKED

	current_draft_upgrade_level += 1
	# Enhanced semantic logging handled in clicker.gd on_core_event
	core.action(core.UpgradeEvent.new(current_draft_upgrade_level))


func _on_debug_event(event: DebugManager.DebugEventType, _data: Array) -> void:
	match event:
		DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL, DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL:
			current_draft_upgrade_level = 0
