extends ColorRect

var object_type = core.ObjectType.CARD_HOLDER
var _content = null


func set_card(card):
	if _content != null:
		return false
	_content = card
	card.set_as_top_level(false)
	var p = card.get_parent()
	if p != null:
		p.remove_child(card)
	get_node("%attach_point").add_child(card)
	pos_card_in_holder()
	card.holder = self
	card.block_context = Cards.CONTEXT.LINEUP
	return true


func get_card():
	return _content


func pos_card_in_holder():
	_content.set_as_top_level(false)
	_content.position = Vector2.ZERO


func remove_card():
	_content = null


func _on_area_2d_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventScreenTouch:
		#ui.action(ui.EVENT_TYPE.TOUCH,[self,_event])
		ui.action(ui.TouchEvent.new(self, _event))
