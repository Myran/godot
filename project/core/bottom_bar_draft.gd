extends NinePatchRect


func _on_button_upgrade_pressed() -> void:
	Log.debug("Upgrade button pressed", {}, ["ui", "draft"])
	ui.action(ui.UpgradeEvent.new())


func _on_button_reroll_pressed() -> void:
	Log.debug("Reroll button pressed", {}, ["ui", "draft"])
	ui.action(ui.RerollEvent.new())


func _on_button_to_battle_pressed() -> void:
	ui.action(ui.TransitionEvent.new(core.GameState.PREPARE))
