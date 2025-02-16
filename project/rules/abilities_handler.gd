# ability_parser.gd
class_name AbilitiesHandler extends Resource


static func parse_ability_string(ability_string: String) -> Array[Ability]:
	var parsed_abilities: Array[Ability] = []
	if ability_string.is_empty():
		return parsed_abilities

	var packed_ability_commands: PackedStringArray = ability_string.split(",")
	var ability_commands: Array[String] = []
	ability_commands.assign(packed_ability_commands)
	for command: String in ability_commands:
		var command_parts: PackedStringArray = command.split(":")
		var ability_type: String = command_parts[0]
		var ability_params: PackedStringArray = []

		if command_parts.size() > 1:
			ability_params = command_parts[1].split(";")

		var new_ability: Ability = create_ability_from_type(ability_type, ability_params)
		if new_ability:
			parsed_abilities.append(new_ability)

	return parsed_abilities


static func create_ability_from_type(ability_type: String, params: PackedStringArray) -> Ability:
	var new_ability: Ability = null
	match ability_type:
		"guard":
			var health_bonus: int = int(params[0])
			new_ability = DeathTriggerHealthAbility.new(health_bonus)
		"troll":
			var health_bonus: int = int(params[0])
			var attack_bonus: int = int(params[1])
			new_ability = EvilSynergyAbility.new(health_bonus, attack_bonus)
		"shield":
			new_ability = DamageShieldAbility.new()
		"merge_bonus":
			var health_bonus: int = int(params[0])
			var attack_bonus: int = int(params[1])
			new_ability = MergeBonusAbility.new(health_bonus, attack_bonus)
	return new_ability
