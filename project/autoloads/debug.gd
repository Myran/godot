extends Node

signal debug_event

enum DebugEventType {
	EVENT_OPEN_DEBUG_MENU,
	EVENT_OPEN_GAME_SELECTOR,
	EVENT_RESET_MATCH_LEVEL,
	EVENT_FORCE_LOAD_MATCH_LEVEL,
	EVENT_OPEN_DB_DEBUG_MENU,
	EVENT_CLOSE_DB_DEBUG_MENU
}

#export (bool) var force_level = false setget set_force_level,get_force_level
#export (String,FILE,"*.tscn") var forced_level = "res://zen/levels/"
#export (PackedScene) var test_scene = null
#export (bool) var force_test_scene = false
@export var use_local_battle_db: bool
@export var asset_variant: int
@export var popup_debug: Control
@export var v_box_container_buttons: VBoxContainer


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


func _on_debug_event(event: DebugEventType, _data: Variant = null) -> void:
	match event:
		DebugEventType.EVENT_OPEN_DEBUG_MENU:
			popup_debug.show()
		#DebugEventType.EVENT_OPEN_GAME_SELECTOR:
		#popup_debug_game.popup_centered()



#func set_force_level(_force):
#force_level = _force
#
#func get_test_scene():
#return test_scene
#
#func get_force_level():
#return force_level if OS.is_debug_build() else false
#
func _ready() -> void:
	Log.info("Debug module initialized", {}, [Log.TAG_DB])
	popup_debug.hide()
	debug_event.connect(_on_debug_event)
	for btn : Button in v_box_container_buttons.get_children():
		btn.pressed.connect(debug_button_pressed.bind(btn.name))

	# Verify logger file export if on iOS or Android
	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()

## Verify logger file export (used on mobile platforms)
func _verify_logger_export() -> void:

	# If the verifier isn't available, do a basic check
	Log.warning("Logger export verifier not found, performing basic check", {}, [Log.TAG_DEBUG])

	# Check for iOS helper on iOS
	if OS.get_name() == "iOS":
		var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
		if ios_helper:
			Log.info("iOS logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("iOS logger helper missing!", {}, [Log.TAG_DEBUG])

	# Check for Android helper on Android
	if OS.get_name() == "Android":
		var android_helper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
		if android_helper:
			Log.info("Android logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("Android logger helper missing!", {}, [Log.TAG_DEBUG])


func debug_button_pressed(_name: String) -> void:
	match _name:
		"button_close":
			popup_debug.hide()
		'button_db_debug':
			action(DebugEventType.EVENT_OPEN_DB_DEBUG_MENU)
		"button_pop_enemy":
			Log.debug("Populating enemy lineup with test cards", {}, [Log.TAG_DB, Log.TAG_DEBUG])
			for n : int in 3:
				var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
				new_card.block_context = Cards.CONTEXT.LINEUP
				#core.action(core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD,[new_card,n])
				core.action(core.EnemyLineupAddCardEvent.new(new_card, n))
			for n : int in 3:
				var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
				new_card.block_context = Cards.CONTEXT.LINEUP
				#core.action(core.EVENT_TYPE.LINEUP_ADD_CARD,[new_card,n])
				core.action(core.DebugLineupAddCardEvent.new(new_card, n))
		"select_game":
			Log.debug("Game selection requested", {}, [Log.TAG_DEBUG, Log.TAG_UI])
			popup_debug.hide()
			action(DebugEventType.EVENT_OPEN_GAME_SELECTOR)

		"reset_current_match_level":
			action(DebugEventType.EVENT_RESET_MATCH_LEVEL)
		"match_level_1":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_01"])
		"match_level_2":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_02"])

		"match_level_3":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_03"])

		"match_level_4":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_04"])

		"match_level_5":
			action(DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_05"])
		_:
			Log.warning("Unused debug button pressed", {"button_name": _name}, [Log.TAG_DEBUG, Log.TAG_UI])
#
#func _process(_delta):
#if toggle_orientation:
#toggle_orientation = false
#OS.set_window_size(Vector2(OS.get_window_size().y,OS.get_window_size().x))
