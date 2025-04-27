class_name CardFullView extends AspectRatioContainer

@export var card_info: CardInfoContainer
@export var card_image: TextureRect
@export var anim_player: AnimationPlayer


func show_card() -> void:
	anim_player.play("scale_up")


func _on_button_pressed() -> void:
	ui.action(ui.HideCardEvent.new())


func setup_card(card: Card) -> void:
	Log.info("Setting up card in card view", {"card": card}, [Log.TAG_DB, Log.TAG_CARD, Log.TAG_UI])

	var info: UnitData = card.unit_info
#	var img_string = str("cardtest/card_image_",debug.asset_variant,"_",info.card_info.id,".png")
	var id: String = info.card_info.id
	var img_string: String = card_controller.get_card_image_name(id)
	card_image.texture = load(img_string)
	card_info.set_attack(info.current_attack)
	card_info.set_health(info.current_health)
	var card_name: String = info.card_info.card_name
	card_info.set_card_name(card_name)
	card_info.set_card_level(info.level)
	card_info.add_tag("testtag1")
	card_info.add_tag("testtag1")
	var desc: String = info.card_info.description
	card_info.set_rules_text(desc)
	var level: String = info.card_info.upgrade_level
	var lvl: int = int(level)
	card_info.set_upgrade_level(lvl)
