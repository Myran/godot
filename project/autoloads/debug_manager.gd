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
	EVENT_QUIT,
	EVENT_TOGGLE_DEBUG_MENU_LIST,
	EVENT_RESTART_GAME  # Restart the current game scene cleanly
}

@export var popup_debug: Control  # Assign in editor
@export var v_box_container_buttons: VBoxContainer

var use_local_battle_db: bool
var asset_variant: int


func _ready() -> void:
	use_local_battle_db = false
	asset_variant = 1

	Log.info("DebugManager (Global Event Bus) initialized.", {}, ["debug", "system"])

	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		_verify_logger_export()


func action(type: DebugEventType, args: Array = []) -> void:
	debug_event.emit(type, args)


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


func _verify_mobile_helper(helper_path: String) -> bool:
	var helper_class: Resource = load(helper_path)
	if helper_class == null:
		Log.debug("Failed to load helper class", {"path": helper_path}, [Log.TAG_DEBUG])
		return false

	if not helper_class.has_method("process_log_message"):
		Log.debug("Helper class missing required methods", {"path": helper_path}, [Log.TAG_DEBUG])
		return false

	Log.debug("Mobile helper verification successful", {"path": helper_path}, [Log.TAG_DEBUG])
	return true
