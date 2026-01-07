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
			var attack_bonus: int = int(params[1])
			new_ability = SoldierBonusAbility.new(health_bonus, attack_bonus)
		"troll":
			var health_bonus: int = int(params[0])
			var attack_bonus: int = int(params[1])
			new_ability = EvilSynergyAbility.new(health_bonus, attack_bonus)
		"shield":
			new_ability = DamageShieldAbility.new()
		"onanyupgrade":
			# Handle onanyupgrade:shield format
			if params.size() > 0 and params[0] == "shield":
				new_ability = DamageShieldAbility.new()
		"merge_bonus":
			var health_bonus: int = int(params[0])
			var attack_bonus: int = int(params[1])
			new_ability = MergeBonusAbility.new(health_bonus, attack_bonus)
		"harmony":
			new_ability = HarmonyAbility.new()
		"cleave":
			var health_bonus: int = 1
			var attack_bonus: int = 1
			if params.size() > 0:
				health_bonus = int(params[0])
			if params.size() > 1:
				attack_bonus = int(params[1])
			new_ability = BarbarianAbility.new(health_bonus, attack_bonus)
		"alternateattack":
			# Handle alternateattack:zap;damage format
			if params.size() >= 2 and params[0] == "zap":
				var zap_damage: int = int(params[1])
				new_ability = WizardAbility.new(zap_damage, 1)
		"damage":
			# Handle damage:frontandbackrow format (Spearman breakthrough)
			if params.size() > 0 and params[0] == "frontandbackrow":
				var breakthrough_damage: int = 1
				if params.size() > 1:
					breakthrough_damage = int(params[1])
				new_ability = SpearmanAbility.new(breakthrough_damage)
		"firststrike":
			# Handle firststrike:arrow_damage format (Archer ability)
			var arrow_damage: int = 1
			if params.size() > 0:
				arrow_damage = int(params[0])
			new_ability = ArcherAbility.new(arrow_damage)
		_:
			if not ability_type.is_empty():
				Log.warning(
					"Unknown ability type in create_ability_from_type",
					{"ability_type": ability_type, "params": params},
					["ability", "parsing", "warning"]
				)
	return new_ability
