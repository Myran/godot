extends AspectRatioContainer
@onready var card_info = $"%card_info"
@onready var card_image = $"%card_image"


func show_card():
	#$animation_player_fadein.play("fadein")
	#$animation_player_beam.play("reveal")
	#$animation_player_beam.play("regular")
	$animation_player.play("scale_up")
	pass



func _on_button_pressed():
	#ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.TAP_POP_CARD,[self])
	ui.action(ui.EVENT_TYPE.TAP_POP_CARD,[self])
func setup_card(card):
	print("CARD: setup card in card",card)

	var info = card.unit_info
#	var img_string = str("cardtest/card_image_",debug.asset_variant,"_",info.card_info.id,".png")
	var img_string = card_controller.get_card_image_name(info.card_info.id)
	card_image.texture = load(img_string)
	card_info.set_attack(info.current_attack)
	card_info.set_health(info.current_health)
	card_info.set_card_name(info.card_info.card_name)
	card_info.set_card_level(info.level)
	card_info.add_tag("testtag1")
	card_info.add_tag("testtag1")
	card_info.set_rules_text(info.card_info.description)
	card_info.set_upgrade_level(info.card_info.upgrade_level)
