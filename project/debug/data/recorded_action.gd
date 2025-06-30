class_name RecordedAction
extends Resource

# Data structure for serializing Context.Event objects to JSON for recording system
# Uses var2str for complete event serialization

var event_class: String = ""
var event_serialized: String = ""
var sequence_number: int = 0
var timestamp_ms: int = 0


func _init(event: Context.Event = null, sequence: int = 0) -> void:
	Log.info("RecordedAction._init called", {"sequence": sequence}, ["debug", "recording", "init"])

	if not event:
		Log.error(
			"RecordedAction created with null event",
			{"sequence": sequence},
			["debug", "recording", "error"]
		)
		event_class = "NullEvent"
		event_serialized = ""
		sequence_number = sequence
		timestamp_ms = Time.get_ticks_msec()
		return

	# Use enhanced PickledGD for inner class serialization
	var pickler: Pickler = Pickler.new()

	# Register inner classes using enhanced PickledGD support
	# Note: These constructors are called during unpickling only
	pickler.register_inner_class("Context.Event", _create_context_event)
	pickler.register_inner_class("core.CoreEvent", _create_core_event)
	pickler.register_inner_class("core.UpgradeEvent", _create_upgrade_event)
	pickler.register_inner_class("core.RerollDraftEvent", _create_reroll_draft_event)
	pickler.register_inner_class("core.StatEffectEvent", _create_stat_effect_event)
	pickler.register_inner_class("core.MoveLineupCardEvent", _create_move_lineup_card_action)
	# LineupCardMoveEvent removed - using MoveLineupCardEvent for both PLAYER and SYSTEM_CASCADE
	pickler.register_inner_class("core.DraftColumnStateEvent", _create_draft_column_state_event)
	pickler.register_inner_class("core.LineupAddCardEvent", _create_lineup_add_card_event)
	pickler.register_inner_class("core.RemoveBlockFromDraft", _create_remove_block_from_draft_event)
	pickler.register_inner_class("ui.TransitionEvent", _create_transition_event)
	pickler.register_inner_class("ui.RerollEvent", _create_ui_reroll_event)
	pickler.register_inner_class("ui.UpgradeEvent", _create_ui_upgrade_event)

	# Use explicit type checking to avoid PickledGD enhanced class name confusion
	# This is more reliable than the enhanced detection for structurally similar classes
	if event is core.MoveLineupCardEvent:
		event_class = "core.MoveLineupCardEvent"
		Log.info("Detected MoveLineupCardEvent", {}, ["debug", "recording", "type_fix"])
	# LineupCardMoveEvent removed - using MoveLineupCardEvent for both PLAYER and SYSTEM_CASCADE
	elif event is core.DraftColumnStateEvent:
		event_class = "core.DraftColumnStateEvent"
	elif event is core.LineupAddCardEvent:
		event_class = "core.LineupAddCardEvent"
	elif event is core.RemoveBlockFromDraft:
		event_class = "core.RemoveBlockFromDraft"
	elif event is core.StatEffectEvent:
		event_class = "core.StatEffectEvent"
	elif event is core.UpgradeEvent:
		event_class = "core.UpgradeEvent"
	elif event is core.RerollDraftEvent:
		event_class = "core.RerollDraftEvent"
	elif event is ui.TransitionEvent:
		event_class = "ui.TransitionEvent"
	elif event is ui.RerollEvent:
		event_class = "ui.RerollEvent"
	elif event is ui.UpgradeEvent:
		event_class = "ui.UpgradeEvent"
	elif event is core.CoreEvent:
		event_class = "core.CoreEvent"
	elif event is Context.Event:
		event_class = "Context.Event"
	else:
		# Fallback to enhanced class name detection for unknown types
		var enhanced_class_name: StringName = pickler.get_object_class_name(event)
		event_class = (
			str(enhanced_class_name)
			if not enhanced_class_name.is_empty()
			else str(event.get_class())
		)

	# Serialize using PickledGD with PackedByteArray converted to string
	var serialized_bytes: PackedByteArray = pickler.pickle(event)
	event_serialized = Marshalls.raw_to_base64(serialized_bytes)

	Log.debug(
		"Enhanced PickledGD serialization",
		{
			"original_type": str(type_string(typeof(event))),
			"original_class": str(event.get_class()),
			"enhanced_class_name": event_class,
			"serialized_bytes_length": serialized_bytes.size(),
			"serialized_string_length": event_serialized.length(),
			"serialized_preview": _get_serialized_preview(event_serialized)
		},
		["debug", "recording", "enhanced_picklegd_serialize"]
	)
	sequence_number = sequence
	timestamp_ms = Time.get_ticks_msec()

	Log.debug(
		"Event serialized with Enhanced PickledGD",
		{
			"event_class": event_class,
			"sequence": sequence,
			"serialized_length": event_serialized.length(),
			"event_type": str(type_string(typeof(event))),
			"is_resource": event is Resource,
			"uses_explicit_typing": true
		},
		["debug", "recording", "enhanced_serialize"]
	)


func to_dictionary() -> Dictionary:
	return {
		"event_class": event_class,
		"event_serialized": event_serialized,
		"sequence_number": sequence_number,
		"timestamp_ms": timestamp_ms
	}


static func from_dictionary(data: Dictionary) -> RecordedAction:
	var action: RecordedAction = RecordedAction.new()
	action.event_class = data.get("event_class", "UnknownEvent")
	action.event_serialized = data.get("event_serialized", "")
	action.sequence_number = data.get("sequence_number", 0)
	action.timestamp_ms = data.get("timestamp_ms", 0)
	return action


func deserialize_event() -> Context.Event:
	if event_serialized.is_empty():
		Log.error(
			"Cannot deserialize empty event",
			{"event_class": event_class, "sequence": sequence_number},
			["debug", "recording", "deserialize", "error"]
		)
		return null

	# Use enhanced PickledGD for inner class deserialization
	var pickler: Pickler = Pickler.new()

	# Register the same inner classes using enhanced PickledGD support
	# Note: These constructors are called during unpickling only
	pickler.register_inner_class("Context.Event", _create_context_event)
	pickler.register_inner_class("core.CoreEvent", _create_core_event)
	pickler.register_inner_class("core.UpgradeEvent", _create_upgrade_event)
	pickler.register_inner_class("core.RerollDraftEvent", _create_reroll_draft_event)
	pickler.register_inner_class("core.StatEffectEvent", _create_stat_effect_event)
	pickler.register_inner_class("core.MoveLineupCardEvent", _create_move_lineup_card_action)
	# LineupCardMoveEvent removed - using MoveLineupCardEvent for both PLAYER and SYSTEM_CASCADE
	pickler.register_inner_class("core.DraftColumnStateEvent", _create_draft_column_state_event)
	pickler.register_inner_class("core.LineupAddCardEvent", _create_lineup_add_card_event)
	pickler.register_inner_class("core.RemoveBlockFromDraft", _create_remove_block_from_draft_event)
	pickler.register_inner_class("ui.TransitionEvent", _create_transition_event)
	pickler.register_inner_class("ui.RerollEvent", _create_ui_reroll_event)
	pickler.register_inner_class("ui.UpgradeEvent", _create_ui_upgrade_event)

	# Convert base64 string back to PackedByteArray and deserialize
	var serialized_bytes: PackedByteArray = Marshalls.base64_to_raw(event_serialized)
	var deserialized_event: Context.Event = pickler.unpickle(serialized_bytes)

	Log.debug(
		"Enhanced PickledGD deserialization",
		{
			"event_class": event_class,
			"sequence": sequence_number,
			"serialized_bytes_length": serialized_bytes.size(),
			"deserialized_success": deserialized_event != null,
			"deserialized_type": _get_deserialized_type(deserialized_event),
			"deserialized_source": _get_deserialized_source(deserialized_event),
			"expected_class": event_class,
			"type_match": _get_deserialized_type(deserialized_event) == event_class
		},
		["debug", "recording", "enhanced_picklegd_deserialize"]
	)

	if not deserialized_event:
		Log.error(
			"Enhanced PickledGD deserialization failed",
			{"event_class": event_class, "sequence": sequence_number},
			["debug", "recording", "deserialize", "error"]
		)
		return null

	# Accept any valid deserialized object - PickledGD preserves data even if type reconstruction fails
	# The event system can work with the data regardless of exact type inheritance

	# Critical fix: Verify that PickledGD restored the correct specific type
	# If not, this indicates a PickledGD issue with inner class reconstruction
	if event_class != "Context.Event" and deserialized_event.get_class() == "Resource":
		Log.warning(
			"PickledGD type reconstruction issue - got generic Resource instead of specific type",
			{
				"event_class": event_class,
				"expected_specific_type": event_class,
				"actual_type": deserialized_event.get_class(),
				"sequence": sequence_number,
				"workaround": "event_still_functional_but_type_checking_may_fail"
			},
			["debug", "recording", "deserialize", "picklegd_issue"]
		)

	return deserialized_event


# Helper factory functions for PickledGD inner class registration
static func _create_context_event() -> Context.Event:
	return Context.Event.new()


static func _create_core_event() -> core.CoreEvent:
	return core.CoreEvent.new()


static func _create_upgrade_event() -> core.UpgradeEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.UpgradeEvent.new(1)


static func _create_reroll_draft_event() -> core.RerollDraftEvent:
	return core.RerollDraftEvent.new()


static func _create_stat_effect_event() -> core.StatEffectEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.StatEffectEvent.new(null, 0, 0, core.EventSource.SYSTEM_CASCADE)


# LineupCardMoveEvent factory removed - using MoveLineupCardEvent for both PLAYER and SYSTEM_CASCADE


static func _create_move_lineup_card_action() -> core.MoveLineupCardEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.MoveLineupCardEvent.new(null, -1, -1)


static func _create_draft_column_state_event() -> core.DraftColumnStateEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.DraftColumnStateEvent.new(-1, false)


static func _create_lineup_add_card_event() -> core.LineupAddCardEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.LineupAddCardEvent.new(null)


static func _create_remove_block_from_draft_event() -> core.RemoveBlockFromDraft:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.RemoveBlockFromDraft.new(null)


static func _create_transition_event() -> Context.Event:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return ui.TransitionEvent.new(core.GameState.START)


static func _create_ui_reroll_event() -> ui.RerollEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return ui.RerollEvent.new()


static func _create_ui_upgrade_event() -> ui.UpgradeEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return ui.UpgradeEvent.new()


func _get_serialized_preview(serialized_text: String) -> String:
	if serialized_text.length() > 50:
		return serialized_text.left(50)
	else:
		return serialized_text


func _get_deserialized_type(deserialized_event: Variant) -> String:
	if deserialized_event != null:
		return str(deserialized_event.get_class())
	else:
		return "null"


func _get_deserialized_source(deserialized_event: Variant) -> String:
	if deserialized_event != null:
		return str(deserialized_event.source)
	else:
		return "null"
