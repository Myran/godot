# project/debug/actions/rtdb/rtdb_set_simple_value_action.gd
@tool
class_name RTDBSetSimpleValueAction
extends DebugAction


func _init():
	action_name = "Set Simple Value"
	category = "RTDB"
	group = "Basic"
	description = "Sets a simple string value at a predefined test path in RTDB."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")  # Assuming it's registered
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix = ["simple_value_test"]
	var test_base_path = ["debug_tests", "rtdb"]  # Define your base path
	var full_path = test_base_path + path_suffix
	var value_to_set = "Test Value: " + str(Time.get_ticks_msec())

	_update_status(
		target_node, "Setting value '%s' at path '%s'..." % [value_to_set, str(full_path)]
	)

	# Simplified call for example; replace with your _make_rtdb_request or FirebaseBackend usage
	# This is where you'd use your FirebaseBackend's set_data method
	# For this example, let's assume a direct call to the C++ module.
	var request_id = 1  # Manage request IDs appropriately
	db.set_value_async(request_id, full_path, value_to_set)

	# You'd typically await a signal here. For simplicity, we'll assume it worked for now.
	# In a real scenario, you'd connect to db.set_value_completed and await it.
	# var result = await db.set_value_completed # Pseudo-code for await
	# if result.success:
	#    _update_status(target_node, "Successfully set value.")
	#    return _success({"path": full_path, "value_set": value_to_set})
	# else:
	#    _update_status(target_node, "Failed to set value: " + result.error_message, true)
	#    return _failure(result.error_message)

	# Placeholder:
	await target_node.get_tree().create_timer(0.1).timeout  # Simulate async work
	_update_status(target_node, "Set value (simulated) for path '%s'." % str(full_path))
	Log.debug(
		"RTDBSetSimpleValueAction executed (simulated)",
		{"path": full_path, "value": value_to_set},
		["test", "rtdb"]
	)
	return _success({"path": full_path, "value_set": value_to_set})
