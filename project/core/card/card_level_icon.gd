extends TextureRect


func set_level(_lvl: int = 1) -> void:
	$label_level.text = str(_lvl)
