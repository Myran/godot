class_name InputHandler extends Node

const TAP_TIME = 0.15
const DRAG_LERP = 0.25
var clicker: Clicker
var last_touch_pos: Vector2 = Vector2.ZERO
var tap_timer: float = 0
var empty_item := Empty.new()
var holding_item: Object = empty_item
var tap_state: core.TapState = core.TapState.IDLE
var dragging_cargo: Object = empty_item

class Empty:
	extends  Object

func setup(_clicker: Clicker) -> void:
	clicker = _clicker


func reset_inputs()-> void:
	last_touch_pos = Vector2.ZERO
	tap_timer = 0
	holding_item = empty_item
	tap_state = core.TapState.IDLE
	dragging_cargo = empty_item


func input(event: InputEvent)-> void:
	if (
		event is InputEventScreenDrag
		and (tap_state == core.TapState.HOLDING or tap_state == core.TapState.PRESSING)
	):
		last_touch_pos = event.position


func process(delta: float)-> void:
	if tap_state == core.TapState.PRESSING:
		tap_timer = tap_timer + delta
		if holding_item is not Empty and last_touch_pos != Vector2.ZERO and tap_timer > TAP_TIME:
			holding_item.set_global_position(
				lerp(holding_item.get_global_position(), last_touch_pos, DRAG_LERP)
			)
		if tap_timer > TAP_TIME:
			if holding_item is not Empty:
				tap_state = core.TapState.HOLDING
				tap_timer = 0
				holding()
	elif tap_state == core.TapState.HOLDING:
		if last_touch_pos != Vector2.ZERO and dragging_cargo is not Empty:
			dragging_cargo.set_global_position(
				lerp(dragging_cargo.get_global_position(), last_touch_pos, DRAG_LERP)
			)


func holding()-> void:
	var pos: Vector2 = holding_item.get_global_position()
	holding_item.set_as_top_level(true)
	holding_item.set_global_position(pos)
	dragging_cargo = holding_item
	dragging_cargo.set_process_input(false)
	holding_item = empty_item


func touch_handler(event: InputEvent, interacted_object: Object, current_context: Context)-> bool:
	var update_draft: bool = false
	if event.pressed == true:
		match tap_state:
			core.TapState.IDLE:
				match interacted_object.object_type:
					core.ObjectType.CARD:
						tap_state = core.TapState.PRESSING
						holding_item = interacted_object
					core.ObjectType.CARD_HOLDER:
						pass
					core.ObjectType.BLOCK_LOCKED:
						tap_state = core.TapState.PRESSING
	elif event.pressed == false:
		match tap_state:
			core.TapState.PRESSING:
				if interacted_object.object_type == core.ObjectType.CARD:
					current_context.add_event(ui.ShowCardEvent.new(interacted_object))
					current_context.solve_events()
					update_draft = true
				if interacted_object.object_type == core.ObjectType.BLOCK_LOCKED:
					core.action(core.RemoveBlockFromDraft.new(interacted_object, true))
					update_draft = true

			core.TapState.HOLDING:
				if dragging_cargo.object_type == core.ObjectType.CARD:
					dragging_cargo.set_process_input(true)
					var release_handled: bool = false
					var dragging_card: Card = dragging_cargo as Card
					match interacted_object.object_type:
						core.ObjectType.BACKGROUND:
							pass
						core.ObjectType.CARD:
							if interacted_object == dragging_card:
								return false
						core.ObjectType.CARD_HOLDER:
							var interacted_holder: Holder = interacted_object
							match dragging_card.block_context:
								Cards.CONTEXT.LINEUP:
									var prev_holder: Holder = dragging_card.holder
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
												current_context.add_event(
													core.RemoveBlockFromDraft.new(dragging_card)
												)
												current_context.solve_events()
												current_context.add_event(
													core.LineupAddCardEvent.new(dragging_card)
												)

												current_context.solve_events()
												update_draft = true

					if not release_handled:
						match dragging_card.block_context:
							Cards.CONTEXT.LINEUP:
								dragging_card.holder.pos_card_in_holder()
							Cards.CONTEXT.DRAFT:
								var pos: Vector2 = dragging_card.get_global_position()
								dragging_card.set_as_top_level(false)
								dragging_card.set_global_position(pos)
								update_draft = true
		reset_inputs()
	return update_draft
