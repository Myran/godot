class_name Card extends Block

const CARD_IMAGE_PREFIX: String = "card_image_"
@export_dir var card_image_folder: String
@export var base: SmallBase
@export var shield: Sprite2D
@export var level: int = 1
@export var unit_info: UnitData = null
@export var card_info: Dictionary = {}  # CardInfo data structure
@export var card_name: String = ""


func show_shield() -> void:
	shield.show()


func hide_shield() -> void:
	shield.hide()


func init_card(_card_info: Dictionary, _card_level: int = 1) -> void:
	card_info = _card_info
	level = _card_level
	var card_name_value: String = _card_info.get("card_name", "Unknown")
	card_name = card_name_value

	unit_info = UnitData.new()
	unit_info.init_with_info(_card_info)
	unit_info.upgrade_unit_to_level(_card_level)

	var id: String = ""
	if _card_info.has("id"):
		var id_value: String = _card_info.id
		id = id_value
	else:
		Log.warning("Card info missing 'id' field", {"card_info": _card_info}, ["debug"])

	var img_string: String = card_controller.get_card_image_name(id)
	var upgrade_level: String = unit_info.card_info.upgrade_level
	base.set_card_img(img_string)

	var upgrade_level_int: int = 1
	if unit_info.card_info.has("upgrade_level"):
		var upgrade_level_str: String = unit_info.card_info.upgrade_level
		upgrade_level_int = upgrade_level_str.to_int()

	base.set_upgrade_level(upgrade_level_int)
	base.set_card_health(unit_info.current_health)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_level(unit_info.level)


func init_battle_reenactment(source_card: Card) -> void:
	level = source_card.level
	card_name = source_card.card_name

	# Extract minimal data from source
	var card_id: String = source_card.unit_info.card_info.id

	# Set visual components only (no UnitData)
	var img_string: String = card_controller.get_card_image_name(card_id)
	base.set_card_img(img_string)
	base.set_card_attack(source_card.unit_info.current_attack)
	base.set_card_health(source_card.unit_info.current_health)
	base.set_card_level(source_card.level)


func get_card_name() -> String:
	return card_name


func refresh_ui_from_unit_data() -> void:
	"""Updates card UI to reflect current unit_info stats"""
	Log.debug(
		"UI REFRESH - Updating card display stats",
		{
			"card_id": card_info.get("id", "unknown"),
			"level": level,
			"attack_displayed": unit_info.current_attack,
			"health_displayed": unit_info.current_health,
			"effects_count": unit_info.effects_perm.size(),
			"context": "refresh_ui_from_unit_data"
		},
		[Log.TAG_UI, Log.TAG_CARD, Log.TAG_STAT, "ui_refresh"]
	)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_health(unit_info.current_health)
