class_name RTDBTestPaths
extends RefCounted


class Path:
	var _path: Array[Variant]

	func _init(path: Array[Variant]) -> void:
		_path = path.duplicate()

	func as_strings() -> Array[Variant]:
		return _path

	func as_variants() -> Array[Variant]:
		var result: Array[Variant] = []
		result.assign(_path)
		return result

	func with_timestamp() -> Path:
		var result: Array[Variant] = _path.duplicate()
		result.append("test_" + str(TimeUtils.now_ms()))
		return Path.new(result)


const BASE: Array[Variant] = ["debug_tests", "rtdb"]

const SIMPLE_VALUE: Array[Variant] = ["debug_tests", "rtdb", "simple_value_test"]
const CHILD_EVENTS: Array[Variant] = ["debug_tests", "rtdb", "child_events"]
const BATCH_OPS: Array[Variant] = ["debug_tests", "rtdb", "batch_test"]
const TRANSACTIONS: Array[Variant] = ["debug_tests", "rtdb", "transaction_test"]
const NESTED_DATA: Array[Variant] = ["debug_tests", "rtdb", "nested_path"]
const LARGE_DATA: Array[Variant] = ["debug_tests", "rtdb", "large_data"]
const PATH_VALIDATION: Array[Variant] = ["debug_tests", "rtdb", "path_validation"]
const ERROR_HANDLING: Array[Variant] = ["debug_tests", "rtdb", "error_test"]
const CONCURRENT_OPS: Array[Variant] = ["debug_tests", "rtdb", "concurrent_test"]
const LIST_CHILDREN: Array[Variant] = ["debug_tests", "rtdb", "list_test"]
const SINGLE_VALUE: Array[Variant] = ["debug_tests", "rtdb", "single_value"]


static func create_path(path: Array[Variant]) -> Path:
	return Path.new(path)


static func with_timestamp(base_path: Array[Variant]) -> Array[Variant]:
	var result: Array[Variant] = base_path.duplicate()
	result.append("test_" + str(TimeUtils.now_ms()))
	return result


static func to_variant_array(path: Array[Variant]) -> Array[Variant]:
	var result: Array[Variant] = []
	result.assign(path)
	return result
