class_name DictUtils
extends RefCounted
## Utility class for deterministic and type-safe dictionary operations.
##
## Provides standardized methods for dictionary iteration, transformation,
## and validation to ensure consistent behavior across the project.
## Critical for battle system determinism and type safety.
##
## USAGE EXAMPLES:
##
## # Primary method - iterate with key-value pairs:
## for item in DictUtils.get_sorted_items(my_dict):
##     print("Key: ", item.key, ", Value: ", item.value)
##
## # Extract just keys for map operations:
## var keys: Array = DictUtils.get_sorted_items(my_dict).map(func(item): return item.key)
##
## # Replace direct dictionary iteration:
## # BEFORE: for key in dict:
## # AFTER:  for key in DictUtils.keys_sorted(dict):
##
## # Battle system usage (strongly typed):
## var lineup: Dictionary[int, UnitData] = get_lineup()
## var positions: Array[int] = DictUtils.get_battle_positions(lineup)
## for pos in positions:
##     var unit: UnitData = lineup[pos]
##     # Process unit deterministically
##
## # Type-safe key extraction:
## var string_keys: Array[String] = DictUtils.keys_typed_sorted(dict, TYPE_STRING)
## var int_keys: Array[int] = DictUtils.keys_typed_sorted(dict, TYPE_INT)
##
## # Validation for deterministic behavior:
## if DictUtils.validate_deterministic_keys(dict):
##     # Safe to iterate deterministically


## Returns an array of dictionaries, each containing a 'key' and 'value',
## sorted deterministically by the original dictionary's key.
## This is the primary, simplified way to iterate over dictionaries where order matters.
##
## Parameters:
## - dict: The dictionary to iterate over.
##
## Returns: An Array[Dictionary] of key-value pairs, e.g., [{key: key1, value: val1}, {key: key2, value: val2}]
##
## Example Usage:
## for item in DictUtils.get_sorted_items(my_dictionary):
##     print("Key: ", item.key, ", Value: ", item.value)
##
static func get_sorted_items(dict: Dictionary) -> Array[Dictionary]:
	if not dict is Dictionary:
		Log.error(
			"Invalid input to get_sorted_items: not a dictionary.",
			{"input_type": typeof(dict)},
			[Log.TAG_SYSTEM, Log.TAG_ERROR]
		)
		var empty_dict_array: Array[Dictionary] = []
		return empty_dict_array

	var keys: Array = dict.keys()
	keys.sort()

	var items: Array[Dictionary] = []
	for key: Variant in keys:
		items.append({"key": key, "value": dict[key]})

	return items


## Get dictionary keys as a sorted array for deterministic iteration
## Returns Array[Variant] containing the sorted keys
static func keys_sorted(dict: Dictionary) -> Array:
	var keys_array: Array = dict.keys()
	keys_array.sort()
	return keys_array


## Get dictionary keys as a strongly-typed sorted array
## Type parameter must match the actual key type in the dictionary
static func keys_typed_sorted(dict: Dictionary, type: Variant.Type = TYPE_NIL) -> Array:
	var keys_array: Array = dict.keys()
	keys_array.sort()

	# If type is specified, validate and create typed array
	if type != TYPE_NIL:
		match type:
			TYPE_INT:
				var typed_keys: Array[int] = []
				typed_keys.assign(keys_array)
				return typed_keys
			TYPE_STRING:
				var typed_keys: Array[String] = []
				typed_keys.assign(keys_array)
				return typed_keys
			_:
				Log.warning(
					"DictUtils: Unsupported type for keys_typed_sorted",
					{"type": type, "supported": [TYPE_INT, TYPE_STRING]},
					[Log.TAG_VALIDATION, Log.TAG_ERROR]
				)

	return keys_array


## Get dictionary values in key-sorted order for deterministic iteration
## Returns values in the same order as keys_sorted() would return keys
static func values_sorted(dict: Dictionary) -> Array:
	var sorted_keys: Array = keys_sorted(dict)
	var values_array: Array = []

	for key: Variant in sorted_keys:
		values_array.append(dict[key])

	return values_array


## Get dictionary values as strongly-typed array in key-sorted order
static func values_typed_sorted(dict: Dictionary, type: Variant.Type) -> Array:
	var sorted_keys: Array = keys_sorted(dict)

	# Create typed array based on specified type
	match type:
		TYPE_INT:
			var typed_values: Array[int] = []
			for key: Variant in sorted_keys:
				typed_values.append(dict[key])
			return typed_values
		TYPE_STRING:
			var typed_values: Array[String] = []
			for key: Variant in sorted_keys:
				typed_values.append(dict[key])
			return typed_values
		TYPE_OBJECT:
			var typed_values: Array[RefCounted] = []
			for key: Variant in sorted_keys:
				typed_values.append(dict[key])
			return typed_values
		_:
			Log.warning(
				"DictUtils: Unsupported type for values_typed_sorted",
				{"type": type},
				[Log.TAG_VALIDATION, Log.TAG_ERROR]
			)
			return values_sorted(dict)


## Create a new dictionary with keys and values transformed by functions
## key_func: function to transform keys (key) -> new_key
## value_func: function to transform values (key, value) -> new_value
static func transform_dict(
	dict: Dictionary, key_func: Callable = Callable(), value_func: Callable = Callable()
) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys: Array = keys_sorted(dict)

	for key: Variant in sorted_keys:
		var value: Variant = dict[key]
		var new_key: Variant = key_func.call(key) if key_func.is_valid() else key
		var new_value: Variant = value_func.call(key, value) if value_func.is_valid() else value
		result[new_key] = new_value

	return result


## Filter dictionary entries based on predicate function
## predicate: function (key, value) -> bool
static func filter_dict(dict: Dictionary, predicate: Callable) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys: Array = keys_sorted(dict)

	for key: Variant in sorted_keys:
		var value: Variant = dict[key]
		if predicate.call(key, value):
			result[key] = value

	return result


## Generate deterministic hash for dictionary contents
## Useful for battle system validation and debugging
static func deterministic_hash(dict: Dictionary) -> String:
	var sorted_keys: Array = keys_sorted(dict)
	var hash_parts: Array[String] = []

	for key: Variant in sorted_keys:
		var value: Variant = dict[key]
		var key_str: String = str(key)
		var value_str: String = str(value)
		hash_parts.append("%s:%s" % [key_str, value_str])

	var combined: String = "|".join(hash_parts)
	return combined.sha256_text()


## Validate that dictionary iteration will be deterministic
## Returns true if dictionary can be safely iterated deterministically
static func validate_deterministic_keys(dict: Dictionary) -> bool:
	var keys_array: Array = dict.keys()

	# Check if all keys are comparable (same type)
	if keys_array.is_empty():
		return true

	var first_key_type: int = typeof(keys_array[0])
	for key: Variant in keys_array:
		if typeof(key) != first_key_type:
			Log.warning(
				"DictUtils: Mixed key types detected - iteration may not be deterministic",
				{"expected_type": first_key_type, "found_type": typeof(key), "key": str(key)},
				[Log.TAG_VALIDATION, Log.TAG_DETERMINISM, Log.TAG_ERROR]
			)
			return false

	return true


## Create a copy of dictionary with deterministically sorted keys
## Useful for ensuring consistent ordering when dictionary will be serialized
static func make_deterministic(dict: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys: Array = keys_sorted(dict)

	for key: Variant in sorted_keys:
		result[key] = dict[key]

	return result


## Debug helper: print dictionary contents in deterministic order
static func debug_print_sorted(dict: Dictionary, label: String = "Dictionary") -> void:
	Log.debug(
		"%s contents (deterministic order)" % label,
		{"size": dict.size()},
		[Log.TAG_DEBUG, Log.TAG_DETERMINISM]
	)

	var sorted_keys: Array = keys_sorted(dict)
	for key: Variant in sorted_keys:
		Log.debug("  [%s] -> %s" % [str(key), str(dict[key])], {}, [Log.TAG_DEBUG])


## Merge dictionaries with deterministic key handling
## Later dictionaries override earlier ones for conflicting keys
static func merge_dicts_deterministic(dicts: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}

	# Process dictionaries in order
	for dict: Dictionary in dicts:
		var sorted_keys: Array = keys_sorted(dict)
		for key: Variant in sorted_keys:
			result[key] = dict[key]

	return result


## Helper for battle system: get lineup positions in deterministic order
## Specialized helper for Dictionary[int, UnitData] pattern used in battles
static func get_battle_positions(lineup: Dictionary) -> Array[int]:
	if not validate_deterministic_keys(lineup):
		Log.error(
			"Battle lineup has non-deterministic keys",
			{"lineup_size": lineup.size()},
			[Log.TAG_BATTLE, Log.TAG_VALIDATION, Log.TAG_ERROR]
		)

	var positions: Array[int] = []
	var sorted_keys: Array = keys_sorted(lineup)
	positions.assign(sorted_keys)
	return positions


## Helper for battle system: iterate over lineup in deterministic order
## Returns array of [position, unit] pairs in sorted position order
static func get_battle_lineup_pairs(lineup: Dictionary) -> Array:
	var pairs: Array = []
	var sorted_positions: Array[int] = get_battle_positions(lineup)

	for pos: int in sorted_positions:
		pairs.append([pos, lineup[pos]])

	return pairs
