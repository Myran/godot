extends Node

@export var use_actions_in_editor: bool = false


func _ready() -> void:
	Log.info("Main scene initialized", {}, ["system", "initialization"])
	Log.set_debug_filter_logging(false)

	var _args: PackedStringArray = OS.get_cmdline_user_args()

	DebugManager.debug_event.connect(_on_debug_event)
	match OS.get_name():
		"Windows":
			Log.info("Running on Windows platform", {}, ["system", "initialization"])
		"macOS":
			Log.info("Running on macOS platform", {}, ["system", "initialization"])
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			Log.info("Running on Linux/BSD platform", {}, ["system", "initialization"])
		"Android":
			Log.info("Running on Android platform", {}, ["system", "initialization"])
		"iOS":
			Log.info("Running on iOS platform", {}, ["system", "initialization"])
		"Web":
			Log.info("Running on Web platform", {}, ["system", "initialization"])
	if (
		not use_actions_in_editor
		and OS.has_feature("editor")
		and not DisplayServer.get_name() == "headless"
	):
		return

	DebugStartupCoordinator.startDebugCoordinator()


func _on_debug_event(event_type: DebugManager.DebugEventType, _args: Array[Variant] = []) -> void:
	match event_type:
		DebugManager.DebugEventType.EVENT_OPEN_DB_DEBUG_MENU, DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU:
			%PopupDebug.show()
		DebugManager.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU, DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU:
			%PopupDebug.hide()
		DebugManager.DebugEventType.EVENT_QUIT:
			Log.info("Quit event received, exiting application", {}, ["debug", "system"])
			get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
	if event.as_text() == "Q" and event.is_pressed():
		get_tree().quit()
