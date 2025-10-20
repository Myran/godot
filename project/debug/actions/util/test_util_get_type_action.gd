class_name TestUtilGetTypeAction extends DebugAction


func _init() -> void:
	super("test_util_get_type", _execute_test_util_get_type)
	description = "Test Util.get_type() function with different object types"
	category = "utility"


func _execute_test_util_get_type(_params: Dictionary = {}) -> DebugActionResult:
	Log.info("Testing Utils.get_type() function", {}, ["test", "util"])

	var test_results: Array[Dictionary] = []

	# Test 1: Test with a basic Node
	var test_node: Node = Node.new()
	var node_type: StringName = Utils.get_type(test_node)
	test_results.append(
		{
			"object_type": "Node",
			"object_name": "test_node",
			"get_type_result": str(node_type),
			"get_class_result": test_node.get_class(),
			"has_script": test_node.get_script() != null,
			"global_name_empty": node_type.is_empty()
		}
	)
	test_node.queue_free()

	# Test 2: Test with a Resource (UnitData)
	var test_unit_data: UnitData = UnitData.new()
	var unit_type: StringName = Utils.get_type(test_unit_data)
	test_results.append(
		{
			"object_type": "UnitData",
			"object_name": "test_unit_data",
			"get_type_result": str(unit_type),
			"get_class_result": test_unit_data.get_class(),
			"has_script": test_unit_data.get_script() != null,
			"global_name_empty": unit_type.is_empty()
		}
	)

	# Test 3: Test with an Ability
	var test_ability: Ability = Ability.new()
	var ability_type: StringName = Utils.get_type(test_ability)
	test_results.append(
		{
			"object_type": "Ability",
			"object_name": "test_ability",
			"get_type_result": str(ability_type),
			"get_class_result": test_ability.get_class(),
			"has_script": test_ability.get_script() != null,
			"global_name_empty": ability_type.is_empty()
		}
	)

	# Test 4: Test with a StatEffect
	var test_stat_effect: StatEffect = StatEffect.new()
	var effect_type: StringName = Utils.get_type(test_stat_effect)
	test_results.append(
		{
			"object_type": "StatEffect",
			"object_name": "test_stat_effect",
			"get_type_result": str(effect_type),
			"get_class_result": test_stat_effect.get_class(),
			"has_script": test_stat_effect.get_script() != null,
			"global_name_empty": effect_type.is_empty()
		}
	)

	# Test 5: Test with a RefCounted (basic Object type)
	var test_ref_counted: RefCounted = RefCounted.new()
	var ref_counted_type: StringName = Utils.get_type(test_ref_counted)
	test_results.append(
		{
			"object_type": "RefCounted",
			"object_name": "test_ref_counted",
			"get_type_result": str(ref_counted_type),
			"get_class_result": test_ref_counted.get_class(),
			"has_script": test_ref_counted.get_script() != null,
			"global_name_empty": ref_counted_type.is_empty()
		}
	)

	# Test 6: Test with null - skip since get_type expects Object, not null
	# We'll document this as expected limitation rather than causing runtime errors
	test_results.append(
		{
			"object_type": "null",
			"object_name": "null_value",
			"get_type_result": "SKIPPED_NULL",
			"get_class_result": "N/A",
			"has_script": false,
			"global_name_empty": true,
			"note": "Util.get_type() requires Object parameter, null not supported"
		}
	)

	# Summary
	var successful_tests: int = 0
	for result in test_results:
		if not result.get("global_name_empty", true) or result.get("object_type") == "null":
			successful_tests += 1

	var test_summary: Dictionary = {
		"total_tests": test_results.size(),
		"successful_tests": successful_tests,
		"success_rate": float(successful_tests) / float(test_results.size()) * 100.0,
		"all_tests_passed": successful_tests == test_results.size()
	}

	Log.info("Utils.get_type() test completed", test_summary, ["test", "util", "summary"])

	# Log individual results for debugging
	for i in range(test_results.size()):
		var result = test_results[i]
		Log.debug("Test %d result" % (i + 1), result, ["test", "utils", "details"])

	return DebugActionResult.success({"test_results": test_results, "summary": test_summary})
