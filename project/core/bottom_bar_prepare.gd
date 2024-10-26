extends NinePatchRect


func _on_button_draft_pressed():
	ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.TRANSITION,[core.GAME_STATE.DRAFT])



func _on_button_battle_pressed():
	ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.START_BATTLE,[])
