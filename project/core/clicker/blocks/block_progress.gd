extends Block
@export var level: int = 0


func serialize_to_dict() -> Dictionary:
	"""Override to include upgrade block level (set by scene)"""
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["level"] = level  # This is set by the scene file (1, 2, or 3)
	Log.debug(
		"Serializing upgrade block",
		{"level": level, "object_type": object_type},
		["serialization", "upgrade_block"]
	)
	return base_data


static func deserialize_from_dict(data: Dictionary, game: Game = null) -> Block:
	"""Upgrade block deserialization - creates block with proper level and restores all properties"""
	var upgrade_level: int = data.get("level", 1)

	# Create upgrade block using the game's level controller (proper factory approach)
	if not game or not game.level_controller:
		Log.error(
			"Cannot deserialize upgrade block - game/level_controller not available",
			{"level": upgrade_level},
			["serialization", "error"]
		)
		return null

	var upgrade_block: Block = game.level_controller.create_upgrade_block(upgrade_level)
	if not upgrade_block:
		Log.error(
			"Failed to create upgrade block from factory",
			{"level": upgrade_level},
			["serialization", "error"]
		)
		return null

	# Restore base properties using helper method
	upgrade_block._restore_base_properties(data)

	Log.debug(
		"Upgrade block deserialized",
		{
			"level": upgrade_block.level,
			"object_type": upgrade_block.object_type,
			"block_context": upgrade_block.block_context
		},
		["serialization", "upgrade_block"]
	)

	return upgrade_block
