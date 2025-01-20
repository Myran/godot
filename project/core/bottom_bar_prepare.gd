extends NinePatchRect


func _on_button_draft_pressed() -> void:
	ui.action(ui.TransitionEvent.new(core.GameState.DRAFT))


func _on_button_battle_pressed() -> void:
	ui.action(ui.StartBattleEvent.new())
