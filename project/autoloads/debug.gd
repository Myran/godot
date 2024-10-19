extends Node

signal debug_event

const SIGNAL_DEBUG = "debug_event"
enum DEBUG_EVENT_TYPE {EVENT_OPEN_DEBUG_MENU,EVENT_OPEN_GAME_SELECTOR,EVENT_RESET_MATCH_LEVEL,EVENT_FORCE_LOAD_MATCH_LEVEL}

#export (bool) var force_level = false setget set_force_level,get_force_level
#export (String,FILE,"*.tscn") var forced_level = "res://zen/levels/"
#export (PackedScene) var test_scene = null
#export (bool) var force_test_scene = false
@export var use_local_battle_db : bool
#export (bool) var toggle_orientation = false
#export (bool) var force_game_selector_at_start = false
@export var asset_variant : int



@export var popup_debug : Control
@export var v_box_container_buttons : VBoxContainer
#onready var v_box_container_buttons = $"%v_box_container_buttons"
#onready var popup_debug_game = $"%popup_debug_game"
#onready var v_box_container_buttons_game = $"%v_box_container_buttons_game"
#var _main = null

func _on_debug_event(event,_data = null):
	match event:
		DEBUG_EVENT_TYPE.EVENT_OPEN_DEBUG_MENU:
			popup_debug.show()
		#DEBUG_EVENT_TYPE.EVENT_OPEN_GAME_SELECTOR:
			#popup_debug_game.popup_centered()
	pass

#func set_force_level(_force):
	#force_level = _force
#
#func get_test_scene():
	#return test_scene
#
#func get_force_level():
	#return force_level if OS.is_debug_build() else false
#
func _ready():
	print("debug ready")
	popup_debug.hide()
	connect(SIGNAL_DEBUG,Callable(self,"_on_debug_event"))
	for btn in v_box_container_buttons.get_children():
		btn.connect("pressed",Callable(self,"debug_button_pressed").bind(btn.name))
	#for btn in v_box_container_buttons_game.get_children():
		#btn.connect("pressed",self,"debug_game_selector_button_pressed",[btn.name])
#
#func debug_game_selector_button_pressed(name):
	#popup_debug_game.hide()
	#match name:
		#"button_close":
			#popup_debug_game.hide()
		#"button_game_1":
			#_main.restart_game(main.MODE.ZEN)
		#"button_game_2":
			#_main.restart_game(main.MODE.DEFAULT)
		#"button_game_3":
			#_main.restart_game(main.MODE.MATCH)
		#"button_game_4":
			#_main.restart_game(main.MODE.EMPIRE)
		#_:
			#print("button selected: ",name)
#
func debug_button_pressed(name):
	match name:
		"button_close":
			popup_debug.hide()
		"button_pop_enemy":
			print("pop enemy")
			for n in 3:
				var new_card = await card_controller.create_unit_from_id(n,1)
				new_card.context = cards.CONTEXT.LINEUP
				core.emit_signal("event",core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD,[new_card,n])
			for n in 3:
				var new_card = await card_controller.create_unit_from_id(n,1)
				new_card.context = cards.CONTEXT.LINEUP
				core.emit_signal("event",core.EVENT_TYPE.LINEUP_ADD_CARD,[new_card,n])
		"select_game":
			print("select game")
			popup_debug.hide()
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_OPEN_GAME_SELECTOR,null)
		"reset_current_match_level":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL,null)
		"match_level_1":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL,["level_01"])
		"match_level_2":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL,["level_02"])
		"match_level_3":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL,["level_03"])
		"match_level_4":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL,["level_04"])
		"match_level_5":
			debug.emit_signal(debug.SIGNAL_DEBUG,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL,["level_05"])
			pass
		_:
				print("unnused button pressed: ",name)
#
#func _process(_delta):
	#if toggle_orientation:
		#toggle_orientation = false
		#OS.set_window_size(Vector2(OS.get_window_size().y,OS.get_window_size().x))
