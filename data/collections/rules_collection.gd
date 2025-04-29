class_name RulesCollection
extends BaseCollection

# Import class references directly
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd") 
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

## Collection class for game rules data.
## Provides access to configurable game rules with validation.

# Key for retrieving rules data
var _collection_key: String = ""

# Cache for rules data
var _cache: Dictionary = {}

# Whether the cache has been initialized
var _is_cache_initialized: bool = false

## Initialize the rules collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0) -> void:
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
	
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	Log.debug("Rules data request completed", {
		"duration_ms": request_duration,
		"result_null": result == null,
		"result_empty": result == null or result.is_empty(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Define the expected structure for rules data
	var expected_structure: Dictionary = {
		"chance_lvl_2_star_1": {"type": TYPE_INT, "default": 30, "description": "Chance for level 2, 1-star unit"},
		"chance_lvl_2_star_2": {"type": TYPE_INT, "default": 10, "description": "Chance for level 2, 2-star unit"},
		"chance_lvl_2_star_3": {"type": TYPE_INT, "default": 5, "description": "Chance for level 2, 3-star unit"},
		"chance_lvl_3_star_1": {"type": TYPE_INT, "default": 50, "description": "Chance for level 3, 1-star unit"},
		"chance_lvl_3_star_2": {"type": TYPE_INT, "default": 20, "description": "Chance for level 3, 2-star unit"},
		"chance_lvl_3_star_3": {"type": TYPE_INT, "default": 10, "description": "Chance for level 3, 3-star unit"}
	}
	
	# Process result with JSONPathNavigator if not null
	if result != null:
		# Check if result needs to be processed with JSONPathNavigator
		if not (result is Dictionary):
			Log.warning("Rules data is not a dictionary, attempting to navigate result", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_WARNING])
			
			var nav_result: NavigationResultClass = JSONPathNavigatorClass.navigate(result, [])
			if nav_result.is_dictionary():
				result = nav_result.as_dictionary()
			else:
				# Try to extract rules key if in a nested structure
				var rules_result: NavigationResultClass = JSONPathNavigatorClass.navigate(result, ["rules"])
				if rules_result.is_dictionary():
					result = rules_result.as_dictionary()
				else if rules_result.is_array() and rules_result.as_array().size() > 0 and rules_result.as_array()[0] is Dictionary:
					result = rules_result.as_array()[0]
		
	# Error out if result is null, empty or couldn't be processed to a dictionary
	if result == null or not (result is Dictionary) or (result is Dictionary and result.is_empty()):
		Log.error("Rules data is missing or empty", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"base_path": _base_path,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		# Emergency defaults for editor testing - still error out for visibility
		var default_rules: Dictionary = {}
		for key in expected_structure:
			default_rules[key] = expected_structure[key].default
		
		Log.warning("Using emergency default rules data to avoid crashes", {
			"default_keys": default_rules.keys(),
			"collection_name": _collection_name,
			"emergency_data": true,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		push_error("Required rules data is missing - using emergency defaults for editor testing ONLY in " + _collection_name)
		
		return default_rules
	
	# Check data structure in detail
	Log.debug("Validating rules data structure", {
		"result_keys": result.keys(),
		"expected_keys": expected_structure.keys(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Check for required keys
	var missing_keys: Array = []
	var type_mismatches: Array = []
	var values_info: Dictionary = {}
	
	for key in expected_structure.keys():
		if not result.has(key):
			missing_keys.append(key)
		else:
			var expected_type: int = expected_structure[key].type
			var actual_type: int = typeof(result[key])
			
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
		
		push_error("Required rules data keys missing: " + str(missing_keys) + 
			". Available keys: " + str(result.keys()) + " in " + _collection_name)
		
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
	
	# Store in cache
	_cache = result
	_is_cache_initialized = true
	
	return result
	
## Helper to get a simplified stack trace for debugging
func _get_stack_trace(depth: int = 2) -> Array:
	var stack: Array = get_stack()
	var simplified_stack: Array = []
	
	for i: int in range(min(depth, stack.size())):
		if i >= stack.size():
			break
			
		var frame: Dictionary = stack[i]
		simplified_stack.append({
			"function": frame.function,
			"file": frame.source.get_file(),
			"line": frame.line
		})
	
	return simplified_stack
	
## Get a specific rule value
## @param rule_key The key of the rule to retrieve
## @param default_value Default value to return if rule is not found
## @return The value of the rule or the default value if not found
func get_rule(rule_key: String, default_value: Variant = null) -> Variant:
	Log.info("Getting rule value", {"rule_key": rule_key}, [Log.TAG_DB])
	
	var rules: Dictionary = await get_rules()
	if rules.has(rule_key):
		Log.debug("Rule found", {"rule_key": rule_key, "value": rules[rule_key]}, [Log.TAG_DB])
		return rules[rule_key]
		
	Log.warning("Rule not found, using default", {
		"rule_key": rule_key, 
		"default_value": default_value
	}, [Log.TAG_DB, Log.TAG_WARNING])
	
	return default_value
	
## Clear the rules cache
## @return void
func clear_cache() -> void:
	Log.info("Clearing rules cache", {}, [Log.TAG_DB, Log.TAG_CACHE])
	_is_cache_initialized = false
	_cache.clear()