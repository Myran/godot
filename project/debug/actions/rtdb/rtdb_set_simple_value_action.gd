# project/debug/actions/rtdb/rtdb_set_simple_value_action.gd
@tool
class_name RTDBSetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Set Simple Value"
	group = "Basic"
	description = "Sets a simple string value at a predefined test path in RTDB."


func execute() -> Array:
	var test_value: String = "Test Value: " + str(TimeUtils.now_ms())

	return await execute_simple_operation(
		"set_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		test_value,
		action_name
	)
