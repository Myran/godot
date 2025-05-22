# project/autoloads/debug_manager.gd (renamed from debug.gd)
extends Node

signal debug_event(event_type: DebugEventType, args: Array)

enum DebugEventType {
	EVENT_OPEN_DEBUG_MENU,  # Main dynamic debug menu
	EVENT_CLOSE_DEBUG_MENU,
	EVENT_OPEN_LEGACY_POPUP,  # For the old simple popup
	EVENT_CLOSE_LEGACY_POPUP,
	EVENT_OPEN_GAME_SELECTOR,  # Preserved from original debug.gd
	EVENT_RESET_MATCH_LEVEL,  # Preserved from original debug.gd
	EVENT_FORCE_LOAD_MATCH_LEVEL,  # Preserved from original debug.gd
	EVENT_OPEN_DB_DEBUG_MENU,  # Preserved from original debug.gd
	EVENT_CLOSE_DB_DEBUG_MENU  # Preserved from original debug.gd
}

# Keep legacy popup here if desired, or move its control elsewhere
@export var popup_debug: Control  # Assign in editor
@export var v_box_container_buttons: VBoxContainer

# Variables preserved from original debug.gd for backward compatibility
# These may be refactored later if needed
@export var use_local_battle_db: bool
@export var asset_variant: int


func _ready():
	# Connect to our own signal if legacy popup needs to reac
	debug_event.connect(_on_debug_event)

	# If popup_debug is assigned, set it up
	if popup_debug:
		popup_debug.hide()
		# Connect buttons if container is assigned
		if v_box_container_buttons:
			for btn: Button in v_box_container_buttons.get_children():
				btn.pressed.connect(debug_button_pressed.bind(btn.name))

	Log.info("DebugManager (Global Event Bus) initialized.", {}, ["debug", "system"])

	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


func _on_debug_event(event_type: DebugEventType, args: Array = []) -> void:
	match event_type:
		DebugEventType.EVENT_OPEN_LEGACY_POPUP:
			if popup_debug:
				popup_debug.show()
				Log.debug("Legacy debug popup opened.", {}, ["debug", "ui"])

		DebugEventType.EVENT_CLOSE_LEGACY_POPUP:
			if popup_debug:
				popup_debug.hide()
				Log.debug("Legacy debug popup closed.", {}, ["debug", "ui"])

		DebugEventType.EVENT_OPEN_DEBUG_MENU:
			# This event will be handled by the main.gd script to show the new debug menu
			Log.debug("Open debug menu event emitted", {}, ["debug", "ui"])

		# Original debug.gd events handling for backward compatibility
		DebugEventType.EVENT_OPEN_DB_DEBUG_MENU:
			# Handle legacy behavior
			# This would previously open scene_debug.tscn
			Log.info("Opening DB debug menu (will be handled by main.gd)", {}, ["debug", "ui"])

		# Other events preserved from original debug.gd
		DebugEventType.EVENT_OPEN_GAME_SELECTOR, DebugEventType.EVENT_RESET_MATCH_LEVEL, DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU:
			Log.debug("Event emitted: " + str(event_type), {"args": args}, ["debug", "events"])

		_:
			Log.warning("Unhandled debug event type: " + str(event_type), {}, ["debug", "events"])


# Keep legacy helper functions until fully migrated
func _verify_logger_export() -> void:
	if OS.get_name() == "iOS":
		if Engine.has_singleton("IosLoggerHelper"):
			Log.info("iOS logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("iOS logger helper missing!", {}, [Log.TAG_DEBUG])
	if OS.get_name() == "Android":
		if Engine.has_singleton("AndroidLoggerHelper"):
			Log.info("Android logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("Android logger helper missing!", {}, [Log.TAG_DEBUG])


# This function is kept for backward compatibility with the legacy popup
# Eventually, these actions should be migrated to DebugAction resources
func debug_button_pressed(button_name: String) -> void:
	match button_name:
		"button_close":
			action(DebugEventType.EVENT_CLOSE_LEGACY_POPUP)
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
			Log.warning("Unhandled button press: " + button_name, {}, ["debug", "ui"])


# Legacy function preserved for backward compatibility
func _populate_enemy_lineup() -> void:
	if not (Engine.has_singleton("core") and Engine.has_singleton("card_controller")):
		Log.error("Cannot populate enemy lineup: core or card_controller missing", {}, ["debug"])
		return

	var core = Engine.get_singleton("core")
	var card_controller = Engine.get_singleton("card_controller")

	if core and card_controller:
		for n: int in 3:
			var new_card = await card_controller.create_unit_from_id(str(n), 1)
			new_card.block_context = Engine.get_singleton("Cards").CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(new_card, n))
		for n: int in 3:
			var new_card = await card_controller.create_unit_from_id(str(n), 1)
			new_card.block_context = Engine.get_singleton("Cards").CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(new_card, n))
