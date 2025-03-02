extends Node

## Data source manager for handling game data from Firebase or local JSON files.
## Provides centralized access to cards, levels, items, and player data.

signal value_received(data: Dictionary)

# Logger tags
const TAG_DB: String = "database"
const TAG_CACHE: String = "cache"
const TAG_FIREBASE: String = "firebase"
const TAG_LOCAL: String = "local_data"
const TAG_ERROR: String = "error"
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

var db: Object  # FirebaseDatabase instance
var _initialized: bool = false
var current_uuid: String = ""
var test_group: int = 0
var local_data: Dictionary = {}
var current_root: Array = []
var debug_data: Dictionary = {}
var card_cache: Array = []

func _ready() -> void:
	Log.info("DataSource initializing", {}, [TAG_DB])
	_initialized = false

	if ClassDB.class_exists("FirebaseDatabase"):
		Log.info("Firebase RealTime Database available", {}, [TAG_FIREBASE])

		# FirebaseDatabase inherits from RefCounted in the C++ code
		db = ClassDB.instantiate("FirebaseDatabase")

		if db:
			# Connect to signals defined in database.h
			# These signals are emitted in the OnGetValue, OnChildAdded, etc. methods
			db.connect("get_value", Callable(self, "get_value"))
			db.connect("child_changed", Callable(self, "child_changed"))
			db.connect("child_moved", Callable(self, "child_moved"))
			db.connect("child_removed", Callable(self, "child_removed"))
			db.connect("child_added", Callable(self, "child_added"))

			# Set the initial database root
			set_root([SHEETS])
			Log.info("Firebase RealTime Database initialized", {}, [TAG_FIREBASE])
		else:
			Log.error("Failed to instantiate FirebaseDatabase", {}, [TAG_FIREBASE, TAG_ERROR])
	else:
		Log.info("Using local database file", {}, [TAG_LOCAL])
		var file: String = LOCAL_DB_FILE
		if debug.use_local_battle_db:
			file = LOCAL_DB_BATTLE_FILE
			Log.debug("Using battle database file", {"file": file}, [TAG_LOCAL])

		load_local_data(file)

	Log.info("DataSource initialization complete", {"firebase_available": is_firebase_available()}, [TAG_DB])
	_initialized = true


func is_firebase_available() -> bool:
	"""Check if Firebase is available and connected."""
	return db != null


func is_initialized() -> bool:
	"""Check if data source is fully initialized"""
	return _initialized


func addtest(tab: String) -> String:
	"""Add test group suffix to table name"""
	return str(tab, "_", test_group)


func activate_card_cache() -> void:
	"""Initialize card cache with all cards"""
	Log.info("Activating card cache", {}, [TAG_CACHE])

	card_cache = await get_all_cards()

	Log.info("Card cache activated", {"count": card_cache.size()}, [TAG_CACHE])


func get_default_player_data() -> Dictionary:
	"""Return default player data structure"""
	var data: Dictionary = {
		"progress": 1,
		"sfx": true,
		"music": false,
		"vibrate": true,
		"notification": false,
		"name": "test_avatar_name",
		"id": "1"
	}

	Log.debug("Generated default player data", {}, [TAG_DB])
	return data


func load_local_data(db_file: String) -> void:
	"""Load data from local JSON file"""
	Log.info("Loading local data file", {"file": db_file}, [TAG_LOCAL])

	if not FileAccess.file_exists(db_file):
		Log.error("Local data file does not exist", {"file": db_file}, [TAG_LOCAL, TAG_ERROR])
		return

	var file: FileAccess = FileAccess.open(db_file, FileAccess.READ)
	if not file:
		Log.error("Failed to open local data file", {"file": db_file, "error": FileAccess.get_open_error()}, [TAG_LOCAL, TAG_ERROR])
		return

	var json_text: String = file.get_as_text()
	file.close()

	var res: Variant = JSON.parse_string(json_text)
	if res == null:
		Log.error("Failed to parse local data JSON", {"file": db_file}, [TAG_LOCAL, TAG_ERROR])
		return

	if res is Dictionary:
		local_data = res[SHEETS]
		Log.info("Local data file loaded successfully", {"tables": local_data.keys().size()}, [TAG_LOCAL])
	else:
		Log.error("Local data is not a Dictionary", {"type": typeof(res)}, [TAG_LOCAL, TAG_ERROR])


func setup_player_data() -> int:
	"""Set up player data from server or create new data"""
	Log.info("Setting up player data", {}, [TAG_DB])

	var retval: int = await login()
	if OS.has_feature("editor"):
		retval = 0

	if retval:
		Log.warning("Login failed during player data setup", {"error_code": retval}, [TAG_DB, TAG_ERROR])
		return retval

	Log.debug("Fetching player data", {}, [TAG_DB])
	var data: Variant = await get_zen_player_data()

	if typeof(data) == TYPE_BOOL:
		Log.info("Player data not found, creating new data", {}, [TAG_DB])
		data = set_zen_player_data()

	return retval


func login() -> int:
	"""Login to auth service and return result code."""
	Log.debug("Logging in to auth service", {}, [TAG_DB])
	return await auth.login()


func get_user_data(uuid: String = "") -> Dictionary:
	"""Get user data for specified UUID or current user"""
	Log.info("Getting user data", {"specified_uuid": uuid.is_empty()}, [TAG_DB])

	var ret_val: Dictionary = {}
	if uuid.is_empty():
		if auth.is_available():
			uuid = auth.uid()
			Log.debug("Using auth UUID", {"uuid": uuid}, [TAG_DB])
		else:
			uuid = "0"
			Log.debug("Auth not available, using default UUID", {}, [TAG_DB])

	if db:
		set_root([PLAYERS, uuid])
		ret_val = await get_db_value(AVATAR_DATA)
		Log.debug("Retrieved user data from Firebase", {"uuid": uuid}, [TAG_DB, TAG_FIREBASE])
	else:
		await get_tree().idle_frame
		if debug_data:
			ret_val = debug_data
			Log.debug("Using debug data for user data", {}, [TAG_DB])

	return ret_val


func save_user_data(data: Dictionary) -> void:
	"""Save user data to server for current user"""
	Log.info("Saving user data", {}, [TAG_DB])

	var retval: int = await auth.login()
	if retval == 0:
		data_source.set_user_data(auth.uid(), data)
		Log.info("User data saved successfully", {"uuid": auth.uid()}, [TAG_DB])
	else:
		Log.error("Failed to save user data - login failed", {"error_code": retval}, [TAG_DB, TAG_ERROR])


func set_user_data(uuid: String, data: Dictionary) -> void:
	"""Set user data for specified UUID"""
	Log.info("Setting user data", {"uuid": uuid}, [TAG_DB])

	if not db:
		Log.error("Cannot set user data - database not available", {}, [TAG_DB, TAG_ERROR])
		return

	db.set_db_root([PLAYERS, uuid, AVATAR_DATA])
	db.set_value(["name"], data.name)
	db.set_value(["avatar_id"], data.avatar_id)

	Log.debug("User data set successfully", {"uuid": uuid, "name": data.name}, [TAG_DB])


func set_root(new_root: Array) -> void:
	"""Set current database root path"""
	if not db:
		Log.warning("Cannot set root - database not available", {"path": new_root}, [TAG_DB, TAG_ERROR])
		return

	db.set_db_root(new_root)
	current_root = new_root.duplicate(true)

	Log.debug("Set database root", {"path": new_root}, [TAG_DB, TAG_FIREBASE])


func get_db_sheet(sheet_name: String, is_dictionary: bool = false) -> Variant:
	"""Get data sheet from database or local data"""
	var full_name: String = str(sheet_name, "_", test_group)
	Log.debug("Getting database sheet", {"sheet": sheet_name, "full_name": full_name, "is_dict": is_dictionary}, [TAG_DB])

	var result: Variant
	if db:
		set_root([SHEETS])
		result = await get_db_value(full_name)
		Log.debug("Retrieved sheet from database", {"sheet": sheet_name}, [TAG_DB, TAG_FIREBASE])
	else:
		if not local_data.has(full_name):
			Log.error("Sheet not found in local data", {"sheet": full_name}, [TAG_DB, TAG_LOCAL, TAG_ERROR])
			if is_dictionary:
				return {}
			return []

		result = local_data[full_name]
		Log.debug("Retrieved sheet from local data", {"sheet": sheet_name}, [TAG_DB, TAG_LOCAL])

	if is_dictionary and result is Array and result.size() > 0:
		result = result[0]

	return result


func get_db_value(value: String) -> Variant:
	"""Get value from database with signal response handling"""
	Log.debug("Getting database value", {"key": value}, [TAG_DB, TAG_FIREBASE])

	var retval: Variant
	if not db:
		Log.error("Cannot get database value - database not available", {"key": value}, [TAG_DB, TAG_ERROR])
		return null

	db.get_value([value])
	var recieved: Dictionary = {"key": null}

	# Wait for value to be received via signal
	while recieved.key != value:
		recieved = await self.value_received
		retval = recieved.value

	return retval


func get_value(key: String, value: Variant) -> void:
	"""Signal handler for database value received from FirebaseDatabase::OnGetValue."""
	# This matches the signature in database.h for the "get_value" signal
	#emit_signal("value_received", {"key": key, "value": value})
	value_received.emit.call_deferred(({"key": key, "value": value}))
	Log.debug("Database value received", {"key": key, 'value': value}, [TAG_DB, TAG_FIREBASE])


func child_moved(_key: String, _value: Variant) -> void:
	"""Signal handler for database child moved"""
	Log.debug("Database child moved", {"key": _key}, [TAG_DB, TAG_FIREBASE])
	pass


func child_added(_key: String, _value: Variant) -> void:
	"""Signal handler for database child added"""
	Log.debug("Database child added", {"key": _key}, [TAG_DB, TAG_FIREBASE])
	pass


func child_removed(_key: String, _value: Variant) -> void:
	"""Signal handler for database child removed"""
	Log.debug("Database child removed", {"key": _key}, [TAG_DB, TAG_FIREBASE])
	pass


func child_changed(_key: String, _value: Variant) -> void:
	"""Signal handler for database child changed"""
	Log.debug("Database child changed", {"key": _key}, [TAG_DB, TAG_FIREBASE])
	pass


func get_zen_player_data() -> Variant:
	"""Get player data from zen data"""
	Log.debug("Getting zen player data", {}, [TAG_DB])
	# Placeholder - this method appears to be used but not implemented in original
	await get_tree().idle_frame
	return false


func set_zen_player_data() -> Dictionary:
	"""Set default zen player data"""
	Log.debug("Setting zen player data", {}, [TAG_DB])
	# Placeholder - this method appears to be used but not implemented in original
	return get_default_player_data()


func get_event_data() -> Array:
	"""Get event data from database"""
	Log.info("Getting event data", {}, [TAG_DB])
	var result: Array = await get_db_sheet(EVENTS, false)
	return result


func get_item_info(item_id: String) -> Dictionary:
	"""Get specific item info by ID"""
	Log.info("Getting item info", {"item_id": item_id}, [TAG_DB])

	var results: Array = await get_db_sheet(ITEMS, false)
	for item: Dictionary in results:
		if item.id == item_id:
			Log.debug("Item found", {"item_id": item_id}, [TAG_DB])
			return item

	Log.error("Item with id not found", {"item_id": item_id}, [TAG_DB, TAG_ERROR])
	return {}


func get_item_id_from_name(target_name: String) -> String:
	"""Find item ID by name"""
	Log.info("Getting item ID from name", {"name": target_name}, [TAG_DB])

	var result: Array = await get_db_sheet(ITEMS, false)
	for item: Dictionary in result:
		if item.name == target_name:
			Log.debug("Item name found", {"name": target_name, "id": item.id}, [TAG_DB])
			return item.id

	Log.error("Item name not found", {"name": target_name}, [TAG_DB, TAG_ERROR])
	return ""


func get_level_data(level_nr: int) -> Dictionary:
	"""Get level data by level number"""
	Log.info("Getting level data", {"level": level_nr}, [TAG_DB])

	var result: Array = await get_db_sheet(LEVELS, false)
	for level: Dictionary in result:
		var id: String = level.id
		if int(id) == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [TAG_DB])
			return level

	Log.warning("No level data found for level", {"level": level_nr}, [TAG_DB])
	return {}


func get_card_id_from_name(target_name: String) -> String:
	"""Find card ID by name"""
	Log.info("Getting card ID from name", {"name": target_name}, [TAG_DB])

	var result: Array = await get_all_cards()
	for card: Dictionary in result:
		if card.name == target_name:
			Log.debug("Card name found", {"name": target_name, "id": card.id}, [TAG_DB])
			return card.id

	Log.error("Card name not found", {"name": target_name}, [TAG_DB, TAG_ERROR])
	return ""


func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	"""Get specific card info by ID"""
	Log.info("Getting card info", {"card_id": card_id, "use_cache": use_cache}, [TAG_DB])

	var results: Array
	if use_cache:
		if card_cache.is_empty():
			Log.warning("Card cache requested but empty, loading cache first", {}, [TAG_CACHE, TAG_DB])
			await activate_card_cache()
		results = card_cache
	else:
		results = await get_all_cards()

	for card: Dictionary in results:
		var id: String = card.id
		if int(id) == int(card_id):
			Log.debug("Card found", {"card_id": card_id}, [TAG_DB])
			return card

	Log.error("Card with id not found", {"card_id": card_id}, [TAG_DB, TAG_ERROR])
	return {}


func get_all_cards(use_cache: bool = false) -> Array:
	"""Get all card data"""
	Log.info("Getting all cards", {"use_cache": use_cache}, [TAG_DB])

	if use_cache and not card_cache.is_empty():
		Log.debug("Using card cache", {"cache_size": card_cache.size()}, [TAG_CACHE, TAG_DB])
		return card_cache

	var cards: Array = await get_db_sheet(_CARDS, false)
	Log.debug("Retrieved all cards", {"count": cards.size()}, [TAG_DB])
	return cards


func get_rules_data() -> Dictionary:
	"""Get game rules data"""
	Log.info("Getting rules data", {}, [TAG_DB])
	return await get_db_sheet(RULES, true)


func get_all_levels() -> Array:
	"""Get all level data"""
	Log.info("Getting all levels", {}, [TAG_DB])
	return await get_db_sheet(LEVELS, false)


func get_all_items() -> Array:
	"""Get all item data"""
	Log.info("Getting all items", {}, [TAG_DB])
	return await get_db_sheet(ITEMS, false)


func create_arena_card(card_data: Dictionary) -> String:
	"""Create a new arena card in player collection"""
	Log.info("Creating arena card", {}, [TAG_DB])

	if not db:
		Log.error("Cannot create arena card - database not available", {}, [TAG_DB, TAG_ERROR])
		return ""

	if not auth.is_available():
		Log.error("Cannot create arena card - auth not available", {}, [TAG_DB, TAG_ERROR])
		return ""

	var uuid: String = auth.uid()
	db.set_db_root([PLAYERS, uuid, "COLLECTION"])
	var card_uid: String = db.push_child(["COLLECTION"])
	db.update_children([card_uid], card_data)

	Log.debug("Arena card created", {"card_uid": card_uid, "player_uuid": uuid}, [TAG_DB])
	return card_uid


func remove_event_lineups(event: String) -> void:
	"""Remove lineups from an event"""
	Log.info("Removing event lineups", {"event": event}, [TAG_DB])

	if not db:
		Log.error("Cannot remove event lineups - database not available", {}, [TAG_DB, TAG_ERROR])
		return

	db.set_db_root(["EVENTS", event])
	db.remove_value(["lineups"])

	Log.debug("Event lineups removed", {"event": event}, [TAG_DB])


func get_event_lineups_data(event: String) -> Dictionary:
	"""Get lineup data for an event"""
	Log.info("Getting event lineups data", {"event": event}, [TAG_DB])

	if db:
		db.set_db_root(["EVENTS", event])
		var lineups: Dictionary = await get_db_value("lineups")
		Log.debug("Event lineups retrieved", {"event": event, "count": lineups.size()}, [TAG_DB])
		return lineups

	Log.error("Database not available for getting event lineups", {}, [TAG_DB, TAG_ERROR])
	return {}


func save_event_lineup_data(
	event: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	"""Save lineup data for an event"""
	Log.info("Saving event lineup data", {"event": event, "level": level, "lives": lives}, [TAG_DB])

	if not db:
		Log.error("Cannot save event lineup - database not available", {}, [TAG_DB, TAG_ERROR])
		return ""

	var json_data: String = JSON.stringify(lineup)
	db.set_db_root(["EVENTS", event])
	var push_string: String = lineup_uuid if lineup_uuid else db.push_child(["lineups", event])
	var path: Array = [str("lineups", "/", push_string)]

	var data: Dictionary = {"lineup_level": level, "lineup_data": json_data, "lives": lives}
	if p_data:
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id

	db.update_children(path, data)

	Log.debug("Event lineup saved", {"event": event, "lineup_id": push_string}, [TAG_DB])
	return push_string

func ensure_db_available() -> bool:
	"""Helper function to check database availability and log error if unavailable."""
	if not db:
		Log.error("Database not available", {}, [TAG_DB, TAG_ERROR])
		return false
	return true
func safely_has_key(dict: Dictionary, key: String) -> bool:
	"""Helper function to safely check if a dictionary has a key."""
	return dict is Dictionary and dict.has(key)
