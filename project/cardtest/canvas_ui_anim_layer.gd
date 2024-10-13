extends CanvasLayer

const TAG_ANIMATORS = "animator"
@export var speed: float = 0.15
@export var use_animate: bool = false
@export var min_dist: float = 0.1

func _ready():
	return
#	for animator in get_tree().get_nodes_in_group(TAG_ANIMATORS):
#		if animator.anim_layer_name != name:
#			continue
#		if !use_animate:
#			continue
#		var anim_pup = new_puppet(animator)
#		var org = animator.get_parent()
#		var start_node = $attach_points.get_node(animator.attach_point_name)
#		var start_pos = start_node.get_global_position() - org.rect_size/2
#		set_position_with_margin(anim_pup,start_pos,org)
#		org.modulate.a = 0


func _process(_delta):
	for animator in get_tree().get_nodes_in_group(TAG_ANIMATORS):
		if animator.anim_layer_name != name:
			continue
		if !animator.active:
			continue
		var org = animator.get_parent()
		var anim_pup = animator.anim_puppet
		var target

		if !use_animate:
			org.modulate.a = 1
			if anim_pup != null:
				remove_child(anim_pup)
			continue

		if org.visible:
			target = org.get_global_position()
		else:
			var start_node = $attach_points.get_node(animator.attach_point_name)
			target = start_node.get_global_position() - org.size/2

		if target != animator.last_pos and anim_pup == null and org.modulate.a == 1:
				anim_pup = new_puppet(animator)
				org.modulate.a = 0
				var pos = animator.last_pos
				var new_pos = animator.last_pos
				if pos == null:
					var start_node = $attach_points.get_node(animator.attach_point_name)
					pos = start_node.get_global_position() - org.size/2
				if new_pos == null:
					new_pos = pos
				set_position_with_margin(anim_pup,new_pos,org)
				animator.last_pos = target

		if anim_pup != null:
			if abs(anim_pup.get_global_position().distance_to(target)) > min_dist:
				var new_pos = anim_pup.get_global_position().lerp(target, speed)
				set_position_with_margin(anim_pup,new_pos,org)
			else:
				if anim_pup != null:
					animator.last_pos = target
					remove_child(anim_pup)
					anim_pup.queue_free()
					animator.anim_puppet = null
					org.modulate.a = 1



func new_puppet(animator):
		var anim_node = animator.get_parent()
		var anim_puppet = anim_node.duplicate(8)
		anim_puppet.set_process_input(false)
		anim_puppet.set_process_unhandled_input(false)
		anim_puppet.get_node("animator").remove_from_group("animator")
		anim_puppet.visible = true
		animator.anim_puppet = anim_puppet
		add_child(anim_puppet)
		return anim_puppet

func set_position_with_margin(_node,_new_pos,_margin_owner,_use_margin = true):
		_node.set_global_position(_new_pos,_use_margin)
		_node.offset_left = _margin_owner.offset_left
		_node.offset_top = _margin_owner.offset_top
		_node.offset_right = _margin_owner.offset_right
		_node.offset_bottom = _margin_owner.offset_bottom
