class_name RulesCollection
extends BaseCollection

var _collection_key: String = ""

## Initialize the rules collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0)->void:
	super(backend, [data_source.DEFAULT_SHEETS_ID], "rules")
	_collection_key = "rules_" + str(test_group)
	Log.info("RulesCollection initialized", {"test_group": test_group}, [Log.TAG_DB])

## Get rules data
## @return Dictionary containing rules data
func get_rules() -> Dictionary:
	Log.info("Getting rules data", {
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"collection_id": get_instance_id(),
		"stack_trace": _get_stack_trace(2)},[Log.TAG_DB])
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time

	Log.debug("Rules data request completed", {
		"duration_ms": request_duration,
		"result_null": result == null,
		"result_empty": result == null or result.is_empty(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()}, [Log.TAG_DB])
		# Define the expected structure for rules data


	# Error out if result is null or empty
	if result == null or result.is_empty():
		Log.error("Rules data is missing or empty", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])

	var result_dict: Dictionary = {}
	if result is Array:
		var array_result: Array = result
		if array_result.size() > 0 and array_result[0] is Dictionary:
			result_dict = array_result[0]
	elif result is Dictionary:
		result_dict = result

	# Check data structure in detail
	Log.debug("Validating rules data structure", {
		"result_keys": result_dict.keys(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])

	return result_dict

## Helper to get a simplified stack trace for debugging
func _get_stack_trace(depth: int = 2) -> Array[Dictionary]:
	var stack: Array = get_stack()
	var simplified_stack: Array[Dictionary] = []
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
