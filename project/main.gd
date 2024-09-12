extends Node

func _ready() -> void:
	print("Main ready")

func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
		
