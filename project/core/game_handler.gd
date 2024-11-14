class_name GameHandler extends Node
var current_gamestate


func set_gamestate(new_state):
	print("Set gamestate:", core.GAME_STATE.keys()[new_state])
	match new_state:
		core.GAME_STATE.START:
			owner.call_deferred("start_game")
		core.GAME_STATE.DRAFT:
			owner.call_deferred("mode_draft")
		core.GAME_STATE.PREPARE:
			owner.call_deferred("mode_prepare")
		core.GAME_STATE.PREBATTLE:
			owner.call_deferred("mode_pre_battle")
		core.GAME_STATE.BATTLE:
			owner.call_deferred("mode_battle")
		core.GAME_STATE.POSTBATTLE:
			owner.call_deferred("mode_post_battle")
	current_gamestate = new_state
