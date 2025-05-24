@tool
class_name RTDBTestPaths
extends RefCounted
## Centralized test path definitions for RTDB debug actions.
## All paths are strongly typed as Array[String] for consistency.

# Base paths
const BASE: Array[String] = ["debug_tests", "rtdb"]

# Test category paths
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


## Create a test path with a timestamp suffix for uniqueness
static func with_timestamp(base_path: Array[String]) -> Array[String]:
	var result: Array[String] = base_path.duplicate()
	result.append("test_" + str(TimeUtils.now_ms()))
	return result


## Convert string array to variant array for Firebase API compatibility
static func to_variant_array(path: Array[String]) -> Array[Variant]:
	var result: Array[Variant] = []
	for element in path:
		result.append(element)
	return result
