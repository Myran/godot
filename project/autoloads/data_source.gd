extends Node

## DataSource manager for game data
## Provides centralized access to cards, levels, items, player data, etc.
## Hybrid implementation using collection-based architecture with fallback to test data

# Signals
signal startup_completed
signal value_received(data: Dictionary)

# Constants (restored from original)
# Google Sheet ID from the JSON structure
const SHEET_ID = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
const SHEETS = "sheets" # Legacy key - not used in actual JSON
const PLAYERS = "players"
const AVATAR_DATA = "avatar_data"
const EVENTS = "event_data_0"
const LEVELS = "levels_0"
const ITEMS = "items_0"
const RULES = "rules_0"
const _CARDS = "cards_0"

# Add helper function to check if we have game data
func has_game_data() -> bool:
	return local_data.has(_CARDS) or local_data.has("cards_0") or local_data.has("cards")

# Collections
var cards: Node
var levels: Node
var items: Node
var players: Node
var events: Node
var rules: Node

# Internal state
var _backend: Node = null
var using_local_data: bool = false
var _initialized: bool = false
var card_cache: Array = []
var local_data: Dictionary = {}
var test_group: int = 0
var default_db_file: String = "res://resources/data.json"
var battle_db_file: String = "res://resources/gameone-577cb-export.json"
var current_file: String = "res://resources/data.json"

func _ready() -> void:
	Log.info("DataSource initializing", {
		"version": "hybrid_implementation",
		"os": OS.get_name(),
		"in_editor": OS.has_feature("editor"),
		"debug_build": OS.is_debug_build()
	}, [Log.TAG_DB])

	_initialized = false

	# Always use the battle DB file since that's what contains our game data
	current_file = battle_db_file
	Log.debug("Using battle database file", {"file": current_file}, [Log.TAG_LOCAL])

	# Load actual data from JSON
	load_local_data(current_file)

	# If we don't have game data, try the standard data.json as fallback
	if not has_game_data():
		Log.warning("No game data found in battle DB file, trying standard data file", {}, [Log.TAG_LOCAL])
		load_local_data(default_db_file)

	# Create collections
	_initialize_collections()

	# Initialize async
	_finalize_init()

func load_local_data(db_file: String) -> void:
	"""Load data from local JSON file"""
	Log.info("Loading local data file", {"file": db_file}, [Log.TAG_LOCAL])

	if not FileAccess.file_exists(db_file):
		Log.error(
			"Local data file does not exist", {"file": db_file}, [Log.TAG_LOCAL, Log.TAG_ERROR]
		)
		return

	var file: FileAccess = FileAccess.open(db_file, FileAccess.READ)
	if not file:
		Log.error(
			"Failed to open local data file",
			{"file": db_file, "error": FileAccess.get_open_error()},
			[Log.TAG_LOCAL, Log.TAG_ERROR]
		)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var res: Variant = JSON.parse_string(json_text)
	if res == null:
		Log.error(
			"Failed to parse local data JSON", {"file": db_file}, [Log.TAG_LOCAL, Log.TAG_ERROR]
		)
		return

	if res is Dictionary:
		# Log the top-level structure to help diagnose
		Log.debug("JSON root structure", {"keys": res.keys()}, [Log.TAG_LOCAL])

		# Handle different JSON structures
		if res.has(SHEETS):
			# Standard format with sheets key (unlikely in our case)
			local_data = res[SHEETS]
			Log.debug("Found standard SHEETS key in JSON", {}, [Log.TAG_LOCAL])
		elif res.has(SHEET_ID) and res[SHEET_ID] is Dictionary:
			# This is our actual structure with Google Sheet ID as the key
			var sheet_data = res[SHEET_ID]
			Log.debug("Found Sheet ID in JSON with keys", {"keys": sheet_data.keys()}, [Log.TAG_LOCAL])

			# Extract all the collections we need directly
			local_data = sheet_data.duplicate()

			# Look for game cards - debug the structure
			if sheet_data.has(_CARDS):
				var card_data = sheet_data[_CARDS]
				Log.debug("Found card data", {
					"card_type": typeof(card_data),
					"is_array": card_data is Array,
					"count": card_data.size() if card_data is Array else 0
				}, [Log.TAG_LOCAL])
		else:
			Log.warning("JSON data does not match expected format", {"keys": res.keys()}, [Log.TAG_LOCAL])
			# Try to find any collection keys at root level
			var found_collections = false
			for key in [_CARDS, LEVELS, ITEMS, RULES, EVENTS]:
				if res.has(key):
					local_data[key] = res[key]
					found_collections = true
					Log.debug("Found collection at root level", {"key": key}, [Log.TAG_LOCAL])

			if not found_collections:
				Log.error("No valid data collections found in JSON", {}, [Log.TAG_LOCAL, Log.TAG_ERROR])

		Log.info(
			"Local data file loaded successfully",
			{"tables": local_data.keys().size(), "keys": local_data.keys()},
			[Log.TAG_LOCAL]
		)
	else:
		Log.error(
			"Local data is not a Dictionary",
			{"type": typeof(res)},
			[Log.TAG_LOCAL, Log.TAG_ERROR]
		)

class CardCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "cards_0"):
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			Log.debug("Using card cache", {"cache_size": _cache.size()}, [Log.TAG_DB, Log.TAG_CACHE])
			return _cache

		# Use the parent's get_db_sheet method to access actual data
		var cards = await _parent.get_db_sheet(_collection_key.trim_suffix("_0"), false)

		# If we didn't find any data, check if we have test data
		if (cards.is_empty() or cards.size() == 0) and _parent.has_method("_get_test_cards"):
			Log.warning("No card data found, using test cards", {}, [Log.TAG_DB])
			cards = _parent._get_test_cards()

		_cache = cards
		_is_cache_initialized = true

		Log.info("Retrieved all cards", {"count": cards.size()}, [Log.TAG_DB])
		return cards

	func get_by_id(card_id: String, use_cache: bool = true) -> Dictionary:
		Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [Log.TAG_DB])

		# Handle empty card_id case
		if card_id.is_empty():
			Log.error("Empty card_id provided", {}, [Log.TAG_DB, Log.TAG_ERROR])
			return {}

		var results = await get_all(use_cache)

		if results.is_empty():
			Log.error("No cards found in collection", {}, [Log.TAG_DB, Log.TAG_ERROR])
			return {}

		Log.debug("Searching through cards", {"count": results.size()}, [Log.TAG_DB])

		# First try integer comparison exactly like the original implementation
		for card in results:
			if not card.has("id"):
				continue

			var id = card.id
			if int(id) == int(card_id):
				Log.debug("Card found by int comparison", {"card_id": card_id, "card_id_value": card_id, "id_value": id}, [Log.TAG_DB])
				return card

		# If that fails, try string comparison as backup
		for card in results:
			if not card.has("id"):
				continue

			var id = card.id
			if str(id) == str(card_id):
				Log.debug("Card found by string comparison", {"card_id": card_id}, [Log.TAG_DB])
				return card

		Log.error("Card with id not found", {"card_id": card_id}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}

	func get_id_by_name(card_name: String) -> String:
		Log.info("Getting card ID from name", {"name": card_name}, [Log.TAG_DB])

		var cards = await get_all()
		for card in cards:
			if not card.has("name"):
				continue

			if card.name == card_name:
				Log.debug("Card name found", {"name": card_name, "id": card.id}, [Log.TAG_DB])
				return card.id

		Log.error("Card name not found", {"name": card_name}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""

	func get_by_type(card_type: String) -> Array:
		var filtered = []
		var cards = await get_all()
		for card in cards:
			if "type" in card and card.type == card_type:
				filtered.append(card)
		return filtered

	func clear_cache() -> void:
		_is_cache_initialized = false
		_cache = []

class LevelCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "levels_0"):
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			return _cache

		# Use the parent's get_db_sheet method to access actual data
		var levels = await _parent.get_db_sheet(_collection_key.trim_suffix("_0"), false)

		# If we didn't find any data, check if we have test data
		if levels.is_empty() and _parent.has_method("_get_test_levels"):
			Log.warning("No level data found, using test levels", {}, [Log.TAG_DB])
			levels = _parent._get_test_levels()

		_cache = levels
		_is_cache_initialized = true
		return levels

	func get_by_number(level_nr: int) -> Dictionary:
		Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB])

		var levels = await get_all()
		for level in levels:
			if not level.has("id"):
				continue

			var id = level.id
			if int(id) == level_nr:
				Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
				return level

		Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB])
		return {}

	func clear_cache() -> void:
		_is_cache_initialized = false
		_cache = []

class ItemCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String
	var _cache: Array = []
	var _is_cache_initialized: bool = false

	func _init(parent: Node, collection_key: String = "items_0"):
		_parent = parent
		_collection_key = collection_key

	func get_all(use_cache: bool = true) -> Array:
		if use_cache and _is_cache_initialized and not _cache.is_empty():
			return _cache

		# Use the parent's get_db_sheet method to access actual data
		var items = await _parent.get_db_sheet(_collection_key.trim_suffix("_0"), false)

		# If we didn't find any data, check if we have test data
		if items.is_empty() and _parent.has_method("_get_test_items"):
			Log.warning("No item data found, using test items", {}, [Log.TAG_DB])
			items = _parent._get_test_items()

		_cache = items
		_is_cache_initialized = true
		return items

	func get_by_id(item_id: String) -> Dictionary:
		Log.info("Getting item info", {"item_id": item_id}, [Log.TAG_DB])

		var items = await get_all()
		for item in items:
			if not item.has("id"):
				continue

			if str(item.id) == str(item_id):
				Log.debug("Item found", {"item_id": item_id}, [Log.TAG_DB])
				return item

		Log.error("Item with id not found", {"item_id": item_id}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}

	func get_id_by_name(item_name: String) -> String:
		Log.info("Getting item ID from name", {"name": item_name}, [Log.TAG_DB])

		var items = await get_all()
		for item in items:
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

	func _init(parent: Node, collection_key: String = "rules_0"):
		_parent = parent
		_collection_key = collection_key

	func get_rules() -> Dictionary:
		var rules = await _parent.get_db_sheet(_collection_key.trim_suffix("_0"), true)

		# If we didn't find any data, check if we have test data
		if rules.is_empty() and _parent.has_method("_get_test_rules"):
			Log.warning("No rules data found, using test rules", {}, [Log.TAG_DB])
			rules = _parent._get_test_rules()

		return rules

class EventCollectionImpl extends Node:
	var _parent: Node
	var _collection_key: String

	func _init(parent: Node, collection_key: String = "event_data_0"):
		_parent = parent
		_collection_key = collection_key

	func get_all() -> Array:
		var events = await _parent.get_db_sheet(_collection_key.trim_suffix("_0"), false)

		# If we didn't find any data, check if we have test data
		if events.is_empty() and _parent.has_method("_get_test_events"):
			Log.warning("No event data found, using test events", {}, [Log.TAG_DB])
			events = _parent._get_test_events()

		return events

	func get_lineup_data(event: String) -> Dictionary:
		Log.info("Getting event lineups data", {"event": event}, [Log.TAG_DB])

		# Since we're using test data, we don't have event lineups
		return {}

	func save_lineup_data(
		event: String,
		lineup: Dictionary,
		level: int = 1,
		p_data: Dictionary = {},
		lives: int = 3,
		lineup_uuid: String = ""
	) -> String:
		return "test-id-" + str(Time.get_unix_time_from_system())

	func remove_event_lineups(event: String) -> bool:
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

	func save_user_data(data: Dictionary) -> bool:
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
	cards = CardCollectionImpl.new(self, _CARDS)
	levels = LevelCollectionImpl.new(self, LEVELS)
	items = ItemCollectionImpl.new(self, ITEMS)
	players = PlayerCollectionImpl.new()
	events = EventCollectionImpl.new(self, EVENTS)
	rules = RulesCollectionImpl.new(self, RULES)

	# In editor mode, always use local data
	using_local_data = true

	# If local_data is empty, initialize with test data
	if local_data.is_empty():
		Log.warning("No local data found, initializing with test data", {}, [Log.TAG_DB])
		_initialize_test_data()

	Log.info("Collections initialized with local data", {
		"data_keys": local_data.keys()
	}, [Log.TAG_DB])

func _finalize_init() -> void:
	# Mark as initialized and emit signal
	_initialized = true
	startup_completed.emit()

	Log.info("DataSource initialization complete (hybrid version)", {
		"using_local_data": using_local_data
	}, [Log.TAG_DB])

# Implement the original get_db_sheet method that all collections will use
func get_db_sheet(sheet_name: String, is_dictionary: bool = false) -> Variant:
	"""Get data sheet from database or local data"""
	var full_name: String = str(sheet_name, "_", test_group)
	Log.debug(
		"Getting database sheet",
		{"sheet": sheet_name, "full_name": full_name, "is_dict": is_dictionary},
		[Log.TAG_DB]
	)

	# Try the full name first (with test_group suffix)
	if local_data.has(full_name):
		var result = local_data[full_name]
		Log.debug(
			"Retrieved sheet from local data (with test_group)",
			{"sheet": full_name},
			[Log.TAG_DB, Log.TAG_LOCAL]
		)

		if is_dictionary and result is Array and result.size() > 0:
			result = result[0]
		return result

	# If not found, try with "_0" suffix (standard format)
	var standard_name = str(sheet_name, "_0")
	if local_data.has(standard_name):
		var result = local_data[standard_name]
		Log.debug(
			"Retrieved sheet from local data (standard format)",
			{"sheet": standard_name},
			[Log.TAG_DB, Log.TAG_LOCAL]
		)

		if is_dictionary and result is Array and result.size() > 0:
			result = result[0]
		return result

	# If still not found, try without any suffix
	if local_data.has(sheet_name):
		var result = local_data[sheet_name]
		Log.debug(
			"Retrieved sheet from local data (no suffix)",
			{"sheet": sheet_name},
			[Log.TAG_DB, Log.TAG_LOCAL]
		)

		if is_dictionary and result is Array and result.size() > 0:
			result = result[0]
		return result

	# Nothing found, log error and return empty result
	Log.error(
		"Sheet not found in local data",
		{"sheet": full_name, "tried_also": [standard_name, sheet_name], "available_keys": local_data.keys()},
		[Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR]
	)

	if is_dictionary:
		return {}
	return []

# Public API - convenience methods
func is_firebase_available() -> bool:
	return false # This implementation only uses local data

func is_initialized() -> bool:
	return _initialized

# Legacy compatibility methods
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

func get_user_data(uuid: String = "") -> Dictionary:
	return await players.get_user_data(uuid)

func save_user_data(data: Dictionary) -> bool:
	return await players.save_user_data(data)

func get_default_player_data() -> Dictionary:
	return players.get_default_data()

func get_rules_data() -> Dictionary:
	return await rules.get_rules()

func get_event_data() -> Array:
	return await events.get_all()

func get_event_lineups_data(event: String) -> Dictionary:
	return await events.get_lineup_data(event)

func save_event_lineup_data(
	event: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	return await events.save_lineup_data(event, lineup, level, p_data, lives, lineup_uuid)

func remove_event_lineups(event: String) -> bool:
	return await events.remove_event_lineups(event)

func activate_card_cache() -> void:
	Log.info("Activating card cache", {}, [Log.TAG_CACHE, Log.TAG_DB])
	card_cache = await cards.get_all(true)
	Log.info("Card cache activated", {"count": card_cache.size()}, [Log.TAG_CACHE, Log.TAG_DB])

func clear_card_cache() -> void:
	Log.info("Clearing card cache", {}, [Log.TAG_CACHE, Log.TAG_DB])
	cards.clear_cache()
	card_cache = []

func clear_level_cache() -> void:
	Log.info("Clearing level cache", {}, [Log.TAG_CACHE, Log.TAG_DB])
	levels.clear_cache()

func clear_item_cache() -> void:
	Log.info("Clearing item cache", {}, [Log.TAG_CACHE, Log.TAG_DB])
	items.clear_cache()

# Legacy method kept for backward compatibility
func set_root(new_root: Array) -> void:
	Log.debug("Legacy set_root called (simplified)", {"path": new_root}, [Log.TAG_DB])

# Legacy method - simplified implementation
func get_db_value(value: String) -> Variant:
	Log.debug("Legacy get_db_value called (simplified)", {"key": value}, [Log.TAG_DB])
	return null

# For compatibility with other code
func get_backend():
	return null

# Enhanced debugging function
func debug_card_retrieval(card_id: String) -> Dictionary:
	Log.info("Debugging card retrieval", {"card_id": card_id}, [Log.TAG_DB])

	var debug_info = {
		"original_id": card_id,
		"id_type": typeof(card_id),
		"results": {}
	}

	# Try with cache
	var with_cache = await cards.get_by_id(card_id, true)
	debug_info.results.with_cache = {
		"found": not with_cache.is_empty(),
		"data": with_cache if not with_cache.is_empty() else null
	}

	# Clear cache and try again
	cards.clear_cache()
	var without_cache = await cards.get_by_id(card_id, false)
	debug_info.results.without_cache = {
		"found": not without_cache.is_empty(),
		"data": without_cache if not without_cache.is_empty() else null
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
	var cards_data = await get_db_sheet(_CARDS.trim_suffix("_0"), false)
	debug_info["direct_sheet_access"] = {
		"found_cards": cards_data is Array and not cards_data.is_empty(),
		"card_count": cards_data.size() if cards_data is Array else 0
	}

	Log.info("Card retrieval debug complete", debug_info, [Log.TAG_DB])
	return debug_info

# Initialize test data (only used if no data is found in JSON)
func _initialize_test_data() -> void:
	Log.warning("No data found in JSON, initializing test data", {}, [Log.TAG_DB])

	# Create test card data that matches the structure in the original implementation
	var test_cards = []
	for i in range(10):
		var rarity = "rare" if i % 3 == 0 else "common"
		test_cards.append({
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
	var test_levels = []
	for i in range(5):
		test_levels.append({
			"id": str(i + 1),
			"name": "Level " + str(i + 1),
			"difficulty": i + 1,
			"reward": 100 * (i + 1)
		})

	# Create test item data
	var test_items = []
	for i in range(5):
		var item_type = "weapon" if i % 2 == 0 else "armor"
		test_items.append({
			"id": str(i),
			"name": "Test Item " + str(i),
			"type": item_type,
			"value": 50 * (i + 1)
		})

	# Create test rules data - must match structure exactly expected by the game
	var test_rules = [{
		"chance_lvl_2_star_1": "30",
		"chance_lvl_2_star_2": "10",
		"chance_lvl_2_star_3": "5",
		"chance_lvl_3_star_1": "50",
		"chance_lvl_3_star_2": "20",
		"chance_lvl_3_star_3": "10"
	}]

	# Create test event data
	var test_events = []
	for i in range(3):
		test_events.append({
			"id": str(i),
			"name": "Test Event " + str(i),
			"start_date": "2025-0" + str(i+1) + "-01",
			"end_date": "2025-0" + str(i+1) + "-15"
		})

	# Add the test data to the local_data dictionary with the correct keys including the _0 suffix
	local_data[_CARDS] = test_cards
	local_data[LEVELS] = test_levels
	local_data[ITEMS] = test_items
	local_data[RULES] = test_rules
	local_data[EVENTS] = test_events

	Log.info("Test data initialized", {
		"cards": test_cards.size(),
		"levels": test_levels.size(),
		"items": test_items.size(),
		"events": test_events.size()
	}, [Log.TAG_DB])

# Helper methods to access test data
func _get_test_cards() -> Array:
	if local_data.has(_CARDS):
		return local_data[_CARDS]
	return []

func _get_test_levels() -> Array:
	if local_data.has(LEVELS):
		return local_data[LEVELS]
	return []

func _get_test_items() -> Array:
	if local_data.has(ITEMS):
		return local_data[ITEMS]
	return []

func _get_test_rules() -> Dictionary:
	if local_data.has(RULES):
		return local_data[RULES]
	return {}

func _get_test_events() -> Array:
	if local_data.has(EVENTS):
		return local_data[EVENTS]
	return []
