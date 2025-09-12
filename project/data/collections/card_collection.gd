class_name CardCollection
extends BaseCollection

const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd")
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

var _is_cache_initialized: bool = false
var _collection_key: String = ""
var _card_cache: Array[Dictionary] = []


func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, [data_source.DEFAULT_SHEETS_ID], "cards")
	_collection_key = "cards_" + str(test_group)
	Log.info("CardCollection initialized", {"test_group": test_group}, [Log.TAG_DB])


func get_all(use_cache: bool = true) -> Array[Dictionary]:
	if use_cache and _is_cache_initialized:
		Log.debug(
			"Using card cache",
			{
				"cache_size": _card_cache.size(),
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB, Log.TAG_CACHE]
		)
		return _card_cache

	Log.info(
		"Getting all cards",
		{
			"use_cache": use_cache,
			"cache_initialized": _is_cache_initialized,
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(2)  # Show 2 frames of the stack
		},
		[Log.TAG_DB]
	)

	var request_start_time: int = Time.get_ticks_msec()

	var raw_result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time

	var result: Array[Dictionary]

	if raw_result != null and raw_result is Array:
		var array_result: Array = raw_result
		# Type-safe assignment for strongly typed Array[Dictionary]
		for item: Variant in array_result:
			if item is Dictionary:
				var dict_item: Dictionary = item
				result.append(dict_item)

		Log.debug(
			"Retrieved card data array directly",
			{
				"duration_ms": request_duration,
				"count": result.size(),
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)
	elif raw_result != null:
		var nav_result: NavigationResult = JSONPathNavigator.navigate(raw_result, [])

		if nav_result.found and nav_result.is_array():
			var nav_array: Array = nav_result.as_array()
			# Type-safe assignment for strongly typed Array[Dictionary]
			for item: Variant in nav_array:
				if item is Dictionary:
					var dict_item: Dictionary = item
					result.append(dict_item)

			Log.debug(
				"Retrieved card data via JSONPathNavigator",
				{
					"duration_ms": request_duration,
					"count": result.size(),
					"collection_name": _collection_name,
					"collection_id": get_instance_id()
				},
				[Log.TAG_DB]
			)
		else:
			Log.error(
				"Expected card data to be an array, got different type",
				{
					"result_type": nav_result.result_type,
					"collection_name": _collection_name,
					"collection_id": get_instance_id()
				},
				[Log.TAG_DB, Log.TAG_ERROR]
			)

	Log.debug(
		"Backend get_data call completed",
		{
			"duration_ms": request_duration,
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"result_null": result == null,
			"collection_id": get_instance_id()
		},
		[Log.TAG_DB]
	)

	if result == null:
		Log.error(
			"No card data returned",
			{
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"backend_class": _backend.get_class(),
				"collection_id": get_instance_id(),
				"stack_trace": _get_stack_trace(3)  # Show more stack frames for errors
			},
			[Log.TAG_DB, Log.TAG_ERROR]
		)

		var test_cards: Array[Dictionary] = []
		for i: int in range(5):
			test_cards.append(
				{
					"id": str(i),
					"name": "Test Card " + str(i),
					"type": "unit",
					"rarity": "common",
					"health": 10,
					"attack": 5,
					"abilities": ["none"],
					"level": 1,
					"stars": 1
				}
			)

		Log.warning(
			"Using emergency test cards for editor testing ONLY",
			{
				"count": test_cards.size(),
				"collection_name": _collection_name,
				"collection_id": get_instance_id(),
				"emergency_data": true
			},
			[Log.TAG_DB]
		)

		_card_cache = test_cards
	else:
		Log.debug(
			"Processing card data result",
			{
				"result_type": typeof(result),
				"is_array": result is Array,
				"result_size": result.size() if result is Array else 0,
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)

		_card_cache = result

	_is_cache_initialized = true

	Log.info(
		"Retrieved all cards",
		{
			"count": _card_cache.size(),
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"empty_result": _card_cache.size() == 0,
			"duration_ms": request_duration,
			"collection_id": get_instance_id()
		},
		[Log.TAG_DB]
	)

	if _card_cache.size() > 0:
		var sample_card: Dictionary = _card_cache[0]
		var sample_card_keys: Array[String]  # This is used in logging below
		sample_card_keys.assign(sample_card.keys())
		var required_keys: Array[String] = ["id", "name", "abilities", "health"]
		var missing_keys: Array[String] = []

		Log.debug(
			"Validating card data structure",
			{
				"sample_card_keys": sample_card_keys,
				"required_keys": required_keys,
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)

		for key: String in required_keys:
			if not sample_card.has(key):
				missing_keys.append(key)

		if missing_keys.size() > 0:
			Log.error(
				"Card data missing required fields",
				{
					"missing_keys": missing_keys,
					"available_keys": sample_card_keys,
					"collection_name": _collection_name,
					"collection_id": get_instance_id(),
					"stack_trace": _get_stack_trace(3)
				},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
		else:
			Log.debug(
				"Card data validation successful",
				{"collection_name": _collection_name, "collection_id": get_instance_id()},
				[Log.TAG_DB]
			)
	else:
		Log.warning(
			"No cards found to validate structure",
			{
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)

	return _card_cache


func _get_stack_trace(depth: int = 2) -> Array[Dictionary]:
	var stack: Array = get_stack()
	var simplified_stack: Array[Dictionary] = []

	for i: int in range(min(depth, stack.size())):
		if i >= stack.size():
			break

		var frame: Dictionary = stack[i]
		simplified_stack.append(
			{"function": frame.function, "file": frame.source.get_file(), "line": frame.line}
		)

	return simplified_stack


func get_by_id(card_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [Log.TAG_DB])

	var cards: Array[Dictionary] = await get_all(use_cache)
	for card: Dictionary in cards:
		var id: Variant = card.id
		if str(id) == str(card_id):
			Log.debug("Card found", {"card_id": card_id}, [Log.TAG_DB])
			return card

	Log.error("Card with id not found", {"card_id": card_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}


func get_id_by_name(card_name: String) -> String:
	Log.info("Getting card ID from name", {"name": card_name}, [Log.TAG_DB])

	var cards: Array[Dictionary] = await get_all()
	for card: Dictionary in cards:
		if card.name == card_name:
			Log.debug("Card name found", {"name": card_name, "id": card.id}, [Log.TAG_DB])
			return card.id

	Log.error("Card name not found", {"name": card_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""


func get_by_type(card_type: String) -> Array[Dictionary]:
	Log.info("Getting cards by type", {"type": card_type}, [Log.TAG_DB])

	var cards: Array[Dictionary] = await get_all()
	var filtered_cards: Array[Dictionary] = []

	for card: Dictionary in cards:
		if "type" in card and card.type == card_type:
			filtered_cards.append(card)

	Log.debug(
		"Found cards by type", {"type": card_type, "count": filtered_cards.size()}, [Log.TAG_DB]
	)
	return filtered_cards


func clear_cache() -> void:
	Log.info("Clearing card cache", {}, [Log.TAG_DB, Log.TAG_CACHE])
	_is_cache_initialized = false
	_card_cache = []
	super.clear_cache()
