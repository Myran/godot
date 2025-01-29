extends Node

signal event


class UIEvent:
	extends core.CoreEvent


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
	var new_state: core.GameState

	func _init(_new_state: core.GameState) -> void:
		new_state = _new_state


class StartBattleEvent:
	extends UIEvent


class RerollEvent:
	extends UIEvent


class HideCardEvent:
	extends UIEvent


class UpgradeEvent:
	extends UIEvent


func action(_event: UIEvent) -> void:
	event.emit(_event)


func _ready() -> void:
	print("ui autoload ready")
