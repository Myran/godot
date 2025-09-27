class_name Block extends TouchScreenButton

signal movement_done

const MOVE_SPEED: float = 0.05
const MERGE_SPEED: float = 0.15
const TOP_MOVE_SPEED: float = 0.15

@export var object_type: core.ObjectType = core.ObjectType.TEST
var holder: Holder = null
var block_context: Cards.CONTEXT = Cards.CONTEXT.NOT_SET


func _ready() -> void:
	pass


func shake(left: bool = true) -> void:
	var shake_tween: Tween = create_tween()
	var block_tween: Tween = create_tween()
	var fade_length: float = 1.1

	@warning_ignore("return_value_discarded")
	block_tween.tween_property(self, "modulate", Color(0, 0, 0, 0), fade_length).set_trans(
		Tween.TRANS_QUINT
	)
	var card_image_base: SmallBase = %card_image_base
	var vignette: ColorRect = card_image_base.get_vignette_shader_node()
	var vig_tween: Tween = create_tween()
	@warning_ignore("return_value_discarded")
	(
		vig_tween
		. tween_property(
			vignette.material, "shader_parameter/vignette_rgb", Color(0, 0, 0, 0), fade_length
		)
		. set_trans(Tween.TRANS_QUINT)
	)
	@warning_ignore("return_value_discarded")
	vig_tween.chain().tween_callback(
		func() -> void:
			var mat: ShaderMaterial = vignette.material
			mat.set_shader_parameter("vignette_rgb", Color(0, 0, 0, 1))
	)

	if left:
		self.rotation_degrees = wrapi(0, 0, 360)  # Set initial rotation if needed
		@warning_ignore("return_value_discarded")
		(
			shake_tween
			. tween_property(self, "rotation_degrees", wrapi(120, 0, 360), fade_length)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	else:
		self.rotation_degrees = 360  # Set initial rotation
		@warning_ignore("return_value_discarded")
		(
			shake_tween
			. tween_property(self, "rotation_degrees", 140, fade_length)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	await block_tween.finished
	block_kill()


func move_to_position(new_position: Vector2) -> void:
	var time: float = abs(((new_position - position).y / texture_normal.get_height()) * MOVE_SPEED)

	var scene_tween: Tween = create_tween()

	@warning_ignore("return_value_discarded")
	scene_tween.tween_property(self, "position", new_position, time)
	@warning_ignore("return_value_discarded")
	scene_tween.tween_callback(func() -> void: movement_done.emit())

	if time != 0 and object_type == core.ObjectType.CARD:
		@warning_ignore("return_value_discarded")
		scene_tween.chain().tween_property(self, "scale", Vector2(1.05, 1.05), 0.08)
		@warning_ignore("return_value_discarded")
		scene_tween.chain().tween_property(self, "scale", Vector2(1, 1), 0.08)


func merge_into_position(merge_pos: Vector2) -> void:
	var scene_tween: Tween = create_tween()
	@warning_ignore("return_value_discarded")
	scene_tween.tween_property(self, "position", merge_pos, MERGE_SPEED)
	@warning_ignore("return_value_discarded")
	scene_tween.tween_callback(func() -> void: movement_done.emit())


func move_to_on_top(_pos: Vector2) -> void:
	var current_global_pos: Vector2 = get_global_position()
	set_as_top_level(true)
	set_global_position(current_global_pos)
	var scene_tween: Tween = create_tween()
	@warning_ignore("return_value_discarded")
	scene_tween.tween_property(self, "global_position", _pos, MERGE_SPEED)
	@warning_ignore("return_value_discarded")
	scene_tween.tween_callback(func() -> void: movement_done.emit())


func show_upgrade() -> Tween:
	var scene_tween: Tween = create_tween()
	@warning_ignore("return_value_discarded")
	scene_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	@warning_ignore("return_value_discarded")
	scene_tween.tween_property(self, "scale", Vector2(1, 1), 0.2)
	return scene_tween


func block_kill() -> void:
	movement_done.emit()
	queue_free()


func block_force_destroy_silent() -> void:
	"""
	Silent forceful block destruction for gamestate restoration.
	Does NOT emit any signals or trigger events - purely cleanup.
	"""
	# Clear any references without emitting signals
	holder = null
	block_context = Cards.CONTEXT.NOT_SET
	# Direct cleanup without events
	queue_free()


func _on_area_2d_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	if _event is InputEventScreenTouch:
		ui.action(ui.TouchEvent.new(self, _event))
	elif _event is InputEventScreenDrag:
		ui.action(ui.DragEvent.new(self, _event))


# Serialization Interface for Distributed Block-Level State Management
func serialize_to_dict() -> Dictionary:
	"""
	Virtual method for block-level serialization.
	Override in subclasses to include block-specific data.

	Returns basic block properties that all blocks need for restoration.
	"""
	return {
		"object_type": int(object_type),
		"draft_position": get_draft_position() if has_method("get_draft_position") else -1,
		"block_context": int(block_context) if block_context != Cards.CONTEXT.NOT_SET else 0
	}


func _restore_base_properties(data: Dictionary) -> void:
	"""
	Protected helper method to restore common block properties.
	Call this from subclass deserialization methods.
	"""
	var object_type_value: int = data.get("object_type", 0)
	if object_type_value > 0:
		object_type = object_type_value as core.ObjectType

	var block_context_value: int = data.get("block_context", 0)
	if block_context_value > 0:
		block_context = block_context_value as Cards.CONTEXT

	Log.debug(
		"Restored base block properties",
		{"object_type": object_type, "block_context": block_context},
		["serialization", "base_block"]
	)


static func deserialize_from_dict(data: Dictionary) -> Block:
	"""
	Virtual static method for block-level deserialization.
	Override in subclasses to handle block-specific restoration.

	Base implementation creates a generic block with basic properties.
	"""
	# This should be overridden in specific block classes
	# Base implementation returns null to force proper subclass implementation
	Log.warning(
		"Base Block.deserialize_from_dict called - should be overridden in subclasses",
		{"data": data},
		["serialization", "warning"]
	)
	return null


func get_draft_position() -> int:
	"""
	Helper method to get the current draft position of this block.
	Used by serialization to preserve block positioning.
	"""
	# Try to get position from parent clicker system
	var game: Game = _get_game_instance()
	if game and game.clicker and game.clicker.has_method("get_all_cards"):
		var all_blocks: Array[Block] = game.clicker.get_all_cards()
		for i: int in range(all_blocks.size()):
			if all_blocks[i] == self:
				return i
	return -1


static func _get_game_instance() -> Game:
	"""Helper method to get current Game instance"""
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene is Game:
		return current_scene as Game
	return null
