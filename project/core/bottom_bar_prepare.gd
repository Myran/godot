extends NinePatchRect


func _on_button_draft_pressed():
#	ui.action(ui.EVENT_TYPE.TRANSITION,[core.GAME_STATE.DRAFT])
	ui.action(ui.TransitionEvent.new(core.GAME_STATE.DRAFT))


func _on_button_battle_pressed():
#	ui.action(ui.EVENT_TYPE.START_BATTLE,[])
	ui.action(ui.StartBattleEvent.new())
