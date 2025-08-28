extends Block


static func deserialize_from_dict(data: Dictionary, game: Game = null) -> Block:
	"""Locked block deserialization - creates block and restores all properties"""
	if not game or not game.level_controller:
		Log.error(
			"Cannot deserialize locked block - game/level_controller not available",
			{},
			["serialization", "error"]
		)
		return null
	
	var locked_block: Block = game.level_controller._block_factory.create_locked_block()
	if not locked_block:
		Log.error(
			"Failed to create locked block from factory",
			{},
			["serialization", "error"]
		)
		return null
	
	# Restore base properties using helper method
	locked_block._restore_base_properties(data)
	
	Log.debug(
		"Locked block deserialized",
		{"object_type": locked_block.object_type, "block_context": locked_block.block_context},
		["serialization", "locked_block"]
	)
	
	return locked_block