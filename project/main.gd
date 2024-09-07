extends Node

func _ready() -> void:
	print("Main ready")
	pass  # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.as_text() == "Escape" and event.is_pressed():
		%PopupDebug.show()
		
func _process(_delta: float) -> void:
	pass
