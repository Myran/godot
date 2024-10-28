extends CanvasLayer

var object_type = core.OBJECT_TYPE.BACKGROUND

func input_handling(new_state):
	print("Unhandled input handling disabled")
	$area_2d/collision_shape_2d.disabled = new_state

func _on_area_2d_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventScreenTouch:
		await get_tree().process_frame
		ui.action(ui.EVENT_TYPE.TOUCH,[self,_event])
