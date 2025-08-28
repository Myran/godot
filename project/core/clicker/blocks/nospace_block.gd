class_name NoSpaceBlock extends Block


static func deserialize_from_dict(data: Dictionary, game: Game = null) -> Block:
	"""Nospace block deserialization - creates block and restores all properties"""
	if not game or not game.level_controller:
		Log.error(
			"Cannot deserialize nospace block - game/level_controller not available",
			{},
			["serialization", "error"]
		)
		return null

	var nospace_block: Block = game.level_controller._block_factory.create_nospace_block()
	if not nospace_block:
		Log.error("Failed to create nospace block from factory", {}, ["serialization", "error"])
		return null

	# Restore base properties using helper method
	nospace_block._restore_base_properties(data)

	Log.debug(
		"Nospace block deserialized",
		{"object_type": nospace_block.object_type, "block_context": nospace_block.block_context},
		["serialization", "nospace_block"]
	)

	return nospace_block
