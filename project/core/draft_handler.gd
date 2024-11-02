class_name DraftHandler extends Node
var current_draft_upgrade_level = 0


func hold_toggle(col, new_state):
	var state
	if new_state:
		state = core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED
	else:
		state = core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED
	core.action(state, [col])


func reroll():
	core.action(core.EVENT_TYPE.REROLL_DRAFT, [])


func upgrade():
	current_draft_upgrade_level += 1
	core.action(core.EVENT_TYPE.UPGRADE, [current_draft_upgrade_level])
