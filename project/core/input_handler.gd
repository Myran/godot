class_name InputHandler extends Object

const TAP_TIME = 0.25

var last_touch_pos = null
var tap_timer = 0
var holding_item = null
var tap_state = core.TAP_STATE.IDLE
var dragging_cargo = null
#var drag_start_pos = null

func reset_inputs():
	last_touch_pos = null
	tap_timer = 0
	holding_item = null
	tap_state = core.TAP_STATE.IDLE
	dragging_cargo = null
	#drag_start_pos = null
	

	
func input(event):
	if (event is InputEventScreenDrag and (tap_state == core.TAP_STATE.HOLDING or tap_state == core.TAP_STATE.PRESSING)):
		last_touch_pos = event.position
func process(delta):
	if tap_state == core.TAP_STATE.PRESSING:
		tap_timer = tap_timer + delta
		if holding_item and last_touch_pos and tap_timer> 0.15:
			holding_item.set_global_position(lerp(holding_item.get_global_position(),last_touch_pos,0.25))
		if tap_timer > TAP_TIME:
			if holding_item:
				tap_state = core.TAP_STATE.HOLDING
				tap_timer = 0
				holding()
	elif tap_state == core.TAP_STATE.HOLDING:
		if last_touch_pos and dragging_cargo:
				dragging_cargo.set_global_position(lerp(dragging_cargo.get_global_position(),last_touch_pos,0.99))
func holding():
	var pos = holding_item.get_global_position()
	holding_item.set_as_top_level(true)
	holding_item.set_global_position(pos)
	dragging_cargo = holding_item
	dragging_cargo.set_process_input(false)
	holding_item = null
