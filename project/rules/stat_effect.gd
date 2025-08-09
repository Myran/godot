class_name StatEffect extends Resource

var health_bonus: int = 0
var attack_bonus: int = 0
var source: String = ""


func _init(h: int = 0, a: int = 0, src: String = "") -> void:
	health_bonus = h
	attack_bonus = a
	source = src


func deep_duplicate() -> StatEffect:
	var copy: StatEffect = StatEffect.new(health_bonus, attack_bonus, source)
	return copy


func get_description() -> String:
	var parts: Array[String] = []
	if health_bonus != 0:
		parts.append("%+d Health" % health_bonus)
	if attack_bonus != 0:
		parts.append("%+d Attack" % attack_bonus)
	return "%s (%s)" % [" ".join(parts), source]
