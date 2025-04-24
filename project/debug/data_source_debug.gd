extends Node

## Debug script for testing DataSource functionality
## Attach this to a node in a test scene

func _ready() -> void:
	# Check if DataSource is loaded
	if not has_node("/root/data_source"):
		print("DataSource node not found! Make sure to run the full game with autoloads.")
		print("Attempting to load DataSource manually...")
		
		# Try to load DataSource manually
		var data_source_script = load("res://autoloads/data_source.gd")
		if data_source_script:
			var data_source = data_source_script.new()
			get_tree().root.add_child(data_source)
			data_source.name = "data_source"
			print("DataSource loaded manually. Waiting for initialization...")
			await data_source.startup_completed
			print("DataSource initialized. Running diagnostics...")
			diagnose_data_source()
		else:
			print("Failed to load DataSource script!")
			return
	else:
		# Wait for DataSource to initialize if it's already loaded
		print("DataSource node found. Waiting for initialization...")
		
		# Add a timeout mechanism
		var timeout = Time.get_ticks_msec() + 2000  # 2 second timeout
		var data_source = get_node("/root/data_source")
		
		if data_source.is_initialized():
			print("DataSource already initialized. Running diagnostics...")
			diagnose_data_source()
		else:
			print("Waiting for DataSource to initialize (with timeout)...")
			# Try to wait for startup_completed signal with timeout
			while not data_source.is_initialized() and Time.get_ticks_msec() < timeout:
				await get_tree().create_timer(0.1).timeout
			
			if data_source.is_initialized():
				print("DataSource initialized. Running diagnostics...")
				diagnose_data_source()
			else:
				print("Timeout waiting for DataSource initialization. Running diagnostics anyway...")
				diagnose_data_source()

func diagnose_data_source() -> void:
	print("\n=== STARTING DATASOURCE DIAGNOSTICS ===")
	
	# Check data loading
	var data_source = get_node("/root/data_source")
	print("DataSource initialized: ", data_source.is_initialized())
	print("Using local data: ", data_source.using_local_data)
	
	# Check JSON data structure
	print("\n=== JSON DATA STRUCTURE ===")
	print("Local data keys: ", data_source.local_data.keys())
	
	# Check collections
	diagnose_cards()
	diagnose_levels()
	diagnose_items()
	diagnose_rules()
	
	print("\n=== DATASOURCE DIAGNOSTICS COMPLETE ===")

func diagnose_cards() -> void:
	print("\n=== CARD DIAGNOSTICS ===")
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	print("Checking direct JSON structure for cards...")
	var card_key = "cards_0"
	if data_source.local_data.has(card_key):
		print("Found cards key '", card_key, "' in local_data with ", data_source.local_data[card_key].size(), " entries")
	else:
		print("No '", card_key, "' key found in local_data")
		print("Available keys: ", data_source.local_data.keys())
	
	# Get all cards through API
	print("Retrieving cards through API...")
	var cards = []
	
	# Use error handling to prevent crashes
	if data_source.has_method("get_all_cards"):
		cards = await data_source.get_all_cards(false)
		print("Found ", cards.size(), " cards")
		
		if cards.size() > 0:
			# Sample first card
			var first_card = cards[0]
			print("\nFirst card details:")
			print("Name: ", first_card.get("name", "N/A"))
			print("ID: ", first_card.get("id", "N/A"))
			print("All keys: ", first_card.keys())
	else:
		print("Method get_all_cards not found!")

func diagnose_levels() -> void:
	print("\n=== LEVEL DIAGNOSTICS ===")
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	print("Checking direct JSON structure for levels...")
	var level_key = "levels_0"
	if data_source.local_data.has(level_key):
		print("Found levels key '", level_key, "' in local_data with ", data_source.local_data[level_key].size(), " entries")
	else:
		print("No '", level_key, "' key found in local_data")
		print("Available keys: ", data_source.local_data.keys())
	
	# Get all levels through API 
	print("Retrieving levels through API...")
	if data_source.has_method("get_all_levels"):
		var levels = await data_source.get_all_levels()
		print("Found ", levels.size(), " levels")
	else:
		print("Method get_all_levels not found!")

func diagnose_items() -> void:
	print("\n=== ITEM DIAGNOSTICS ===")
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	print("Checking direct JSON structure for items...")
	var item_key = "items_0"
	if data_source.local_data.has(item_key):
		print("Found items key '", item_key, "' in local_data with ", data_source.local_data[item_key].size(), " entries")
	else:
		print("No '", item_key, "' key found in local_data")
		print("Available keys: ", data_source.local_data.keys())
	
	# Get all items through API
	print("Retrieving items through API...")
	if data_source.has_method("get_all_items"):
		var items = await data_source.get_all_items()
		print("Found ", items.size(), " items")
	else:
		print("Method get_all_items not found!")

func diagnose_rules() -> void:
	print("\n=== RULES DIAGNOSTICS ===")
	var data_source = get_node("/root/data_source")
	
	# Try direct JSON data check first
	print("Checking direct JSON structure for rules...")
	var rules_key = "rules_0"
	if data_source.local_data.has(rules_key):
		print("Found rules key '", rules_key, "' in local_data")
		if data_source.local_data[rules_key] is Dictionary:
			print("Rules keys: ", data_source.local_data[rules_key].keys())
		else:
			print("Rules data is not a Dictionary: ", typeof(data_source.local_data[rules_key]))
	else:
		print("No '", rules_key, "' key found in local_data")
		print("Available keys: ", data_source.local_data.keys())
	
	# Get rules through API
	print("Retrieving rules through API...")
	if data_source.has_method("get_rules_data"):
		var rules = await data_source.get_rules_data()
		print("Rules data found: ", not rules.is_empty())
	else:
		print("Method get_rules_data not found!")