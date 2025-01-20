extends PanelContainer


func set_level(_lvl: int) -> void:
	$"%icon_level_1".visible = false
	$"%icon_level_2".visible = false
	$"%icon_level_3".visible = false

	match int(_lvl):
		1:
			$"%icon_level_1".visible = true
		2:
			$"%icon_level_1".visible = true
			$"%icon_level_2".visible = true
		3:
			$"%icon_level_1".visible = true
			$"%icon_level_2".visible = true
			$"%icon_level_3".visible = true
