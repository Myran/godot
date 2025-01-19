class_name Card extends Block

const CARD_IMAGE_PREFIX = "card_image_"
@export_dir var card_image_folder: String
@export var base: Node
@export var shield: Sprite2D
@export var level: int = 1
@export var unit_info = null
@export var card_info = null



func show_shield():
	shield.show()


func hide_shield():
	shield.hide()


func init_card(_card_info, _card_level = 1):
	card_info = _card_info
	level = _card_level

	unit_info = UnitData.new()
	unit_info.init_with_info(_card_info)
	unit_info.upgrade_unit_to_level(_card_level)
	var img_string = card_controller.get_card_image_name(_card_info.id)

	base.set_card_img(img_string)
	base.set_upgrade_level(unit_info.card_info.upgrade_level)
	base.set_card_health(unit_info.current_health)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_level(unit_info.level)
