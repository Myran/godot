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
	EVENT_CLOSE_DB_DEBUG_MENU,  # Preserved from original debug.gd
	EVENT_QUIT,
	EVENT_TOGGLE_DEBUG_MENU_LIST
}

# Keep legacy popup here if desired, or move its control elsewhere
@export var popup_debug: Control  # Assign in editor
@export var v_box_container_buttons: VBoxContainer

# Variables preserved from original debug.gd for backward compatibility
# These may be refactored later if needed
var use_local_battle_db: bool
var asset_variant: int


func _ready() -> void:
	use_local_battle_db = false
	asset_variant = 1

	# Connect to our own signal if legacy popup needs to react
	#debug_event.connect(_on_debug_event)

	# If popup_debug is assigned, set it up
	#if popup_debug:
	#popup_debug.hide()
	## Connect buttons if container is assigned
	#if v_box_container_buttons:
	#for btn: Button in v_box_container_buttons.get_children():
	#btn.pressed.connect(debug_button_pressed.bind(btn.name))

	Log.info("DebugManager (Global Event Bus) initialized.", {}, ["debug", "system"])

	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


#func _on_debug_event(event_type: DebugEventType, args: Array = []) -> void:
#match event_type:
#DebugEventType.EVENT_QUIT:
#get_tree().quit(0)
#DebugEventType.EVENT_OPEN_LEGACY_POPUP:
#if popup_debug:
#popup_debug.show()
#Log.debug("Legacy debug popup opened.", {}, ["debug", "ui"])
#
#DebugEventType.EVENT_CLOSE_LEGACY_POPUP:
#if popup_debug:
#popup_debug.hide()
#Log.debug("Legacy debug popup closed.", {}, ["debug", "ui"])
#
#DebugEventType.EVENT_OPEN_DEBUG_MENU:
## This event will be handled by the main.gd script to show the new debug menu
#Log.debug("Open debug menu event emitted", {}, ["debug", "ui"])
#
## Original debug.gd events handling for backward compatibility
#DebugEventType.EVENT_OPEN_DB_DEBUG_MENU:
## Handle legacy behavior
## This would previously open scene_debug.tscn
#Log.info("Opening DB debug menu (will be handled by main.gd)", {}, ["debug", "ui"])
#
## Other events preserved from original debug.gd
#DebugEventType.EVENT_OPEN_GAME_SELECTOR, DebugEventType.EVENT_RESET_MATCH_LEVEL, DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU:
#Log.debug("Event emitted: " + str(event_type), {"args": args}, ["debug", "events"])
#
#_:
#Log.warning("Unhandled debug event type: " + str(event_type), {}, ["debug", "events"])


# Keep legacy helper functions until fully migrated
func _verify_logger_export() -> void:
	if OS.get_name() == "iOS":
		if _verify_mobile_helper("res://addons/advanced_logger/utils/ios_logger_helper.gd"):
			Log.info("iOS logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("iOS logger helper missing!", {}, [Log.TAG_DEBUG])
	if OS.get_name() == "Android":
		if _verify_mobile_helper("res://addons/advanced_logger/utils/android_logger_helper.gd"):
			Log.info("Android logger helper found", {}, [Log.TAG_DEBUG])
		else:
			Log.error("Android logger helper missing!", {}, [Log.TAG_DEBUG])


## Verifies that a mobile helper class can be loaded and is valid
## This matches the actual loading pattern used in the logger system
func _verify_mobile_helper(helper_path: String) -> bool:
	# Try to load the helper class
	var helper_class: Resource = load(helper_path)
	if helper_class == null:
		Log.debug("Failed to load helper class", {"path": helper_path}, [Log.TAG_DEBUG])
		return false

	# Verify the helper has expected static methods
	# For AndroidLoggerHelper, we expect: configure_for_android, process_log_message
	# For IosLoggerHelper, we expect: configure_for_ios, process_log_message
	if not helper_class.has_method("process_log_message"):
		Log.debug("Helper class missing required methods", {"path": helper_path}, [Log.TAG_DEBUG])
		return false

	Log.debug("Mobile helper verification successful", {"path": helper_path}, [Log.TAG_DEBUG])
	return true

# Updated debug button handler - simplified since manual actions are now in DebugRegistry
#func debug_button_pressed(button_name: String) -> void:
## Handle special cases
#match button_name:
#"button_close":
#action(DebugEventType.EVENT_CLOSE_LEGACY_POPUP)
#_:
#Log.warning("Unhandled button press: " + button_name, {}, ["debug", "ui"])
