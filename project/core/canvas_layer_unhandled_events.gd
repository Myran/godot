extends CanvasLayer

var object_type: core.ObjectType = core.ObjectType.BACKGROUND

# func input_handling(new_stat):
# 	print("Unhandled input handling disabled")
# 	$area_2d/collision_shape_2d.disabled = new_state


func _on_area_2d_input_event(_viewport: Viewport, _event: InputEvent, _shape_idx: int) -> void:
	if _event is InputEventScreenTouch:
		await get_tree().process_frame
		#ui.action(ui.EVENT_TYPE.TOUCH,[self,_event])
		ui.action(ui.TouchEvent.new(self, _event))
