class_name EventCollection
extends BaseCollection

var _collection_key: String = ""


func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, [data_source.DEFAULT_SHEETS_ID], "events")
	_collection_key = "event_data_" + str(test_group)
	Log.info("EventCollection initialized", {"test_group": test_group}, [Log.TAG_DB])


func get_all() -> Array[Dictionary]:
	Log.info("Getting event data", {}, [Log.TAG_DB])
	@warning_ignore("redundant_await")
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)

	if result == null:
		Log.warning("No event data returned, using empty array", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return []

	if result is Array:
		var typed_result: Array[Dictionary] = []
		for item: Variant in result:
			if item is Dictionary:
				typed_result.append(item)
			else:
				Log.warning(
					"Skipped non-dictionary item in array",
					{"item_type": typeof(item)},
					[Log.TAG_DB, Log.TAG_WARNING]
				)
		return typed_result
	Log.error(
		"Expected Array but got different type",
		{"type": typeof(result)},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return []


func get_lineup_data(event: String) -> Dictionary:
	Log.info("Getting event lineups data", {"event": event}, [Log.TAG_DB])

	if not _backend.is_available():
		Log.error(
			"Database not available for getting event lineups", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return {}

	var path: Array[Variant] = ["events", event]
	@warning_ignore("redundant_await")
	var result: Variant = await _backend.get_data(path, "lineups")
	if result is Dictionary:
		return result
	return {}


func save_lineup_data(
	event: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	Log.info(
		"Saving event lineup data", {"event": event, "level": level, "lives": lives}, [Log.TAG_DB]
	)

	if not _backend.is_available():
		Log.error(
			"Cannot save event lineup - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return ""

	var json_data: String = JSON.stringify(lineup)
	var path: Array[Variant] = ["events", event, "lineups"]

	var data: Dictionary = {"lineup_level": level, "lineup_data": json_data, "lives": lives}

	if not p_data.is_empty():
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id

	var push_id: String
	if lineup_uuid.is_empty():
		@warning_ignore("redundant_await")
		push_id = await _backend.push_data(path, data)
	else:
		push_id = lineup_uuid
		var update_path: Array[Variant] = ["events", event, "lineups"]
		@warning_ignore("redundant_await")
		await _backend.set_data(update_path, push_id, data)

	Log.debug("Event lineup saved", {"event": event, "lineup_id": push_id}, [Log.TAG_DB])
	return push_id


func remove_event_lineups(event: String) -> bool:
	Log.info("Removing event lineups", {"event": event}, [Log.TAG_DB])

	if not _backend.is_available():
		Log.error(
			"Cannot remove event lineups - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return false

	var path: Array[Variant] = ["events", event]
	@warning_ignore("redundant_await")
	return await _backend.remove_data(path, "lineups")
