class_name RecordedAction
extends Resource

# Data structure for serializing Context.Event objects using RefSerializer
# Clean, simple serialization for inner class support

var event_class: String = ""
var event_data: Dictionary = {}
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
		event_data = {}
		sequence_number = sequence
		timestamp_ms = Time.get_ticks_msec()
		return

	# Ensure RefSerializer types are registered
	_ensure_types_registered()

	# Determine the type name based on the object's class/script
	var event_type_name: StringName = _get_simple_type_name(event)
	if event_type_name.is_empty():
		Log.error(
			"Cannot determine event type for serialization",
			{"event_class": event.get_class()},
			["debug", "recording", "error"]
		)
		event_class = "UnknownEvent"
		event_data = {}
		sequence_number = sequence
		timestamp_ms = Time.get_ticks_msec()
		return

	# Set RefSerializer type metadata before serialization
	event.set_meta(RefSerializer.TYPE_META, event_type_name)

	# Use RefSerializer for clean inner class serialization
	event_data = RefSerializer.serialize_object(event)
	event_class = event_data.get(RefSerializer.TYPE_KEY, "UnknownEvent")

	Log.debug(
		"RefSerializer serialization",
		{
			"original_type": str(type_string(typeof(event))),
			"original_class": str(event.get_class()),
			"event_class": event_class,
			"data_keys": event_data.keys(),
			"data_size": event_data.size()
		},
		["debug", "recording", "refserializer"]
	)

	sequence_number = sequence
	timestamp_ms = Time.get_ticks_msec()

	Log.debug(
		"Event serialized with RefSerializer",
		{
			"event_class": event_class,
			"sequence": sequence,
			"data_keys": event_data.keys(),
			"event_type": str(type_string(typeof(event))),
			"uses_refserializer": true
		},
		["debug", "recording", "refserializer_complete"]
	)


func to_dictionary() -> Dictionary:
	return {
		"event_class": event_class,
		"event_data": event_data,
		"sequence_number": sequence_number,
		"timestamp_ms": timestamp_ms
	}


static func from_dictionary(data: Dictionary) -> RecordedAction:
	var action: RecordedAction = RecordedAction.new()
	action.event_class = data.get("event_class", "UnknownEvent")
	action.event_data = data.get("event_data", {})
	action.sequence_number = data.get("sequence_number", 0)
	action.timestamp_ms = data.get("timestamp_ms", 0)
	return action


func deserialize_event() -> Context.Event:
	if event_data.is_empty():
		Log.error(
			"Cannot deserialize empty event data",
			{"event_class": event_class, "sequence": sequence_number},
			["debug", "recording", "deserialize", "error"]
		)
		return null

	# Ensure RefSerializer types are registered
	_ensure_types_registered()

	# Use RefSerializer for clean deserialization
	var deserialized_event: Context.Event = RefSerializer.deserialize_object(event_data)

	if deserialized_event == null:
		Log.error(
			"RefSerializer deserialization failed",
			{"event_class": event_class, "sequence": sequence_number},
			["debug", "recording", "deserialize", "error"]
		)
		return null

	Log.debug(
		"RefSerializer deserialization",
		{
			"event_class": event_class,
			"sequence": sequence_number,
			"data_keys": event_data.keys(),
			"deserialized_success": deserialized_event != null,
			"deserialized_type": str(deserialized_event.get_class()),
			"expected_class": event_class
		},
		["debug", "recording", "refserializer_deserialize"]
	)

	Log.info(
		"RefSerializer deserialization successful",
		{
			"event_class": event_class,
			"deserialized_type": deserialized_event.get_class(),
			"sequence": sequence_number,
			"type_preserved": true
		},
		["debug", "recording", "deserialize", "refserializer_success"]
	)

	return deserialized_event


# API compatibility alias for deserialization
func from_serialized_data() -> Context.Event:
	return deserialize_event()


# RefSerializer type registration - ensures all inner class types are registered
static var _types_registered: bool = false


static func _ensure_types_registered() -> void:
	if _types_registered:
		return

	# Register player action event classes with RefSerializer
	# Clean .new() calls thanks to default constructor parameters
	RefSerializer.register_type(&"core.UpgradeEvent", core.UpgradeEvent.new)
	RefSerializer.register_type(&"core.RerollDraftEvent", core.RerollDraftEvent.new)
	RefSerializer.register_type(&"core.MoveLineupCardEvent", core.MoveLineupCardEvent.new)
	RefSerializer.register_type(&"core.DraftColumnStateEvent", core.DraftColumnStateEvent.new)
	RefSerializer.register_type(&"core.LineupAddCardEvent", core.LineupAddCardEvent.new)
	RefSerializer.register_type(&"core.RemoveBlockFromDraft", core.RemoveBlockFromDraft.new)
	RefSerializer.register_type(&"ui.TransitionEvent", ui.TransitionEvent.new)
	RefSerializer.register_type(&"ui.RerollEvent", ui.RerollEvent.new)
	RefSerializer.register_type(&"ui.UpgradeEvent", ui.UpgradeEvent.new)

	_types_registered = true

	Log.info(
		"RefSerializer types registered",
		{"total_types": 8},
		["debug", "recording", "refserializer", "init"]
	)


# Get the type name using polymorphic method - compile-time type safety
static func _get_simple_type_name(event: Context.Event) -> StringName:
	# Use polymorphic method call instead of runtime type checking
	var type_name: StringName = event.get_serialization_type_name()

	if type_name.is_empty():
		Log.warning(
			"Event type not supported for serialization - only player action events allowed",
			{"event_class": event.get_class()},
			["debug", "recording", "type_identification"]
		)
		return &""

	return type_name
