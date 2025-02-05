class_name Holder extends ColorRect

var object_type: int = core.ObjectType.CARD_HOLDER
var _content: Node2D = null  # Assuming card is a Node2D-derived type

func set_card(card: Node2D) -> bool:
	if _content != null:
		return false
	_content = card
	card.set_as_top_level(false)
	var p: Node = card.get_parent()
	if p != null:
		p.remove_child(card)
	get_node("%attach_point").add_child(card)
	pos_card_in_holder()
	card.holder = self
	card.block_context = Cards.CONTEXT.LINEUP
	return true

func get_card() -> Node2D:
	return _content

func pos_card_in_holder() -> void:
	_content.set_as_top_level(false)
	_content.position = Vector2.ZERO

func remove_card() -> void:
	_content = null

func _on_area_2d_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	if _event is InputEventScreenTouch:
		ui.action(ui.TouchEvent.new(self, _event))
