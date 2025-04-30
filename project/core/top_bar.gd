extends NinePatchRect

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_button_debug_pressed() -> void:
	debug.action(debug.DebugEventType.EVENT_OPEN_DEBUG_MENU)
