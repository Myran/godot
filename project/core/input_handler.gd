class_name InputHandler extends Node

const TAP_TIME = 0.25
var clicker
var last_touch_pos = null
var tap_timer = 0
var holding_item = null
var tap_state = core.TAP_STATE.IDLE
var dragging_cargo = null


func setup(_clicker) -> void:
	clicker = _clicker


func reset_inputs():
	last_touch_pos = null
	tap_timer = 0
	holding_item = null
	tap_state = core.TAP_STATE.IDLE
	dragging_cargo = null


func input(event):
	if (
		event is InputEventScreenDrag
		and (tap_state == core.TAP_STATE.HOLDING or tap_state == core.TAP_STATE.PRESSING)
	):
		last_touch_pos = event.position


func process(delta):
	if tap_state == core.TAP_STATE.PRESSING:
		tap_timer = tap_timer + delta
		if holding_item and last_touch_pos and tap_timer > 0.15:
			holding_item.set_global_position(
				lerp(holding_item.get_global_position(), last_touch_pos, 0.25)
			)
		if tap_timer > TAP_TIME:
			if holding_item:
				tap_state = core.TAP_STATE.HOLDING
				tap_timer = 0
				holding()
	elif tap_state == core.TAP_STATE.HOLDING:
		if last_touch_pos and dragging_cargo:
			dragging_cargo.set_global_position(
				lerp(dragging_cargo.get_global_position(), last_touch_pos, 0.99)
			)


func holding():
	var pos = holding_item.get_global_position()
	holding_item.set_as_top_level(true)
	holding_item.set_global_position(pos)
	dragging_cargo = holding_item
	dragging_cargo.set_process_input(false)
	holding_item = null


func touch_handler(event, interacted_object, current_context):
	var update_draft = false
	if event.pressed == true:
		match tap_state:
			core.TAP_STATE.IDLE:
				match interacted_object.object_type:
					core.OBJECT_TYPE.CARD:
						tap_state = core.TAP_STATE.PRESSING
						holding_item = interacted_object
					core.OBJECT_TYPE.CARD_HOLDER:
						pass
					core.OBJECT_TYPE.BLOCK_LOCKED:
						tap_state = core.TAP_STATE.PRESSING
	elif event.pressed == false:
		match tap_state:
			core.TAP_STATE.PRESSING:
				if interacted_object.object_type == core.OBJECT_TYPE.CARD:
					#card_pop.show_card(interacted_object)
#					current_context.add_event(DraftContext.Event.new(core.SOLVE_TYPE.UI,ui.EVENT_TYPE.SHOW_CARD,[interacted_object]))
					current_context.add_event(ui.ShowCardEvent.new(interacted_object))
					# #current_context.add_event(
					#{
					#solve_type = core.SOLVE_TYPE.UI,
					#event_type = ui.EVENT_TYPE.SHOW_CARD,
					#data = [interacted_object]
					#}
					#)
					current_context.solve_events()
					update_draft = true
				if interacted_object.object_type == core.OBJECT_TYPE.BLOCK_LOCKED:
#				core.action(core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT, [interacted_object, true])
					core.action(core.RemoveBlockFromDraft.new(interacted_object, true))
					update_draft = true

			core.TAP_STATE.HOLDING:
				if dragging_cargo.object_type == core.OBJECT_TYPE.CARD:
					dragging_cargo.set_process_input(true)
					var release_handled = false
					var dragging_card = dragging_cargo
					match interacted_object.object_type:
						core.OBJECT_TYPE.BACKGROUND:
							pass
						core.OBJECT_TYPE.CARD:
							if interacted_object == dragging_card:
								return false
						core.OBJECT_TYPE.CARD_HOLDER:
							var interacted_holder = interacted_object
							match dragging_card.block_context:
								Cards.CONTEXT.LINEUP:
									var prev_holder = dragging_card.holder
									if interacted_holder.set_card(dragging_card):
										prev_holder.remove_card()
										release_handled = true

								Cards.CONTEXT.DRAFT:
									if is_instance_valid(dragging_card):
										if clicker.has_card(dragging_card):
											release_handled = interacted_holder.set_card(
												dragging_card
											)
											if release_handled:
#												current_context.add_event(DraftContext.Event.new(core.SOLVE_TYPE.CORE,core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT,[dragging_card]))
												current_context.add_event(
													core.RemoveBlockFromDraft.new(dragging_card)
												)
												# #current_context.add_event(
												#{
												#solve_type = core.SOLVE_TYPE.CORE,
												#event_type =
												#core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT,
												#data = [dragging_card]
												#}
												#)
												current_context.solve_events()
												#current_context.add_event(DraftContext.Event.new(core.SOLVE_TYPE.CORE,core.EVENT_TYPE.LINEUP_ADD_CARD,[dragging_card]))
												current_context.add_event(
													core.LineupAddCardEvent.new(dragging_card)
												)
												# #current_context.add_event(
												#{
												#solve_type = core.SOLVE_TYPE.CORE,
												#event_type =
												#core.EVENT_TYPE.LINEUP_ADD_CARD,
												#data = [dragging_card]
												#}
												#)
												current_context.solve_events()
												update_draft = true

					if not release_handled:
						match dragging_card.block_context:
							Cards.CONTEXT.LINEUP:
								dragging_card.holder.pos_card_in_holder()
							Cards.CONTEXT.DRAFT:
								var pos = dragging_card.get_global_position()
								dragging_card.set_as_top_level(false)
								dragging_card.set_global_position(pos)
								update_draft = true
		reset_inputs()
	return update_draft
