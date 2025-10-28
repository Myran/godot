class_name CardUtils
extends RefCounted

## Static utility functions for card image management
## Uses GameConstants.CardSystem for all constants


static func get_card_image_name(card_id: String) -> String:
	"""Generate card image path from card ID with debug variant support"""
	var asset_variant_value: int = 0  # Default value

	if DebugManager.get("asset_variant") != null:
		asset_variant_value = DebugManager.asset_variant

	return str(
		"res://assets/card_images/", "card_image_", asset_variant_value, "_", card_id, ".png"
	)  # CARD_IMAGE_FOLDER + CARD_IMAGE_PREFIX
