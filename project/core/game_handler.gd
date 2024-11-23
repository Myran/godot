class_name GameHandler extends Node
var current_gamestate: core.GameState


func set_gamestate(new_state: core.GameState)-> void:
	print("Set gamestate:", core.GameState.keys()[new_state])
	match new_state:
		core.GameState.START:
			owner.call_deferred("start_game")
		core.GameState.DRAFT:
			owner.call_deferred("mode_draft")
		core.GameState.PREPARE:
			owner.call_deferred("mode_prepare")
		core.GameState.PREBATTLE:
			owner.call_deferred("mode_pre_battle")
		core.GameState.BATTLE:
			owner.call_deferred("mode_battle")
		core.GameState.POSTBATTLE:
			owner.call_deferred("mode_post_battle")
	current_gamestate = new_state
