# project/debug/actions/rtdb/rtdb_update_value_action.gd
@tool
class_name RTDBUpdateValueAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Update Value"
	group = "Basic"
	description = "Updates an existing value at a predefined test path in RTDB."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var path_suffix: Array[Variant] = ["update_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)
	var new_value: String = "Updated Value: " + str(Time.get_ticks_msec())

	_update_status("Updating value at path '%s' to '%s'..." % [str(full_path), new_value])

	# Execute real Firebase operation instead of fake simulation
	var result: Dictionary = await execute_firebase_operation(
		db, "set_value_async", [full_path, new_value]
	)

	if result.success:
		_update_status("Successfully updated value at path '%s'" % str(full_path))

		Log.debug(
			"RTDBUpdateValueAction executed successfully",
			{"path": full_path, "new_value": new_value, "operation": "update"},
			["test", "rtdb"]
		)

		return _success(
			{
				"operation": "update_value",
				"path": full_path,
				"value": new_value,
				"timestamp": Time.get_ticks_msec()
			}
		)
	else:
		_update_status("Failed to update value: %s" % result.error, true)

		Log.error(
			"RTDBUpdateValueAction failed",
			{
				"path": full_path,
				"new_value": new_value,
				"error": result.error,
				"operation": "update"
			},
			["test", "rtdb", "error"]
		)

		return _failure("Failed to update value: " + str(result.error))
