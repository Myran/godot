extends Node

## DataSource manager for game data
## Provides centralized access to cards, levels, items, player data, etc.
## Hybrid implementation using collection-based architecture with backend factory

# Import required classes
const BackendFactoryClass = preload("res://data/backends/backend_factory.gd")
const DataBackendClass = preload("res://data/backends/data_backend.gd")
const LocalJSONBackendClass = preload("res://data/backends/local_json_backend.gd")

# Signals
signal startup_completed
# Signal below is used by Firebase connections - kept for compatibility with original code
@warning_ignore("unused_signal")
signal value_received(data: Dictionary)

# Constants (restored from original)
# Google Sheet ID from the JSON structure - explicitly typed constants
const SHEET_ID: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
const SHEETS: String = "sheets" # Legacy key - not used in actual JSON
const PLAYERS: String = "players"
const AVATAR_DATA: String = "avatar_data"
const EVENTS: String = "event_data_0"
const LEVELS: String = "levels_0"
const ITEMS: String = "items_0"
const RULES: String = "rules_0"
const _CARDS: String = "cards_0"

# Add helper function to check if we have game data
func has_game_data() -> bool:
	# Check if the backend has been initialized
	if _backend == null:
		return local_data.has(_CARDS) or local_data.has("cards_0") or local_data.has("cards")

	# Try to access data under the sheet ID
	var sheet_data_result: Variant = await _backend.get_data([], SHEET_ID)
	if sheet_data_result is Dictionary:
		return sheet_data_result.has(_CARDS) or sheet_data_result.has("cards_0") or sheet_data_result.has("cards")

	return false

# Collections with specific type annotations
var cards: CardCollectionImpl
var levels: LevelCollectionImpl
var items: ItemCollectionImpl
var players: PlayerCollectionImpl
var events: EventCollectionImpl
var rules: RulesCollectionImpl

# Internal state
var _backend: DataBackendClass
var using_local_data: bool = false
var _initialized: bool = false
var card_cache: Array = []
var local_data: Dictionary = {}
var test_group: int = 0
var default_db_file: String = "res://resources/data.json"
var battle_db_file: String = "res://resources/gameone-577cb-export.json"
var current_file: String = "res://resources/data.json"
var sheet_data: Dictionary = {}

func _ready() -> void:
	Log.info("DataSource initializing", {
		"version": "backend_factory_implementation",
		"os": OS.get_name(),
		"in_editor": OS.has_feature("editor"),
		"debug_build": OS.is_debug_build()
	}, [Log.TAG_DB, "initialization", "system"])

	_initialized = false

	# Initialize async
	await _initialize()

## Initialize the data source using BackendFactory
func _initialize() -> void:
	# Create backend with battle file as primary option
	Log.debug("Using battle database file", {"file": battle_db_file}, [Log.TAG_LOCAL, "initialization"])
	_backend = LocalJSONBackendClass.new(battle_db_file)
	var success: bool = await _backend.initialize()

	# Check for game data
	var has_data: bool = await has_game_data()

	# If initialization failed or we don't have game data, try default file
	if not success or not has_data:
		Log.warning("No game data found in battle DB file, trying standard data file", {}, [Log.TAG_LOCAL, "initialization"])
		_backend = LocalJSONBackendClass.new(default_db_file)
		await _backend.initialize()

	# Populate local_data for backward compatibility
	var backend_data: Variant = await _backend.get_data([], SHEET_ID)
	if backend_data is Dictionary:
		local_data = backend_data.duplicate()
		Log.debug("Populated local_data from backend", {"keys": local_data.keys()}, [Log.TAG_DB, "initialization"])

	# Track if we're using local data
	using_local_data = true

	# Create collections
	_initialize_collections()

	# Connect to backend signals
	_backend.startup_completed.connect(func() -> void:
		Log.info("DataSource initialization complete", {
			"using_local_data": using_local_data,
			"firebase_available": is_firebase_available(),
			"collections": [_CARDS, LEVELS, ITEMS, RULES, EVENTS]
		}, [Log.TAG_DB, Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])

		_finalize_init()
	)

class CardCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array[Dictionary] = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "cards_0") -> void:
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array[Dictionary]:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			Log.debug("Using card cache", {"cache_size": _cache.size()}, [Log.TAG_DB, Log.TAG_CACHE, "card", "performance"])
			return _cache

		# Use the backend to get data - access the Sheet ID directly
		var path: Array = []
		var key: String = SHEET_ID
		var sheet_data: Variant = await _parent._backend.get_data(path, key)
		var cards: Array[Dictionary] = []

		# Get cards data from the sheet data
		var cards_data: Variant = null
		if sheet_data is Dictionary and sheet_data.has(_collection_key):
			cards_data = sheet_data[_collection_key]

		# Convert to typed array
		if cards_data is Array:
			for card_item: Dictionary in cards_data:
				if card_item is Dictionary:
					cards.append(card_item)

		# If we didn't find any data, check if we have test data
		if (cards.is_empty() or cards.size() == 0) and _parent.has_method("_get_test_cards"):
			Log.warning("No card data found, using test cards", {}, [Log.TAG_DB, "card"])
			var test_cards: Array = _parent._get_test_cards()
			for card_item: Dictionary in test_cards:
				if card_item is Dictionary:
					cards.append(card_item)

		_cache = cards
		_is_cache_initialized = true

		Log.info("Retrieved all cards", {"count": cards.size()}, [Log.TAG_DB, "card"])
		return cards

	func get_by_id(card_id: String, use_cache: bool = true) -> Dictionary:
		Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [Log.TAG_DB, "card"])

		# Handle empty card_id case
		if card_id.is_empty():
			Log.error("Empty card_id provided", {}, [Log.TAG_DB, Log.TAG_ERROR, "card", "validation"])
			return {}

		var results: Array[Dictionary] = await get_all(use_cache)

		if results.is_empty():
			Log.error("No cards found in collection", {}, [Log.TAG_DB, Log.TAG_ERROR, "card"])
			return {}

		Log.debug("Searching through cards", {"count": results.size()}, [Log.TAG_DB, "card"])

		# First try integer comparison exactly like the original implementation
		for card: Dictionary in results:
			if not card.has("id"):
				continue

			var id: Variant = card.id
			# Safely convert to int using is_valid_int check
			if str(id).is_valid_int() and str(card_id).is_valid_int():
				if str(id).to_int() == str(card_id).to_int():
					Log.debug("Card found by int comparison", {"card_id": card_id, "card_id_value": card_id, "id_value": id}, [Log.TAG_DB, "card"])
					return card

		# If that fails, try string comparison as backup
		for card: Dictionary in results:
			if not card.has("id"):
				continue

			var id: Variant = card.id
			if str(id) == str(card_id):
				Log.debug("Card found by string comparison", {"card_id": card_id}, [Log.TAG_DB, "card"])
				return card

		Log.error("Card with id not found", {"card_id": card_id}, [Log.TAG_DB, Log.TAG_ERROR, "card"])
		return {}

	func get_id_by_name(card_name: String) -> String:
		Log.info("Getting card ID from name", {"name": card_name}, [Log.TAG_DB])

		var cards: Array[Dictionary] = await get_all()
		for card: Dictionary in cards:
			if not card.has("name"):
				continue

			if card.name == card_name:
				Log.debug("Card name found", {"name": card_name, "id": card.id}, [Log.TAG_DB])
				return card.id

		Log.error("Card name not found", {"name": card_name}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""

	func get_by_type(card_type: String) -> Array[Dictionary]:
		var filtered: Array[Dictionary] = []
		var cards: Array[Dictionary] = await get_all()
		for card: Dictionary in cards:
			if "type" in card and card.type == card_type:
				filtered.append(card)
		return filtered

	func clear_cache() -> void:
		_is_cache_initialized = false
		_cache = []

class LevelCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array[Dictionary] = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "levels_0") -> void:
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array[Dictionary]:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			return _cache

		# Use the backend to get data - access the Sheet ID directly
		var path: Array = []
		var key: String = SHEET_ID
		var sheet_data: Variant = await _parent._backend.get_data(path, key)
		var levels: Array[Dictionary] = []

		# Get levels data from the sheet data
		var levels_data: Variant = null
		if sheet_data is Dictionary and sheet_data.has(_collection_key):
			levels_data = sheet_data[_collection_key]

		# Convert to typed array
		if levels_data is Array:
			for level_item: Dictionary in levels_data:
				if level_item is Dictionary:
					levels.append(level_item)

		# If we didn't find any data, check if we have test data
		if levels.is_empty() and _parent.has_method("_get_test_levels"):
			Log.warning("No level data found, using test levels", {}, [Log.TAG_DB, "level"])
			var test_levels: Array = _parent._get_test_levels()
			for level_item: Dictionary in test_levels:
				if level_item is Dictionary:
					levels.append(level_item)

		_cache = levels
		_is_cache_initialized = true
		return levels

	func get_by_number(level_nr: int) -> Dictionary:
		Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB, "level"])

		var levels: Array = await get_all()
		for level: Dictionary in levels:
			if not level.has("id"):
				continue

			var id: Variant = level.id
			# Safely convert to int using is_valid_int check
			if str(id).is_valid_int():
				if str(id).to_int() == level_nr:
					Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB, "level"])
					return level

		Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB, "level"])
		return {}

	func clear_cache() -> void:
		_is_cache_initialized = false
		_cache = []

class ItemCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array[Dictionary] = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "items_0") -> void:
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array[Dictionary]:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			return _cache

		# Use the backend to get data - access the Sheet ID directly
		var path: Array = []
		var key: String = SHEET_ID
		var sheet_data: Variant = await _parent._backend.get_data(path, key)
		var items: Array[Dictionary] = []

		# Get items data from the sheet data
		var items_data: Variant = null
		if sheet_data is Dictionary and sheet_data.has(_collection_key):
			items_data = sheet_data[_collection_key]

		# Convert to typed array
		if items_data is Array:
			for item_item: Dictionary in items_data:
				if item_item is Dictionary:
					items.append(item_item)

		# If we didn't find any data, check if we have test data
		if items.is_empty() and _parent.has_method("_get_test_items"):
			Log.warning("No item data found, using test items", {}, [Log.TAG_DB, "item"])
			var test_items: Array = _parent._get_test_items()
			for item_item: Dictionary in test_items:
				if item_item is Dictionary:
					items.append(item_item)

		_cache = items
		_is_cache_initialized = true
		return items

	func get_by_id(item_id: String) -> Dictionary:
		Log.info("Getting item info", {"item_id": item_id}, [Log.TAG_DB, "item"])

		var items: Array[Dictionary] = await get_all()
		for item: Dictionary in items:
			if not item.has("id"):
				continue

			if str(item.id) == str(item_id):
				Log.debug("Item found", {"item_id": item_id}, [Log.TAG_DB, "item"])
				return item

		Log.error("Item with id not found", {"item_id": item_id}, [Log.TAG_DB, Log.TAG_ERROR, "item"])
		return {}

	func get_id_by_name(item_name: String) -> String:
		Log.info("Getting item ID from name", {"name": item_name}, [Log.TAG_DB])

		var items: Array[Dictionary] = await get_all()
		for item: Dictionary in items:
			if not item.has("name"):
				continue

			if item.name == item_name:
				Log.debug("Item name found", {"name": item_name, "id": item.id}, [Log.TAG_DB])
				return item.id

		Log.error("Item name not found", {"name": item_name}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""

	func clear_cache() -> void:
		_is_cache_initialized = false
		_cache = []

class RulesCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String

	func _init(parent: Node, collection_key: String = "rules_0") -> void:
		_parent = parent
		_collection_key = collection_key

	func get_rules() -> Dictionary:
		# Use the backend to get data - access the Sheet ID directly
		var path: Array = []
		var key: String = SHEET_ID
		var sheet_data: Variant = await _parent._backend.get_data(path, key)
		var rules: Dictionary = {}

		# Get rules data from the sheet data
		var rules_data: Variant = null
		if sheet_data is Dictionary and sheet_data.has(_collection_key):
			rules_data = sheet_data[_collection_key]

		# Handle array response (keep first item as dictionary)
		if rules_data is Array and rules_data.size() > 0:
			if rules_data[0] is Dictionary:
				rules = rules_data[0]
		elif rules_data is Dictionary:
			rules = rules_data

		# If we didn't find any data, check if we have test data
		if rules.is_empty() and _parent.has_method("_get_test_rules"):
			Log.warning("No rules data found, using test rules", {}, [Log.TAG_DB, "rules"])
			rules = _parent._get_test_rules()

		return rules

class EventCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String

	func _init(parent: Node, collection_key: String = "event_data_0") -> void:
		_parent = parent
		_collection_key = collection_key

	func get_all() -> Array[Dictionary]:
		# Use the backend to get data - access the Sheet ID directly
		var path: Array = []
		var key: String = SHEET_ID
		var sheet_data: Variant = await _parent._backend.get_data(path, key)
		var events: Array[Dictionary] = []

		# Get events data from the sheet data
		var events_data: Variant = null
		if sheet_data is Dictionary and sheet_data.has(_collection_key):
			events_data = sheet_data[_collection_key]

		# Convert to typed array
		if events_data is Array:
			for event_item: Dictionary in events_data:
				if event_item is Dictionary:
					events.append(event_item)

		# If we didn't find any data, check if we have test data
		if events.is_empty() and _parent.has_method("_get_test_events"):
			Log.warning("No event data found, using test events", {}, [Log.TAG_DB, "event"])
			var test_events: Array = _parent._get_test_events()
			for event_item: Dictionary in test_events:
				if event_item is Dictionary:
					events.append(event_item)

		return events

	func get_lineup_data(event: String) -> Dictionary:
		Log.info("Getting event lineups data", {"event": event}, [Log.TAG_DB, "event"])

		# Since we're using test data, we don't have event lineups
		return {}

	func save_lineup_data(
		_event: String,  # Underscore prefix for unused parameter
		_lineup: Dictionary,
		_level: int = 1,
		_p_data: Dictionary = {},
		_lives: int = 3,
		_lineup_uuid: String = ""
	) -> String:
		return "test-id-" + str(Time.get_unix_time_from_system())

	func remove_event_lineups(_event: String) -> bool:  # Underscore prefix for unused parameter
		return true

class PlayerCollectionImpl extends Node:
	func get_user_data(uuid: String = "") -> Dictionary:
		# Always return a default test user
		return {
			"progress": 1,
			"sfx": true,
			"music": false,
			"vibrate": true,
			"notification": false,
			"name": "test_player",
			"id": uuid if not uuid.is_empty() else "1"
		}

	func save_user_data(_data: Dictionary) -> bool:  # Unused parameter with underscore
		return true

	func get_default_data() -> Dictionary:
		return {
			"progress": 1,
			"sfx": true,
			"music": false,
			"vibrate": true,
			"notification": false,
			"name": "test_avatar_name",
			"id": "1"
		}

func _initialize_collections() -> void:
	# Create collections that use the parent DataSource for data access
	cards = CardCollectionImpl.new(self, _CARDS) as CardCollectionImpl
	levels = LevelCollectionImpl.new(self, LEVELS) as LevelCollectionImpl
	items = ItemCollectionImpl.new(self, ITEMS) as ItemCollectionImpl
	players = PlayerCollectionImpl.new() as PlayerCollectionImpl
	events = EventCollectionImpl.new(self, EVENTS) as EventCollectionImpl
	rules = RulesCollectionImpl.new(self, RULES) as RulesCollectionImpl

	# In editor mode, always use local data
	using_local_data = true

	# If local_data is empty, initialize with test data
	if local_data.is_empty():
		Log.warning("No local data found, initializing with test data", {}, [Log.TAG_DB])
		_initialize_test_data()

	Log.info("Collections initialized with local data", {
		"data_keys": local_data.keys()
	}, [Log.TAG_DB, "initialization"])

func _finalize_init() -> void:
	# Mark as initialized and emit signal
	_initialized = true
	startup_completed.emit()

	Log.info("DataSource initialization complete (hybrid version)", {
		"using_local_data": using_local_data
	}, [Log.TAG_DB])

# Implement the get_db_sheet method that maintains compatibility with collections
func get_db_sheet(sheet_name: String, is_dictionary: bool = false) -> Variant:
	"""Get data sheet from database using the backend"""
	var full_name: String = str(sheet_name, "_", test_group)
	Log.debug(
		"Getting database sheet via backend",
		{"sheet": sheet_name, "full_name": full_name, "is_dict": is_dictionary},
		[Log.TAG_DB, "data"]
	)

	# Try different path patterns
	var paths_to_try: Array[Array] = [
		[],  # Root level
		["sheets"]  # Standard sheets path
	]

	# Keys to try in order
	var keys_to_try: Array[String] = [
		full_name,  # First try with test_group suffix
		str(sheet_name, "_0"),  # Then standard _0 suffix
		sheet_name  # Finally try without suffix
	]

	# Try all combinations
	for path: Array in paths_to_try:
		for key: String in keys_to_try:
			var result: Variant = await _backend.get_data(path, key)
			if result != null:
				Log.debug(
					"Retrieved sheet from backend",
					{"path": path, "key": key},
					[Log.TAG_DB, "data"]
				)

				# Handle dictionary conversion if needed
				if is_dictionary and result is Array and result.size() > 0:
					result = result[0]
				return result

	# Nothing found, log error and return empty result
	Log.error(
		"Sheet not found via backend",
		{"sheet": sheet_name, "tried_keys": keys_to_try},
		[Log.TAG_DB, Log.TAG_ERROR, "data"]
	)

	if is_dictionary:
		return {}
	return []

# Public API - convenience methods
func is_firebase_available() -> bool:
	return _backend is FirebaseBackend and _backend.is_available()

func is_initialized() -> bool:
	return _initialized

# Legacy compatibility methods with explicit return types
func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	return await cards.get_by_id(card_id, use_cache)

func get_all_cards(use_cache: bool = false) -> Array:
	return await cards.get_all(use_cache)

func get_card_id_from_name(target_name: String) -> String:
	return await cards.get_id_by_name(target_name)

func get_level_data(level_nr: int) -> Dictionary:
	return await levels.get_by_number(level_nr)

func get_all_levels() -> Array:
	return await levels.get_all()

func get_item_info(item_id: String) -> Dictionary:
	return await items.get_by_id(item_id)

func get_item_id_from_name(target_name: String) -> String:
	return await items.get_id_by_name(target_name)

func get_all_items() -> Array:
	return await items.get_all()

# @warning_ignore:redundant_await - Kept for consistency with other async methods
func get_user_data(uuid: String = "") -> Dictionary:
	return await players.get_user_data(uuid)

# @warning_ignore:redundant_await - Kept for consistency with other async methods
func save_user_data(data: Dictionary) -> bool:
	return await players.save_user_data(data)

func get_default_player_data() -> Dictionary:
	return players.get_default_data()

func get_rules_data() -> Dictionary:
	return await rules.get_rules()

func get_event_data() -> Array:
	return await events.get_all()

# @warning_ignore:redundant_await
func get_event_lineups_data(event: String) -> Dictionary:
	return await events.get_lineup_data(event)

# @warning_ignore:redundant_await - Kept for consistency with other async methods
func save_event_lineup_data(
	_event: String,    # Unused parameter prefixed with underscore
	_lineup: Dictionary,
	_level: int = 1,
	_p_data: Dictionary = {},
	_lives: int = 3,
	_lineup_uuid: String = ""
) -> String:
	return await events.save_lineup_data(_event, _lineup, _level, _p_data, _lives, _lineup_uuid)

# @warning_ignore:redundant_await - Kept for consistency with other async methods
func remove_event_lineups(_event: String) -> bool:    # Unused parameter prefixed with underscore
	return await events.remove_event_lineups(_event)

func activate_card_cache() -> void:
	Log.info("Activating card cache", {}, [Log.TAG_CACHE, Log.TAG_DB, "card", "performance"])
	card_cache = await cards.get_all(true)
	Log.info("Card cache activated", {"count": card_cache.size()}, [Log.TAG_CACHE, Log.TAG_DB, "card", "performance"])

func clear_card_cache() -> void:
	Log.info("Clearing card cache", {}, [Log.TAG_CACHE, Log.TAG_DB, "card", "performance"])
	cards.clear_cache()
	card_cache = []

func clear_level_cache() -> void:
	Log.info("Clearing level cache", {}, [Log.TAG_CACHE, Log.TAG_DB, "level", "performance"])
	levels.clear_cache()

func clear_item_cache() -> void:
	Log.info("Clearing item cache", {}, [Log.TAG_CACHE, Log.TAG_DB, "item", "performance"])
	items.clear_cache()

# Legacy method kept for backward compatibility
func set_root(_new_root: Array) -> void:    # Unused parameter prefixed with underscore
	Log.debug("Legacy set_root called (simplified)", {"path": _new_root}, [Log.TAG_DB, "data"])

# Legacy method - simplified implementation
func get_db_value(_value: String) -> Variant:    # Unused parameter prefixed with underscore
	Log.debug("Legacy get_db_value called (simplified)", {"key": _value}, [Log.TAG_DB, "data"])
	return null

# For compatibility with other code
func get_backend() -> Variant:    # Add explicit return type
	return null

# Enhanced debugging function with typed variables
func debug_card_retrieval(card_id: String) -> Dictionary:
	Log.info("Debugging card retrieval", {"card_id": card_id}, [Log.TAG_DB])

	var debug_info: Dictionary = {
		"original_id": card_id,
		"id_type": typeof(card_id),
		"results": {}
	}

	# Try with cache
	var with_cache: Dictionary = await cards.get_by_id(card_id, true)
	debug_info.results.with_cache = {
		"found": not with_cache.is_empty(),
		"data": with_cache if not with_cache.is_empty() else {}
	}

	# Clear cache and try again
	cards.clear_cache()
	var without_cache: Dictionary = await cards.get_by_id(card_id, false)
	debug_info.results.without_cache = {
		"found": not without_cache.is_empty(),
		"data": without_cache if not without_cache.is_empty() else {}
	}

	# Check local data structure in detail
	debug_info["local_data_info"] = {
		"has_data": not local_data.is_empty(),
		"available_keys": local_data.keys(),
		"has_cards_key": local_data.has(_CARDS),
		"has_levels_key": local_data.has(LEVELS),
		"has_items_key": local_data.has(ITEMS),
		"has_rules_key": local_data.has(RULES),
		"has_events_key": local_data.has(EVENTS)
	}

	# Check data from get_db_sheet directly
	var cards_data: Array = await get_db_sheet(_CARDS.trim_suffix("_0"), false)
	debug_info["direct_sheet_access"] = {
		"found_cards": cards_data is Array and not cards_data.is_empty(),
		"card_count": cards_data.size() if cards_data is Array else 0
	}

	Log.info("Card retrieval debug complete", debug_info, [Log.TAG_DB])
	return debug_info

# Initialize test data (only used if no data is found in JSON) with typed variables and iterators
func _initialize_test_data() -> void:
	Log.warning("No data found in JSON, initializing test data", {}, [Log.TAG_DB])

	# Create test card data that matches the structure in the original implementation
	var test_card_data: Array = []
	# @warning_ignore:incompatible_ternary
	for i: int in range(10):
		var rarity: String = "rare" if i % 3 == 0 else "common"
		test_card_data.append({
			"id": str(i),
			"name": "Test Card " + str(i),
			"card_name": "Test Card " + str(i),
			"type": "unit",
			"rarity": rarity,
			"health": str(10 + i),
			"attack": str(5 + i),
			"abilities": "placeholder",
			"level": "1",
			"stars": str(1 + (i % 3)),
			"upgrade_level": "1",
			"description": "This is a test card with placeholder abilities."
		})

	# Create test level data
	var test_level_data: Array = []
	for i: int in range(5):
		test_level_data.append({
			"id": str(i + 1),
			"name": "Level " + str(i + 1),
			"difficulty": i + 1,
			"reward": 100 * (i + 1)
		})

	# Create test item data
	var test_item_data: Array = []
	# @warning_ignore:incompatible_ternary
	for i: int in range(5):
		var item_type: String = "weapon" if i % 2 == 0 else "armor"
		test_item_data.append({
			"id": str(i),
			"name": "Test Item " + str(i),
			"type": item_type,
			"value": 50 * (i + 1)
		})

	# Create test rules data - must match structure exactly expected by the game
	var test_rules: Array = [{
		"chance_lvl_2_star_1": "30",
		"chance_lvl_2_star_2": "10",
		"chance_lvl_2_star_3": "5",
		"chance_lvl_3_star_1": "50",
		"chance_lvl_3_star_2": "20",
		"chance_lvl_3_star_3": "10"
	}]

	# Create test event data
	var test_event_data: Array = []
	for i: int in range(3):
		test_event_data.append({
			"id": str(i),
			"name": "Test Event " + str(i),
			"start_date": "2025-0" + str(i+1) + "-01",
			"end_date": "2025-0" + str(i+1) + "-15"
		})

	# Add the test data to the local_data dictionary with the correct keys including the _0 suffix
	local_data[_CARDS] = test_card_data
	local_data[LEVELS] = test_level_data
	local_data[ITEMS] = test_item_data
	local_data[RULES] = test_rules
	local_data[EVENTS] = test_event_data

	Log.info("Test data initialized", {
		"cards": test_card_data.size(),
		"levels": test_level_data.size(),
		"items": test_item_data.size(),
		"events": test_event_data.size()
	}, [Log.TAG_DB])

# Helper methods to access test data with typed returns
func _get_test_cards() -> Array[Dictionary]:
	if local_data.has(_CARDS):
		var cards_result: Array[Dictionary] = []
		var raw_data: Array = local_data[_CARDS]
		for card: Dictionary in raw_data:
			if card is Dictionary:
				cards_result.append(card)
		return cards_result
	return []

func _get_test_levels() -> Array[Dictionary]:
	if local_data.has(LEVELS):
		var levels_result: Array[Dictionary] = []
		var raw_data: Array = local_data[LEVELS]
		for level: Dictionary in raw_data:
			if level is Dictionary:
				levels_result.append(level)
		return levels_result
	return []

func _get_test_items() -> Array[Dictionary]:
	if local_data.has(ITEMS):
		var items_result: Array[Dictionary] = []
		var raw_data: Array = local_data[ITEMS]
		for item: Dictionary in raw_data:
			if item is Dictionary:
				items_result.append(item)
		return items_result
	return []

func _get_test_rules() -> Dictionary:
	if local_data.has(RULES) and local_data[RULES] is Array and local_data[RULES].size() > 0:
		var rules_data: Dictionary = local_data[RULES][0]
		return rules_data
	return {}

func _get_test_events() -> Array[Dictionary]:
	if local_data.has(EVENTS):
		var events_result: Array[Dictionary] = []
		var raw_data: Array = local_data[EVENTS]
		for event: Dictionary in raw_data:
			if event is Dictionary:
				events_result.append(event)
		return events_result
	return []
