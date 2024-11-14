extends VBoxContainer
@export var tag_scene: PackedScene
@onready var label_rules_text = $"%label_rules_text"
@onready var label_card_name = $"%label_card_name"
@onready var label_level = $"%label_level"
@onready var label_attack = $"%label_attack"
@onready var label_health = $"%label_health"
@onready var panel_container_level = $"%panel_container_level"
@onready var h_box_container_tags = $"%h_box_container_tags"


func set_card_level(_lvl = 1):
	label_level.text = str(_lvl)


func set_card_name(_name = "unnamed"):
	label_card_name.text = _name


func set_rules_text(_rules_text = "rules text missing"):
	label_rules_text.text = _rules_text


func set_attack(_a = 1):
	label_attack.text = str(_a)


func set_health(_h = 1):
	label_health.text = str(_h)


func set_upgrade_level(_up_level):
	panel_container_level.set_level(_up_level)


func add_tag(_tag_name = "tag_name"):
	var tag = tag_scene.instantiate()
	h_box_container_tags.add_child(tag)
	tag.set_tag(_tag_name)
