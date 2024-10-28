extends TouchScreenButton

const CARD_IMAGE_PREFIX = "card_image_"

@export_dir var card_image_folder : String
@export var move_speed: float = 0.05

var object_type = core.OBJECT_TYPE.CARD
var holder = null
var block_context = Cards.CONTEXT.NOT_SET
var level = 1
var card_info = null
var card_base = null
var merge_speed = 0.15
var top_move_speed = 0.15
var unit_info

func init_card(_card_info,_card_level = 1):

	card_info = _card_info
	level = _card_level

	unit_info = UnitData.new()
	unit_info.init_with_info(_card_info)
	unit_info.upgrade_unit_to_level(_card_level)

	var base = get_node("%card_image_base")
	card_base = base
	var img_string = card_controller.get_card_image_name(_card_info.id)
	base.set_card_img(img_string)

	base.set_upgrade_level(unit_info.card_info.upgrade_level)
	base.set_card_health(unit_info.current_health)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_level(unit_info.level)

func shake(left = true):
	var shake_tween = create_tween()
	var block_tween = create_tween()
	var fade_length = 1.1
	block_tween.tween_property(self,"modulate",Color(0,0,0,0),fade_length).set_trans(Tween.TRANS_QUINT)
	#block_tween.start()
	var vignette = %card_image_base.get_vignette_shader_node()
	var vig_tween = create_tween()
	vig_tween.tween_property(
		vignette.material,
		"shader_parameter/vignette_rgb",
		Color(0,0,0,0),
		fade_length).set_trans(Tween.TRANS_QUINT)

	vig_tween.chain().tween_callback(
		func():
			vignette.material.set_shader_parameter("vignette_rgb",Color(0,0,0,1)))
	if left:
		self.rotation_degrees = wrapi(0, 0, 360)  # Set initial rotation if needed
		shake_tween.tween_property(
			self,
			"rotation_degrees",
			wrapi(120, 0, 360),
			fade_length).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)
	else:
		self.rotation_degrees = 360  # Set initial rotation
		shake_tween.tween_property(
			self,
			"rotation_degrees",
			140,
			fade_length).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)
	#shake_tween.start()
	await block_tween.finished
	#await vig_tween.finished
	queue_free()


func move_to_position(new_position):
	#printt("move_to_position: ",self)
	var time = abs(((new_position-position).y / texture_normal.get_height()) * move_speed)
	var scene_tween = create_tween()
	scene_tween.tween_property(self,"position",new_position,time)
	scene_tween.tween_callback(func(): core.action(core.EVENT_TYPE.CARD_FINISHED_MOVING,self))
	if time != 0 and object_type == core.OBJECT_TYPE.CARD:
		scene_tween.chain().tween_property(self,"scale",Vector2(1.05,1.05),0.08)
		scene_tween.chain().tween_property(self,"scale",Vector2(1,1),0.08)

func merge_into_position(merge_pos):
	var scene_tween = create_tween()
	scene_tween.tween_property(self,"position",merge_pos,merge_speed)
	scene_tween.tween_callback(func(): core.action(core.EVENT_TYPE.CARD_MERGE_MOVE_FINISHED,self))


func move_to_on_top(_pos):
	var current_global_pos = get_global_position()
	set_as_top_level(true)
	set_global_position(current_global_pos)
	var scene_tween = create_tween()
	scene_tween.tween_property(self,"global_position",_pos,top_move_speed)
	scene_tween.tween_callback(func(): core.action(core.EVENT_TYPE.CARD_FINISHED_MOVING_TOP,self))

func show_upgrade():
	var scene_tween = create_tween()
	scene_tween.tween_property(self,"scale",Vector2(1.1,1.1),0.2)
	scene_tween.tween_property(self,"scale",Vector2(1,1),0.2)
	scene_tween.tween_callback(func(): core.action(core.EVENT_TYPE.MERGE_CARD_DONE,self))


func _on_area_2d_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventScreenTouch:
		ui.action(ui.EVENT_TYPE.TOUCH,[self,_event])
	elif _event is InputEventScreenDrag:
		ui.action(ui.EVENT_TYPE.DRAG,[self,_event])
