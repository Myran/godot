# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
@tool
class_name RTDBGetSimpleValueAction
extends DebugAction


func _init():
	action_name = "Get Simple Value"
	category = "RTDB"
	group = "Basic"
	description = "Retrieves a simple value from a predefined test path in RTDB."


func execute(target_node: Node = null) -> Array:
# Check if Firebase backend is available
	if not data_source.is_firebase_available():
	_update_status(target_node, "Firebase backend not available.", true)
	return _failure("Firebase backend not available.")

	var firebase_backend = data_source.get_firebase_backend()
	if not firebase_backend:
	_update_status(target_node, "Unable to get Firebase backend instance.", true)
	return _failure("Firebase backend instance unavailable.")

	var path_suffix: Array[Variant] = ["simple_value_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Getting value from path '%s'..." % str(full_path))

# Use the Firebase backend's get_data method
	var result: Variant = await firebase_backend.get_data(full_path, "")

	if result != null:
		_update_status(target_node, "Successfully retrieved value: '%s'" % str(result))

		Log.debug(
			"RTDBGetSimpleValueAction executed successfully",
			{"path": full_path, "retrieved_value": result, "operation": "get_value"},
			["test", "rtdb"]
		)

		return _success(
			{
				"operation": "get_value",
				"path": full_path,
				"value": result,
				"timestamp": Time.get_ticks_msec()
			}
		)
	else:
		var error_msg: String = "No value found at path '%s'" % str(full_path)
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"path": full_path, "operation": "get_value"})
