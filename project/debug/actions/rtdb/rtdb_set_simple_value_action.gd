# project/debug/actions/rtdb/rtdb_set_simple_value_action.gd
@tool
class_name RTDBSetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Set Simple Value"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")
	var test_value: String = "Test Value: " + str(TimeUtils.now_ms())

	var success: bool = await execute_simple_operation(
		"set_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		test_value,
		action_name
	)
	# Return the result for the base class test tracking
	return success
