extends Popup


func _ready() -> void:
	size = get_tree().root.get_visible_rect().size
	position = Vector2.ZERO
