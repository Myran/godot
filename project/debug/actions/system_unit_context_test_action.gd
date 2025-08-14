class_name UnitContextTestAction
extends DebugAction


func _init() -> void:
	super("system.battle.unit_context_test", _execute_action_logic)
	set_category("System")
	set_group("Battle System")
	set_description("Unit tests for UnitContext")


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing UnitContext class...")

	var tests_passed: int = 0
	var total_tests: int = 0
	var test_results: Array[Dictionary] = []

	# Create mock battle context for testing
	var mock_context = _create_mock_battle_context()
	var mock_event = BattleContext.DamageEvent.new(5, 1, true)

	# Test basic functionality
	total_tests += 8
	tests_passed += _test_basic_initialization(mock_context, mock_event, test_results)
	tests_passed += _test_intelligent_targeting(mock_context, test_results)
	tests_passed += _test_rule_delegation(mock_context, mock_event, test_results)
	tests_passed += _test_convenience_methods(mock_context, mock_event, test_results)
	tests_passed += _test_event_filtering(mock_context, test_results)
	tests_passed += _test_validation_methods(mock_context, mock_event, test_results)
	tests_passed += _test_debug_functionality(mock_context, mock_event, test_results)
	tests_passed += _test_edge_cases(test_results)

	var duration: int = Time.get_ticks_msec() - start_time
	var coverage_percentage: float = (float(tests_passed) / float(total_tests)) * 100.0

	_update_status(
		(
			"UnitContext tests completed: %d/%d passed (%.1f%%)"
			% [tests_passed, total_tests, coverage_percentage]
		)
	)

	var test_data: Dictionary = {
		"tests_passed": tests_passed,
		"total_tests": total_tests,
		"coverage_percentage": coverage_percentage,
		"test_results": test_results,
		"duration_ms": duration
	}

	if tests_passed == total_tests and coverage_percentage >= 100.0:
		return DebugAction.Result.new_success(
			{
				"message":
				"All UnitContext tests passed with %.1f%% coverage" % coverage_percentage,
				"tests_passed": tests_passed,
				"total_tests": total_tests,
				"coverage_percentage": coverage_percentage,
				"test_data": test_data,
				"duration_ms": duration
			}
		)
	else:
		return DebugAction.Result.new_failure(
			(
				"UnitContext tests failed: %d/%d passed (%.1f%% coverage)"
				% [tests_passed, total_tests, coverage_percentage]
			),
			"UNIT_CONTEXT_TESTS_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION
		)


func _create_mock_battle_context() -> BattleContext:
	var mock_context = BattleContext.new(null)

	# Set up allied side with units at positions 0, 1, 3
	mock_context.allied_side.add_unit(0, _create_mock_unit("Allied1", 10, 5))
	mock_context.allied_side.add_unit(1, _create_mock_unit("Allied2", 8, 3))
	mock_context.allied_side.add_unit(3, _create_mock_unit("Allied3", 12, 4))

	# Set up enemy side with units at positions 0, 2
	mock_context.enemy_side.add_unit(0, _create_mock_unit("Enemy1", 6, 2))
	mock_context.enemy_side.add_unit(2, _create_mock_unit("Enemy2", 9, 6))

	return mock_context


func _create_mock_unit(name: String, health: int, attack: int) -> UnitData:
	var unit = UnitData.new()
	unit.card_info = {"name": name, "id": name.hash()}
	unit.current_health = health
	unit.current_attack = attack
	unit.max_health = health + 5
	unit.max_attack = attack + 2
	return unit


# Basic functionality tests
func _test_basic_initialization(
	context: BattleContext, event: Context.Event, results: Array[Dictionary]
) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)

	var success = (
		unit_context.position == 1
		and unit_context.is_allied == true
		and unit_context.battle_context == context
		and unit_context.event == event
		and unit_context.phase == core.Tempus.PRE
	)

	results.append(
		{
			"test_name": "basic_initialization",
			"success": success,
			"position": unit_context.position,
			"is_allied": unit_context.is_allied,
			"phase": unit_context.phase
		}
	)

	return 1 if success else 0


func _test_intelligent_targeting(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test damage event targeting
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit_context = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)

	var targeting_success = unit_context.is_event_targeting_this_unit()

	# Test different position/side - should not target
	var unit_context2 = UnitContext.create(0, false, context, damage_event, core.Tempus.PRE)
	var non_targeting_success = not unit_context2.is_event_targeting_this_unit()

	# Test combat event from unit
	var combat_event = BattleContext.CombatEvent.new(1, 0, true)
	var unit_context3 = UnitContext.create(1, true, context, combat_event, core.Tempus.PRE)
	var from_unit_success = unit_context3.is_event_from_this_unit()

	var success = targeting_success and non_targeting_success and from_unit_success

	results.append(
		{
			"test_name": "intelligent_targeting",
			"success": success,
			"targeting_this_unit": targeting_success,
			"non_targeting": non_targeting_success,
			"from_this_unit": from_unit_success
		}
	)

	return 1 if success else 0


func _test_rule_delegation(
	context: BattleContext, event: Context.Event, results: Array[Dictionary]
) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)

	# Test delegation methods
	var ally_positions = unit_context.get_ally_positions()
	var enemy_positions = unit_context.get_enemy_positions()
	var allies_count = unit_context.count_allies_alive()
	var enemies_count = unit_context.count_enemies_alive()

	var expected_allied: Array[int] = [0, 1, 3]
	var expected_enemies: Array[int] = [0, 2]

	var success = (
		ally_positions == expected_allied
		and enemy_positions == expected_enemies
		and allies_count == 3
		and enemies_count == 2
	)

	results.append(
		{
			"test_name": "rule_delegation",
			"success": success,
			"ally_positions": ally_positions,
			"enemy_positions": enemy_positions,
			"allies_count": allies_count,
			"enemies_count": enemies_count
		}
	)

	return 1 if success else 0


func _test_convenience_methods(
	context: BattleContext, event: Context.Event, results: Array[Dictionary]
) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)

	var self_unit = unit_context.get_self_unit()
	var unit_at_0 = unit_context.get_unit_at_position(0, true)
	var battle_ongoing = unit_context.is_battle_ongoing()

	var success = (
		self_unit != null
		and self_unit.card_info.get("name", "") == "Allied2"
		and unit_at_0 != null
		and unit_at_0.card_info.get("name", "") == "Allied1"
		and battle_ongoing == true
	)

	results.append(
		{
			"test_name": "convenience_methods",
			"success": success,
			"self_unit_name": self_unit.card_info.get("name", "null") if self_unit else "null",
			"unit_at_0_name": unit_at_0.card_info.get("name", "null") if unit_at_0 else "null",
			"battle_ongoing": battle_ongoing
		}
	)

	return 1 if success else 0


func _test_event_filtering(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test various event types
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 2)
	var combat_event = BattleContext.CombatEvent.new(1, 0, true)

	var unit_context = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	var damage_targeting = unit_context.is_event_targeting_this_unit()

	# Test that we can create a new context - the original _reset_and_initialize method is no longer available
	var unit_context2 = UnitContext.create(1, true, context, stat_event, core.Tempus.PRE)
	var stat_targeting = unit_context2.is_event_targeting_this_unit()

	var unit_context3 = UnitContext.create(1, true, context, combat_event, core.Tempus.PRE)
	var combat_from = unit_context3.is_event_from_this_unit()

	var success = damage_targeting and stat_targeting and combat_from

	results.append(
		{
			"test_name": "event_filtering",
			"success": success,
			"damage_targeting": damage_targeting,
			"stat_targeting": stat_targeting,
			"combat_from": combat_from
		}
	)

	return 1 if success else 0


func _test_validation_methods(
	context: BattleContext, event: Context.Event, results: Array[Dictionary]
) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)

	var is_valid = unit_context.is_valid()
	var debug_info = unit_context.get_debug_info()

	# Test invalid context
	var invalid_context = UnitContext.create(-1, true, null, null, core.Tempus.PRE)
	var is_invalid = not invalid_context.is_valid()

	var success = (
		is_valid and debug_info.has("position") and debug_info.position == 1 and is_invalid
	)

	results.append(
		{
			"test_name": "validation_methods",
			"success": success,
			"is_valid": is_valid,
			"debug_info_keys": debug_info.keys(),
			"is_invalid": is_invalid
		}
	)

	return 1 if success else 0


func _test_debug_functionality(
	context: BattleContext, event: Context.Event, results: Array[Dictionary]
) -> int:
	var unit_context = UnitContext.create(2, false, context, event, core.Tempus.POST)

	var debug_info = unit_context.get_debug_info()

	var success = (
		debug_info.position == 2
		and debug_info.is_allied == false
		and debug_info.phase == core.Tempus.POST
		and debug_info.battle_context_valid == true
		and debug_info.is_valid == true
	)

	results.append(
		{"test_name": "debug_functionality", "success": success, "debug_info": debug_info}
	)

	return 1 if success else 0


func _test_edge_cases(results: Array[Dictionary]) -> int:
	var null_event_context = UnitContext.create(0, true, null, null, core.Tempus.PRE)
	var is_invalid = not null_event_context.is_valid()

	# Test with invalid position
	var invalid_pos_context = UnitContext.create(-5, true, null, null, core.Tempus.PRE)
	var still_invalid = not invalid_pos_context.is_valid()

	var success = is_invalid and still_invalid

	results.append(
		{
			"test_name": "edge_cases",
			"success": success,
			"null_context_invalid": is_invalid,
			"invalid_pos_invalid": still_invalid
		}
	)

	return 1 if success else 0
