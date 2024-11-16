extends NinePatchRect


func _on_button_upgrade_pressed():
	print("upgrade button pressed")
	ui.action(ui.UpgradeEvent.new())


func _on_button_reroll_pressed():
	print("Reroll button pressed")
	ui.action(ui.RerollEvent.new())


func _on_button_to_battle_pressed():
	ui.action(ui.TransitionEvent.new(core.GameState.PREPARE))
