extends Node

## Debug script for testing DataSource functionality
## Attach this to a node in a test scene

func _ready() -> void:
	# Check if DataSource is loaded
	if not has_node("/root/data_source"):
		Log.warning("DataSource node not found", {"action": "Manual load attempt"}, [Log.TAG_DB, "debug"])
		Log.info("Attempting to load DataSource manually", {}, [Log.TAG_DB, "debug"])
		
		# Try to load DataSource manually
		var data_source_script = load("res://autoloads/data_source.gd")
		if data_source_script:
			var data_source = data_source_script.new()
			get_tree().root.add_child(data_source)
			data_source.name = "data_source"
			Log.info("DataSource loaded manually", {"waiting": "initialization"}, [Log.TAG_DB, "debug"])
			await data_source.startup_completed
			Log.info("DataSource initialized", {"action": "Running diagnostics"}, [Log.TAG_DB, "debug"])
			diagnose_data_source()
		else:
			Log.error("Failed to load DataSource script", {}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
			return
	else:
		# Wait for DataSource to initialize if it's already loaded
		Log.info("DataSource node found", {"action": "Waiting for initialization"}, [Log.TAG_DB, "debug"])
		
		# Add a timeout mechanism
		var timeout = Time.get_ticks_msec() + 2000  # 2 second timeout
		var data_source = get_node("/root/data_source")
		
		if data_source.is_initialized():
			Log.info("DataSource already initialized", {"action": "Running diagnostics"}, [Log.TAG_DB, "debug"])
			diagnose_data_source()
		else:
			Log.info("Waiting for DataSource to initialize", {"timeout_ms": 2000}, [Log.TAG_DB, "debug"])
			# Try to wait for startup_completed signal with timeout
			while not data_source.is_initialized() and Time.get_ticks_msec() < timeout:
				await get_tree().create_timer(0.1).timeout
			
			if data_source.is_initialized():
				Log.info("DataSource initialized", {"action": "Running diagnostics"}, [Log.TAG_DB, "debug"])
				diagnose_data_source()
			else:
				Log.warning("Timeout waiting for DataSource initialization", {"action": "Running diagnostics anyway"}, [Log.TAG_DB, "debug"])
				diagnose_data_source()

func diagnose_data_source() -> void:
	Log.info("=== STARTING DATASOURCE DIAGNOSTICS ===", {}, [Log.TAG_DB, "debug"])
	
	# Check data loading
	var data_source = get_node("/root/data_source")
	Log.info("DataSource status", {
		"initialized": data_source.is_initialized(),
		"using_local_data": data_source.using_local_data
	}, [Log.TAG_DB, "debug"])
	
	# Check JSON data structure
	Log.info("=== JSON DATA STRUCTURE ===", {
		"local_data_keys": data_source.local_data.keys()
	}, [Log.TAG_DB, "debug"])
	
	# Check collections
	diagnose_cards()
	diagnose_levels()
	diagnose_items()
	diagnose_rules()
	
	Log.info("=== DATASOURCE DIAGNOSTICS COMPLETE ===", {}, [Log.TAG_DB, "debug"])

func diagnose_cards() -> void:
	Log.info("=== CARD DIAGNOSTICS ===", {}, [Log.TAG_DB, "debug"])
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	Log.debug("Checking direct JSON structure for cards", {}, [Log.TAG_DB, "debug"])
	var card_key = "cards_0"
	if data_source.local_data.has(card_key):
		Log.info("Found cards key in local_data", {
			"key": card_key,
			"entries": data_source.local_data[card_key].size()
		}, [Log.TAG_DB, "debug"])
	else:
		Log.warning("Card key not found in local_data", {
			"key_searched": card_key,
			"available_keys": data_source.local_data.keys()
		}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
	
	# Get all cards through API
	Log.debug("Retrieving cards through API", {}, [Log.TAG_DB, "debug"])
	var cards = []
	
	# Use error handling to prevent crashes
	if data_source.has_method("get_all_cards"):
		cards = await data_source.get_all_cards(false)
		Log.info("Cards retrieved", {"count": cards.size()}, [Log.TAG_DB, "debug"])
		
		if cards.size() > 0:
			# Sample first card
			var first_card = cards[0]
			Log.info("First card details", {
				"name": first_card.get("name", "N/A"),
				"id": first_card.get("id", "N/A"),
				"available_keys": first_card.keys()
			}, [Log.TAG_DB, "debug"])
	else:
		Log.error("Method get_all_cards not found", {}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])

func diagnose_levels() -> void:
	Log.info("=== LEVEL DIAGNOSTICS ===", {}, [Log.TAG_DB, "debug"])
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	Log.debug("Checking direct JSON structure for levels", {}, [Log.TAG_DB, "debug"])
	var level_key = "levels_0"
	if data_source.local_data.has(level_key):
		Log.info("Found levels key in local_data", {
			"key": level_key,
			"entries": data_source.local_data[level_key].size()
		}, [Log.TAG_DB, "debug"])
	else:
		Log.warning("Level key not found in local_data", {
			"key_searched": level_key,
			"available_keys": data_source.local_data.keys()
		}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
	
	# Get all levels through API 
	Log.debug("Retrieving levels through API", {}, [Log.TAG_DB, "debug"])
	if data_source.has_method("get_all_levels"):
		var levels = await data_source.get_all_levels()
		Log.info("Levels retrieved", {"count": levels.size()}, [Log.TAG_DB, "debug"])
	else:
		Log.error("Method get_all_levels not found", {}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])

func diagnose_items() -> void:
	Log.info("=== ITEM DIAGNOSTICS ===", {}, [Log.TAG_DB, "debug"])
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	Log.debug("Checking direct JSON structure for items", {}, [Log.TAG_DB, "debug"])
	var item_key = "items_0"
	if data_source.local_data.has(item_key):
		Log.info("Found items key in local_data", {
			"key": item_key, 
			"entries": data_source.local_data[item_key].size()
		}, [Log.TAG_DB, "debug"])
	else:
		Log.warning("Item key not found in local_data", {
			"key_searched": item_key,
			"available_keys": data_source.local_data.keys()
		}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
	
	# Get all items through API
	Log.debug("Retrieving items through API", {}, [Log.TAG_DB, "debug"])
	if data_source.has_method("get_all_items"):
		var items = await data_source.get_all_items()
		Log.info("Items retrieved", {"count": items.size()}, [Log.TAG_DB, "debug"])
	else:
		Log.error("Method get_all_items not found", {}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])

func diagnose_rules() -> void:
	Log.info("=== RULES DIAGNOSTICS ===", {}, [Log.TAG_DB, "debug"])
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	Log.debug("Checking direct JSON structure for rules", {}, [Log.TAG_DB, "debug"])
	var rules_key = "rules_0"
	if data_source.local_data.has(rules_key):
		Log.info("Found rules key in local_data", {"key": rules_key}, [Log.TAG_DB, "debug"])
		if data_source.local_data[rules_key] is Dictionary:
			Log.debug("Rules keys", {"keys": data_source.local_data[rules_key].keys()}, [Log.TAG_DB, "debug"])
		else:
			Log.warning("Rules data is not a Dictionary", {
				"type": typeof(data_source.local_data[rules_key])
			}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
	else:
		Log.warning("Rules key not found in local_data", {
			"key_searched": rules_key,
			"available_keys": data_source.local_data.keys()
		}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])
	
	# Get rules through API
	Log.debug("Retrieving rules through API", {}, [Log.TAG_DB, "debug"])
	if data_source.has_method("get_rules_data"):
		var rules = await data_source.get_rules_data()
		Log.info("Rules data", {"found": not rules.is_empty()}, [Log.TAG_DB, "debug"])
	else:
		Log.error("Method get_rules_data not found", {}, [Log.TAG_DB, Log.TAG_ERROR, "debug"])