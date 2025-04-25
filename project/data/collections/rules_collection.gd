class_name RulesCollection
extends BaseCollection

var _collection_key: String = ""

## Initialize the rules collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0):
	super(backend, ["sheets"], "Rules")
	_collection_key = "rules_" + str(test_group)
	Log.info("RulesCollection initialized", {"test_group": test_group}, [Log.TAG_DB])
	
## Get rules data
## @return Dictionary containing rules data
func get_rules() -> Dictionary:
	Log.info("Getting rules data", {
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"base_path": _base_path,
		"collection_id": get_instance_id(),
		"stack_trace": _get_stack_trace(2)
	}, [Log.TAG_DB])
	
	var request_start_time = Time.get_ticks_msec()
	var result = await _backend.get_data(_get_path(), _collection_key)
	var request_duration = Time.get_ticks_msec() - request_start_time
	
	Log.debug("Rules data request completed", {
		"duration_ms": request_duration,
		"result_null": result == null,
		"result_empty": result == null or result.is_empty(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Define the expected structure for rules data
	var expected_structure = {
		"chance_lvl_2_star_1": {"type": TYPE_INT, "default": 30, "description": "Chance for level 2, 1-star unit"},
		"chance_lvl_2_star_2": {"type": TYPE_INT, "default": 10, "description": "Chance for level 2, 2-star unit"},
		"chance_lvl_2_star_3": {"type": TYPE_INT, "default": 5, "description": "Chance for level 2, 3-star unit"},
		"chance_lvl_3_star_1": {"type": TYPE_INT, "default": 50, "description": "Chance for level 3, 1-star unit"},
		"chance_lvl_3_star_2": {"type": TYPE_INT, "default": 20, "description": "Chance for level 3, 2-star unit"},
		"chance_lvl_3_star_3": {"type": TYPE_INT, "default": 10, "description": "Chance for level 3, 3-star unit"}
	}
	
	# Error out if result is null or empty
	if result == null or result.is_empty():
		Log.error("Rules data is missing or empty", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"base_path": _base_path,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		# Emergency defaults for editor testing - still error out for visibility
		var default_rules = {}
		for key in expected_structure:
			default_rules[key] = expected_structure[key].default
		
		Log.warning("Using emergency default rules data to avoid crashes", {
			"default_keys": default_rules.keys(),
			"collection_name": _collection_name,
			"emergency_data": true,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		return default_rules
	
	# Check data structure in detail
	Log.debug("Validating rules data structure", {
		"result_keys": result.keys(),
		"expected_keys": expected_structure.keys(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Check for required keys
	var missing_keys = []
	var type_mismatches = []
	var values_info = {}
	
	for key in expected_structure.keys():
		if not result.has(key):
			missing_keys.append(key)
		else:
			var expected_type = expected_structure[key].type
			var actual_type = typeof(result[key])
			
			if expected_type != actual_type:
				type_mismatches.append({
					"key": key,
					"expected_type": expected_type,
					"actual_type": actual_type
				})
			
			# Log values for debugging
			values_info[key] = {
				"value": result[key],
				"type": actual_type
			}
	
	# Log detailed validation results
	Log.debug("Rules data validation results", {
		"missing_keys": missing_keys,
		"type_mismatches": type_mismatches,
		"values": values_info,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	if missing_keys.size() > 0:
		Log.error("Required keys missing in rules data", {
			"missing_keys": missing_keys, 
			"available_keys": result.keys(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		# Add emergency values for the missing keys for editor testing
		Log.warning("Adding emergency default values for missing rules", {
			"missing_keys": missing_keys,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		for key in missing_keys:
			if expected_structure.has(key):
				result[key] = expected_structure[key].default
			else:
				result[key] = 0
	
	if type_mismatches.size() > 0:
		Log.warning("Type mismatches in rules data", {
			"type_mismatches": type_mismatches,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
	
	return result
	
## Helper to get a simplified stack trace for debugging
func _get_stack_trace(depth: int = 2) -> Array:
	var stack = get_stack()
	var simplified_stack = []
	
	for i in range(min(depth, stack.size())):
		if i >= stack.size():
			break
			
		var frame = stack[i]
		simplified_stack.append({
			"function": frame.function,
			"file": frame.source.get_file(),
			"line": frame.line
		})
	
	return simplified_stack