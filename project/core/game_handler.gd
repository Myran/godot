class_name GameHandler extends Node

var current_gamestate: core.GameState = core.GameState.START


func set_gamestate(new_state: core.GameState) -> void:
	Log.info(
		"Game state changing",
		{"from": core.GameState.keys()[current_gamestate], "to": core.GameState.keys()[new_state]},
		["game_state", "state_transition"]
	)

	match new_state:
		core.GameState.START:
			owner.start_game()
		core.GameState.DRAFT:
			owner.mode_draft()
		core.GameState.PREPARE:
			owner.mode_prepare()
		core.GameState.PREBATTLE:
			owner.mode_pre_battle()
		core.GameState.BATTLE:
			owner.mode_battle()
		core.GameState.POSTBATTLE:
			owner.mode_post_battle()

	# current_gamestate update moved to individual mode functions for atomic state transitions
