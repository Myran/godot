extends NinePatchRect


func _ready() -> void:
	pass  # Replace with function body.


func _on_button_debug_pressed() -> void:
	DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)
