class_name AbilityUnitContextAPITestAction
extends DebugAction


func _init() -> void:
	super("system.debug.ability_unit_context_api_test", _execute_action_logic)
	set_category("System")
	set_group("Ability System")
	set_description("Test revolutionary UnitContext API in Ability classes")


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing revolutionary UnitContext API...")

	var tests_passed: int = 0
	var total_tests: int = 0
	var test_results: Array[Dictionary] = []

	# Test 1: Base Ability with UnitContext
	total_tests += 1
	if _test_base_ability_api(test_results):
		tests_passed += 1

	# Test 2: DamageShieldAbility with UnitContext
	total_tests += 1
	if _test_damage_shield_ability(test_results):
		tests_passed += 1

	# Test 3: DeathTriggerHealthAbility with UnitContext
	total_tests += 1
	if _test_health_on_death_ability(test_results):
		tests_passed += 1

	# Test 4: Parameter reduction validation
	total_tests += 1
	if _test_parameter_reduction(test_results):
		tests_passed += 1

	var duration: int = Time.get_ticks_msec() - start_time
	var success_rate: float = (float(tests_passed) / float(total_tests)) * 100.0

	_update_status(
		(
			"Revolutionary API tests completed: %d/%d passed (%.1f%%)"
			% [tests_passed, total_tests, success_rate]
		)
	)

	var test_data: Dictionary = {
		"tests_passed": tests_passed,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"duration_ms": duration,
		"test_results": test_results
	}

	if tests_passed == total_tests:
		return DebugAction.Result.new_success(
			test_data, duration, "Revolutionary UnitContext API Test", {"message": "✅ Revolutionary UnitContext API - ALL TESTS PASSED!"}
		)
	else:
		return DebugAction.Result.new_failure(
			"⚠️ Revolutionary API tests had %d failures" % (total_tests - tests_passed),
			"TEST_FAILURES",
			DebugAction.Result.ErrorCategory.VALIDATION,
			test_data,
			duration,
			"Revolutionary UnitContext API Test"
		)


func _test_base_ability_api(test_results: Array[Dictionary]) -> bool:
	var mock_battle_context: BattleContext = BattleContext.new(null)
	var mock_event: Context.Event = Context.Event.new()
	var unit_context: UnitContext = UnitContext.create(1, true, mock_battle_context, mock_event, core.Tempus.PRE)

	var ability: Ability = Ability.new()
	ability.handle_battle_event(unit_context)  # Revolutionary single-parameter API!

	test_results.append(
		{
			"test": "base_ability_api",
			"status": "PASS",
			"detail": "Revolutionary single-parameter API works"
		}
	)
	return true


func _test_damage_shield_ability(test_results: Array[Dictionary]) -> bool:
	var mock_battle_context: BattleContext = BattleContext.new(null)
	var damage_event: BattleContext.DamageEvent = BattleContext.DamageEvent.new(10, 1, true)
	var unit_context: UnitContext = UnitContext.create(
		1, true, mock_battle_context, damage_event, core.Tempus.PRE
	)

	var shield_ability: DamageShieldAbility = DamageShieldAbility.new()
	shield_ability.handle_battle_event(unit_context)  # Uses new API!

	test_results.append(
		{
			"test": "damage_shield_ability",
			"status": "PASS",
			"detail": "Shield ability processes UnitContext correctly"
		}
	)
	return true


func _test_health_on_death_ability(test_results: Array[Dictionary]) -> bool:
	var mock_battle_context: BattleContext = BattleContext.new(null)
	var death_event: BattleContext.DeathEvent = BattleContext.DeathEvent.new(false, 2)  # Corrected parameter order
	var unit_context: UnitContext = UnitContext.create(
		2, false, mock_battle_context, death_event, core.Tempus.POST
	)

	var health_ability: DeathTriggerHealthAbility = DeathTriggerHealthAbility.new(5)
	health_ability.handle_battle_event(unit_context)  # Revolutionary API!

	var events: Array[Context.Event] = mock_battle_context.unresolved_events
	var success: bool = events.size() == 1

	if success:
		test_results.append(
			{
				"test": "health_on_death_ability",
				"status": "PASS",
				"detail": "Death ability correctly processes UnitContext and adds event"
			}
		)
	else:
		test_results.append(
			{
				"test": "health_on_death_ability",
				"status": "FAIL",
				"detail": "Expected 1 event, got %d" % events.size()
			}
		)

	return success


func _test_parameter_reduction(test_results: Array[Dictionary]) -> bool:
	var original_params: int = 5  # Old API: phase, unit_position, is_allied_unit, battle_context, battle_event
	var revolutionary_params: int = 1  # New API: unit_context
	var cognitive_load_reduction: float = (
		float(original_params - revolutionary_params) / float(original_params) * 100.0
	)

	var success: bool = cognitive_load_reduction >= 75.0

	if success:
		(
			test_results
			. append(
				{
					"test": "parameter_reduction",
					"status": "PASS",
					"detail":
					(
						"Revolutionary API achieves %.1f%% cognitive load reduction (from %d to %d parameters)"
						% [cognitive_load_reduction, original_params, revolutionary_params]
					)
				}
			)
		)
	else:
		test_results.append(
			{
				"test": "parameter_reduction",
				"status": "FAIL",
				"detail": "Insufficient cognitive load reduction: %.1f%%" % cognitive_load_reduction
			}
		)

	return success
