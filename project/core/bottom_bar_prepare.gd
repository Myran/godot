extends NinePatchRect


func _on_button_draft_pressed():
	ui.action(ui.TransitionEvent.new(core.GameState.DRAFT))


func _on_button_battle_pressed():
	ui.action(ui.StartBattleEvent.new())
