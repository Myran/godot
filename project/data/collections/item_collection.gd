class_name ItemCollection
extends BaseCollection

var _cache: Array[Dictionary] = []
var _is_cache_initialized: bool = false
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
		return _cache
		
	Log.info("Getting all items", {}, [Log.TAG_DB])
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	
	# Handle case where result is null
	if result == null:
		Log.warning("No item data returned, using empty array", {}, [Log.TAG_DB, Log.TAG_ERROR])
		_cache = []
	else:
		_cache = result
		
	_is_cache_initialized = true
	return _cache
	
## Get a specific item by ID
## @param item_id The ID of the item to retrieve
## @return Item dictionary or empty dictionary if not found
func get_by_id(item_id: String) -> Dictionary:
	Log.info("Getting item info", {"item_id": item_id}, [Log.TAG_DB])
	
	var items: Array[Dictionary] = await get_all()
	for item: Dictionary in items:
		if item.id == item_id:
			Log.debug("Item found", {"item_id": item_id}, [Log.TAG_DB])
			return item
			
	Log.error("Item with id not found", {"item_id": item_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}
	
## Get item ID from name
## @param item_name The name of the item to look up
## @return Item ID or empty string if not found
func get_id_by_name(item_name: String) -> String:
	Log.info("Getting item ID from name", {"name": item_name}, [Log.TAG_DB])
	
	var items: Array[Dictionary] = await get_all()
	for item: Dictionary in items:
		if item.name == item_name:
			Log.debug("Item name found", {"name": item_name, "id": item.id}, [Log.TAG_DB])
			return item.id
			
	Log.error("Item name not found", {"name": item_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""
	
## Clear the item cache
## @return void
func clear_cache() -> void:
	_is_cache_initialized = false
	_cache = []