class_name CardCollection
extends BaseCollection

# Import class references directly
const JSONPathNavigator = preload("res://data/backends/json_path_navigator.gd")
const NavigationResult = preload("res://data/backends/navigation_result.gd")

## Collection class for card data.
## Provides access to card information with caching and validation.

# Cache of retrieved cards
var _cache: Array = []

# Whether the cache has been initialized
var _is_cache_initialized: bool = false

# Key for retrieving card data
var _collection_key: String = ""

## Initialize the card collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, ["sheets"], "Cards")
	_collection_key = "cards_" + str(test_group)
	Log.info("CardCollection initialized", {"test_group": test_group}, [Log.TAG_DB])

## Get all cards
## @param use_cache Whether to use the cache if available
## @return Array of card dictionaries
func get_all(use_cache: bool = true) -> Array:
	var cache_key: String = "all_cards"
	
	# Try to get from cache first
	if use_cache and _has_in_cache(cache_key):
		var cached_cards: Array = _get_from_cache(cache_key, [])
		Log.debug("Using card cache", {
			"cache_size": cached_cards.size(),
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		return cached_cards
		
	Log.info("Getting all cards", {
		"use_cache": use_cache,
		"cache_initialized": _is_cache_initialized,
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"base_path": _base_path,
		"collection_id": get_instance_id(),
		"stack_trace": _get_stack_trace(2) # Show 2 frames of the stack
	}, [Log.TAG_DB])
	
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	Log.debug("Backend get_data call completed", {
		"duration_ms": request_duration,
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"result_null": result == null,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Handle case where result is null
	if result == null:
		Log.error("No card data returned", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"base_path": _base_path,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3) # Show more stack frames for errors
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		push_error("Required card data is missing for collection: " + _collection_name + " with key: " + _collection_key)
		
		# For editor testing, create minimal test cards
		var test_cards: Array = []
		for i in range(5):
			test_cards.append({
				"id": str(i),
				"name": "Test Card " + str(i),
				"type": "unit",
				"rarity": "common",
				"health": 10,
				"attack": 5,
				"abilities": ["none"],
				"level": 1,
				"stars": 1
			})
			
		Log.warning("Using emergency test cards for editor testing ONLY", {
			"count": test_cards.size(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"emergency_data": true
		}, [Log.TAG_DB])
		
		_cache = test_cards
	else:
		Log.debug("Processing card data result", {
			"result_type": typeof(result),
			"is_array": result is Array,
			"result_size": result.size() if result is Array else 0,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		# Use JSONPathNavigator for safe handling if result is not already an array
		if not (result is Array):
			Log.warning("Card data is not an array, attempting to navigate result", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_WARNING])
			
			var nav_result: NavigationResult = JSONPathNavigator.navigate(result, [])
			if nav_result.is_array():
				result = nav_result.as_array()
			elif nav_result.is_dictionary():
				# Try to extract cards from dictionary structure
				var cards_result: NavigationResult = JSONPathNavigator.navigate(nav_result.value, ["cards"])
				if cards_result.is_array():
					result = cards_result.as_array()
				else:
					# Use first array found in dictionary as fallback
					for key in nav_result.as_dictionary().keys():
						var value: Variant = nav_result.as_dictionary()[key]
						if value is Array:
							Log.warning("Using array found at key: " + str(key), {
								"collection_name": _collection_name,
								"collection_id": get_instance_id()
							}, [Log.TAG_DB, Log.TAG_WARNING])
							result = value
							break
		
		if result is Array:
			_cache = result
		else:
			Log.error("Failed to process card data", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_ERROR])
			_cache = []
		
	# Store in cache for future use
	_store_in_cache(cache_key, _cache)
	
	# Log detailed results
	Log.info("Retrieved all cards", {
		"count": _cache.size(),
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"empty_result": _cache.size() == 0,
		"duration_ms": request_duration,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Validate important fields in the cards
	if _cache.size() > 0:
		var sample_card: Dictionary = _cache[0]
		var sample_card_keys: Array = sample_card.keys()
		var required_keys: Array = ["id", "name", "abilities", "health"]
		var missing_keys: Array = []
		
		Log.debug("Validating card data structure", {
			"sample_card_keys": sample_card_keys,
			"required_keys": required_keys,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		for key in required_keys:
			if not sample_card.has(key):
				missing_keys.append(key)
				
		if missing_keys.size() > 0:
			Log.error("Card data missing required fields", {
				"missing_keys": missing_keys,
				"available_keys": sample_card_keys,
				"collection_name": _collection_name,
				"collection_id": get_instance_id(),
				"stack_trace": _get_stack_trace(3)
			}, [Log.TAG_DB, Log.TAG_ERROR])
			
			push_error("Card data missing required fields: " + str(missing_keys) + 
				". Available keys: " + str(sample_card_keys))
		else:
			Log.debug("Card data validation successful", {
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			}, [Log.TAG_DB])
	else:
		Log.warning("No cards found to validate structure", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
	
	return _cache
	
## Get a specific card by ID
## @param card_id The ID of the card to retrieve
## @param use_cache Whether to use the cache if available
## @return Card dictionary or empty dictionary if not found
func get_by_id(card_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [Log.TAG_DB])
	
	var cache_key: String = "card_" + card_id
	
	# Try to get from cache first
	if use_cache and _has_in_cache(cache_key):
		var cached_card: Dictionary = _get_from_cache(cache_key, {})
		if not cached_card.is_empty():
			Log.debug("Using cached card", {
				"card_id": card_id,
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_CACHE])
			return cached_card
	
	# Not in cache or cache disabled, search in all cards
	var cards: Array = await get_all(use_cache)
	for card in cards:
		if not card is Dictionary:
			continue
			
		var card_dict: Dictionary = card
		if not card_dict.has("id"):
			continue
			
		var id: String = str(card_dict.id)
		if id == card_id:
			Log.debug("Card found", {"card_id": card_id}, [Log.TAG_DB])
			
			# Store in cache for future use
			if use_cache:
				_store_in_cache(cache_key, card_dict)
				
			return card_dict
			
	Log.error("Card with id not found", {"card_id": card_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}
	
## Get card ID from name
## @param card_name The name of the card to look up
## @return Card ID or empty string if not found
func get_id_by_name(card_name: String) -> String:
	Log.info("Getting card ID from name", {"name": card_name}, [Log.TAG_DB])
	
	var cards: Array = await get_all()
	for card in cards:
		if not card is Dictionary:
			continue
			
		var card_dict: Dictionary = card
		if not card_dict.has("name"):
			continue
			
		if card_dict.name == card_name:
			Log.debug("Card name found", {"name": card_name, "id": card_dict.id}, [Log.TAG_DB])
			return str(card_dict.id)
			
	Log.error("Card name not found", {"name": card_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""
	
## Get cards by type
## @param card_type The type of cards to retrieve
## @return Array of card dictionaries matching the type
func get_by_type(card_type: String) -> Array:
	Log.info("Getting cards by type", {"type": card_type}, [Log.TAG_DB])
	
	var cards: Array = await get_all()
	var filtered_cards: Array = []
	
	for card in cards:
		if not card is Dictionary:
			continue
			
		var card_dict: Dictionary = card
		if card_dict.has("type") and card_dict.type == card_type:
			filtered_cards.append(card_dict)
			
	Log.debug("Found cards by type", {"type": card_type, "count": filtered_cards.size()}, [Log.TAG_DB])
	return filtered_cards
	
## Get cards by rarity
## @param rarity The rarity of cards to retrieve
## @return Array of card dictionaries matching the rarity
func get_by_rarity(rarity: String) -> Array:
	Log.info("Getting cards by rarity", {"rarity": rarity}, [Log.TAG_DB])
	
	var cards: Array = await get_all()
	var filtered_cards: Array = []
	
	for card in cards:
		if not card is Dictionary:
			continue
			
		var card_dict: Dictionary = card
		if card_dict.has("rarity") and card_dict.rarity == rarity:
			filtered_cards.append(card_dict)
			
	Log.debug("Found cards by rarity", {"rarity": rarity, "count": filtered_cards.size()}, [Log.TAG_DB])
	return filtered_cards

## Clear the card cache
## @return void
func clear_cache() -> void:
	Log.info("Clearing card cache", {
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_CACHE])
	
	# Clear legacy cache variables
	_is_cache_initialized = false
	_cache = []
	
	# Clear cache using cache manager
	super.clear_cache()
	
## Get full data for an array of card IDs
## @param card_ids Array of card IDs to get data for
## @return Array of card dictionaries
func get_cards_by_ids(card_ids: Array) -> Array:
	Log.info("Getting cards by IDs", {"id_count": card_ids.size()}, [Log.TAG_DB])
	
	var cards: Array = await get_all()
	var result_cards: Array = []
	var found_ids: Array = []
	
	for card in cards:
		if not card is Dictionary:
			continue
			
		var card_dict: Dictionary = card
		if not card_dict.has("id"):
			continue
			
		var id: String = str(card_dict.id)
		if card_ids.has(id):
			result_cards.append(card_dict)
			found_ids.append(id)
	
	var missing_ids: Array = []
	for id in card_ids:
		if not found_ids.has(id):
			missing_ids.append(id)
	
	if missing_ids.size() > 0:
		Log.warning("Some card IDs not found", {
			"missing_ids": missing_ids, 
			"found_count": result_cards.size(),
			"total_requested": card_ids.size()
		}, [Log.TAG_DB, Log.TAG_WARNING])
	else:
		Log.debug("All card IDs found", {"count": result_cards.size()}, [Log.TAG_DB])
		
	return result_cards
