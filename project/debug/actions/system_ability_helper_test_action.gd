class_name AbilityHelperTestAction
extends DebugAction

func _init() -> void:
	super("system.battle.ability_helper_test", _execute_action_logic)
	set_category("System")
	set_group("Battle System")
	set_description("Unit tests for AbilityHelper static methods")

func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing AbilityHelper class static methods...")
	
	var tests_passed: int = 0
	var total_tests: int = 0
	var test_results: Array[Dictionary] = []
	
	# Create mock battle context and events for testing
	var mock_context = _create_mock_battle_context()
	
	# Test event type checking
	total_tests += 8
	tests_passed += _test_event_type_checking(mock_context, test_results)
	tests_passed += _test_phase_checking(mock_context, test_results)
	tests_passed += _test_event_filtering(mock_context, test_results)
	tests_passed += _test_shield_event_checking(mock_context, test_results)
	tests_passed += _test_turn_event_checking(mock_context, test_results)
	tests_passed += _test_stat_change_checking(mock_context, test_results)
	tests_passed += _test_complex_event_combinations(mock_context, test_results)
	tests_passed += _test_event_timing_edge_cases(mock_context, test_results)
	
	# Test single-unit event creation
	total_tests += 6
	tests_passed += _test_health_bonus_creation(mock_context, test_results)
	tests_passed += _test_attack_bonus_creation(mock_context, test_results)
	tests_passed += _test_damage_creation(mock_context, test_results)
	tests_passed += _test_shield_activation(mock_context, test_results)
	tests_passed += _test_custom_stat_bonuses(mock_context, test_results)
	tests_passed += _test_event_creation_edge_cases(mock_context, test_results)
	
	# Test delegation to BattleRules
	total_tests += 5
	tests_passed += _test_damage_to_random_enemy(mock_context, test_results)
	tests_passed += _test_ally_bonuses_delegation(mock_context, test_results)
	tests_passed += _test_damage_all_enemies(mock_context, test_results)
	tests_passed += _test_bonuses_including_self(mock_context, test_results)
	tests_passed += _test_delegation_edge_cases(mock_context, test_results)
	
	# Test utility and helper methods
	total_tests += 7
	tests_passed += _test_targeting_helpers(mock_context, test_results)
	tests_passed += _test_unit_retrieval(mock_context, test_results)
	tests_passed += _test_condition_checking(mock_context, test_results)
	tests_passed += _test_event_data_extraction(mock_context, test_results)
	tests_passed += _test_ability_optimization(test_results)
	tests_passed += _test_counting_with_conditions(mock_context, test_results)
	tests_passed += _test_trigger_condition_checking(mock_context, test_results)
	
	var duration: int = Time.get_ticks_msec() - start_time
	var coverage_percentage: float = (float(tests_passed) / float(total_tests)) * 100.0
	
	_update_status("AbilityHelper tests completed: %d/%d passed (%.1f%%)" % [tests_passed, total_tests, coverage_percentage])
	
	# Debug: Log failed tests (if any)
	for test_result in test_results:
		if not test_result.success:
			_update_status("FAILED TEST: %s" % test_result.test_name)
	
	var test_data: Dictionary = {
		"tests_passed": tests_passed,
		"total_tests": total_tests,
		"coverage_percentage": coverage_percentage,
		"test_results": test_results,
		"duration_ms": duration
	}
	
	if tests_passed == total_tests and coverage_percentage >= 100.0:
		return DebugAction.Result.new_success({
			"message": "All AbilityHelper tests passed with %.1f%% coverage" % coverage_percentage,
			"tests_passed": tests_passed,
			"total_tests": total_tests,
			"coverage_percentage": coverage_percentage,
			"test_data": test_data,
			"duration_ms": duration
		})
	else:
		return DebugAction.Result.new_failure(
			"AbilityHelper tests failed: %d/%d passed (%.1f%% coverage)" % [tests_passed, total_tests, coverage_percentage],
			"ABILITY_HELPER_TESTS_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION
		)

func _create_mock_battle_context() -> BattleContext:
	var mock_context = BattleContext.new(null)
	
	# Set up allied side with units at positions 0, 1, 3
	mock_context.allied_side.add_unit(0, _create_mock_unit("Allied1", 10, 5, 20, 10))
	mock_context.allied_side.add_unit(1, _create_mock_unit("Allied2", 2, 3, 8, 6))  # Low health
	mock_context.allied_side.add_unit(3, _create_mock_unit("Allied3", 18, 4, 20, 8))  # High health
	
	# Set up enemy side with units at positions 0, 2
	mock_context.enemy_side.add_unit(0, _create_mock_unit("Enemy1", 6, 2, 12, 4))
	mock_context.enemy_side.add_unit(2, _create_mock_unit("Enemy2", 9, 6, 15, 8))
	
	return mock_context

func _create_mock_unit(name: String, current_health: int, current_attack: int, max_health: int, max_attack: int) -> UnitData:
	var unit = UnitData.new()
	unit.card_info = {"name": name, "id": name.hash()}
	unit.current_health = current_health
	unit.current_attack = current_attack
	unit.max_health = max_health
	unit.max_attack = max_attack
	return unit

# Event type checking tests
func _test_event_type_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var death_event = BattleContext.DeathEvent.new(true, 1)
	var combat_event = BattleContext.CombatEvent.new(1, 0, true)
	
	# Test damage event detection
	var damage_unit_pre = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	var damage_unit_post = UnitContext.create(1, true, context, damage_event, core.Tempus.POST)
	
	var damage_pre_correct = AbilityHelper.is_damage_pre(damage_unit_pre)
	var damage_post_correct = AbilityHelper.is_damage_post(damage_unit_post)
	var damage_pre_false = not AbilityHelper.is_damage_pre(damage_unit_post)
	
	# Test death event detection
	var death_unit = UnitContext.create(1, true, context, death_event, core.Tempus.POST)
	var death_correct = AbilityHelper.is_death_post(death_unit)
	var death_false = not AbilityHelper.is_death_post(damage_unit_post)
	
	# Test combat event detection
	var combat_unit_pre = UnitContext.create(1, true, context, combat_event, core.Tempus.PRE)
	var combat_unit_post = UnitContext.create(1, true, context, combat_event, core.Tempus.POST)
	
	var combat_pre_correct = AbilityHelper.is_combat_pre(combat_unit_pre)
	var combat_post_correct = AbilityHelper.is_combat_post(combat_unit_post)
	
	var success = (
		damage_pre_correct and damage_post_correct and damage_pre_false and
		death_correct and death_false and
		combat_pre_correct and combat_post_correct
	)
	
	results.append({
		"test_name": "event_type_checking",
		"success": success,
		"damage_pre": damage_pre_correct,
		"damage_post": damage_post_correct,
		"death_post": death_correct,
		"combat_pre": combat_pre_correct,
		"combat_post": combat_post_correct
	})
	
	# No cleanup needed with instance-based UnitContext
	
	return 1 if success else 0

func _test_phase_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 5)
	
	var stat_unit_pre = UnitContext.create(1, true, context, stat_event, core.Tempus.PRE)
	var stat_unit_post = UnitContext.create(1, true, context, stat_event, core.Tempus.POST)
	
	var stat_pre_correct = AbilityHelper.is_stat_change_pre(stat_unit_pre)
	var stat_post_correct = AbilityHelper.is_stat_change_post(stat_unit_post)
	var stat_pre_false = not AbilityHelper.is_stat_change_pre(stat_unit_post)
	var stat_post_false = not AbilityHelper.is_stat_change_post(stat_unit_pre)
	
	var success = stat_pre_correct and stat_post_correct and stat_pre_false and stat_post_false
	
	results.append({
		"test_name": "phase_checking",
		"success": success,
		"stat_pre": stat_pre_correct,
		"stat_post": stat_post_correct,
		"cross_phase_false": stat_pre_false and stat_post_false
	})
	
	# No cleanup needed
	
	return 1 if success else 0

func _test_event_filtering(context: BattleContext, results: Array[Dictionary]) -> int:
	# Create a mock ability for testing
	var mock_ability = _create_mock_ability([BattleContext.DamageEvent, BattleContext.DeathEvent])
	
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var death_event = BattleContext.DeathEvent.new(true, 1)
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 5)
	
	var should_process_damage = AbilityHelper.should_process_event(mock_ability, damage_event)
	var should_process_death = AbilityHelper.should_process_event(mock_ability, death_event)
	var should_not_process_stat = not AbilityHelper.should_process_event(mock_ability, stat_event)
	
	# Test with null ability
	var null_ability_false = not AbilityHelper.should_process_event(null, damage_event)
	
	var success = should_process_damage and should_process_death and should_not_process_stat and null_ability_false
	
	results.append({
		"test_name": "event_filtering",
		"success": success,
		"process_damage": should_process_damage,
		"process_death": should_process_death,
		"not_process_stat": should_not_process_stat,
		"null_ability_handled": null_ability_false
	})
	
	return 1 if success else 0

func _test_shield_event_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var shield_event = BattleContext.ShieldEvent.new(1, true, true)
	
	var shield_unit_pre = UnitContext.create(1, true, context, shield_event, core.Tempus.PRE)
	var shield_unit_post = UnitContext.create(1, true, context, shield_event, core.Tempus.POST)
	
	var shield_pre_correct = AbilityHelper.is_shield_event_pre(shield_unit_pre)
	var shield_post_correct = AbilityHelper.is_shield_event_post(shield_unit_post)
	
	var success = shield_pre_correct and shield_post_correct
	
	results.append({
		"test_name": "shield_event_checking",
		"success": success,
		"shield_pre": shield_pre_correct,
		"shield_post": shield_post_correct
	})
	
	# No cleanup needed
	
	return 1 if success else 0

func _test_turn_event_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var start_turn_event = BattleContext.StartOfTurnEvent.new()
	var end_turn_event = BattleContext.EndOfTurnEvent.new()
	
	var start_unit = UnitContext.create(1, true, context, start_turn_event, core.Tempus.POST)
	var end_unit = UnitContext.create(1, true, context, end_turn_event, core.Tempus.POST)
	
	var start_correct = AbilityHelper.is_start_of_turn_post(start_unit)
	var end_correct = AbilityHelper.is_end_of_turn_post(end_unit)
	
	var success = start_correct and end_correct
	
	results.append({
		"test_name": "turn_event_checking",
		"success": success,
		"start_of_turn": start_correct,
		"end_of_turn": end_correct
	})
	
	# No cleanup needed
	
	return 1 if success else 0

func _test_stat_change_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 5)
	
	var unit_pre = UnitContext.create(1, true, context, stat_event, core.Tempus.PRE)
	var unit_post = UnitContext.create(1, true, context, stat_event, core.Tempus.POST)
	
	var pre_correct = AbilityHelper.is_stat_change_pre(unit_pre)
	var post_correct = AbilityHelper.is_stat_change_post(unit_post)
	
	var success = pre_correct and post_correct
	
	results.append({
		"test_name": "stat_change_checking",
		"success": success,
		"stat_pre": pre_correct,
		"stat_post": post_correct
	})
	
	# No cleanup needed
	
	return 1 if success else 0

func _test_complex_event_combinations(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	# Test multiple conditions
	var is_damage_and_pre = AbilityHelper.is_damage_pre(unit) and not AbilityHelper.is_damage_post(unit)
	var is_not_death = not AbilityHelper.is_death_post(unit)
	var is_not_combat = not AbilityHelper.is_combat_pre(unit)
	
	var success = is_damage_and_pre and is_not_death and is_not_combat
	
	results.append({
		"test_name": "complex_event_combinations",
		"success": success,
		"damage_and_pre": is_damage_and_pre,
		"not_death": is_not_death,
		"not_combat": is_not_combat
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_event_timing_edge_cases(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	
	# Test same event in different phases
	var unit_pre = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	var unit_post = UnitContext.create(1, true, context, damage_event, core.Tempus.POST)
	
	# PRE phase should only match PRE methods
	var pre_matches_pre = AbilityHelper.is_damage_pre(unit_pre) and not AbilityHelper.is_damage_post(unit_pre)
	# POST phase should only match POST methods  
	var post_matches_post = AbilityHelper.is_damage_post(unit_post) and not AbilityHelper.is_damage_pre(unit_post)
	
	var success = pre_matches_pre and post_matches_post
	
	results.append({
		"test_name": "event_timing_edge_cases",
		"success": success,
		"pre_matches_pre": pre_matches_pre,
		"post_matches_post": post_matches_post
	})
	
	# No cleanup needed #unit_pre)
	# No cleanup needed #unit_post)
	
	return 1 if success else 0

# Event creation tests
func _test_health_bonus_creation(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var initial_event_count = context.unresolved_events.size()
	
	AbilityHelper.grant_health_bonus(unit, 3)
	
	var health_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if (stat_event.stat_name == Battle.UNIT_HEALTH and 
				stat_event.target_position == 1 and 
				stat_event.is_allied_side == true and 
				stat_event.change_value == 3):
				health_events += 1
	
	# Test zero/negative bonus
	AbilityHelper.grant_health_bonus(unit, 0)
	AbilityHelper.grant_health_bonus(unit, -2)
	
	var final_event_count = context.unresolved_events.size()
	var no_invalid_events = (final_event_count - initial_event_count) == 1
	
	var success = health_events == 1 and no_invalid_events
	
	results.append({
		"test_name": "health_bonus_creation",
		"success": success,
		"health_events": health_events,
		"blocked_invalid_events": no_invalid_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_attack_bonus_creation(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var initial_event_count = context.unresolved_events.size()
	
	AbilityHelper.grant_attack_bonus(unit, 2)
	
	var attack_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if (stat_event.stat_name == Battle.UNIT_ATTACK and 
				stat_event.target_position == 1 and 
				stat_event.is_allied_side == true and 
				stat_event.change_value == 2):
				attack_events += 1
	
	var success = attack_events == 1
	
	results.append({
		"test_name": "attack_bonus_creation",
		"success": success,
		"attack_events": attack_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_damage_creation(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var initial_event_count = context.unresolved_events.size()
	
	AbilityHelper.deal_damage_to_unit(unit, 4)
	
	var damage_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.DamageEvent:
			var dmg_event = event as BattleContext.DamageEvent
			if (dmg_event.damage_amount == 4 and 
				dmg_event.target_position == 1 and 
				dmg_event.is_allied_side == true):
				damage_events += 1
	
	var success = damage_events == 1
	
	results.append({
		"test_name": "damage_creation",
		"success": success,
		"damage_events": damage_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_shield_activation(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	AbilityHelper.activate_shield(unit, true)
	
	var shield_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.ShieldEvent:
			var shield_event = event as BattleContext.ShieldEvent
			if (shield_event.target_position == 1 and 
				shield_event.is_allied_side == true and 
				shield_event.shield_active == true):
				shield_events += 1
	
	var success = shield_events == 1
	
	results.append({
		"test_name": "shield_activation",
		"success": success,
		"shield_events": shield_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_custom_stat_bonuses(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var custom_stat: StringName = "custom_stat"
	AbilityHelper.grant_stat_bonus(unit, custom_stat, 7)
	
	var custom_stat_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if (stat_event.stat_name == custom_stat and 
				stat_event.change_value == 7):
				custom_stat_events += 1
	
	var success = custom_stat_events == 1
	
	results.append({
		"test_name": "custom_stat_bonuses",
		"success": success,
		"custom_stat_events": custom_stat_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_event_creation_edge_cases(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var initial_event_count = context.unresolved_events.size()
	
	# Test zero and negative values
	AbilityHelper.grant_health_bonus(unit, 0)
	AbilityHelper.grant_attack_bonus(unit, -1)
	AbilityHelper.deal_damage_to_unit(unit, 0)
	AbilityHelper.grant_stat_bonus(unit, "test", -5)
	
	var final_event_count = context.unresolved_events.size()
	var no_events_added = final_event_count == initial_event_count
	
	var success = no_events_added
	
	results.append({
		"test_name": "event_creation_edge_cases",
		"success": success,
		"no_invalid_events_created": no_events_added,
		"event_count_unchanged": final_event_count == initial_event_count
	})
	
	# No cleanup needed
	return 1 if success else 0

# Delegation tests
func _test_damage_to_random_enemy(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var initial_event_count = context.unresolved_events.size()
	
	AbilityHelper.deal_damage_to_random_enemy(unit, 6, 2)
	
	var damage_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.DamageEvent:
			var dmg_event = event as BattleContext.DamageEvent
			if dmg_event.damage_amount == 6 and not dmg_event.is_allied_side:
				damage_events += 1
	
	var success = damage_events == 2  # Should create 2 damage events to enemies
	
	results.append({
		"test_name": "damage_to_random_enemy",
		"success": success,
		"damage_events_created": damage_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_ally_bonuses_delegation(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	AbilityHelper.grant_ally_bonuses(unit, 2, 1)
	
	var health_events = 0
	var attack_events = 0
	
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if stat_event.is_allied_side and stat_event.target_position != 1:  # Exclude self
				if stat_event.stat_name == Battle.UNIT_HEALTH and stat_event.change_value == 2:
					health_events += 1
				elif stat_event.stat_name == Battle.UNIT_ATTACK and stat_event.change_value == 1:
					attack_events += 1
	
	var success = health_events == 2 and attack_events == 2  # 2 other allies
	
	results.append({
		"test_name": "ally_bonuses_delegation",
		"success": success,
		"health_events": health_events,
		"attack_events": attack_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_damage_all_enemies(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	AbilityHelper.deal_damage_to_all_enemies(unit, 3)
	
	var damage_events = 0
	for event in context.unresolved_events:
		if event is BattleContext.DamageEvent:
			var dmg_event = event as BattleContext.DamageEvent
			if dmg_event.damage_amount == 3 and not dmg_event.is_allied_side:
				damage_events += 1
	
	var success = damage_events == 2  # Should damage all 2 enemies
	
	results.append({
		"test_name": "damage_all_enemies",
		"success": success,
		"damage_events": damage_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_bonuses_including_self(context: BattleContext, results: Array[Dictionary]) -> int:
	# Clear any events from previous tests
	context.unresolved_events.clear()
	
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	AbilityHelper.grant_bonuses_to_all_allies_including_self(unit, 1, 1)
	
	var health_events = 0
	var attack_events = 0
	var self_events = 0
	
	for event in context.unresolved_events:
		if event is BattleContext.StatChangeEvent:
			var stat_event = event as BattleContext.StatChangeEvent
			if stat_event.is_allied_side and stat_event.change_value == 1:
				if stat_event.target_position == 1:  # Self
					self_events += 1
				if stat_event.stat_name == Battle.UNIT_HEALTH:
					health_events += 1
				elif stat_event.stat_name == Battle.UNIT_ATTACK:
					attack_events += 1
	
	var success = health_events == 3 and attack_events == 3 and self_events == 2  # All 3 allies + self gets both bonuses
	
	# Debug output (for development)
	# _update_status("bonuses_including_self: health=%d, attack=%d, self=%d (expect: 3,3,2)" % [health_events, attack_events, self_events])
	
	results.append({
		"test_name": "bonuses_including_self",
		"success": success,
		"health_events": health_events,
		"attack_events": attack_events,
		"self_events": self_events
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_delegation_edge_cases(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test with empty battle context
	var empty_context = BattleContext.new(null)
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, empty_context, damage_event, core.Tempus.PRE)
	
	var initial_events = empty_context.unresolved_events.size()
	
	# These should not crash but also not add events to empty context
	AbilityHelper.deal_damage_to_random_enemy(unit, 5)
	AbilityHelper.grant_ally_bonuses(unit, 2, 1)
	AbilityHelper.deal_damage_to_all_enemies(unit, 3)
	
	var final_events = empty_context.unresolved_events.size()
	var no_crash_and_no_events = final_events == initial_events
	
	var success = no_crash_and_no_events
	
	results.append({
		"test_name": "delegation_edge_cases",
		"success": success,
		"handled_empty_context": no_crash_and_no_events
	})
	
	# No cleanup needed
	return 1 if success else 0

# Utility and helper method tests
func _test_targeting_helpers(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var is_targeting = AbilityHelper.is_event_targeting_unit(unit)
	var target_unit = AbilityHelper.get_target_unit(unit)
	
	var combat_event = BattleContext.CombatEvent.new(1, 0, true)
	# Create new context for combat event since we can't reset
	var combat_unit = UnitContext.create(1, true, context, combat_event, core.Tempus.PRE)
	
	var is_from_unit = AbilityHelper.is_event_from_unit(combat_unit)
	var attacker_unit = AbilityHelper.get_attacker_unit(combat_unit)
	
	var success = (
		is_targeting and 
		target_unit != null and target_unit.card_info.get("name", "") == "Allied2" and
		is_from_unit and 
		attacker_unit != null and attacker_unit.card_info.get("name", "") == "Allied2"
	)
	
	results.append({
		"test_name": "targeting_helpers",
		"success": success,
		"is_targeting": is_targeting,
		"target_unit_found": target_unit != null,
		"is_from_unit": is_from_unit,
		"attacker_unit_found": attacker_unit != null
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_unit_retrieval(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 0, false)  # Target enemy at pos 0
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var target_unit = AbilityHelper.get_target_unit(unit)
	var target_is_enemy = target_unit != null and target_unit.card_info.get("name", "") == "Enemy1"
	
	# Test with non-targeting event - create new context
	var start_turn_event = BattleContext.StartOfTurnEvent.new()
	var turn_unit = UnitContext.create(1, true, context, start_turn_event, core.Tempus.POST)
	
	var no_target_for_turn_event = AbilityHelper.get_target_unit(turn_unit) == null
	var no_attacker_for_turn_event = AbilityHelper.get_attacker_unit(turn_unit) == null
	
	var success = target_is_enemy and no_target_for_turn_event and no_attacker_for_turn_event
	
	results.append({
		"test_name": "unit_retrieval",
		"success": success,
		"target_is_enemy": target_is_enemy,
		"no_target_for_turn_event": no_target_for_turn_event,
		"no_attacker_for_turn_event": no_attacker_for_turn_event
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_condition_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	
	# Test with low health unit (position 1: 2/8 health = 25%)
	var low_health_unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	var is_low_health = AbilityHelper.is_unit_at_low_health(low_health_unit, 0.25)
	var is_not_high_health = not AbilityHelper.is_unit_at_high_health(low_health_unit, 0.75)
	
	# Test with high health unit (position 3: 18/20 health = 90%)
	var high_health_unit = UnitContext.create(3, true, context, damage_event, core.Tempus.PRE)
	var is_high_health = AbilityHelper.is_unit_at_high_health(high_health_unit, 0.75)
	var is_not_low_health = not AbilityHelper.is_unit_at_low_health(high_health_unit, 0.25)
	
	var success = is_low_health and is_not_high_health and is_high_health and is_not_low_health
	
	results.append({
		"test_name": "condition_checking",
		"success": success,
		"low_health_detected": is_low_health,
		"high_health_detected": is_high_health,
		"thresholds_work": is_not_high_health and is_not_low_health
	})
	
	# No cleanup needed #low_health_unit)
	# No cleanup needed #high_health_unit)
	
	return 1 if success else 0

func _test_event_data_extraction(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(7, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	var damage_amount = AbilityHelper.get_damage_from_event(unit)
	
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 3, 13)
	# Create new context for stat event
	var stat_unit = UnitContext.create(1, true, context, stat_event, core.Tempus.PRE)
	
	var stat_change = AbilityHelper.get_stat_change_from_event(stat_unit)
	
	var success = (
		damage_amount == 7 and
		stat_change.has("stat_name") and
		stat_change.stat_name == Battle.UNIT_HEALTH and
		stat_change.change_value == 3
	)
	
	results.append({
		"test_name": "event_data_extraction",
		"success": success,
		"damage_amount": damage_amount,
		"stat_change_keys": stat_change.keys()
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_ability_optimization(results: Array[Dictionary]) -> int:
	# Test with ability that accepts all events
	var all_events_ability = _create_mock_ability([])
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	
	var accepts_all = AbilityHelper.should_process_event(all_events_ability, damage_event)
	
	# Test with ability that only accepts damage events
	var damage_only_ability = _create_mock_ability([BattleContext.DamageEvent])
	var accepts_damage = AbilityHelper.should_process_event(damage_only_ability, damage_event)
	
	var stat_event = BattleContext.StatChangeEvent.new(Battle.UNIT_HEALTH, 1, true, 5)
	var rejects_stat = not AbilityHelper.should_process_event(damage_only_ability, stat_event)
	
	var success = accepts_all and accepts_damage and rejects_stat
	
	results.append({
		"test_name": "ability_optimization",
		"success": success,
		"accepts_all_events": accepts_all,
		"filters_correctly": accepts_damage and rejects_stat
	})
	
	return 1 if success else 0

func _test_counting_with_conditions(context: BattleContext, results: Array[Dictionary]) -> int:
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var unit = UnitContext.create(1, true, context, damage_event, core.Tempus.PRE)
	
	# Count low health allies (< 50% health)
	var low_health_condition = func(unit_data: UnitData) -> bool:
		return float(unit_data.current_health) / float(unit_data.max_health) < 0.5
	
	var low_health_allies = AbilityHelper.count_allies_with_condition(unit, low_health_condition)
	
	# Count high attack enemies (attack >= 6)
	var high_attack_condition = func(unit_data: UnitData) -> bool:
		return unit_data.current_attack >= 6
	
	var high_attack_enemies = AbilityHelper.count_enemies_with_condition(unit, high_attack_condition)
	
	# Expected: 1 low health ally (position 1: 2/8), 1 high attack enemy (position 2: 6 attack)
	var success = low_health_allies == 1 and high_attack_enemies == 1
	
	results.append({
		"test_name": "counting_with_conditions",
		"success": success,
		"low_health_allies": low_health_allies,
		"high_attack_enemies": high_attack_enemies
	})
	
	# No cleanup needed
	return 1 if success else 0

func _test_trigger_condition_checking(context: BattleContext, results: Array[Dictionary]) -> int:
	# Test death trigger
	var death_event = BattleContext.DeathEvent.new(true, 1)
	var death_unit = UnitContext.create(1, true, context, death_event, core.Tempus.POST)
	var death_trigger = AbilityHelper.is_ability_trigger_condition_met(death_unit, "on_death")
	
	# Test damage trigger
	var damage_event = BattleContext.DamageEvent.new(5, 1, true)
	var damage_unit = UnitContext.create(1, true, context, damage_event, core.Tempus.POST)
	var damage_trigger = AbilityHelper.is_ability_trigger_condition_met(damage_unit, "on_take_damage")
	
	# Test turn trigger
	var turn_event = BattleContext.StartOfTurnEvent.new()
	var turn_unit = UnitContext.create(1, true, context, turn_event, core.Tempus.POST)
	var turn_trigger = AbilityHelper.is_ability_trigger_condition_met(turn_unit, "on_turn_start")
	
	# Test unknown trigger
	var unknown_trigger = not AbilityHelper.is_ability_trigger_condition_met(death_unit, "unknown_trigger")
	
	var success = death_trigger and damage_trigger and turn_trigger and unknown_trigger
	
	# Debug output (for development)
	# _update_status("trigger_condition_checking: death=%s, damage=%s, turn=%s, unknown=%s" % [death_trigger, damage_trigger, turn_trigger, unknown_trigger])
	
	results.append({
		"test_name": "trigger_condition_checking",
		"success": success,
		"death_trigger": death_trigger,
		"damage_trigger": damage_trigger,
		"turn_trigger": turn_trigger,
		"handles_unknown": unknown_trigger
	})
	
	# No cleanup needed
	
	return 1 if success else 0

# Helper method to create mock ability
func _create_mock_ability(handled_events: Array) -> Ability:
	var ability = Ability.new()
	# Override the get_handled_event_classes method
	ability.set_script(load("res://rules/ability.gd"))
	
	# Create a simple mock that returns our test event classes
	var mock_ability = MockAbility.new()
	mock_ability._handled_events = handled_events
	return mock_ability

# Mock ability class for testing
class MockAbility extends Ability:
	var _handled_events: Array = []
	
	func get_handled_event_classes() -> Array:
		return _handled_events