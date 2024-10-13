extends Node

enum EVENT_TYPE{TEST,TOUCH,DRAG,UPGRADE,TAP_TAG,TAP_POP_CARD,REROLL,START_BATTLE,TRANSITION,DRAFT_HOLD_TOGGLED}
signal event

const SIGNAL_EVENT = "event"

func _ready():
	print("ui autoload ready")
