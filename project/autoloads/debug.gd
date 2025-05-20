extends Node

signal debug_event

enum DebugEventType {
	EVENT_OPEN_DEBUG_MENU,  # Used by top bar to open legacy debug menu
	EVENT_OPEN_GAME_SELECTOR,
	EVENT_RESET_MATCH_LEVEL,
	EVENT_FORCE_LOAD_MATCH_LEVEL,
	EVENT_OPEN_DB_DEBUG_MENU,
	EVENT_CLOSE_DB_DEBUG_MENU
}

# Variable to track if debug menu setup is complete
var setup_ok: bool = false

@export var use_local_battle_db: bool
@export var asset_variant: int
@export var popup_debug: Control
@export var v_box_container_buttons: VBoxContainer

# UI component for showing status messages
var status_label: Label = null


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


# The debug_menu reference
var debug_menu: Node = null
var debug_menu_controller: Node = null


func _on_debug_event(event: DebugEventType, _data: Variant = null) -> void:
	match event:
		DebugEventType.EVENT_OPEN_DEBUG_MENU:
			Log.info("Opening legacy popup debug menu", {}, [Log.TAG_DEBUG])
			popup_debug.show()

		DebugEventType.EVENT_OPEN_DB_DEBUG_MENU:
			if debug_menu:
				debug_menu.show_menu_content()
			else:
				# Legacy behavior
				Log.info("Opening scene_debug.tscn (legacy)", {}, [Log.TAG_DEBUG])
				# Old implementation would handle this


func _ready() -> void:
	Log.info("Debug module initialized", {}, [Log.TAG_DB])
	popup_debug.hide()
	debug_event.connect(_on_debug_event)
	for btn: Button in v_box_container_buttons.get_children():
		btn.pressed.connect(debug_button_pressed.bind(btn.name))

	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()


func _verify_logger_export() -> void:
	if OS.get_name() == "iOS":
		if IosLoggerHelper:
			Log.info("iOS logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("iOS logger helper missing!", {}, [Log.TAG_DEBUG])
	if OS.get_name() == "Android":
		if AndroidLoggerHelper:
			Log.info("Android logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("Android logger helper missing!", {}, [Log.TAG_DEBUG])


func _populate_enemy_lineup() -> void:
	for n: int in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, n))
	for n: int in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))


func debug_button_pressed(button_name: String) -> void:
	match button_name:
		"button_close":
			popup_debug.hide()
		"button_db_debug":
			action(DebugEventType.EVENT_OPEN_DB_DEBUG_MENU)
		"button_pop_enemy":
			_populate_enemy_lineup()
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
			pass
