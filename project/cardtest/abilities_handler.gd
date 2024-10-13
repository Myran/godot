extends Resource
class_name abilities_handler

static func parse_abilities(abstring):
	var new_abilities= []
	if abstring == "": return []
	
	# parse as csv
	var commands = abstring.split(",")
	for command in commands:
		var command_parts = command.split(":")
		var ability_name = command_parts[0]
		var argarray = []
		if command_parts[1]:
			var args = command_parts[1]
			argarray = args.split(";") 
		var new_ability = create_ability(ability_name,argarray)
		if new_ability:
			new_abilities.append(new_ability)
	return new_abilities
	
static func create_ability(ability_name, argarray):
	#argarray kommer in som string 
	var ret_ability = null
	match ability_name:
		"guard":
			ret_ability = ability_health_on_death.new(int(argarray[0]))
			pass
		"troll":
			ret_ability = ability_troll.new(int(argarray[0]),int(argarray[1]))
		"damage":
			#ret_ability = ability_damage.new(argarray[0])
			pass
	return ret_ability
