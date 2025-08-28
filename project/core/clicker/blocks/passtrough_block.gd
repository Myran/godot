extends Block


static func deserialize_from_dict(data: Dictionary, game: Game = null) -> Block:
	"""Passthrough block deserialization - creates block and restores all properties"""
	if not game or not game.level_controller:
		Log.error(
			"Cannot deserialize passthrough block - game/level_controller not available",
			{},
			["serialization", "error"]
		)
		return null
	
	var passtrough_block: Block = game.level_controller._block_factory.create_passtrough_block()
	if not passtrough_block:
		Log.error(
			"Failed to create passthrough block from factory",
			{},
			["serialization", "error"]
		)
		return null
	
	# Restore base properties using helper method
	passtrough_block._restore_base_properties(data)
	
	Log.debug(
		"Passthrough block deserialized",
		{"object_type": passtrough_block.object_type, "block_context": passtrough_block.block_context},
		["serialization", "passtrough_block"]
	)
	
	return passtrough_block