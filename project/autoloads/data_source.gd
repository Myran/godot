extends Node

signal value_received

const local_db_file = "res://resources/data.json"
const local_db_battle_file = "res://resources/gameone-577cb-export.json"
const sheets = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
const zen_data = "zen_data"
const zen_players = "zen_players"
const player_data = "player_data"
const zen_rules = "zen_rules"
const zen_location_data = "zen_location_data"
const zen_progression = "zen_progression"

var test_group = 0
var local_data = {}
var db
var current_root = null
var debug_data = null
var card_cache = null

const _cards = "cards"
const rules = "rules"
const levels = "levels"
const items = "items"
const players = "players"
const avatar_data = "avatar_data"
const events = "event_data"
const arena_card = "arena_card"
const collection = "collection"
var current_uuid

func activate_card_cache():
	card_cache = await get_all_cards()

func addtest(tab):
	return str(tab,"_",test_group)


func get_default_player_data():
	var data = {}

	data.progress = 1
	data.sfx = true
	data.music = false
	data.vibrate = true
	data.notification = false
	data.name = "test_avatar_name"
	data.id = "1"
	return data


func _ready():
	if ClassDB.class_exists("FirebaseDatabase"):
		print("Firebase RealTime Database exists singleton")
		db = ClassDB.instantiate("FirebaseDatabase")
		db.connect("get_value", Callable(self, "get_value"))
		db.connect("child_changed", Callable(self, "child_changed"))
		db.connect("child_moved", Callable(self, "child_moved"))
		db.connect("child_removed", Callable(self, "child_removed"))
		db.connect("child_added", Callable(self, "child_added"))
		#db.set_db_root([sheets])
		set_root([sheets])
	else:
		var file = local_db_file
		if debug.use_local_battle_db:
			file = local_db_battle_file
		load_local_data(file)

func load_local_data(db_file):
	# var file = FileAccess.new();
	var file = FileAccess.open(db_file, FileAccess.READ);
	#TODO: Error handling?
	var res = JSON.parse_string(file.get_as_text())
	file.close()
	if res is Dictionary:
		local_data =res[sheets]
		printt("local data file loaded successfully")
	else:
		push_error(str("Failed to load local data file error: ",res))

func setup_player_data():
	var retval = await data_source.login()

	if OS.has_feature("editor"):
		# Login "works" if in editor
		retval = 0

	if retval:
		# error since not 0 
		return retval
	var data = await data_source.get_zen_player_data()
	if TYPE_BOOL == typeof(data):
		print("Zen player data missing. creating new player data")
		data = data_source.set_zen_player_data()
	return retval

#func get_user_data(uuid = null):
#	print("uuid:",uuid)
#	if uuid == null:
#		#assert(auth,"Auth not available")
#		#print("Default to user: 3rmglsWkuIaymJUJUcMXSva983J2")
#		#uuid = "3rmglsWkuIaymJUJUcMXSva983J2"
#		uuid = auth.uid()
#	print("get_user data from uid:",uuid)
#	db.set_db_root([players,uuid])
##	db.get_value([avatar_data])
##	var ret_val = yield(self,"player_data")
#	var ret_val = yield(get_db_value(avatar_data),"completed")
#	print("get user data:",ret_val)
#	return ret_val

func get_user_data(uuid = null):
	#print("get zen player data uuid:",uuid)
	var ret_val = false
	if uuid == null:
		if auth.is_available():
			#print("auth available")
			uuid = auth.uid()
		else:
			uuid = 0
		#print("new uuid: ", uuid)
	#print("get_user data from uid:",uuid)
	if db:
		set_root([players,uuid])
		ret_val = await get_db_value(avatar_data)
	else:
		await get_tree().idle_frame
		if debug_data:
			ret_val = debug_data
	return ret_val
#
func save_user_data(data):
	var retval = await auth.login()
	if retval == 0:
		data_source.set_user_data(auth.uid(),data)

func set_user_data(uuid,data):
	print("set user data:",data)
	db.set_db_root([players,uuid,avatar_data])
	db.set_value(["name"],data.name)
	db.set_value(["avatar_id"],data.avatar_id)

func set_root(new_root):
	#if current_root == new_root:
	#	return
#	printt("current root:",current_root,"new root:",new_root)
#	if current_root == new_root:
#		print("compared true")
#	else:
#		print("compared false")
	db.set_db_root(new_root)
	current_root = new_root.duplicate(true)


func get_db_sheet(sheet_name,is_dictionary = false):
	var result
	var _name = str(sheet_name,"_",test_group)

	if db:
		#db.set_db_root([sheets])
		set_root([sheets])
		result = await get_db_value(_name)
		#print("DB RESULT: ",result)
	else:
		#await get_tree().process_frame
		result = local_data[_name]
	#print("result received: ",result)
	if is_dictionary:
		result = result[0]
	return result

func get_db_value(value):
	var retval
	db.get_value([value])
	var recieved = {"key":null}
	while recieved.key != value:
		recieved = await self.value_received
		retval = recieved.value
	return retval
"""
func get_zen_progression():
	return await get_db_sheet(zen_progression)

func get_zen_location_data():
	return await get_db_sheet(zen_location_data)

func get_zen_rules_data():
	return await get_db_sheet(zen_rules,true)

func get_zen_level_data():
	return await get_db_sheet(zen_data)

func get_zen_level(level_uuid):
	var result
	if db:
		#db.set_db_root(["zen","levels"])
		set_root(["zen","levels"])
		db.get_value([level_uuid,"zen_level"])
		var ret_val
		var recieved = {"key":null}
		while recieved.key != "zen_level":
			recieved = await self.value_received
			ret_val = recieved.value
		var test_json_conv = JSON.new()
		test_json_conv.JSON.parse_string(ret_val).result
		result =  test_json_conv.get_data()
	else:
		await get_tree().idle_frame
		push_warning("No DB: Load zen levels from disk as scenes instead")
	return result

func set_zen_level(level_uuid, level_data):

	var json_data = JSON.stringify(level_data)
	#db.set_db_root(["zen","levels"])
	set_root(["zen","levels"])
	var pushString
	if level_uuid == null:
		pushString = db.push_child(["zen","levels"])
	else:
		pushString = level_uuid
	var path = [str(pushString)]
	var data = {"zen_level":json_data}

	#print("data source zen level data: ",data)
	db.update_children(path,data)
	return pushString


func get_zen_player_data(uuid = null):
	#print("get zen player data uuid:",uuid)
	var ret_val = false
	if uuid == null:
		if auth.is_available():
			#print("auth available")
			uuid = auth.uid()
		else:
			uuid = 0
		#print("new uuid: ", uuid)
	#print("get_user data from uid:",uuid)
	if db:
		set_root([zen_players,uuid])
		ret_val = await get_db_value(player_data)
	else:
		await get_tree().idle_frame
		if debug_data:
			ret_val = debug_data
	if TYPE_BOOL == typeof(ret_val):
		print("Zen player data missing. creating new")
		ret_val= data_source.set_zen_player_data()

	var val_converted = {}
	for key in ret_val.keys():
		var val = ret_val[key]
		val_converted[key] = str_to_var(val)

	return val_converted

func set_zen_player_data(data = null, uuid = null):
	print("set_zen_player_data")
	if uuid == null:
		if auth.is_available():
			#uuid = auth.uid()
			pass
		else:
			uuid = 0
	if data == null:
		data = get_default_player_data()

	var ret_data = {}
	if db:
		set_root([zen_players,uuid,player_data])
		for key in data:
			var _t = var_to_str(data[key])
			db.set_value([key],_t)
			ret_data[key] = _t
	else:
		for key in data:
			ret_data[key] = var_to_str(data[key])
		debug_data = ret_data
	return ret_data


func set_zen_player_value(key,_value):
	var value = var_to_str(_value)
	#db.set_db_root([zen_players,auth.uid()])
	if db:
		set_root([zen_players,auth.uid(),player_data])
		db.set_value([key],value)
	else:
		if !debug_data:
			debug_data = set_zen_player_data()
		debug_data[key] = value

func login():
	return await auth.login()

#func addtest(tab):
#	return str(tab,"_",test_group)
"""
func get_value(key,value):
	#printt("key:",key,"Value:",value)
	emit_signal("value_received",{"key":key,"value":value})

func child_moved(_key,_value):
	#printt("child moved",_key,"value",_value)
	pass

func child_added(_key,_value):
	#printt("child added",_key,"value",_value)
	pass

func child_removed(_key,_value):
	#printt("child removed",_key,"value",_value)
	pass

func child_changed(_key,_value):
	#printt("Child changed:","key:",_key,"value",_value)
	pass

func get_event_data():
	var result = await get_db_sheet(events,false)
	return result



func get_item_info(item_id):
	print("get item info:",item_id)
	var results = await get_db_sheet(items,false)
	for item in results:
		if item.id == item_id:
			return item
	assert(false,str("item with id not found! : ",item_id))


func get_item_id_from_name(target_name):
	var result = await get_db_sheet(items,false)
	for item in result:
		if item.name == target_name:
			return item.id
	assert(false,str("item name not found! : ",target_name))


func get_level_data(level_nr):
	var result = await get_db_sheet(levels,false)
	for level in result:
		if int(level.id) == int(level_nr):
			return level
	push_warning(str("No level data found for level:",level_nr))
	return {}

func get_card_id_from_name(target_name):
	#print("get card from name ",target_name)
	var result = await get_all_cards()

	for card in result:
		if card.name == target_name:
			return card.id
	assert(false,str("card name not found! : ",target_name))

func get_card_info(card_id,use_cache = false):
	print("get card info:",card_id)
	var results
	if use_cache:
		assert(card_cache,"Card cache is missing!")
		results = card_cache
	else:
		results = await get_all_cards()

	for card in results:
		if int(card.id) == int(card_id):
			return card
	assert(false,str("card with id not found! : ",card_id))

func get_all_cards(use_cache = false):
	if use_cache:
		assert(card_cache,"Card cache is missing!")
		return card_cache
	return await get_db_sheet(_cards,false)

func get_rules_data():
	return await get_db_sheet(rules,true)

func get_all_levels():
	return await get_db_sheet(levels,false)

func get_all_items():
	return await get_db_sheet(items,false)



## Arena game mode
func create_arena_card(card_data):
	assert(auth,"Auth not available")
	var uuid = auth.uid()
	print("create arena card")
	db.set_db_root([players,uuid,"collection"])
	var card_uid = db.push_child(["collection"])
	print("pushstring",card_uid)
	db.update_children([card_uid],card_data)
	return card_uid


func remove_card_from_collection():
	pass

"""
func get_arena_card_data(card_uid):
	print("TTT Get arena card data:",card_uid)
	assert(auth,"Auth not available")
	var uuid
	if !auth.is_logged_in():
		login()
		await auth.logged_in

	uuid = auth.uid()
	assert(uuid,"uuid not available")
	printt("TTT card_uid:",card_uid,"uuid:",uuid)
	db.set_db_root([players,uuid,"collection"])
	db.get_value([card_uid])
	var ret_val = await self.arena_card
	print("arena card return:",ret_val)
	return ret_val

func get_arena_collection():
	assert(auth,"Auth not available")
	var uuid = auth.uid()
	db.set_db_root([players,uuid])
	db.get_value(["collection"])
	var ret_val = await self.collection
	print("collection retrieved:",ret_val)
	return ret_val

func set_arena_deck(deck,deck_number = 0):
	print("set deck:",deck)
	assert(auth,"Auth not available")
	var uuid = auth.uid()
	db.set_db_root([players,uuid,avatar_data])
	var json_deck = JSON.stringify(deck)
	var deck_string = str("deck_",deck_number)
	#db.update_children([avatar_data],{deck_string:json_deck})
	db.set_value([deck_string],json_deck)

func get_arena_deck(deck_number = 0):
	var deck_string = str("deck_",deck_number)
	print("deck_string:",deck_string)
	var user_data = await get_user_data()
	print("user_data:",user_data)
	var test_json_conv = JSON.new()
	test_json_conv.JSON.parse_string(user_data[deck_string]).result
	var deck = test_json_conv.get_data()
	print("deck:",deck)
	return deck
"""
func remove_event_lineups(event):
	db.set_db_root(["events",event])
	db.remove_value(["lineups"])

func get_event_lineups_data(event):
	print("get event lineups data ",event)
	if db:
		db.set_db_root(["events",event])
		var ret_val = await get_db_value("lineups")
#		db.get_value(["lineups"])
#		var ret_val = yield(self,"lineups")
		return ret_val
	else:
		print("database not available!")

func save_event_lineup_data(event,lineup,level = 1,p_data = null,lives = 3,lineup_uuid = null):

	var json_data = JSON.stringify(lineup)
	db.set_db_root(["events",event])
	var pushString
	if lineup_uuid == null:
		pushString = db.push_child(["lineups",event])
	else:
		pushString = lineup_uuid
	var path = [str("lineups","/",pushString)]
	var data = {"lineup_level":level,"lineup_data":json_data,"lives":lives}
	if p_data:
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id


	db.update_children(path,data)
	return pushString
