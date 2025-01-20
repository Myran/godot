extends ColorRect


func set_upgrade_level(_lvl: int = 1) -> void:
	get_node("%panel_container_level_top").set_level(_lvl)


func set_card_img(_img_name: String = "card_image_0_1.png") -> void:
	get_node("%card_image").texture = load(_img_name)


func set_card_health(_h: int = 1) -> void:
	get_node("%label_health").text = str(_h)


func set_card_attack(_a: int = 1) -> void:
	get_node("%label_attack").text = str(_a)


func set_card_level(_lvl: int = 1) -> void:
	if _lvl == 1:
		get_node("%icon_level").visible = false
	else:
		get_node("%icon_level").visible = true
	get_node("%label_level").text = str(_lvl)


func get_vignette_shader_node() -> ColorRect:
	return %vignette
