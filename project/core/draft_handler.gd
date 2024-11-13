class_name DraftHandler extends Node
var current_draft_upgrade_level = 0


func _ready() -> void:
	debug.debug_event.connect(_on_debug_event)


func hold_toggle(col, new_state):
	if new_state:
#		state = core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED
		core.action(core.DraftColumnLocked.new(col))
	else:
		core.action(core.DraftColumnUnlocked.new(col))


#		state = core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED
#	core.action(state, [col])


func reroll():
	core.action(core.RerollDraftEvent.new())


#	core.action(core.EVENT_TYPE.REROLL_DRAFT, [])


func upgrade():
	current_draft_upgrade_level += 1
	core.action(core.UpgradeEvent.new(current_draft_upgrade_level))


#	core.action(core.EVENT_TYPE.UPGRADE, [current_draft_upgrade_level])


func _on_debug_event(event, _data):
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL, debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			current_draft_upgrade_level = 0
