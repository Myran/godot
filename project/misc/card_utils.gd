class_name CardUtils
extends RefCounted

## Static utility functions for card image management
## This replaces the global CardController pattern for utility functions

const CARD_IMAGE_PREFIX: String = "card_image_"
const CARD_IMAGE_FOLDER: String = "res://assets/card_images/"


static func get_card_image_name(card_id: String) -> String:
	"""Generate card image path from card ID with debug variant support"""
	var asset_variant_value: int = 0  # Default value

	if (
		DebugManager
		and DebugManager.has_method("get")
		and DebugManager.get("asset_variant") != null
	):
		asset_variant_value = DebugManager.asset_variant

	return str(CARD_IMAGE_FOLDER, CARD_IMAGE_PREFIX, asset_variant_value, "_", card_id, ".png")
