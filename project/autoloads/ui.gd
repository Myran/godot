extends Node

enum EVENT_TYPE {
	TEST,
	TOUCH,
	DRAG,
	UPGRADE,
	TAP_TAG,
	TAP_POP_CARD,
	REROLL,
	START_BATTLE,
	TRANSITION,
	DRAFT_HOLD_TOGGLED,
	SHOW_CARD
}
signal event


class UIEvent:
	pass


class TouchEvent:
	extends UIEvent
	var sender: Variant
	var event: InputEvent

	func _init(_sender: Variant, _event: InputEvent) -> void:
		sender = _sender
		event = _event


class DragEvent:
	extends UIEvent
	var sender: Variant
	var event: InputEvent

	func _init(_sender: Variant, _event: InputEvent) -> void:
		sender = _sender
		event = _event


class DraftHolderToggledEvent:
	extends UIEvent
	var new_state: bool
	var col: int

	func _init(_new_state: bool, _col: int) -> void:
		new_state = _new_state
		col = _col


class ShowCardEvent:
	extends UIEvent
	var card_to_show: Variant  # inte optimal borde vara nåt annat, card.gd är inte Card

	func _init(_card: Variant) -> void:
		card_to_show = _card


class TransitionEvent:
	extends UIEvent
	var new_state: core.GAME_STATE

	func _init(_new_state) -> void:
		new_state = _new_state


class StartBattleEvent:
	extends UIEvent
	pass


class RerollEvent:
	extends UIEvent
	pass


class HideCardEvent:
	extends UIEvent
	pass


class UpgradeEvent:
	extends UIEvent
	pass


#const SIGNAL_EVENT = "event"
func action(_event: UIEvent):
	event.emit(_event)


func _ready():
	print("ui autoload ready")
