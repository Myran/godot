extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("test in margincontainer")
	position.x = 100


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
