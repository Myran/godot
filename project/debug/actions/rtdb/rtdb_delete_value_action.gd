# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Delete Value"


func execute_rtdb_action() -> void:
	_update_status("Executing " + action_name + "...")
	var result: Variant = await execute_simple_operation(
		"remove_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		null,
		action_name
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
