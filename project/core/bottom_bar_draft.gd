extends NinePatchRect

func _on_button_upgrade_pressed():
	print("upgrade button pressed")
	ui.action(ui.EVENT_TYPE.UPGRADE,[])


func _on_button_reroll_pressed():
	print("Reroll button pressed")
	ui.action(ui.EVENT_TYPE.REROLL,[])


func _on_button_to_battle_pressed():
	ui.action(ui.EVENT_TYPE.TRANSITION,[core.GAME_STATE.PREPARE])
