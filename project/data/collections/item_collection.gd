class_name ItemCollection
extends BaseCollection

# Import class references directly
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd")
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

## Collection class for item data.
## Provides access to item information with caching and validation.

var _item_cache: Array[Dictionary] = []

# Whether the cache has been initialized
var _is_cache_initialized: bool = false

# Key for retrieving item data
var _collection_key: String = ""


## Initialize the item collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, ["sheets"], "Items")
	_collection_key = "items_" + str(test_group)
	Log.info("ItemCollection initialized", {"test_group": test_group}, [Log.TAG_DB])


## Get all items
## @param use_cache Whether to use the cache if available
## @return Array of item dictionaries
func get_all(use_cache: bool = true) -> Array[Dictionary]:
	if use_cache and _is_cache_initialized:
		Log.debug(
			"Using item cache",
			{
				"cache_size": _item_cache.size(),
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB, Log.TAG_CACHE]
		)
		return _item_cache

	Log.info(
		"Getting all items",
		{
			"use_cache": use_cache,
			"cache_initialized": _is_cache_initialized,
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(2)
		},
		[Log.TAG_DB]
	)

	var request_start_time: int = Time.get_ticks_msec()
	var raw_result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time

	# Process the result using JSONPathNavigator for additional safety
	var result: Array[Dictionary]

	if raw_result != null and raw_result is Array:
		# Data is already an array - direct cast will crash if type is wrong (fail fast)
		result.assign(raw_result)

		Log.debug(
			"Retrieved item data array directly",
			{
				"duration_ms": request_duration,
				"count": result.size(),
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)
	elif raw_result != null:
		# Try to navigate using JSONPathNavigator
		var nav_result: NavigationResultClass = JSONPathNavigator.navigate(raw_result, [])

		if nav_result.found and nav_result.is_array():
			result = nav_result.as_array()

			Log.debug(
				"Retrieved item data via JSONPathNavigator",
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
				"Expected item data to be an array, got different type",
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

	# Handle case where result is null or not an array
	if result == null:
		Log.error(
			"No item data returned",
			{
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"backend_class": _backend.get_class(),
				"collection_id": get_instance_id(),
				"stack_trace": _get_stack_trace(3)  # Show more stack frames for errors
			},
			[Log.TAG_DB, Log.TAG_ERROR]
		)

		push_error(
			(
				"Required item data is missing for collection: "
				+ _collection_name
				+ " with key: "
				+ _collection_key
			)
		)

		# For editor testing, create minimal test items
		var test_items: Array[Dictionary] = []
		for i: int in range(5):
			test_items.append(
				{
					"id": str(i),
					"name": "Test Item " + str(i),
					"type": "consumable",
					"rarity": "common",
					"price": 10 * (i + 1),
					"description": "A test item for development",
					"effects": ["heal", "boost"]
				}
			)

		Log.warning(
			"Using emergency test items for editor testing ONLY",
			{
				"count": test_items.size(),
				"collection_name": _collection_name,
				"collection_id": get_instance_id(),
				"emergency_data": true
			},
			[Log.TAG_DB]
		)

		_item_cache = test_items
	else:
		Log.debug(
			"Processing item data result",
			{
				"result_type": typeof(result),
				"is_array": result is Array,
				"result_size": result.size() if result is Array else 0,
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)

		_item_cache = result

	_is_cache_initialized = true

	# Log detailed results
	Log.info(
		"Retrieved all items",
		{
			"count": _item_cache.size(),
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"empty_result": _item_cache.size() == 0,
			"duration_ms": request_duration,
			"collection_id": get_instance_id()
		},
		[Log.TAG_DB]
	)

	# Validate important fields in the items
	if _item_cache.size() > 0:
		var sample_item: Dictionary = _item_cache[0]
		var sample_item_keys: Array[String]
		sample_item_keys.assign(sample_item.keys())
		var required_keys: Array[String] = ["id", "name", "type"]
		var missing_keys: Array[String] = []

		Log.debug(
			"Validating item data structure",
			{
				"sample_item_keys": sample_item_keys,
				"required_keys": required_keys,
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB]
		)

		for key: String in required_keys:
			if not sample_item.has(key):
				missing_keys.append(key)

		if missing_keys.size() > 0:
			Log.error(
				"Item data missing required fields",
				{
					"missing_keys": missing_keys,
					"available_keys": sample_item_keys,
					"collection_name": _collection_name,
					"collection_id": get_instance_id(),
					"stack_trace": _get_stack_trace(3)
				},
				[Log.TAG_DB, Log.TAG_ERROR]
			)

			push_error(
				(
					"Item data missing required fields: "
					+ str(missing_keys)
					+ ". Available keys: "
					+ str(sample_item_keys)
				)
			)
		else:
			Log.debug(
				"Item data validation successful",
				{"collection_name": _collection_name, "collection_id": get_instance_id()},
				[Log.TAG_DB]
			)
	else:
		Log.warning(
			"No items found to validate structure",
			{
				"collection_name": _collection_name,
				"collection_key": _collection_key,
				"collection_id": get_instance_id()
			},
			[Log.TAG_DB, Log.TAG_WARNING]
		)

	return _item_cache


## Helper to get a simplified stack trace for debugging
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


## Get a specific item by ID
## @param item_id The ID of the item to retrieve
## @param use_cache Whether to use the cache if available
## @return Item dictionary or empty dictionary if not found
func get_by_id(item_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting item info", {"item_id": item_id, "use_cache": use_cache}, [Log.TAG_DB])

	var items: Array[Dictionary] = await get_all(use_cache)
	for item: Dictionary in items:
		if not item is Dictionary:
			continue

		var item_dict: Dictionary = item
		if not item_dict.has("id"):
			continue

		var id: String = str(item_dict.id)
		if id == item_id:
			Log.debug("Item found", {"item_id": item_id}, [Log.TAG_DB])
			return item_dict

	Log.error("Item with id not found", {"item_id": item_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}


## Get item ID from name
## @param item_name The name of the item to look up
## @param use_cache Whether to use the cache if available
## @return Item ID or empty string if not found
func get_id_by_name(item_name: String, use_cache: bool = true) -> String:
	Log.info("Getting item ID from name", {"name": item_name, "use_cache": use_cache}, [Log.TAG_DB])

	var items: Array[Dictionary] = await get_all(use_cache)
	for item: Dictionary in items:
		if not item is Dictionary:
			continue

		var item_dict: Dictionary = item
		if not item_dict.has("name"):
			continue

		if item_dict.name == item_name:
			Log.debug("Item name found", {"name": item_name, "id": item_dict.id}, [Log.TAG_DB])
			return str(item_dict.id)

	Log.error("Item name not found", {"name": item_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""


## Get items by type
## @param item_type The type of items to retrieve
## @param use_cache Whether to use the cache if available
## @return Array of item dictionaries matching the type
func get_by_type(item_type: String, use_cache: bool = true) -> Array[Dictionary]:
	Log.info("Getting items by type", {"type": item_type, "use_cache": use_cache}, [Log.TAG_DB])

	var items: Array[Dictionary] = await get_all(use_cache)
	var filtered_items: Array[Dictionary] = []

	for item: Dictionary in items:
		if not item is Dictionary:
			continue

		var item_dict: Dictionary = item
		if not item_dict.has("type"):
			continue

		if item_dict.type == item_type:
			filtered_items.append(item_dict)

	Log.debug(
		"Found items by type", {"type": item_type, "count": filtered_items.size()}, [Log.TAG_DB]
	)
	return filtered_items


## Get items by rarity
## @param rarity The rarity of items to retrieve
## @param use_cache Whether to use the cache if available
## @return Array of item dictionaries matching the rarity
func get_by_rarity(rarity: String, use_cache: bool = true) -> Array[Dictionary]:
	Log.info("Getting items by rarity", {"rarity": rarity, "use_cache": use_cache}, [Log.TAG_DB])

	var items: Array[Dictionary] = await get_all(use_cache)
	var filtered_items: Array[Dictionary] = []

	for item: Dictionary in items:
		if not item is Dictionary:
			continue

		var item_dict: Dictionary = item
		if not item_dict.has("rarity"):
			continue

		if item_dict.rarity == rarity:
			filtered_items.append(item_dict)

	Log.debug(
		"Found items by rarity", {"rarity": rarity, "count": filtered_items.size()}, [Log.TAG_DB]
	)
	return filtered_items


## Get items by price range
## @param min_price Minimum price (inclusive)
## @param max_price Maximum price (inclusive), or -1 for no upper limit
## @param use_cache Whether to use the cache if available
## @return Array of item dictionaries within the price range
func get_by_price_range(
	min_price: int, max_price: int = -1, use_cache: bool = true
) -> Array[Dictionary]:
	Log.info(
		"Getting items by price range",
		{"min_price": min_price, "max_price": max_price, "use_cache": use_cache},
		[Log.TAG_DB]
	)

	var items: Array[Dictionary] = await get_all(use_cache)
	var filtered_items: Array[Dictionary] = []

	for item: Dictionary in items:
		if not item is Dictionary:
			continue

		var item_dict: Dictionary = item
		if not item_dict.has("price"):
			continue

		var price: int
		if item_dict.price is int:
			price = item_dict.price
		elif item_dict.price is float:
			price = int(item_dict.price)
		elif item_dict.price is String and item_dict.price.is_valid_int():
			price = item_dict.price.to_int()
		else:
			continue

		if price >= min_price and (max_price < 0 or price <= max_price):
			filtered_items.append(item_dict)

	Log.debug(
		"Found items in price range",
		{"min_price": min_price, "max_price": max_price, "count": filtered_items.size()},
		[Log.TAG_DB]
	)

	return filtered_items


## Clear the item cache
## @return void
func clear_cache() -> void:
	Log.info("Clearing item cache", {}, [Log.TAG_DB, Log.TAG_CACHE])
	_is_cache_initialized = false
	_item_cache = []
	# Clear cache in parent class
	super.clear_cache()
