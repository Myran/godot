# project/debug/actions/rtdb/rtdb_set_simple_value_action.gd
@tool
class_name RTDBSetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Set Simple Value"


func execute_rtdb_action() -> void:
	_update_status("Executing " + action_name + "...")
	var test_value: String = "Test Value: " + str(TimeUtils.now_ms())

	var result: Array = await execute_simple_operation(
		"set_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		test_value,
		action_name
	)
	# execute_simple_operation() already emits execution_completed signal
	# No need to emit again here to avoid double counting
