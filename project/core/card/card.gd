class_name CardFullView extends AspectRatioContainer

@export var card_info: Container
@export var card_image: TextureRect


func show_card() -> void:
	$animation_player.play("scale_up")


func _on_button_pressed() -> void:
	ui.action(ui.HideCardEvent.new())


func setup_card(card: Card) -> void:
	print("CARD: setup card in card", card)

	var info: UnitData = card.unit_info
#	var img_string = str("cardtest/card_image_",debug.asset_variant,"_",info.card_info.id,".png")
	var img_string: String = card_controller.get_card_image_name(info.card_info.id)
	card_image.texture = load(img_string)
	card_info.set_attack(info.current_attack)
	card_info.set_health(info.current_health)
	card_info.set_card_name(info.card_info.card_name)
	card_info.set_card_level(info.level)
	card_info.add_tag("testtag1")
	card_info.add_tag("testtag1")
	card_info.set_rules_text(info.card_info.description)
	card_info.set_upgrade_level(int(info.card_info.upgrade_level))
