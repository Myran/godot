extends Node
#test
signal value_received(data: Dictionary)

const local_db_file: String = "res://resources/data.json"
const local_db_battle_file: String = "res://resources/gameone-577cb-export.json"
const sheets: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
const zen_data: String = "zen_data"
const zen_players: String = "zen_players"
const player_data: String = "player_data"
const zen_rules: String = "zen_rules"
const zen_location_data: String = "zen_location_data"
const zen_progression: String = "zen_progression"

var test_group: int = 0
var local_data: Dictionary = {}
var db: Object
var current_root: Array = []
var debug_data: Dictionary = {}
var card_cache: Array = []

const _cards: String = "cards"
const rules: String = "rules"
const levels: String = "levels"
const items: String = "items"
const players: String = "players"
const avatar_data: String = "avatar_data"
const events: String = "event_data"
const arena_card: String = "arena_card"
const collection: String = "collection"
var current_uuid: String = ""

func activate_card_cache() -> void:
	card_cache = await get_all_cards()

func addtest(tab: String) -> String:
	return str(tab, "_", test_group)

func get_default_player_data() -> Dictionary:
	var data: Dictionary = {}
	data.progress = 1
	data.sfx = true
	data.music = false
	data.vibrate = true
	data.notification = false
	data.name = "test_avatar_name"
	data.id = "1"
	return data

func _ready() -> void:
	if ClassDB.class_exists("FirebaseDatabase"):
		print("Firebase RealTime Database exists singleton")
		db = ClassDB.instantiate("FirebaseDatabase")
		db.connect("get_value", Callable(self, "get_value"))
		db.connect("child_changed", Callable(self, "child_changed"))
		db.connect("child_moved", Callable(self, "child_moved"))
		db.connect("child_removed", Callable(self, "child_removed"))
		db.connect("child_added", Callable(self, "child_added"))
		set_root([sheets])
	else:
		var file: String = local_db_file
		if debug.use_local_battle_db:
			file = local_db_battle_file
		load_local_data(file)

func load_local_data(db_file: String) -> void:
	var file: FileAccess = FileAccess.open(db_file, FileAccess.READ)
	var res: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if res is Dictionary:
		local_data = res[sheets]
		printt("local data file loaded successfully")
	else:
		push_error(str("Failed to load local data file error: ", res))

func setup_player_data() -> int:
	var retval: int = await data_source.login()
	if OS.has_feature("editor"):
		retval = 0
	if retval:
		return retval
	var data: Variant = await data_source.get_zen_player_data()
	if typeof(data) == TYPE_BOOL:
		data = data_source.set_zen_player_data()
	return retval

func get_user_data(uuid: String = "") -> Dictionary:
	var ret_val: Dictionary = {}
	if uuid.is_empty():
		if auth.is_available():
			uuid = auth.uid()
		else:
			uuid = "0"
	if db:
		set_root([players, uuid])
		ret_val = await get_db_value(avatar_data)
	else:
		await get_tree().idle_frame
		if debug_data:
			ret_val = debug_data
	return ret_val

func save_user_data(data: Dictionary) -> void:
	var retval: int = await auth.login()
	if retval == 0:
		data_source.set_user_data(auth.uid(), data)

func set_user_data(uuid: String, data: Dictionary) -> void:
	print("set user data:", data)
	db.set_db_root([players, uuid, avatar_data])
	db.set_value(["name"], data.name)
	db.set_value(["avatar_id"], data.avatar_id)

func set_root(new_root: Array) -> void:
	db.set_db_root(new_root)
	current_root = new_root.duplicate(true)

func get_db_sheet(sheet_name: String, is_dictionary: bool = false) -> Variant:
	var result: Variant
	var _name: String = str(sheet_name, "_", test_group)
	if db:
		set_root([sheets])
		result = await get_db_value(_name)
	else:
		result = local_data[_name]
	if is_dictionary:
		result = result[0]
	return result

func get_db_value(value: String) -> Variant:
	var retval: Variant
	db.get_value([value])
	var recieved: Dictionary = {"key": null}
	while recieved.key != value:
		recieved = await self.value_received
		retval = recieved.value
	return retval

func get_value(key: String, value: Variant) -> void:
	emit_signal("value_received", {"key": key, "value": value})

func child_moved(_key: String, _value: Variant) -> void:
	pass

func child_added(_key: String, _value: Variant) -> void:
	pass

func child_removed(_key: String, _value: Variant) -> void:
	pass

func child_changed(_key: String, _value: Variant) -> void:
	pass

func get_event_data() -> Array:
	var result: Array = await get_db_sheet(events, false)
	return result

func get_item_info(item_id: String) -> Dictionary:
	print("get item info:", item_id)
	var results: Array = await get_db_sheet(items, false)
	for item: Dictionary in results:
		if item.id == item_id:
			return item
	push_error(str("Item with id not found: ", item_id))
	return {}

func get_item_id_from_name(target_name: String) -> String:
	var result: Array = await get_db_sheet(items, false)
	for item: Dictionary in result:
		if item.name == target_name:
			return item.id
	push_error(str("Item name not found: ", target_name))
	return ""

func get_level_data(level_nr: int) -> Dictionary:
	var result: Array = await get_db_sheet(levels, false)
	for level: Dictionary in result:
		var id : String = level.id
		if int(id) == level_nr:
			return level
	push_warning(str("No level data found for level:", level_nr))
	return {}

func get_card_id_from_name(target_name: String) -> String:
	var result: Array = await get_all_cards()
	for card: Dictionary in result:
		if card.name == target_name:
			return card.id
	push_error(str("Card name not found: ", target_name))
	return ""

func get_card_info(card_id: String, use_cache: bool = false) -> Dictionary:
	print("get card info:", card_id)
	var results: Array
	if use_cache:
		results = card_cache
	else:
		results = await get_all_cards()
	for card: Dictionary in results:
		var id : String = card.id
		if int(id) == int(card_id):
			return card
	push_error(str("Card with id not found: ", card_id))
	return {}

func get_all_cards(use_cache: bool = false) -> Array:
	if use_cache:
		return card_cache
	return await get_db_sheet(_cards, false)

func get_rules_data() -> Dictionary:
	return await get_db_sheet(rules, true)

func get_all_levels() -> Array:
	return await get_db_sheet(levels, false)

func get_all_items() -> Array:
	return await get_db_sheet(items, false)

func create_arena_card(card_data: Dictionary) -> String:
	var uuid: String = auth.uid()
	db.set_db_root([players, uuid, "collection"])
	var card_uid: String = db.push_child(["collection"])
	db.update_children([card_uid], card_data)
	return card_uid

func remove_event_lineups(event: String) -> void:
	db.set_db_root(["events", event])
	db.remove_value(["lineups"])

func get_event_lineups_data(event: String) -> Dictionary:
	print("get event lineups data ", event)
	if db:
		db.set_db_root(["events", event])
		return await get_db_value("lineups")
	push_error("Database not available!")
	return {}

func save_event_lineup_data(event: String, lineup: Dictionary, level: int = 1, 
	p_data: Dictionary = {}, lives: int = 3, lineup_uuid: String = "") -> String:
	var json_data: String = JSON.stringify(lineup)
	db.set_db_root(["events", event])
	var pushString: String = lineup_uuid if lineup_uuid else db.push_child(["lineups", event])
	var path: Array = [str("lineups", "/", pushString)]
	var data: Dictionary = {"lineup_level": level, "lineup_data": json_data, "lives": lives}
	if p_data:
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id
	db.update_children(path, data)
	return pushString
