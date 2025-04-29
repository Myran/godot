extends Node


func _ready() -> void:
	Log.info("Main scene initialized", {}, ["system", "initialization"])
	Log.set_debug_filter_logging(false)


	var args: PackedStringArray = OS.get_cmdline_user_args()
	# Check if a specific flag exists


	# Log which data source implementation is being used
	Log.info("Using updated DataSource implementation", {}, ["system", "initialization"])
	#await data_source.activate_card_cache()
	#var scene = preload("res://cardtest/battle_3.tscn")
	#add_child(scene.instantiate())
	debug.debug_event.connect(_on_debug_event)
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


func _on_debug_event(event: debug.DEBUG_EVENT_TYPE, _data: Variant = null) -> void:
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_OPEN_DB_DEBUG_MENU:
			%PopupDebug.show()

func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
	if event.as_text() == "Q" and event.is_pressed():
		get_tree().quit()
