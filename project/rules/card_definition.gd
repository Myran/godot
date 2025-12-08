class_name CardDefinition
extends Resource
## Strongly-typed Resource class for card definitions.
##
## Replaces loose Dictionary usage (card_info) with compile-time type safety,
## editor auto-completion, and clear property definitions.
##
## Usage:
##   var card_def: CardDefinition = CardDefinition.from_dictionary(data)
##   var attack: int = card_def.base_attack  # Type-safe, auto-complete enabled

## Card unique identifier
@export var id: String = ""

## Display name shown to players
@export var card_name: String = ""

## Internal/technical name used for assets and references
@export var name: String = ""

## Card flavor/description text
@export var description: String = ""

## Base health value (converted from string in data source)
@export var base_health: int = 1

## Base attack value (converted from string in data source)
@export var base_attack: int = 1

## Ability definition string (e.g., "guard:1;1", "archer:1")
## Parsed by AbilitiesHandler.parse_ability_string()
@export var abilities_string: String = ""

## Comma-separated tags (e.g., "knight,evil", "forest")
@export var tags: String = ""

## Tribe classification (e.g., "soldier", "forest")
@export var tribe: String = ""

## Card tier/upgrade level (1, 2, or 3)
@export var upgrade_level: int = 1


static func from_dictionary(data: Dictionary) -> CardDefinition:
	"""Create CardDefinition from legacy Dictionary format (Firebase/JSON data)."""
	var def: CardDefinition = CardDefinition.new()
	def.id = str(data.get("id", ""))
	def.card_name = str(data.get("card_name", ""))
	def.name = str(data.get("name", ""))
	def.description = str(data.get("description", ""))

	# Convert string values to integers (data source stores as strings)
	var health_str: String = str(data.get("health", "1"))
	def.base_health = health_str.to_int() if health_str.is_valid_int() else 1

	var attack_str: String = str(data.get("attack", "1"))
	def.base_attack = attack_str.to_int() if attack_str.is_valid_int() else 1

	def.abilities_string = str(data.get("abilities", ""))
	def.tags = str(data.get("tags", ""))
	def.tribe = str(data.get("tribe", ""))

	var level_str: String = str(data.get("upgrade_level", "1"))
	def.upgrade_level = level_str.to_int() if level_str.is_valid_int() else 1

	return def


func to_dictionary() -> Dictionary:
	"""Convert back to Dictionary for backward compatibility with existing systems."""
	return {
		"id": id,
		"card_name": card_name,
		"name": name,
		"description": description,
		"health": str(base_health),
		"attack": str(base_attack),
		"abilities": abilities_string,
		"tags": tags,
		"tribe": tribe,
		"upgrade_level": str(upgrade_level)
	}


func get_tags_array() -> Array[String]:
	"""Parse comma-separated tags into typed array."""
	var result: Array[String] = []
	if tags.is_empty():
		return result
	var parts: PackedStringArray = tags.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


func has_tag(tag: String) -> bool:
	"""Check if card has a specific tag."""
	return get_tags_array().has(tag)


func is_valid() -> bool:
	"""Check if this CardDefinition has required fields populated."""
	return not id.is_empty() and not card_name.is_empty()


func _to_string() -> String:
	return (
		"CardDefinition(%s: %s, L%d, %d/%d)"
		% [id, card_name, upgrade_level, base_attack, base_health]
	)
