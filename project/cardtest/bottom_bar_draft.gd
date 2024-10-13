extends NinePatchRect

func _on_button_upgrade_pressed():
	print("upgrade button pressed")
	ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.UPGRADE,[])


func _on_button_reroll_pressed():
	print("Reroll button pressed")
	ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.REROLL,[])


func _on_button_to_battle_pressed():
	ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.TRANSITION,[core.GAME_STATE.PREPARE])
