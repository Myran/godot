class_name CardPop extends Control

@export var card_popup: PackedScene
var current_card: CardFullView


func _ready() -> void:
	visible = false


func show_card(_card: Card) -> void:
	setup_card(_card)
	show()


func setup_card(_card: Card) -> void:
	var new_card: CardFullView = card_popup.instantiate()
	add_child(new_card)
	new_card.setup_card(_card)
	if current_card:
		current_card.queue_free()
	current_card = new_card


func _on_popup_card_gui_input(event: InputEvent) -> void:
	Log.debug("Popup card input event", {"event_type": event.get_class()}, [Log.TAG_UI])
