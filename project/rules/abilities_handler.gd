class_name AbilitiesHandler extends Resource


static func parse_abilities(abstring: String) -> Array:
	var new_abilities: Array = []
	if abstring == "":
		return []

	# parse as csv
	var commands: Array = abstring.split(",")
	for command: String in commands:
		var command_parts: Array = command.split(":")
		var ability_name: String = command_parts[0]
		var argarray: Array = []

		if command_parts[1]:
			var args: String = command_parts[1]
			argarray = args.split(";")

		var new_ability: Ability = create_ability(ability_name, argarray)
		if new_ability:
			new_abilities.append(new_ability)
	return new_abilities


static func create_ability(ability_name: String, argarray: Array) -> Ability:
	#argarray kommer in som string
	var ret_ability: Ability = null
	match ability_name:
		"guard":
			var arg0: String = argarray[0]
			ret_ability = AbilityHealthOnDeath.new(int(arg0))
		"troll":
			var arg0: int = argarray[0]
			var arg1: int = argarray[1]
			ret_ability = AbilityTroll.new(arg0, arg1)
		"damage":
			#ret_ability = ability_damage.new(argarray[0])
			pass
	return ret_ability
