class_name Block extends TouchScreenButton

signal movement_done

const MOVE_SPEED: float = 0.05
const MERGE_SPEED = 0.15
const TOP_MOVE_SPEED = 0.15

@export var object_type = core.ObjectType.TEST
var holder = null
var block_context = Cards.CONTEXT.NOT_SET




func shake(left = true):
	var shake_tween = create_tween()
	var block_tween = create_tween()
	var fade_length = 1.1
	block_tween.tween_property(self, "modulate", Color(0, 0, 0, 0), fade_length).set_trans(
		Tween.TRANS_QUINT
	)
	var vignette = %card_image_base.get_vignette_shader_node()
	var vig_tween = create_tween()
	(
		vig_tween
		. tween_property(
			vignette.material, "shader_parameter/vignette_rgb", Color(0, 0, 0, 0), fade_length
		)
		. set_trans(Tween.TRANS_QUINT)
	)

	vig_tween.chain().tween_callback(
		func(): vignette.material.set_shader_parameter("vignette_rgb", Color(0, 0, 0, 1))
	)
	if left:
		self.rotation_degrees = wrapi(0, 0, 360)  # Set initial rotation if needed
		(
			shake_tween
			. tween_property(self, "rotation_degrees", wrapi(120, 0, 360), fade_length)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	else:
		self.rotation_degrees = 360  # Set initial rotation
		(
			shake_tween
			. tween_property(self, "rotation_degrees", 140, fade_length)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	await block_tween.finished
	queue_free()


func move_to_position(new_position):
	var time = abs(((new_position - position).y / texture_normal.get_height()) * MOVE_SPEED)
	var scene_tween = create_tween()
	scene_tween.tween_property(self, "position", new_position, time)
	scene_tween.tween_callback(func(): movement_done.emit())
	if time != 0 and object_type == core.ObjectType.CARD:
		scene_tween.chain().tween_property(self, "scale", Vector2(1.05, 1.05), 0.08)
		scene_tween.chain().tween_property(self, "scale", Vector2(1, 1), 0.08)


func merge_into_position(merge_pos):
	var scene_tween = create_tween()
	scene_tween.tween_property(self, "position", merge_pos, MERGE_SPEED)
	scene_tween.tween_callback(func(): movement_done.emit())


func move_to_on_top(_pos):
	var current_global_pos = get_global_position()
	set_as_top_level(true)
	set_global_position(current_global_pos)
	var scene_tween = create_tween()
	scene_tween.tween_property(self, "global_position", _pos, TOP_MOVE_SPEED)
	scene_tween.tween_callback(func(): movement_done.emit())


func show_upgrade():
	var scene_tween = create_tween()
	scene_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	scene_tween.tween_property(self, "scale", Vector2(1, 1), 0.2)
	return scene_tween


func _on_area_2d_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventScreenTouch:
		ui.action(ui.TouchEvent.new(self, _event))
	elif _event is InputEventScreenDrag:
		ui.action(ui.DragEvent.new(self, _event))
