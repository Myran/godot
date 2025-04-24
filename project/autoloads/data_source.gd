extends Node

## Data source manager for handling game data from Firebase or local JSON files.
## Provides centralized access to cards, levels, items, and player data.
## Improved version with better separation of concerns between Firebase and local data.

## Emitted when a value is received from the database
## The data dictionary contains:
## - key: String - The key of the data received
## - value: Variant - The value received, could be Dictionary, Array, or primitive types
signal value_received(data: Dictionary)

## Emitted when data source initialization is complete
signal startup_completed

# Logger tags
const LOCAL_DB_FILE: String = "res://resources/data.json"
const LOCAL_DB_BATTLE_FILE: String = "res://resources/gameone-577cb-export.json"
const SHEETS: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
const ZEN_DATA: String = "zen_data"
const ZEN_PLAYERS: String = "zen_players"
const PLAYER_DATA: String = "player_data"
const ZEN_RULES: String = "zen_rules"
const ZEN_LOCATION_DATA: String = "zen_location_data"
const ZEN_PROGRESSION: String = "zen_progression"
const _CARDS: String = "cards"
const RULES: String = "rules"
const LEVELS: String = "levels"
const ITEMS: String = "items"
const PLAYERS: String = "players"
const AVATAR_DATA: String = "avatar_data"
const EVENTS: String = "event_data"
const ARENA_CARD: String = "arena_card"
const COLLECTION: String = "collection"

# Internal variables for data management
## Firebase database reference
var db: Object  # FirebaseDatabase instance
## Whether local data source is active
var using_local_data: bool = false
## Whether data source is initialized
var _initialized: bool = false
## Current user UUID
var current_uuid: String = ""
## Test group identifier for database tables
var test_group: int = 0
## Local data cache from JSON files
var local_data: Dictionary = {}
## Current database root path
var current_root: Array[String] = []
## Debug data for testing
var debug_data: Dictionary = {}
## Card data cache containing card dictionaries
var card_cache: Array = []

func _ready() -> void:
	Log.info("DataSource initializing", {}, [Log.TAG_DB])
	_initialized = false

	Log.info("Testing internet connection...", {}, [])
	internet_status.has_internet.connect(Callable(self, "internet_online"))
	internet_status.no_internet.connect(Callable(self, "internet_offline"))
	var internet_status_awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
	internet_status_awaiter.add(internet_status.has_internet)
	internet_status_awaiter.add(internet_status.no_internet)
	internet_status.get_status()
	await internet_status_awaiter.finished

	# Initialize appropriate data source (Firebase or local)
	initialize_data_source()

	Log.info(
		"DataSource initialization complete",
		{"firebase_available": is_firebase_available()},
		[Log.TAG_DB]
	)
	_initialized = true
	startup_completed.emit()

## Initialize either Firebase or local data source based on availability
func initialize_data_source() -> void:
	Log.debug("Initializing data source", {
		"platform": OS.get_name(),
		"in_editor": OS.has_feature("editor"),
		"debug_build": OS.is_debug_build()
	}, [Log.TAG_DB])

	if ClassDB.class_exists("FirebaseDatabase"):
		Log.debug("Firebase class found, initializing Firebase source", {"class": "FirebaseDatabase"}, [Log.TAG_DB, Log.TAG_FIREBASE])
		initialize_firebase_source()
	else:
		Log.warning("Firebase RealTime Database not available", {"reason": "ClassDB.class_exists returned false"}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		initialize_local_source()

## Initialize Firebase data source
func initialize_firebase_source() -> void:
	Log.info("Firebase RealTime Database available", {}, [Log.TAG_FIREBASE])

	# FirebaseDatabase inherits from RefCounted in the C++ code
	db = ClassDB.instantiate("FirebaseDatabase")

	if db:
		# Connect to signals defined in database.h
		db.connect("get_value", Callable(self, "get_value"))
		db.connect("child_changed", Callable(self, "child_changed"))
		db.connect("child_moved", Callable(self, "child_moved"))
		db.connect("child_removed", Callable(self, "child_removed"))
		db.connect("child_added", Callable(self, "child_added"))

		# Set the initial database root
		set_root([SHEETS])
		using_local_data = false
		Log.info("Firebase RealTime Database initialized", {}, [Log.TAG_FIREBASE])
	else:
		Log.error(
			"Failed to instantiate FirebaseDatabase", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		initialize_local_source()

## Initialize local data source
func initialize_local_source() -> void:
	Log.info("Using local database file", {}, [Log.TAG_LOCAL])
	var file: String = LOCAL_DB_FILE
	if debug.use_local_battle_db:
		file = LOCAL_DB_BATTLE_FILE
		Log.debug("Using battle database file", {"file": file}, [Log.TAG_LOCAL])

	load_local_data(file)
	using_local_data = true

## Called when internet connection is detected
func internet_online() -> void:
	Log.info("Internet online", {"time": Time.get_datetime_string_from_system()}, [Log.TAG_NETWORK])

## Called when internet connection is lost
func internet_offline() -> void:
	Log.warning("Internet offline", {"time": Time.get_datetime_string_from_system()}, [Log.TAG_NETWORK])

## Check if Firebase is available and connected
func is_firebase_available() -> bool:
	var available: bool = db != null and not using_local_data
	Log.debug("Firebase availability check", {
		"available": available,
		"db_exists": db != null,
		"using_local": using_local_data
	}, [Log.TAG_DB, Log.TAG_FIREBASE])
	return available

## Check if data source is fully initialized
func is_initialized() -> bool:
	return _initialized

## Add test group suffix to table name
func addtest(tab: String) -> String:
	return str(tab, "_", test_group)

## Initialize card cache with all cards
func activate_card_cache() -> void:
	Log.info("Activating card cache", {"previous_size": card_cache.size()}, [Log.TAG_CACHE, Log.TAG_DB])

	card_cache = await get_all_cards()

	Log.info("Card cache activated", {
		"count": card_cache.size(),
		"data_source": "firebase" if is_firebase_available() else "local"
	}, [Log.TAG_CACHE, Log.TAG_DB])

## Return default player data structure
func get_default_player_data() -> Dictionary:
	var data: Dictionary = {
		"progress": 1,
		"sfx": true,
		"music": false,
		"vibrate": true,
		"notification": false,
		"name": "test_avatar_name",
		"id": "1"
	}

	Log.debug("Generated default player data", {}, [Log.TAG_DB])
	return data

## Load data from local JSON file
func load_local_data(db_file: String) -> void:
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
		local_data = res[SHEETS]
		Log.info(
			"Local data file loaded successfully",
			{"tables": local_data.keys().size()},
			[Log.TAG_LOCAL]
		)
	else:
		Log.error(
			"Local data is not a Dictionary", {"type": typeof(res)}, [Log.TAG_LOCAL, Log.TAG_ERROR]
		)

## Set up player data from server or create new data
func setup_player_data() -> int:
	Log.info("Setting up player data", {}, [Log.TAG_DB])

	var retval: int = await login()
	if OS.has_feature("editor"):
		retval = 0

	if retval:
		Log.warning(
			"Login failed during player data setup",
			{"error_code": retval},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return retval

	Log.debug("Fetching player data", {}, [Log.TAG_DB])
	var data: Variant = await get_zen_player_data()

	if typeof(data) == TYPE_BOOL:
		Log.info("Player data not found, creating new data", {}, [Log.TAG_DB])
		data = set_zen_player_data()

	return retval

## Login to auth service and return result code
func login() -> int:
	Log.debug("Logging in to auth service", {}, [Log.TAG_DB])
	return await auth.login()

## Get user data for specified UUID or current user
func get_user_data(uuid: String = "") -> Dictionary:
	Log.info("Getting user data", {"specified_uuid": uuid.is_empty()}, [Log.TAG_DB])

	var ret_val: Dictionary = {}
	if uuid.is_empty():
		if auth.is_available():
			uuid = auth.uid()
			Log.debug("Using auth UUID", {"uuid": uuid}, [Log.TAG_DB])
		else:
			uuid = "0"
			Log.debug("Auth not available, using default UUID", {}, [Log.TAG_DB])

	if is_firebase_available():
		set_root([PLAYERS, uuid])
		ret_val = await get_db_value(AVATAR_DATA)
		Log.debug(
			"Retrieved user data from Firebase", {"uuid": uuid}, [Log.TAG_DB, Log.TAG_FIREBASE]
		)
	else:
		await get_tree().idle_frame
		if debug_data:
			ret_val = debug_data
			Log.debug("Using debug data for user data", {}, [Log.TAG_DB])

	return ret_val

## Save user data to server for current user
func save_user_data(data: Dictionary) -> void:
	Log.info("Saving user data", {}, [Log.TAG_DB])

	var retval: int = await auth.login()
	if retval == 0:
		set_user_data(auth.uid(), data)
		Log.info("User data saved successfully", {"uuid": auth.uid()}, [Log.TAG_DB])
	else:
		Log.error(
			"Failed to save user data - login failed",
			{"error_code": retval},
			[Log.TAG_DB, Log.TAG_ERROR]
		)

## Set user data for specified UUID
func set_user_data(uuid: String, data: Dictionary) -> void:
	Log.info("Setting user data", {"uuid": uuid}, [Log.TAG_DB])

	if not is_firebase_available():
		Log.error("Cannot set user data - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return

	set_root([PLAYERS, uuid, AVATAR_DATA])
	db.set_value(["name"], data.name)
	db.set_value(["avatar_id"], data.avatar_id)

	Log.debug("User data set successfully", {"uuid": uuid, "name": data.name}, [Log.TAG_DB])

## Set current database root path
func set_root(new_root: Array[String]) -> void:
	if not is_firebase_available():
		Log.warning(
			"Cannot set root - database not available",
			{"path": new_root},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		current_root = new_root.duplicate(true)
		return

	db.set_db_root(new_root)
	current_root = new_root.duplicate(true)

	Log.debug("Set database root", {"path": new_root}, [Log.TAG_DB, Log.TAG_FIREBASE])

## Get data sheet from database or local data
## Returns either an Array[Dictionary] or a Dictionary depending on is_dictionary parameter
## @return Array[Dictionary] if is_dictionary is false, Dictionary otherwise
func get_db_sheet(sheet_name: String, is_dictionary: bool = false) -> Variant:
	var full_name: String = str(sheet_name, "_", test_group)
	Log.debug(
		"Getting database sheet",
		{"sheet": sheet_name, "full_name": full_name, "is_dict": is_dictionary, "source": "firebase" if is_firebase_available() else "local"},
		[Log.TAG_DB]
	)

	var result: Variant
	if is_firebase_available():
		set_root([SHEETS])
		result = await get_db_value(full_name)
		Log.debug(
			"Retrieved sheet from database", {"sheet": sheet_name}, [Log.TAG_DB, Log.TAG_FIREBASE]
		)
	else:
		if not local_data.has(full_name):
			Log.error(
				"Sheet not found in local data",
				{"sheet": full_name},
				[Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR]
			)
			if is_dictionary:
				return {}
			return []

		result = local_data[full_name]
		Log.debug(
			"Retrieved sheet from local data", {"sheet": sheet_name}, [Log.TAG_DB, Log.TAG_LOCAL]
		)

	if is_dictionary and result is Array and result.size() > 0:
		result = result[0]

	return result

## Get value from database with signal response handling
## Returns the value from the database (could be Dictionary, Array, or primitive types)
## @return The requested value from the database, or null if not found
func get_db_value(value: String) -> Variant:
	Log.debug("Getting database value", {"key": value}, [Log.TAG_DB])

	if using_local_data:
		# Handle local data
		if local_data.has(value):
			var result: Variant = local_data[value]
			# Simulate signal emission for API compatibility
			value_received.emit({"key": value, "value": result})
			Log.debug("Local data value retrieved", {"key": value, "type": typeof(result)}, [Log.TAG_DB, Log.TAG_LOCAL])
			return result
		else:
			Log.error(
				"Key not found in local data",
				{"key": value, "available_keys": local_data.keys()},
				[Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR]
			)
			return null

	# Handle Firebase data
	var retval: Variant
	if not db:
		Log.error(
			"Cannot get database value - database not available",
			{"key": value},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return null

	db.get_value([value])
	var recieved: Dictionary = {"key": null}

	# Wait for value to be received via signal
	while recieved.key != value:
		recieved = await self.value_received
		retval = recieved.value

	return retval

## Signal handler for database value received from FirebaseDatabase::OnGetValue
func get_value(key: String, value: Variant) -> void:
	value_received.emit({"key": key, "value": value})
	Log.debug(
		"Database value received", {"key": key, "value": value}, [Log.TAG_DB, Log.TAG_FIREBASE]
	)

## Signal handler for database child moved
func child_moved(_key: String, _value: Variant) -> void:
	Log.debug("Database child moved", {"key": _key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	pass

## Signal handler for database child added
func child_added(_key: String, _value: Variant) -> void:
	Log.debug("Database child added", {"key": _key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	pass

## Signal handler for database child removed
func child_removed(_key: String, _value: Variant) -> void:
	Log.debug("Database child removed", {"key": _key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	pass

## Signal handler for database child changed
func child_changed(_key: String, _value: Variant) -> void:
	Log.debug("Database child changed", {"key": _key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	pass

## Get player data from zen data
## Returns Dictionary if found or boolean false if not found
func get_zen_player_data() -> Variant:
	Log.debug("Getting zen player data", {}, [Log.TAG_DB])
	# Placeholder - this method appears to be used but not implemented in original
	await get_tree().idle_frame
	return false

## Set default zen player data
func set_zen_player_data() -> Dictionary:
	Log.debug("Setting zen player data", {}, [Log.TAG_DB])
	# Placeholder - this method appears to be used but not implemented in original
	return get_default_player_data()

## Get event data from database
## Returns an array of dictionaries containing event information
func get_event_data() -> Array:
	Log.info("Getting event data", {}, [Log.TAG_DB])
	var result: Array = await get_db_sheet(EVENTS, false)
	return result

## Get specific item info by ID
func get_item_info(item_id: String) -> Dictionary:
	Log.info("Getting item info", {"item_id": item_id}, [Log.TAG_DB])

	var results: Array = await get_db_sheet(ITEMS, false)
	for item: Dictionary in results:
		if item.id == item_id:
			Log.debug("Item found", {"item_id": item_id}, [Log.TAG_DB])
			return item

	Log.error("Item with id not found", {"item_id": item_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}

## Find item ID by name
func get_item_id_from_name(target_name: String) -> String:
	Log.info("Getting item ID from name", {"name": target_name}, [Log.TAG_DB])

	var result: Array = await get_db_sheet(ITEMS, false)
	for item: Dictionary in result:
		if item.name == target_name:
			Log.debug("Item name found", {"name": target_name, "id": item.id}, [Log.TAG_DB])
			return item.id

	Log.error("Item name not found", {"name": target_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""

## Get level data by level number
func get_level_data(level_nr: int) -> Dictionary:
	Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB])

	var result: Array = await get_db_sheet(LEVELS, false)
	for level: Dictionary in result:
		var id: String = level.id
		if int(id) == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
			return level

	Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB])
	return {}

## Find card ID by name
func get_card_id_from_name(target_name: String) -> String:
	Log.info("Getting card ID from name", {"name": target_name}, [Log.TAG_DB])

	var result: Array = await get_all_cards()
	for card: Dictionary in result:
		if card.name == target_name:
			Log.debug("Card name found", {"name": target_name, "id": card.id}, [Log.TAG_DB])
			return card.id

	Log.error("Card name not found", {"name": target_name}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""

## Get specific card info by ID
func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [Log.TAG_DB])

	var results: Array = []
	if use_cache:
		if card_cache.is_empty():
			Log.warning(
				"Card cache requested but empty, loading cache first",
				{},
				[Log.TAG_CACHE, Log.TAG_DB]
			)
			await activate_card_cache()
		results = card_cache
	else:
		results = await get_all_cards()

	for card: Dictionary in results:
		var id: String = card.id
		if int(id) == int(card_id):
			Log.debug("Card found", {"card_id": card_id}, [Log.TAG_DB])
			return card

	Log.error("Card with id not found", {"card_id": card_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}

## Get all card data
## Returns an array of dictionaries containing card information
func get_all_cards(use_cache: bool = false) -> Array:
	Log.info("Getting all cards", {"use_cache": use_cache}, [Log.TAG_DB])

	if use_cache and not card_cache.is_empty():
		Log.debug(
			"Using card cache", {"cache_size": card_cache.size()}, [Log.TAG_CACHE, Log.TAG_DB]
		)
		return card_cache

	var cards: Array = await get_db_sheet(_CARDS, false)
	Log.info("Retrieved all cards", {"count": cards.size()}, [Log.TAG_DB])
	return cards

## Get game rules data
func get_rules_data() -> Dictionary:
	Log.info("Getting rules data", {}, [Log.TAG_DB])
	return await get_db_sheet(RULES, true)

## Get all level data
## Returns an array of dictionaries containing level information
func get_all_levels() -> Array:
	Log.info("Getting all levels", {}, [Log.TAG_DB])
	return await get_db_sheet(LEVELS, false)

## Get all item data
## Returns an array of dictionaries containing item information
func get_all_items() -> Array:
	Log.info("Getting all items", {}, [Log.TAG_DB])
	return await get_db_sheet(ITEMS, false)

## Create a new arena card in player collection
func create_arena_card(card_data: Dictionary) -> String:
	Log.info("Creating arena card", {}, [Log.TAG_DB])

	if not is_firebase_available():
		Log.error(
			"Cannot create arena card - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return ""

	if not auth.is_available():
		Log.error("Cannot create arena card - auth not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""

	var uuid: String = auth.uid()
	set_root([PLAYERS, uuid, "COLLECTION"])
	var card_uid: String = db.push_child(["COLLECTION"])
	db.update_children([card_uid], card_data)

	Log.debug("Arena card created", {"card_uid": card_uid, "player_uuid": uuid}, [Log.TAG_DB])
	return card_uid

## Remove lineups from an event
func remove_event_lineups(event: String) -> void:
	Log.info("Removing event lineups", {"event": event}, [Log.TAG_DB])

	if not is_firebase_available():
		Log.error(
			"Cannot remove event lineups - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return

	set_root(["EVENTS", event])
	db.remove_value(["lineups"])

	Log.debug("Event lineups removed", {"event": event}, [Log.TAG_DB])

## Get lineup data for an event
func get_event_lineups_data(event: String) -> Dictionary:
	Log.info("Getting event lineups data", {"event": event}, [Log.TAG_DB])

	if is_firebase_available():
		set_root(["EVENTS", event])
		var lineups: Dictionary = await get_db_value("lineups")
		Log.debug(
			"Event lineups retrieved", {"event": event, "count": lineups.size()}, [Log.TAG_DB]
		)
		return lineups

	Log.error("Database not available for getting event lineups", {}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}

## Save lineup data for an event
func save_event_lineup_data(
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

	if not is_firebase_available():
		Log.error(
			"Cannot save event lineup - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR]
		)
		return ""

	var json_data: String = JSON.stringify(lineup)
	set_root(["EVENTS", event])
	var push_string: String = lineup_uuid if lineup_uuid else db.push_child(["lineups", event])
	var path: Array[String] = [str("lineups", "/", push_string)]

	var data: Dictionary = {"lineup_level": level, "lineup_data": json_data, "lives": lives}
	if p_data:
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id

	db.update_children(path, data)

	Log.debug("Event lineup saved", {"event": event, "lineup_id": push_string}, [Log.TAG_DB])
	return push_string

## Helper function to check database availability and log error if unavailable
func ensure_db_available() -> bool:
	if not is_firebase_available():
		Log.error("Database not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
	return true

## Helper function to safely check if a dictionary has a key
func safely_has_key(dict: Dictionary, key: String) -> bool:
	return dict is Dictionary and dict.has(key)
