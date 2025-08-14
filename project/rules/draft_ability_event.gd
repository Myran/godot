class_name DraftAbilityEvent extends RefCounted

# Event context class encapsulating all draft-related ability event data
# Provides single-parameter API for draft ability processing

var position: int
var unit: Block
var draft_context: DraftContext
var event: core.CoreEvent
var phase: core.Tempus


func _init(
	pos: int = -1,
	unit_block: Block = null,
	context: DraftContext = null,
	evt: core.CoreEvent = null,
	ph: core.Tempus = core.Tempus.PRE
):
	position = pos
	unit = unit_block
	draft_context = context
	event = evt
	phase = ph


static func create(
	pos: int, unit_block: Block, context: DraftContext, evt: core.CoreEvent, ph: core.Tempus
) -> DraftAbilityEvent:
	"""Factory method for creating DraftAbilityEvent instances"""
	return DraftAbilityEvent.new(pos, unit_block, context, evt, ph)
