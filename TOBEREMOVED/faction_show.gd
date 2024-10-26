extends Control


func show_faction():
	$animation_player.play("fadein")

func hide_faction():
	$animation_player.play_backwards("fadein")
