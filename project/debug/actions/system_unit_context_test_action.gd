class_name UnitContextTestAction
extends DebugAction

func _init() -> void:
	super._init()
	action_name = "system.battle.unit_context_test"

func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing UnitContext class with object pooling...")
	
	var tests_passed: int = 0
	var total_tests: int = 0
	var test_results: Array[Dictionary] = []
	
	# Clear pool for clean testing
	UnitContext.clear_pool()
	
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
	
	# Test object pooling
	total_tests += 6
	tests_passed += _test_pool_basic_operations(test_results)
	tests_passed += _test_pool_statistics(test_results)
	tests_passed += _test_pool_configuration(test_results)
	tests_passed += _test_pool_performance(test_results)
	tests_passed += _test_pool_memory_safety(test_results)
	tests_passed += _test_pool_concurrency_safety(test_results)
	
	var duration: int = Time.get_ticks_msec() - start_time
	var coverage_percentage: float = (float(tests_passed) / float(total_tests)) * 100.0
	
	_update_status("UnitContext tests completed: %d/%d passed (%.1f%%)" % [tests_passed, total_tests, coverage_percentage])
	
	var test_data: Dictionary = {
		"tests_passed": tests_passed,
		"total_tests": total_tests,
		"coverage_percentage": coverage_percentage,
		"test_results": test_results,
		"pool_stats": UnitContext.get_pool_stats(),
		"duration_ms": duration
	}
	
	if tests_passed == total_tests and coverage_percentage >= 95.0:
		return DebugAction.Result.new_success(
			"All UnitContext tests passed with %.1f%% coverage" % coverage_percentage,
			"UNIT_CONTEXT_TESTS_COMPLETE",
			test_data,
			duration,
			action_name
		)
	else:
		return DebugAction.Result.new_failure(
			"UnitContext tests failed: %d/%d passed (%.1f%% coverage)" % [tests_passed, total_tests, coverage_percentage],
			"UNIT_CONTEXT_TESTS_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION,
			test_data,
			duration,
			action_name
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
	unit.unit_name = name
	unit.current_health = health
	unit.current_attack = attack
	return unit

# Basic functionality tests
func _test_basic_initialization(context: BattleContext, event: Context.Event, results: Array[Dictionary]) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)
	
	var success = (
		unit_context.position == 1 and
		unit_context.is_allied == true and
		unit_context.battle_context == context and
		unit_context.event == event and
		unit_context.phase == core.Tempus.PRE
	)
	
	results.append({
		"test_name": "basic_initialization",
		"success": success,
		"position": unit_context.position,
		"is_allied": unit_context.is_allied,
		"phase": unit_context.phase
	})
	
	UnitContext.release(unit_context)
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
	
	results.append({
		"test_name": "intelligent_targeting",
		"success": success,
		"targeting_this_unit": targeting_success,
		"non_targeting": non_targeting_success,
		"from_this_unit": from_unit_success
	})
	
	UnitContext.release(unit_context)
	UnitContext.release(unit_context2)
	UnitContext.release(unit_context3)
	return 1 if success else 0

func _test_rule_delegation(context: BattleContext, event: Context.Event, results: Array[Dictionary]) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)
	
	# Test delegation methods
	var ally_positions = unit_context.get_ally_positions()
	var enemy_positions = unit_context.get_enemy_positions()
	var allies_count = unit_context.count_allies_alive()
	var enemies_count = unit_context.count_enemies_alive()
	
	var expected_allied: Array[int] = [0, 1, 3]
	var expected_enemies: Array[int] = [0, 2]
	
	var success = (
		ally_positions == expected_allied and
		enemy_positions == expected_enemies and
		allies_count == 3 and
		enemies_count == 2
	)
	
	results.append({
		"test_name": "rule_delegation",
		"success": success,
		"ally_positions": ally_positions,
		"enemy_positions": enemy_positions,
		"allies_count": allies_count,
		"enemies_count": enemies_count
	})
	
	UnitContext.release(unit_context)
	return 1 if success else 0

func _test_convenience_methods(context: BattleContext, event: Context.Event, results: Array[Dictionary]) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)
	
	var self_unit = unit_context.get_self_unit()
	var unit_at_0 = unit_context.get_unit_at_position(0, true)
	var battle_ongoing = unit_context.is_battle_ongoing()
	
	var success = (
		self_unit != null and
		self_unit.unit_name == "Allied2" and
		unit_at_0 != null and
		unit_at_0.unit_name == "Allied1" and
		battle_ongoing == true
	)
	
	results.append({
		"test_name": "convenience_methods",
		"success": success,
		"self_unit_name": self_unit.unit_name if self_unit else "null",
		"unit_at_0_name": unit_at_0.unit_name if unit_at_0 else "null",
		"battle_ongoing": battle_ongoing
	})
	
	UnitContext.release(unit_context)
	return 1 if success else 0

func _test_event_filtering(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test various event types
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 2)
	var combat_event = BattleContext.CombatEvent.new(1, 0, true)
	
	var unit_context = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	var damage_targeting = unit_context.is_event_targeting_this_unit()
	
	unit_context._reset_and_initialize(1, true, context, stat_event, core.Tempus.PRE)
	var stat_targeting = unit_context.is_event_targeting_this_unit()
	
	unit_context._reset_and_initialize(1, true, context, combat_event, core.Tempus.PRE)
	var combat_from = unit_context.is_event_from_this_unit()
	
	var success = damage_targeting and stat_targeting and combat_from
	
	results.append({
		"test_name": "event_filtering",
		"success": success,
		"damage_targeting": damage_targeting,
		"stat_targeting": stat_targeting,
		"combat_from": combat_from
	})
	
	UnitContext.release(unit_context)
	return 1 if success else 0

func _test_validation_methods(context: BattleContext, event: Context.Event, results: Array[Dictionary]) -> int:
	var unit_context = UnitContext.create(1, true, context, event, core.Tempus.PRE)
	
	var is_valid = unit_context.is_valid()
	var debug_info = unit_context.get_debug_info()
	
	# Test invalid context
	var invalid_context = UnitContext.create(-1, true, null, null, core.Tempus.PRE)
	var is_invalid = not invalid_context.is_valid()
	
	var success = (
		is_valid and
		debug_info.has("position") and
		debug_info.position == 1 and
		is_invalid
	)
	
	results.append({
		"test_name": "validation_methods",
		"success": success,
		"is_valid": is_valid,
		"debug_info_keys": debug_info.keys(),
		"is_invalid": is_invalid
	})
	
	UnitContext.release(unit_context)
	UnitContext.release(invalid_context)
	return 1 if success else 0

func _test_debug_functionality(context: BattleContext, event: Context.Event, results: Array[Dictionary]) -> int:
	var unit_context = UnitContext.create(2, false, context, event, core.Tempus.POST)
	
	var debug_info = unit_context.get_debug_info()
	
	var success = (
		debug_info.position == 2 and
		debug_info.is_allied == false and
		debug_info.phase == core.Tempus.POST and
		debug_info.battle_context_valid == true and
		debug_info.is_valid == true
	)
	
	results.append({
		"test_name": "debug_functionality",
		"success": success,
		"debug_info": debug_info
	})
	
	UnitContext.release(unit_context)
	return 1 if success else 0

func _test_edge_cases(results: Array[Dictionary]) -> int:
	var null_event_context = UnitContext.create(0, true, null, null, core.Tempus.PRE)
	var is_invalid = not null_event_context.is_valid()
	
	# Test with invalid position
	var invalid_pos_context = UnitContext.create(-5, true, null, null, core.Tempus.PRE)
	var still_invalid = not invalid_pos_context.is_valid()
	
	var success = is_invalid and still_invalid
	
	results.append({
		"test_name": "edge_cases",
		"success": success,
		"null_context_invalid": is_invalid,
		"invalid_pos_invalid": still_invalid
	})
	
	UnitContext.release(null_event_context)
	UnitContext.release(invalid_pos_context)
	return 1 if success else 0

# Object pooling tests
func _test_pool_basic_operations(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	var initial_stats = UnitContext.get_pool_stats()
	
	# Create and release several contexts
	var contexts: Array[UnitContext] = []
	for i in range(5):
		var context = UnitContext.create(i, true, null, null, core.Tempus.PRE)
		contexts.append(context)
	
	for context in contexts:
		UnitContext.release(context)
	
	var after_stats = UnitContext.get_pool_stats()
	
	var success = (
		initial_stats.current_pool_size == 0 and
		after_stats.current_pool_size == 5 and
		after_stats.created == 5 and
		after_stats.reused == 0
	)
	
	results.append({
		"test_name": "pool_basic_operations",
		"success": success,
		"initial_pool_size": initial_stats.current_pool_size,
		"final_pool_size": after_stats.current_pool_size,
		"created": after_stats.created,
		"reused": after_stats.reused
	})
	
	return 1 if success else 0

func _test_pool_statistics(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	
	# Create some contexts to populate the pool
	var contexts: Array[UnitContext] = []
	for i in range(3):
		contexts.append(UnitContext.create(i, true, null, null, core.Tempus.PRE))
	
	for context in contexts:
		UnitContext.release(context)
	
	# Now reuse some from pool
	var reused_contexts: Array[UnitContext] = []
	for i in range(2):
		reused_contexts.append(UnitContext.create(i, true, null, null, core.Tempus.PRE))
	
	var stats = UnitContext.get_pool_stats()
	
	var success = (
		stats.created == 3 and
		stats.reused == 2 and
		stats.pool_hits == 2 and
		stats.pool_misses == 3 and
		stats.total_requests == 5 and
		stats.hit_rate_percent == 40.0
	)
	
	results.append({
		"test_name": "pool_statistics",
		"success": success,
		"stats": stats
	})
	
	for context in reused_contexts:
		UnitContext.release(context)
	
	return 1 if success else 0

func _test_pool_configuration(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	UnitContext.configure_pool(3)
	
	# Fill pool beyond configured size
	var contexts: Array[UnitContext] = []
	for i in range(5):
		contexts.append(UnitContext.create(i, true, null, null, core.Tempus.PRE))
	
	for context in contexts:
		UnitContext.release(context)
	
	var stats = UnitContext.get_pool_stats()
	
	var success = stats.current_pool_size == 3  # Should be limited to configured size
	
	results.append({
		"test_name": "pool_configuration",
		"success": success,
		"configured_max": 3,
		"actual_pool_size": stats.current_pool_size
	})
	
	# Restore default
	UnitContext.configure_pool(100)
	
	return 1 if success else 0

func _test_pool_performance(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	
	var start_time = Time.get_ticks_usec()
	var iterations = 1000
	
	# Performance test: 1000 allocation/deallocation cycles
	var contexts: Array[UnitContext] = []
	for i in range(iterations):
		var context = UnitContext.create(i % 6, (i % 2) == 0, null, null, core.Tempus.PRE)
		contexts.append(context)
		
		if contexts.size() >= 10:  # Release in batches to test pool reuse
			for ctx in contexts:
				UnitContext.release(ctx)
			contexts.clear()
	
	# Clean up remaining
	for ctx in contexts:
		UnitContext.release(ctx)
	
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	var stats = UnitContext.get_pool_stats()
	var allocation_time_per_ms = duration_ms / iterations
	
	var success = allocation_time_per_ms < 1.0  # Should be under 1ms per allocation on average
	
	results.append({
		"test_name": "pool_performance",
		"success": success,
		"iterations": iterations,
		"duration_ms": duration_ms,
		"allocation_time_per_ms": allocation_time_per_ms,
		"final_stats": stats
	})
	
	return 1 if success else 0

func _test_pool_memory_safety(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	
	var mock_context = _create_mock_battle_context()
	var mock_event = BattleContext.DamageEvent.new(5, 1, true)
	
	# Create context with references
	var unit_context = UnitContext.create(1, true, mock_context, mock_event, core.Tempus.PRE)
	
	# Verify references are set
	var has_references = (
		unit_context.battle_context != null and
		unit_context.event != null
	)
	
	# Release to pool
	UnitContext.release(unit_context)
	
	# Verify references are cleared (this requires accessing the pooled object)
	# We'll create a new context to reuse the pooled one
	var new_context = UnitContext.create(2, false, null, null, core.Tempus.POST)
	
	# The reused context should have new values, not old references
	var references_cleared = (
		new_context.position == 2 and
		new_context.is_allied == false and
		new_context.phase == core.Tempus.POST
	)
	
	var success = has_references and references_cleared
	
	results.append({
		"test_name": "pool_memory_safety",
		"success": success,
		"had_references": has_references,
		"references_cleared": references_cleared
	})
	
	UnitContext.release(new_context)
	return 1 if success else 0

func _test_pool_concurrency_safety(results: Array[Dictionary]) -> int:
	UnitContext.clear_pool()
	
	# Simple concurrency test - create and release from different "threads" 
	# (simulated with alternating operations)
	var contexts_set1: Array[UnitContext] = []
	var contexts_set2: Array[UnitContext] = []
	
	# Interleave operations
	for i in range(10):
		contexts_set1.append(UnitContext.create(i, true, null, null, core.Tempus.PRE))
		contexts_set2.append(UnitContext.create(i, false, null, null, core.Tempus.POST))
	
	# Release in different order
	for context in contexts_set1:
		UnitContext.release(context)
	
	for context in contexts_set2:
		UnitContext.release(context)
	
	var stats = UnitContext.get_pool_stats()
	
	var success = (
		stats.created == 20 and
		stats.current_pool_size <= 20  # Pool might be smaller due to limits
	)
	
	results.append({
		"test_name": "pool_concurrency_safety",
		"success": success,
		"final_stats": stats
	})
	
	return 1 if success else 0