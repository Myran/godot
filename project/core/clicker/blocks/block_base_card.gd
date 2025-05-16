class_name Card extends Block

const CARD_IMAGE_PREFIX: String = "card_image_"
@export_dir var card_image_folder: String
@export var base: SmallBase
@export var shield: Sprite2D
@export var level: int = 1
@export var unit_info: UnitData = null
@export var card_info: Dictionary = {}  # CardInfo data structure


func show_shield() -> void:
	shield.show()


func hide_shield() -> void:
	shield.hide()


func init_card(_card_info: Dictionary, _card_level: int = 1) -> void:
	card_info = _card_info
	level = _card_level

	unit_info = UnitData.new()
	unit_info.init_with_info(_card_info)
	unit_info.upgrade_unit_to_level(_card_level)

	var id: String = ""
	if _card_info.has("id"):
		id = _card_info.id
	else:
		Log.warning("Card info missing 'id' field", {"card_info": _card_info}, ["debug"])
	var img_string: String = card_controller.get_card_image_name(id)
	var upgrade_level: String = unit_info.card_info.upgrade_level
	base.set_card_img(img_string)

	var upgrade_level_int: int = 1
	if unit_info.card_info.has("upgrade_level"):
		upgrade_level_int = int(unit_info.card_info.upgrade_level)

	base.set_upgrade_level(upgrade_level_int)
	base.set_card_health(unit_info.current_health)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_level(unit_info.level)
