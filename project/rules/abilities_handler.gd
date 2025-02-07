# ability_parser.gd
class_name AbilitiesHandler extends Resource

static func parse_ability_string(ability_string: String) -> Array[Ability]:
	var parsed_abilities: Array[Ability] = []
	if ability_string.is_empty():
		return parsed_abilities

	var ability_commands_packed: PackedStringArray = ability_string.split(",")
	var ability_commands	 : Array[String] = []
	ability_commands.assign(ability_commands_packed)
	for command : String in ability_commands:
		var command_parts: PackedStringArray = command.split(":")
		var ability_type: String = command_parts[0]
		var ability_args: PackedStringArray = []

		if command_parts.size() > 1:
			ability_args = command_parts[1].split(";")

		var new_ability: Ability = create_ability_from_type(ability_type, ability_args)
		if new_ability:
			parsed_abilities.append(new_ability)

	return parsed_abilities

static func create_ability_from_type(ability_type: String, args: PackedStringArray) -> Ability:
	var new_ability: Ability = null
	match ability_type:
		"guard":
			var health_bonus: int = int(args[0])
			new_ability = DeathTriggerHealthAbility.new(health_bonus)
		"troll":
			var health_bonus: int = int(args[0])
			var attack_bonus: int = int(args[1])
			new_ability = EvilSynergyAbility.new(health_bonus, attack_bonus)
		"shield":
			new_ability = DamageShieldAbility.new()
		"merge_bonus":
			var health_bonus: int = int(args[0])
			var attack_bonus: int = int(args[1])
			new_ability = MergeBonusAbility.new(health_bonus, attack_bonus)
	return new_ability
