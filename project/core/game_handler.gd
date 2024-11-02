class_name GameHandler extends Node
var current_battle
var current_gamestate
var game

func _init(_game) -> void:
	game = _game
func set_gamestate(new_state):
	print("Set gamestate:", core.GAME_STATE.keys()[new_state])
	match new_state:
		core.GAME_STATE.START:
			call_deferred("start_game")
		core.GAME_STATE.DRAFT:
			call_deferred("mode_draft")
		core.GAME_STATE.PREPARE:
			call_deferred("mode_prepare")
		core.GAME_STATE.PREBATTLE:
			call_deferred("mode_pre_battle")
		core.GAME_STATE.BATTLE:
			call_deferred("mode_battle")
		core.GAME_STATE.POSTBATTLE:
			call_deferred("mode_post_battle")
	current_gamestate = new_state


func start_game():
	print("Start Game")
	game.ui_state = core.UI_STATE.WAITING
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])


func mode_draft():
	print("Draft mode")
	game.top_bar.visible = true
	game.bottom_bar_draft.visible = true
	game.bottom_bar_prepare.visible = false

	game.holder_enemy.visible = false
	game.holder_draft.visible = true


func mode_prepare():
	print("Preparation mode")
	game.top_bar.visible = true
	game.bottom_bar_draft.visible = false
	game.bottom_bar_prepare.visible = true

	game.holder_enemy.visible = true
	game.holder_draft.visible = false


func mode_pre_battle():
	print("Pre Battle Mode")
	game.ui_state = core.UI_STATE.LOCKED
	game.top_bar.visible = false
	game.bottom_bar_draft.visible = false
	game.bottom_bar_prepare.visible = false
	await get_tree().create_timer(0.5).timeout
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.BATTLE])


func mode_battle():
	print("Battle Mode")
	core.action(core.EVENT_TYPE.BATTLE, [current_battle])


func mode_post_battle():
	print("Post Battle Mode")
	game.ui_state = core.UI_STATE.WAITING
	game.holder_allies.show_lineup()
	game.holder_enemy.show_lineup()
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])
