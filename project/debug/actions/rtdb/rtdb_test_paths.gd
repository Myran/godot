class_name RTDBTestPaths
extends RefCounted


class Path:
	var _path: Array[String]

	func _init(path: Array[String]) -> void:
		_path = path.duplicate()

	func as_strings() -> Array[String]:
		return _path

	func as_variants() -> Array[Variant]:
		var result: Array[Variant] = []
		result.assign(_path)
		return result

	func with_timestamp() -> Path:
		var result: Array[String] = _path.duplicate()
		result.append("test_" + str(TimeUtils.now_ms()))
		return Path.new(result)


const BASE: Array[String] = ["debug_tests", "rtdb"]

const SIMPLE_VALUE: Array[String] = ["debug_tests", "rtdb", "simple_value_test"]
const CHILD_EVENTS: Array[String] = ["debug_tests", "rtdb", "child_events"]
const BATCH_OPS: Array[String] = ["debug_tests", "rtdb", "batch_test"]
const TRANSACTIONS: Array[String] = ["debug_tests", "rtdb", "transaction_test"]
const NESTED_DATA: Array[String] = ["debug_tests", "rtdb", "nested_path"]
const LARGE_DATA: Array[String] = ["debug_tests", "rtdb", "large_data"]
const PATH_VALIDATION: Array[String] = ["debug_tests", "rtdb", "path_validation"]
const ERROR_HANDLING: Array[String] = ["debug_tests", "rtdb", "error_test"]
const CONCURRENT_OPS: Array[String] = ["debug_tests", "rtdb", "concurrent_test"]
const LIST_CHILDREN: Array[String] = ["debug_tests", "rtdb", "list_test"]
const SINGLE_VALUE: Array[String] = ["debug_tests", "rtdb", "single_value"]


static func create_path(path: Array[String]) -> Path:
	return Path.new(path)


static func with_timestamp(base_path: Array[String]) -> Array[String]:
	var result: Array[String] = base_path.duplicate()
	result.append("test_" + str(TimeUtils.now_ms()))
	return result


static func to_variant_array(path: Array[String]) -> Array[Variant]:
	var result: Array[Variant] = []
	result.assign(path)
	return result
