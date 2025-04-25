extends Node

## Data source manager for handling game data from Firebase or local JSON files.
## Provides centralized access to cards, levels, items, and player data via collections.
## Collection-based implementation with clear separation between Firebase and local data.

## Emitted when data source initialization is complete
signal startup_completed

# Collections
var cards: CardCollection
var levels: LevelCollection
var items: ItemCollection
var players: PlayerCollection
var events: EventCollection
var rules: RulesCollection

# Test group identifier
var test_group: int = 0

# Internal state
var _backend: DataBackend
var using_local_data: bool = false
var _initialized: bool = false

## Called when the node enters the scene tree
func _ready() -> void:
	Log.info("DataSource initializing", {}, [Log.TAG_DB])
	_initialized = false

	# Initialize async
	await _initialize()

## Initialize the data source and collections
func _initialize() -> void:
	# Create the backend
	_backend = await BackendFactory.create_backend()

	# Track whether we're using local data
	using_local_data = _backend is LocalJSONBackend

	# Initialize collections
	_initialize_collections()

	# Connect to backend signals
	_backend.startup_completed.connect(func():
		Log.info("DataSource initialization complete", {"firebase_available": is_firebase_available()}, [Log.TAG_DB])
		_initialized = true
		startup_completed.emit()
	)

## Initialize the collection instances
func _initialize_collections() -> void:
	# Create all collections
	cards = CardCollection.new(_backend, test_group)
	levels = LevelCollection.new(_backend, test_group)
	items = ItemCollection.new(_backend, test_group)
	players = PlayerCollection.new(_backend)
	events = EventCollection.new(_backend, test_group)
	rules = RulesCollection.new(_backend, test_group)

	Log.debug("DataSource collections initialized", {}, [Log.TAG_DB])

## Set the test group identifier
## @param group The test group to use
func set_test_group(group: int) -> void:
	test_group = group
	# Reinitialize collections with new test group
	_initialize_collections()

## Check if Firebase is available and connected
## @return True if Firebase is available, false otherwise
func is_firebase_available() -> bool:
	var available = _backend is FirebaseBackend and _backend.is_available()
	Log.debug("Firebase availability check", {
		"available": available,
		"backend_type": _backend.get_class()
	}, [Log.TAG_DB])
	return available

## Check if data source is fully initialized
## @return True if initialized, false otherwise
func is_initialized() -> bool:
	return _initialized

## Initialize card cache with all cards
func activate_card_cache() -> void:
	Log.info("Activating card cache", {}, [Log.TAG_CACHE, Log.TAG_DB])

	var card_data = await cards.get_all(true)

	Log.info("Card cache activated", {
		"count": card_data.size(),
		"data_source": "firebase" if is_firebase_available() else "local"
	}, [Log.TAG_CACHE, Log.TAG_DB])

## Set up player data from server or create new data
## @return Result code (0 for success)
func setup_player_data() -> int:
	Log.info("Setting up player data", {}, [Log.TAG_DB])

	var auth = Engine.get_singleton("Auth")
	var retval = 0

	if auth and auth.is_available():
		retval = await auth.login()
		if OS.has_feature("editor"):
			retval = 0

		if retval:
			Log.warning(
				"Login failed during player data setup",
				{"error_code": retval},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			return retval

	# Create default player data
	var data = players.get_default_data()
	await players.save_user_data(data)

	return retval

#------------------------------------------------------------------
# Legacy compatibility methods - will be gradually deprecated
#------------------------------------------------------------------

## Legacy method: Get card info by ID
## @param card_id The card ID to retrieve
## @param use_cache Whether to use the cache if available
## @return Card dictionary or empty dictionary if not found
func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	return await cards.get_by_id(card_id, use_cache)

## Legacy method: Get all cards
## @param use_cache Whether to use the cache if available
## @return Array of card dictionaries
func get_all_cards(use_cache: bool = false) -> Array:
	return await cards.get_all(use_cache)

## Legacy method: Get card ID from name
## @param target_name The name of the card to look up
## @return Card ID or empty string if not found
func get_card_id_from_name(target_name: String) -> String:
	return await cards.get_id_by_name(target_name)

## Legacy method: Get level data by number
## @param level_nr The level number to retrieve
## @return Level dictionary or empty dictionary if not found
func get_level_data(level_nr: int) -> Dictionary:
	return await levels.get_by_number(level_nr)

## Legacy method: Get all levels
## @return Array of level dictionaries
func get_all_levels() -> Array:
	return await levels.get_all()

## Legacy method: Get item info by ID
## @param item_id The item ID to retrieve
## @return Item dictionary or empty dictionary if not found
func get_item_info(item_id: String) -> Dictionary:
	return await items.get_by_id(item_id)

## Legacy method: Get item ID from name
## @param target_name The name of the item to look up
## @return Item ID or empty string if not found
func get_item_id_from_name(target_name: String) -> String:
	return await items.get_id_by_name(target_name)

## Legacy method: Get all items
## @return Array of item dictionaries
func get_all_items() -> Array:
	return await items.get_all()

## Legacy method: Get user data for UUID
## @param uuid The UUID of the user to retrieve data for (empty for current user)
## @return User data dictionary or empty dictionary if not found
func get_user_data(uuid: String = "") -> Dictionary:
	return await players.get_user_data(uuid)

## Legacy method: Get default player data
## @return Default player data dictionary
func get_default_player_data() -> Dictionary:
	return players.get_default_data()

## Legacy method: Get game rules data
## @return Rules dictionary
func get_rules_data() -> Dictionary:
	return await rules.get_rules()

## Legacy method: Get event data
## @return Array of event dictionaries
func get_event_data() -> Array:
	return await events.get_all()

## Legacy method: Get lineup data for an event
## @param event The event ID to get lineup data for
## @return Dictionary of lineup data or empty dictionary if not found
func get_event_lineups_data(event: String) -> Dictionary:
	return await events.get_lineup_data(event)

## Legacy method: Save lineup data for an event
## @param event The event ID to save lineup data for
## @param lineup The lineup data to save
## @param level The level number
## @param p_data Player data to include
## @param lives Number of lives
## @param lineup_uuid Existing lineup UUID (empty for new)
## @return The lineup UUID
func save_event_lineup_data(
	event: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	return await events.save_lineup_data(event, lineup, level, p_data, lives, lineup_uuid)

## Legacy method: Remove lineups from an event
## @param event The event ID to remove lineups from
func remove_event_lineups(event: String) -> void:
	await events.remove_event_lineups(event)

## Legacy method: Save user data
## @param data The user data to save
func save_user_data(data: Dictionary) -> void:
	await players.save_user_data(data)
