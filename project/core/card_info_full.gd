extends VBoxContainer

@export var tag_scene: PackedScene

@export var label_rules_text: Label  # = $"%label_rules_text"
@export var label_card_name: Label  # = $"%label_card_name"
@export var label_level: Label  # = $"%label_level"
@export var label_attack: Label  # = $"%label_attack"
@export var label_health: Label  # = $"%label_health"
@export var panel_container_level: LevelContainer  # = $"%panel_container_level"
@export var h_box_container_tags: HBoxContainer  # = $"%h_box_container_tags"


func set_card_level(_lvl: int = 1) -> void:
	label_level.text = str(_lvl)


func set_card_name(_name: String = "unnamed") -> void:
	label_card_name.text = _name


func set_rules_text(_rules_text: String = "rules text missing") -> void:
	label_rules_text.text = _rules_text


func set_attack(_a: int = 1) -> void:
	label_attack.text = str(_a)


func set_health(_h: int = 1) -> void:
	label_health.text = str(_h)


func set_upgrade_level(_up_level: int) -> void:
	panel_container_level.set_level(_up_level)


func add_tag(_tag_name: String = "tag_name") -> void:
	var tag: TagContainer = tag_scene.instantiate()
	h_box_container_tags.add_child(tag)
	tag.set_tag(_tag_name)
