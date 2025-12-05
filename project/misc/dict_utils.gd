## Utility class for deterministic and type-safe dictionary operations.
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
class_name DictUtils
extends RefCounted


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


static func keys_sorted(dict: Dictionary) -> Array:
	var keys_array: Array = dict.keys()
	keys_array.sort()
	return keys_array


static func keys_typed_sorted(dict: Dictionary, type: Variant.Type = TYPE_NIL) -> Array:
	var keys_array: Array = dict.keys()
	keys_array.sort()

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


static func values_sorted(dict: Dictionary) -> Array:
	var sorted_keys: Array = keys_sorted(dict)
	var values_array: Array = []

	for key: Variant in sorted_keys:
		values_array.append(dict[key])

	return values_array


static func values_typed_sorted(dict: Dictionary, type: Variant.Type) -> Array:
	var sorted_keys: Array = keys_sorted(dict)

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


static func filter_dict(dict: Dictionary, predicate: Callable) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys: Array = keys_sorted(dict)

	for key: Variant in sorted_keys:
		var value: Variant = dict[key]
		if predicate.call(key, value):
			result[key] = value

	return result


static func deterministic_hash(dict: Dictionary) -> String:
	var sorted_keys: Array = keys_sorted(dict)
	var hash_parts: Array[String] = []

	for key: Variant in sorted_keys:
		var value: Variant = dict[key]
		var key_str: String = str(key)
		# Use JSON for arrays/dicts to ensure deterministic serialization, str() for primitives
		var value_str: String = (
			JSON.stringify(value) if (value is Dictionary or value is Array) else str(value)
		)
		hash_parts.append("%s:%s" % [key_str, value_str])

	var combined: String = "|".join(hash_parts)
	return combined.sha256_text()


static func validate_deterministic_keys(dict: Dictionary) -> bool:
	var keys_array: Array = dict.keys()

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


static func make_deterministic(dict: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys: Array = keys_sorted(dict)

	for key: Variant in sorted_keys:
		result[key] = dict[key]

	return result


static func debug_print_sorted(dict: Dictionary, label: String = "Dictionary") -> void:
	Log.debug(
		"%s contents (deterministic order)" % label,
		{"size": dict.size()},
		[Log.TAG_DEBUG, Log.TAG_DETERMINISM]
	)

	var sorted_keys: Array = keys_sorted(dict)
	for key: Variant in sorted_keys:
		Log.debug("  [%s] -> %s" % [str(key), str(dict[key])], {}, [Log.TAG_DEBUG])


static func merge_dicts_deterministic(dicts: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}

	for dict: Dictionary in dicts:
		var sorted_keys: Array = keys_sorted(dict)
		for key: Variant in sorted_keys:
			result[key] = dict[key]

	return result


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


static func get_battle_lineup_pairs(lineup: Dictionary) -> Array:
	var pairs: Array = []
	var sorted_positions: Array[int] = get_battle_positions(lineup)

	for pos: int in sorted_positions:
		pairs.append([pos, lineup[pos]])

	return pairs
