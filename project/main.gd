extends Node

@export var use_actions_in_editor: bool = false

# Main scene for game coordination


func _ready() -> void:
	Log.info("Main scene initialized", {}, ["system", "initialization"])
	Log.set_debug_filter_logging(false)

	var cmdline_args: PackedStringArray = OS.get_cmdline_args()
	var cmdline_user_args: PackedStringArray = OS.get_cmdline_user_args()

	Log.info(
		"Command line arguments debug",
		{
			"cmdline_args": cmdline_args,
			"cmdline_user_args": cmdline_user_args,
			"cmdline_args_size": cmdline_args.size(),
			"cmdline_user_args_size": cmdline_user_args.size()
		},
		["system", "initialization"]
	)

	DebugManager.debug_event.connect(_on_debug_event)

	# Gamestate loading is now handled by debug actions directly
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

	var is_test_mode: bool = false
	if OS.has_feature("android"):
		is_test_mode = true
		Log.info(
			"Android test mode detection",
			{"is_test_mode": is_test_mode},
			["system", "initialization", "test_mode"]
		)
	elif OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		is_test_mode = "--test-mode" in cmdline_args
		Log.info(
			"Desktop test mode detection",
			{
				"is_test_mode": is_test_mode,
				"cmdline_args": cmdline_args,
				"platform_name": OS.get_name()
			},
			["system", "initialization", "test_mode"]
		)
	else:
		Log.info(
			"Unknown platform test mode detection",
			{
				"is_test_mode": is_test_mode,
				"platform_name": OS.get_name(),
				"has_android": OS.has_feature("android"),
				"has_desktop": OS.has_feature("desktop"),
				"has_editor": OS.has_feature("editor")
			},
			["system", "initialization", "test_mode"]
		)

	if (
		not use_actions_in_editor
		and OS.has_feature("editor")
		and not DisplayServer.get_name() == "headless"
		and not is_test_mode
	):
		Log.info(
			"Skipping debug coordinator - editor mode without test flag",
			{
				"use_actions_in_editor": use_actions_in_editor,
				"is_editor": OS.has_feature("editor"),
				"is_headless": DisplayServer.get_name() == "headless",
				"is_test_mode": is_test_mode
			},
			["system", "initialization"]
		)
		return

	await _wait_for_game_initialization()
	DebugStartupCoordinator.startDebugCoordinator()


func _wait_for_game_initialization() -> void:
	Log.info("Waiting for game initialization to complete", {}, ["system", "initialization"])

	var game_node: Game = get_node("Game")
	if game_node == null:
		Log.error("Game node not found in main scene", {}, ["system", "initialization", "error"])
		return

	await game_node.initialization_complete

	Log.info(
		"Game initialization complete (signal received), starting debug coordinator",
		{},
		["system", "initialization"]
	)


func _on_debug_event(event_type: DebugManager.DebugEventType, _args: Array[Variant] = []) -> void:
	match event_type:
		DebugManager.DebugEventType.EVENT_OPEN_DB_DEBUG_MENU, DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU:
			%PopupDebug.show()
		DebugManager.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU, DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU:
			%PopupDebug.hide()
		DebugManager.DebugEventType.EVENT_QUIT:
			Log.info("Quit event received, exiting application", {}, ["debug", "system"])
			SessionManager.end_gameplay_session()
			if get_tree():
				get_tree().quit(0)
			else:
				Log.warning(
					"Tree not available during quit, using fallback", {}, ["debug", "system"]
				)
				get_tree().quit(0) if get_tree() else print("Force quit: tree unavailable")
		DebugManager.DebugEventType.EVENT_RESTART_GAME:
			Log.info("Restart event received, restarting game scene", {}, ["debug", "system"])
			_restart_game_scene()


func _restart_game_scene() -> void:
	"""Restart the current game scene cleanly"""
	Log.info("Restarting game scene", {}, ["system", "restart"])

	# End any active session cleanly
	if SessionManager.has_active_session():
		SessionManager.end_current_session("game_restart")
		Log.debug("Active session ended for restart", {}, ["system", "restart"])

	# Reload current scene
	var current_scene_path: String = get_tree().current_scene.scene_file_path
	if current_scene_path.is_empty():
		# Fallback to main scene if current scene path is unknown
		current_scene_path = "res://main.tscn"
		Log.warning(
			"Current scene path empty, using fallback",
			{"fallback": current_scene_path},
			["system", "restart"]
		)

	Log.debug("Reloading scene", {"path": current_scene_path}, ["system", "restart"])
	get_tree().change_scene_to_file(current_scene_path)




func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
	if event.as_text() == "Q" and event.is_pressed():
		if get_tree():
			get_tree().quit(0)
