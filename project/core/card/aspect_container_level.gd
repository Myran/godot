class_name LevelContainer extends AspectRatioContainer


func set_level(_lvl: int) -> void:
	$"%icon_level_1".visible = false
	$"%icon_level_2".visible = false
	$"%icon_level_3".visible = false

	match int(_lvl):
		GameConstants.CardSystem.DEFAULT_LEVEL:
			$"%icon_level_1".visible = true
		GameConstants.CardSystem.LEVEL_TWO:
			$"%icon_level_1".visible = true
			$"%icon_level_2".visible = true
		GameConstants.CardSystem.LEVEL_THREE:
			$"%icon_level_1".visible = true
			$"%icon_level_2".visible = true
			$"%icon_level_3".visible = true
