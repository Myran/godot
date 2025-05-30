# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Delete Value"
	group = "Basic"
	description = "Deletes a value from a predefined test path in RTDB."


func execute() -> void:
	_update_status("Executing " + action_name + "...")
	var result: Array = await execute_simple_operation(
		"remove_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		null,
		action_name
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
