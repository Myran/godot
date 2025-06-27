class_name RecordedAction
extends Resource

# Data structure for serializing Context.Event objects to JSON for recording system
# Uses var2str for complete event serialization

var event_class: String = ""
var event_serialized: String = ""
var sequence_number: int = 0
var timestamp_ms: int = 0


func _init(event: Context.Event = null, sequence: int = 0) -> void:
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
	pickler.register_inner_class("core.LineupCardMoveEvent", _create_lineup_card_move_event)
	pickler.register_inner_class("core.DraftColumnStateEvent", _create_draft_column_state_event)
	pickler.register_inner_class("core.LineupAddCardEvent", _create_lineup_add_card_event)
	pickler.register_inner_class("core.RemoveBlockFromDraft", _create_remove_block_from_draft_event)

	# Get enhanced class name for better identification
	var enhanced_class_name: StringName = pickler.get_object_class_name(event)
	event_class = (
		str(enhanced_class_name) if not enhanced_class_name.is_empty() else str(event.get_class())
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
			"serialized_preview":
			event_serialized.left(50) if event_serialized.length() > 50 else event_serialized
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
			"uses_inner_class": not enhanced_class_name.is_empty()
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
	pickler.register_inner_class("core.LineupCardMoveEvent", _create_lineup_card_move_event)
	pickler.register_inner_class("core.DraftColumnStateEvent", _create_draft_column_state_event)
	pickler.register_inner_class("core.LineupAddCardEvent", _create_lineup_add_card_event)
	pickler.register_inner_class("core.RemoveBlockFromDraft", _create_remove_block_from_draft_event)

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
			"deserialized_type":
			str(deserialized_event.get_class()) if deserialized_event != null else "null",
			"deserialized_source":
			str(deserialized_event.source) if deserialized_event != null else "null"
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

	if not deserialized_event is Context.Event:
		Log.error(
			"Enhanced PickledGD returned wrong type",
			{
				"event_class": event_class,
				"expected_type": "Context.Event",
				"actual_type": str(deserialized_event.get_class()),
				"sequence": sequence_number
			},
			["debug", "recording", "deserialize", "error"]
		)
		return null

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


static func _create_lineup_card_move_event() -> core.LineupCardMoveEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.LineupCardMoveEvent.new(null, -1, -1)


static func _create_draft_column_state_event() -> core.DraftColumnStateEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.DraftColumnStateEvent.new(-1, false)


static func _create_lineup_add_card_event() -> core.LineupAddCardEvent:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.LineupAddCardEvent.new(null)


static func _create_remove_block_from_draft_event() -> core.RemoveBlockFromDraft:
	# Default constructor for unpickling - actual data will be restored by PickledGD
	return core.RemoveBlockFromDraft.new(null)
