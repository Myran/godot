class_name BattleRulesTestAction
extends DebugAction

func _init() -> void:
	super("system.battle.rules_test", _execute_action_logic)
	set_category("System")
	set_group("Battle System")
	set_description("Unit tests for BattleRules static methods")

func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing BattleRules class static methods...")
	
	var tests_passed: int = 0
	var total_tests: int = 0
	var test_results: Array[Dictionary] = []
	
	# Create mock battle context for testing
	var mock_context = _create_mock_battle_context()
	
	# Test position and targeting rules
	total_tests += 8
	tests_passed += _test_get_ally_positions(mock_context, test_results)
	tests_passed += _test_get_enemy_positions(mock_context, test_results)
	tests_passed += _test_count_allies_alive(mock_context, test_results)
	tests_passed += _test_count_enemies_alive(mock_context, test_results)
	tests_passed += _test_get_random_enemy_position(mock_context, test_results)
	tests_passed += _test_get_random_ally_position(mock_context, test_results)
	tests_passed += _test_is_position_valid(mock_context, test_results)
	tests_passed += _test_position_edge_cases(mock_context, test_results)
	
	# Test multi-target operations
	total_tests += 4
	tests_passed += _test_deal_damage_to_random_enemies(mock_context, test_results)
	tests_passed += _test_grant_bonuses_to_all_allies(mock_context, test_results)
	tests_passed += _test_multi_target_edge_cases(mock_context, test_results)
	tests_passed += _test_multi_target_zero_damage(mock_context, test_results)
	
	var duration: int = Time.get_ticks_msec() - start_time
	var coverage_percentage: float = (float(tests_passed) / float(total_tests)) * 100.0
	
	_update_status("BattleRules tests completed: %d/%d passed (%.1f%%)" % [tests_passed, total_tests, coverage_percentage])
	
	var test_data: Dictionary = {
		"tests_passed": tests_passed,
		"total_tests": total_tests,
		"coverage_percentage": coverage_percentage,
		"test_results": test_results,
		"duration_ms": duration
	}
	
	if tests_passed == total_tests and coverage_percentage >= 90.0:
		return DebugAction.Result.new_success({
			"message": "All BattleRules tests passed with %.1f%% coverage" % coverage_percentage,
			"tests_passed": tests_passed,
			"total_tests": total_tests,
			"coverage_percentage": coverage_percentage,
			"test_data": test_data,
			"duration_ms": duration
		})
	else:
		return DebugAction.Result.new_failure(
			"BattleRules tests failed: %d/%d passed (%.1f%% coverage)" % [tests_passed, total_tests, coverage_percentage],
			"BATTLE_RULES_TESTS_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION
		)

func _create_mock_battle_context() -> BattleContext:
	# Create a mock battle solver (null is fine for testing)
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

# Position and targeting rule tests
func _test_get_ally_positions(context: BattleContext, results: Array[Dictionary]) -> int:
	var allied_positions = BattleRules.get_ally_positions(context, true)
	var expected_allied: Array[int] = [0, 1, 3]
	
	var enemy_positions = BattleRules.get_ally_positions(context, false)
	var expected_enemy: Array[int] = [0, 2]
	
	var success = (allied_positions == expected_allied and enemy_positions == expected_enemy)
	results.append({
		"test_name": "get_ally_positions",
		"success": success,
		"expected_allied": expected_allied,
		"actual_allied": allied_positions,
		"expected_enemy": expected_enemy,
		"actual_enemy": enemy_positions
	})
	return 1 if success else 0

func _test_get_enemy_positions(context: BattleContext, results: Array[Dictionary]) -> int:
	var allied_enemies = BattleRules.get_enemy_positions(context, true)
	var expected_allied_enemies: Array[int] = [0, 2]
	
	var enemy_enemies = BattleRules.get_enemy_positions(context, false)
	var expected_enemy_enemies: Array[int] = [0, 1, 3]
	
	var success = (allied_enemies == expected_allied_enemies and enemy_enemies == expected_enemy_enemies)
	results.append({
		"test_name": "get_enemy_positions",
		"success": success,
		"expected_allied_enemies": expected_allied_enemies,
		"actual_allied_enemies": allied_enemies,
		"expected_enemy_enemies": expected_enemy_enemies,
		"actual_enemy_enemies": enemy_enemies
	})
	return 1 if success else 0

func _test_count_allies_alive(context: BattleContext, results: Array[Dictionary]) -> int:
	var allied_count = BattleRules.count_allies_alive(context, true)
	var enemy_count = BattleRules.count_allies_alive(context, false)
	
	var success = (allied_count == 3 and enemy_count == 2)
	results.append({
		"test_name": "count_allies_alive",
		"success": success,
		"expected_allied": 3,
		"actual_allied": allied_count,
		"expected_enemy": 2,
		"actual_enemy": enemy_count
	})
	return 1 if success else 0

func _test_count_enemies_alive(context: BattleContext, results: Array[Dictionary]) -> int:
	var allied_enemies = BattleRules.count_enemies_alive(context, true)
	var enemy_enemies = BattleRules.count_enemies_alive(context, false)
	
	var success = (allied_enemies == 2 and enemy_enemies == 3)
	results.append({
		"test_name": "count_enemies_alive",
		"success": success,
		"expected_allied_enemies": 2,
		"actual_allied_enemies": allied_enemies,
		"expected_enemy_enemies": 3,
		"actual_enemy_enemies": enemy_enemies
	})
	return 1 if success else 0

func _test_get_random_enemy_position(context: BattleContext, results: Array[Dictionary]) -> int:
	var valid_allied_enemies: Array[int] = [0, 2]
	var valid_enemy_enemies: Array[int] = [0, 1, 3]
	
	var allied_enemy_pos = BattleRules.get_random_enemy_position(context, true)
	var enemy_enemy_pos = BattleRules.get_random_enemy_position(context, false)
	
	var success = (allied_enemy_pos in valid_allied_enemies and enemy_enemy_pos in valid_enemy_enemies)
	results.append({
		"test_name": "get_random_enemy_position",
		"success": success,
		"valid_allied_enemies": valid_allied_enemies,
		"actual_allied_enemy": allied_enemy_pos,
		"valid_enemy_enemies": valid_enemy_enemies,
		"actual_enemy_enemy": enemy_enemy_pos
	})
	return 1 if success else 0

func _test_get_random_ally_position(context: BattleContext, results: Array[Dictionary]) -> int:
	var valid_allied_allies: Array[int] = [0, 1, 3]
	var valid_enemy_allies: Array[int] = [0, 2]
	
	# Test without exclusion
	var allied_ally_pos = BattleRules.get_random_ally_position(context, true)
	var enemy_ally_pos = BattleRules.get_random_ally_position(context, false)
	
	# Test with exclusion
	var excluded_allied_pos = BattleRules.get_random_ally_position(context, true, 1)
	var valid_excluded: Array[int] = [0, 3]
	
	var success = (allied_ally_pos in valid_allied_allies and 
	               enemy_ally_pos in valid_enemy_allies and 
	               excluded_allied_pos in valid_excluded)
	results.append({
		"test_name": "get_random_ally_position",
		"success": success,
		"allied_ally_pos": allied_ally_pos,
		"enemy_ally_pos": enemy_ally_pos,
		"excluded_allied_pos": excluded_allied_pos
	})
	return 1 if success else 0

func _test_is_position_valid(context: BattleContext, results: Array[Dictionary]) -> int:
	var test_cases: Array[Dictionary] = [
		{"pos": 0, "allied": true, "expected": true},
		{"pos": 1, "allied": true, "expected": true},
		{"pos": 2, "allied": true, "expected": false},
		{"pos": 3, "allied": true, "expected": true},
		{"pos": 4, "allied": true, "expected": false},
		{"pos": 0, "allied": false, "expected": true},
		{"pos": 1, "allied": false, "expected": false},
		{"pos": 2, "allied": false, "expected": true},
	]
	
	var all_passed = true
	for test_case in test_cases:
		var result = BattleRules.is_position_valid(context, test_case.pos, test_case.allied)
		if result != test_case.expected:
			all_passed = false
			break
	
	results.append({
		"test_name": "is_position_valid",
		"success": all_passed,
		"test_cases": test_cases
	})
	return 1 if all_passed else 0

func _test_position_edge_cases(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test with empty side
	var empty_context = BattleContext.new(null)
	var empty_positions = BattleRules.get_ally_positions(empty_context, true)
	var empty_count = BattleRules.count_allies_alive(empty_context, true)
	var invalid_random = BattleRules.get_random_enemy_position(empty_context, true)
	
	var success = (empty_positions.size() == 0 and 
	               empty_count == 0 and 
	               invalid_random == Battle.NO_UNIT_FOUND)
	
	results.append({
		"test_name": "position_edge_cases",
		"success": success,
		"empty_positions_size": empty_positions.size(),
		"empty_count": empty_count,
		"invalid_random": invalid_random
	})
	return 1 if success else 0

# Multi-target operation tests
func _test_deal_damage_to_random_enemies(context: BattleContext, results: Array[Dictionary]) -> int:
	var initial_event_count = context.unresolved_events.size()
	
	# Deal damage to 2 random enemies from allied perspective
	BattleRules.deal_damage_to_random_enemies(context, true, 5, 2)
	
	var damage_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.DamageEvent:
			var dmg_event = event as BattleContext.DamageEvent
			if dmg_event.damage_amount == 5 and not dmg_event.is_allied_side:
				damage_events += 1
	
	var success = (damage_events == 2)
	results.append({
		"test_name": "deal_damage_to_random_enemies",
		"success": success,
		"expected_damage_events": 2,
		"actual_damage_events": damage_events
	})
	return 1 if success else 0

func _test_grant_bonuses_to_all_allies(context: BattleContext, results: Array[Dictionary]) -> int:
	var initial_event_count = context.unresolved_events.size()
	
	# Grant bonuses to all allies except position 1
	BattleRules.grant_bonuses_to_all_allies(context, 1, true, 2, 1)
	
	var health_events = 0
	var attack_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if stat_event.is_allied_side and stat_event.target_position != 1:
				if stat_event.stat_name == Battle.UNIT_HEALTH and stat_event.change_value == 2:
					health_events += 1
				elif stat_event.stat_name == Battle.UNIT_ATTACK and stat_event.change_value == 1:
					attack_events += 1
	
	var success = (health_events == 2 and attack_events == 2)  # 2 allies excluding source
	results.append({
		"test_name": "grant_bonuses_to_all_allies",
		"success": success,
		"expected_health_events": 2,
		"actual_health_events": health_events,
		"expected_attack_events": 2,
		"actual_attack_events": attack_events
	})
	return 1 if success else 0

func _test_multi_target_edge_cases(context: BattleContext, results: Array[Dictionary]) -> int:
	var empty_context = BattleContext.new(null)
	var initial_event_count = empty_context.unresolved_events.size()
	
	# Try operations on empty context - should not crash or add events
	BattleRules.deal_damage_to_random_enemies(empty_context, true, 5, 3)
	BattleRules.grant_bonuses_to_all_allies(empty_context, 0, true, 1, 1)
	
	var success = (empty_context.unresolved_events.size() == initial_event_count)
	results.append({
		"test_name": "multi_target_edge_cases",
		"success": success,
		"initial_events": initial_event_count,
		"final_events": empty_context.unresolved_events.size()
	})
	return 1 if success else 0

func _test_multi_target_zero_damage(context: BattleContext, results: Array[Dictionary]) -> int:
	var initial_event_count = context.unresolved_events.size()
	
	# Grant zero bonuses - should not create events
	BattleRules.grant_bonuses_to_all_allies(context, 0, true, 0, 0)
	
	var success = (context.unresolved_events.size() == initial_event_count)
	results.append({
		"test_name": "multi_target_zero_damage",
		"success": success,
		"initial_events": initial_event_count,
		"final_events": context.unresolved_events.size()
	})
	return 1 if success else 0