class_name ItemBlock extends Block

@export var item_type: String = ""
@export var item_level: int = 1
@export var effect_data: Dictionary = {}


func _ready() -> void:
	super._ready()
	# Ensure object_type is set correctly for ITEM blocks
	object_type = core.ObjectType.BLOCK_ITEM


func serialize_to_dict() -> Dictionary:
	"""
	ITEM block specialized serialization.
	Captures item-specific state including type, level, and effect data.
	"""
	var base_data: Dictionary = super.serialize_to_dict()

	# Add ITEM-specific data
	base_data["item_type"] = item_type
	base_data["item_level"] = item_level
	base_data["effect_data"] = effect_data

	# Include level property for backward compatibility
	if has_method("get_level"):
		base_data["level"] = get_level()
	else:
		base_data["level"] = item_level

	Log.debug(
		"ItemBlock serialized",
		{
			"object_type": base_data["object_type"],
			"item_type": item_type,
			"level": base_data["level"]
		},
		["serialization", "item_block"]
	)

	return base_data


static func deserialize_from_dict(data: Dictionary) -> Block:
	"""
	ITEM block specialized deserialization.
	Restores item-specific state from serialized data.
	"""
	var item_block: ItemBlock = _create_item_block_instance()
	if not item_block:
		Log.error(
			"Failed to create ItemBlock instance during deserialization",
			{"data": data},
			["serialization", "error"]
		)
		return null

	# Restore basic block properties
	var object_type_value: int = data.get("object_type", 9)
	item_block.object_type = object_type_value as core.ObjectType

	var block_context_value: int = data.get("block_context", 0)
	if block_context_value > 0:
		item_block.block_context = block_context_value as Cards.CONTEXT

	# Restore ITEM-specific properties
	item_block.item_type = data.get("item_type", "")
	item_block.item_level = data.get("item_level", data.get("level", 1))
	item_block.effect_data = data.get("effect_data", {})

	# Note: level property will be handled by the ItemBlock's own properties

	Log.debug(
		"ItemBlock deserialized",
		{
			"object_type": item_block.object_type,
			"item_type": item_block.item_type,
			"level": item_block.item_level
		},
		["serialization", "item_block"]
	)

	return item_block


static func _create_item_block_instance() -> ItemBlock:
	"""
	Create a new ITEM block instance.
	Uses proper scene instantiation to ensure all UI components are initialized.
	"""
	# Use scene instantiation to ensure proper TouchScreenButton initialization
	const ITEM_BLOCK_SCENE: String = "res://core/clicker/blocks/block_items.tscn"
	var item_block_scene: PackedScene = load(ITEM_BLOCK_SCENE)
	if not item_block_scene:
		Log.error(
			"Failed to load ItemBlock scene",
			{"scene_path": ITEM_BLOCK_SCENE},
			["serialization", "error"]
		)
		return null
	
	var item_block: ItemBlock = item_block_scene.instantiate() as ItemBlock
	if not item_block:
		Log.error(
			"Failed to instantiate ItemBlock from scene",
			{"scene_path": ITEM_BLOCK_SCENE},
			["serialization", "error"]
		)
		return null
	
	item_block.object_type = core.ObjectType.BLOCK_ITEM
	return item_block


# NOTE: Block factory access is handled in the level_controller which is the calling context


func get_level() -> int:
	"""Compatibility method for level access"""
	return item_level


func set_level(new_level: int) -> void:
	"""Compatibility method for level setting"""
	item_level = new_level
