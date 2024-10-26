extends CanvasLayer

func blur():
	$animation_player_blur.play("blur")

func unblur():
	$animation_player_blur.play("unblur")
