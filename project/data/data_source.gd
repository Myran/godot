class_name DataSource
extends Node
## Emitted when data source initialization is complete
signal startup_completed
# Import required classes
#const BackendFactoryClass = preload("res://data/backends/backend_factory.gd")
#const DataBackendClass = preload("res://data/backends/data_backend.gd")
#const LocalJSONBackendClass = preload("res://data/backends/local_json_backend.gd")
#const FirebaseBackendClass = preload("res://data/backends/firebase_backend.gd")
#const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd")
#const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

## Data source manager for game data from Firebase or local JSON files.
## Provides centralized access to cards, levels, items, players, events, and rules data.
## Uses collection-based architecture with proper separation of concerns.



# Collections
var cards: CardCollection = null
var levels: LevelCollection = null
var items: ItemCollection = null
var players: PlayerCollection = null
var events: EventCollection = null
var rules: RulesCollection = null

# Test group identifier
var test_group: int = 0

# Internal state
var using_local_data: bool = false
var _backend: DataBackend = null
var _initialized: bool = false

## Called when the node enters the scene tree
func _ready() -> void:
	Log.info("DataSource initializing", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])
	_initialized = false

	# Initialize async
	call_deferred("_initialize")

## Initialize the data source and collections
func _initialize() -> void:
	Log.debug("Starting DataSource initialization", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	# Create the backend - let it crash if type is wrong
	@warning_ignore("redundant_await")
	_backend = await BackendFactory.create_backend()

	# Track whether we're using local data
	using_local_data = _backend is LocalJSONBackend

	Log.debug("Backend created", {
		"backend_type": _backend.get_class() if _backend != null else "null",
		"using_local_data": using_local_data,
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	# Initialize collections
	_initialize_collections()

	# Connect to backend signals
	if _backend != null:
		if not _backend.startup_completed.is_connected(_on_backend_startup_completed):
			_backend.startup_completed.connect(_on_backend_startup_completed)

	Log.debug("Waiting for backend startup", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

## Called when backend startup is complete
func _on_backend_startup_completed() -> void:
	Log.info("DataSource initialization complete", {
		"firebase_available": is_firebase_available(),
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	_initialized = true
	startup_completed.emit()

	# Log active collections
	_log_active_collections()

## Initialize the collection instances
func _initialize_collections() -> void:
	Log.debug("Initializing collections", {
		"test_group": test_group,
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	# No null check - will crash immediately if _backend is null (fail fast)

	# Create all collections with proper error handling
	var initialization_success: bool = true

	# Initialize all collections individually to isolate potential errors
	initialization_success = initialization_success and _initialize_collection("cards")
	initialization_success = initialization_success and _initialize_collection("levels")
	initialization_success = initialization_success and _initialize_collection("items")
	initialization_success = initialization_success and _initialize_collection("players")
	initialization_success = initialization_success and _initialize_collection("events")
	initialization_success = initialization_success and _initialize_collection("rules")

	if initialization_success:
		Log.debug("DataSource collections initialized successfully", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB])
	else:
		Log.error("Some collections failed to initialize", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])

## Helper function to initialize a single collection
## @param collection_name The name of the collection to initialize
## @return bool True if initialization was successful
func _initialize_collection(collection_name: String) -> bool:
	Log.debug("Initializing collection", {
		"collection_name": collection_name,
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	var success: bool = true

	match collection_name:
		"cards":
			success = _safely_create_collection(func() -> void: cards = CardCollection.new(_backend, test_group), "cards")
		"levels":
			success = _safely_create_collection(func() -> void: levels = LevelCollection.new(_backend, test_group), "levels")
		"items":
			success = _safely_create_collection(func() -> void: items = ItemCollection.new(_backend, test_group), "items")
		"players":
			success = _safely_create_collection(func() -> void: players = PlayerCollection.new(_backend), "players")
		"events":
			success = _safely_create_collection(func() -> void: events = EventCollection.new(_backend, test_group), "events")
		"rules":
			success = _safely_create_collection(func() -> void: rules = RulesCollection.new(_backend, test_group), "rules")
		_:
			Log.error("Unknown collection name", {
				"collection_name": collection_name,
				"instance_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_ERROR])
			success = false

	return success

## Helper function to create a collection
## @param creation_function The function to call to create the collection
## @param collection_name The name of the collection being created (for logging)
## @return bool True if initialization was successful
func _safely_create_collection(creation_function: Callable, collection_name: String) -> bool:
	var success: bool = true

	# No null check - will crash immediately if _backend is null (fail fast)

	# Just call the function directly - let it crash if there's a type error
	# This will make it easier to find and fix issues directly
	var err: Variant = creation_function.call()

	# Only check for specific Error type returns
	if err is Error and err != OK:
		success = false
		Log.error("Failed to initialize collection", {
			"collection_name": collection_name,
			"error": err,
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
		push_error("Failed to initialize collection: " + collection_name)

	return success

## Set the test group identifier
## @param group The test group to use
func set_test_group(group: int) -> void:
	if group is int:
		test_group = group
		# Reinitialize collections with new test group
		_initialize_collections()
	else:
		Log.error("Invalid test group specified", {
			"provided_value": group,
			"type": typeof(group),
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])

## Check if Firebase is available and connected
## @return True if Firebase is available, false otherwise
func is_firebase_available() -> bool:
	# No null check - will crash if _backend is null (fail fast)
	var available: bool = _backend is FirebaseBackend and _backend.is_available()
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
	Log.info("Activating card cache", {
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE, Log.TAG_DB])

	# No null check - will crash if cards is null (fail fast)

	var request_start_time: int = Time.get_ticks_msec()
	@warning_ignore("redundant_await")
	var card_data: Array[Dictionary] = await cards.get_all(true)
	var request_duration: int = Time.get_ticks_msec() - request_start_time

	Log.info("Card cache activated", {
		"count": card_data.size(),
		"duration_ms": request_duration,
		"data_source": "firebase" if is_firebase_available() else "local",
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE, Log.TAG_DB])

## Set up player data from server or create new data
## @return Result code (0 for success)
func setup_player_data() -> int:
	Log.info("Setting up player data", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	if players == null:
		Log.error("Cannot setup player data - players collection not initialized", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return -1

	var auth: Object = Engine.get_singleton("Auth")
	var retval: int = 0

	if auth != null and auth.is_available():
		Log.debug("Auth singleton available, attempting login", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB])

		# Direct assignment - will crash if type is wrong (fail fast)
		@warning_ignore("redundant_await")
		retval = await auth.login()

		if OS.has_feature("editor"):
			Log.debug("Running in editor, forcing login success", {
				"instance_id": get_instance_id()
			}, [Log.TAG_DB])
			retval = 0

		if retval != 0:
			Log.warning(
				"Login failed during player data setup",
				{
					"error_code": retval,
					"instance_id": get_instance_id()
				},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			return retval
	else:
		Log.warning("Auth singleton not available", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])

	# Create default player data
	var data: Dictionary = players.get_default_data()
	Log.debug("Created default player data", {
		"field_count": data.keys().size(),
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])

	@warning_ignore("redundant_await")
	var save_success: bool = await players.save_user_data(data)

	if not save_success:
		Log.error("Failed to save player data", {
			"instance_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return -2

	Log.info("Player data setup complete", {
		"success": save_success,
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])
	return retval

#------------------------------------------------------------------
# Legacy compatibility methods - will be gradually deprecated
#------------------------------------------------------------------

## Legacy method: Get card info by ID
## @param card_id The card ID to retrieve
## @param use_cache Whether to use the cache if available
## @return Card dictionary or empty dictionary if not found
func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	# No null check - will crash if cards is null (fail fast)
	@warning_ignore("redundant_await")
	return await cards.get_by_id(card_id, use_cache)

## Legacy method: Get all cards
## @param use_cache Whether to use the cache if available
## @return Array of card dictionaries
func get_all_cards(use_cache: bool = false) -> Array[Dictionary]:
	# No null check - will crash if cards is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Array[Dictionary] = await cards.get_all(use_cache)
	return result

## Legacy method: Get card ID from name
## @param target_name The name of the card to look up
## @return Card ID or empty string if not found
func get_card_id_from_name(target_name: String) -> String:
	# No null check - will crash if cards is null (fail fast)
	@warning_ignore("redundant_await")
	return await cards.get_id_by_name(target_name)

## Legacy method: Get level data by number
## @param level_nr The level number to retrieve
## @return Level dictionary or empty dictionary if not found
func get_level_data(level_nr: int) -> Dictionary:
	# No null check - will crash if levels is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Dictionary = await levels.get_by_number(level_nr)
	return result

## Legacy method: Get all levels
## @return Array of level dictionaries
func get_all_levels() -> Array[Dictionary]:
	# No null check - will crash if levels is null (fail fast)
	@warning_ignore("redundant_await")
	var levels_data: Array[Dictionary] = await levels.get_all()
	return levels_data

## Legacy method: Get item info by ID
## @param item_id The item ID to retrieve
## @return Item dictionary or empty dictionary if not found
func get_item_info(item_id: String) -> Dictionary:
	# No null check - will crash if items is null (fail fast)
	@warning_ignore("redundant_await")
	return await items.get_by_id(item_id)

## Legacy method: Get item ID from name
## @param target_name The name of the item to look up
## @return Item ID or empty string if not found
func get_item_id_from_name(target_name: String) -> String:
	# No null check - will crash if items is null (fail fast)
	@warning_ignore("redundant_await")
	return await items.get_id_by_name(target_name)

## Legacy method: Get all items
## @return Array of item dictionaries
func get_all_items() -> Array[Dictionary]:
	# No null check - will crash if items is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Array[Dictionary] = await items.get_all()
	return result

## Legacy method: Get user data for UUID
## @param uuid The UUID of the user to retrieve data for (empty for current user)
## @return User data dictionary or empty dictionary if not found
func get_user_data(uuid: String = "") -> Dictionary:
	# No null check - will crash if players is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Dictionary = await players.get_user_data(uuid)
	return result

## Legacy method: Get default player data
## @return Default player data dictionary
func get_default_player_data() -> Dictionary:
	# No null check - will crash if players is null (fail fast)
	return players.get_default_data()

## Legacy method: Get game rules data
## @return Rules dictionary
func get_rules_data() -> Dictionary:
	# No null check - will crash if rules is null (fail fast)
	@warning_ignore("redundant_await")
	return await rules.get_rules()

## Legacy method: Get event data
## @return Array of event dictionaries
func get_event_data() -> Array[Dictionary]:
	# No null check - will crash if events is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Array[Dictionary] = await events.get_all()
	return result

## Legacy method: Get lineup data for an event
## @param event The event ID to get lineup data for
## @return Dictionary of lineup data or empty dictionary if not found
func get_event_lineups_data(event: String) -> Dictionary:
	# No null check - will crash if events is null (fail fast)
	@warning_ignore("redundant_await")
	var result: Dictionary = await events.get_lineup_data(event)
	return result

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
	# No null check - will crash if events is null (fail fast)
	@warning_ignore("redundant_await")
	var result: String = await events.save_lineup_data(event, lineup, level, p_data, lives, lineup_uuid)
	return result

## Legacy method: Remove lineups from an event
## @param event The event ID to remove lineups from
func remove_event_lineups(event: String) -> void:
	# No null check - will crash if events is null (fail fast)
	@warning_ignore("redundant_await")
	await events.remove_event_lineups(event)

## Legacy method: Save user data
## @param data The user data to save
## @return bool True if save was successful
func save_user_data(data: Dictionary) -> bool:
	# No null check - will crash if players is null (fail fast)
	@warning_ignore("redundant_await")
	var success: bool = await players.save_user_data(data)
	return success

## Clear all collection caches
## Useful for forcing fresh data to be loaded
## @return void
func clear_all_caches() -> void:
	Log.info("Clearing all collection caches", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_CACHE])

	if cards != null:
		cards.clear_cache()

	if levels != null:
		levels.clear_cache()

	if items != null:
		items.clear_cache()

	if events != null:
		events.clear_cache()

	if rules != null:
		rules.clear_cache()

	if players != null:
		players.clear_cache()

	Log.debug("All caches cleared", {
		"instance_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_CACHE])

## Helper to log active collections
## @return void
func _log_active_collections() -> void:
	var collection_status: Dictionary = {
		"cards": cards != null,
		"levels": levels != null,
		"items": items != null,
		"players": players != null,
		"events": events != null,
		"rules": rules != null
	}

	# Count active collections
	var active_count: int = 0
	for collection_name: String in collection_status.keys():
		if collection_status[collection_name]:
			active_count += 1

	Log.debug("Active collections", {
		"collections": collection_status,
		"active_count": active_count,
		"backend_type": _backend.get_class() if _backend != null else "none",
		"instance_id": get_instance_id()
	}, [Log.TAG_DB])
