extends Node


func _ready() -> void:
	print("Main ready")
	Log.set_debug_filter_logging(false)
	#await data_source.activate_card_cache()
	#var scene = preload("res://cardtest/battle_3.tscn")
	#add_child(scene.instantiate())
	debug.debug_event.connect(_on_debug_event)
	match OS.get_name():
		"Windows":
			print("Welcome to Windows!")
		"macOS":
			print("Welcome to macOS!")
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			print("Welcome to Linux/BSD!")
		"Android":
			print("Welcome to Android!")
		"iOS":
			print("Welcome to iOS!")
		"Web":
			print("Welcome to the Web!")


func _on_debug_event(event: debug.DEBUG_EVENT_TYPE, _data: Variant = null) -> void:
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_OPEN_DB_DEBUG_MENU:
			%PopupDebug.show()

func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
	if event.as_text() == "Q" and event.is_pressed():
		get_tree().quit()
