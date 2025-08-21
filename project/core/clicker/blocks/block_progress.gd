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
