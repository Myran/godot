class_name UnitContextPerformanceAction
extends DebugAction

func _init() -> void:
	super._init()
	action_name = "system.battle.unit_context_performance"

func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Benchmarking UnitContext performance with object pooling...")
	
	var benchmark_results: Dictionary = {}
	
	# Clear pool for clean testing
	UnitContext.clear_pool()
	
	# Test scenarios
	var scenarios: Array[Dictionary] = [
		{"name": "cold_start", "pool_warmup": false, "iterations": 1000},
		{"name": "warmed_pool", "pool_warmup": true, "iterations": 1000},
		{"name": "high_load", "pool_warmup": true, "iterations": 5000},
		{"name": "mobile_simulation", "pool_warmup": true, "iterations": 10000}
	]
	
	for scenario in scenarios:
		benchmark_results[scenario.name] = _benchmark_scenario(scenario)
	
	# Memory allocation benchmark
	benchmark_results["memory_allocation"] = _benchmark_memory_allocation()
	
	# Pool efficiency analysis
	benchmark_results["pool_efficiency"] = _analyze_pool_efficiency()
	
	var total_duration = Time.get_ticks_msec() - start_time
	
	# Performance validation
	var performance_analysis = _validate_performance_requirements(benchmark_results)
	
	_update_status("UnitContext performance benchmark completed in %d ms" % total_duration)
	
	var result_data: Dictionary = {
		"benchmark_results": benchmark_results,
		"performance_analysis": performance_analysis,
		"benchmark_duration_ms": total_duration,
		"final_pool_stats": UnitContext.get_pool_stats()
	}
	
	if performance_analysis.meets_requirements:
		return DebugAction.Result.new_success(
			"UnitContext performance benchmark passed all requirements",
			"UNIT_CONTEXT_PERFORMANCE_VALIDATED",
			result_data,
			total_duration,
			action_name
		)
	else:
		return DebugAction.Result.new_failure(
			"UnitContext performance benchmark failed requirements",
			"UNIT_CONTEXT_PERFORMANCE_FAILED",
			DebugAction.Result.ErrorCategory.PERFORMANCE,
			result_data,
			total_duration,
			action_name
		)

func _benchmark_scenario(scenario: Dictionary) -> Dictionary:
	UnitContext.clear_pool()
	
	var scenario_name: String = scenario.name
	var pool_warmup: bool = scenario.pool_warmup
	var iterations: int = scenario.iterations
	
	# Warm up pool if requested
	if pool_warmup:
		var warmup_contexts: Array[UnitContext] = []
		for i in range(50):  # Create 50 contexts to warm pool
			warmup_contexts.append(UnitContext.create(i % 6, (i % 2) == 0, null, null, core.Tempus.PRE))
		for ctx in warmup_contexts:
			UnitContext.release(ctx)
	
	var start_time_us = Time.get_ticks_usec()
	
	# Main benchmark loop
	var contexts: Array[UnitContext] = []
	var release_batch_size = 20  # Release in batches to simulate realistic usage
	
	for i in range(iterations):
		var context = UnitContext.create(
			i % 6,  # position (0-5)
			(i % 2) == 0,  # is_allied (alternating)
			null,  # battle_context
			null,  # event  
			core.Tempus.PRE if (i % 3) == 0 else core.Tempus.POST  # phase
		)
		contexts.append(context)
		
		# Release in batches to test pool reuse
		if contexts.size() >= release_batch_size:
			for ctx in contexts:
				UnitContext.release(ctx)
			contexts.clear()
	
	# Clean up remaining contexts
	for ctx in contexts:
		UnitContext.release(ctx)
	
	var end_time_us = Time.get_ticks_usec()
	var duration_us = end_time_us - start_time_us
	var duration_ms = float(duration_us) / 1000.0
	var avg_allocation_time_us = float(duration_us) / float(iterations)
	
	var final_stats = UnitContext.get_pool_stats()
	
	return {
		"scenario": scenario_name,
		"iterations": iterations,
		"duration_ms": duration_ms,
		"avg_allocation_time_us": avg_allocation_time_us,
		"allocations_per_second": int(float(iterations) / (duration_ms / 1000.0)),
		"pool_hit_rate": final_stats.hit_rate_percent,
		"pool_stats": final_stats
	}

func _benchmark_memory_allocation() -> Dictionary:
	UnitContext.clear_pool()
	
	# Test allocation patterns
	var allocation_tests: Array[Dictionary] = []
	
	# Test 1: Sequential allocation and release
	var start_time = Time.get_ticks_usec()
	var contexts: Array[UnitContext] = []
	
	for i in range(100):
		contexts.append(UnitContext.create(i % 6, true, null, null, core.Tempus.PRE))
	
	for ctx in contexts:
		UnitContext.release(ctx)
	
	var sequential_time = Time.get_ticks_usec() - start_time
	allocation_tests.append({
		"test": "sequential_100",
		"duration_us": sequential_time,
		"avg_us_per_allocation": float(sequential_time) / 100.0
	})
	
	# Test 2: Rapid allocation/deallocation cycles
	start_time = Time.get_ticks_usec()
	
	for i in range(100):
		var ctx = UnitContext.create(i % 6, true, null, null, core.Tempus.PRE)
		UnitContext.release(ctx)
	
	var rapid_time = Time.get_ticks_usec() - start_time
	allocation_tests.append({
		"test": "rapid_cycles_100",
		"duration_us": rapid_time,
		"avg_us_per_cycle": float(rapid_time) / 100.0
	})
	
	# Test 3: Large batch allocation
	start_time = Time.get_ticks_usec()
	var large_batch: Array[UnitContext] = []
	
	for i in range(500):
		large_batch.append(UnitContext.create(i % 6, true, null, null, core.Tempus.PRE))
	
	var large_allocation_time = Time.get_ticks_usec() - start_time
	
	# Release the batch
	start_time = Time.get_ticks_usec()
	for ctx in large_batch:
		UnitContext.release(ctx)
	var large_release_time = Time.get_ticks_usec() - start_time
	
	allocation_tests.append({
		"test": "large_batch_500",
		"allocation_duration_us": large_allocation_time,
		"release_duration_us": large_release_time,
		"total_duration_us": large_allocation_time + large_release_time,
		"avg_us_per_allocation": float(large_allocation_time) / 500.0,
		"avg_us_per_release": float(large_release_time) / 500.0
	})
	
	return {
		"allocation_tests": allocation_tests,
		"final_pool_stats": UnitContext.get_pool_stats()
	}

func _analyze_pool_efficiency() -> Dictionary:
	UnitContext.clear_pool()
	UnitContext.configure_pool(20)  # Small pool for efficiency testing
	
	var efficiency_data: Array[Dictionary] = []
	var contexts: Array[UnitContext] = []
	
	# Phase 1: Fill pool
	for i in range(25):  # More than pool size
		contexts.append(UnitContext.create(i % 6, true, null, null, core.Tempus.PRE))
	
	for ctx in contexts:
		UnitContext.release(ctx)
	
	var stats_after_fill = UnitContext.get_pool_stats()
	efficiency_data.append({
		"phase": "after_pool_fill",
		"pool_size": stats_after_fill.current_pool_size,
		"created": stats_after_fill.created,
		"reused": stats_after_fill.reused
	})
	
	# Phase 2: Reuse from pool
	contexts.clear()
	for i in range(15):  # Less than pool size
		contexts.append(UnitContext.create(i % 6, true, null, null, core.Tempus.PRE))
	
	var stats_after_reuse = UnitContext.get_pool_stats()
	efficiency_data.append({
		"phase": "after_pool_reuse",
		"pool_size": stats_after_reuse.current_pool_size,
		"created": stats_after_reuse.created,
		"reused": stats_after_reuse.reused,
		"hit_rate": stats_after_reuse.hit_rate_percent
	})
	
	# Clean up
	for ctx in contexts:
		UnitContext.release(ctx)
	
	# Restore default pool size
	UnitContext.configure_pool(100)
	
	return {
		"efficiency_phases": efficiency_data,
		"final_stats": UnitContext.get_pool_stats()
	}

func _validate_performance_requirements(benchmark_results: Dictionary) -> Dictionary:
	var requirements: Dictionary = {
		"max_allocation_time_us": 100.0,    # < 100μs per allocation 
		"min_allocations_per_second": 5000, # > 5000 allocations/sec
		"min_pool_hit_rate": 70.0,          # > 70% pool hit rate when warmed
		"max_mobile_allocation_ms": 1.0     # < 1ms for mobile scenario
	}
	
	var validation_results: Dictionary = {}
	var all_requirements_met = true
	
	# Check allocation time requirements
	for scenario_name in benchmark_results:
		if scenario_name in ["cold_start", "warmed_pool", "high_load", "mobile_simulation"]:
			var scenario_data = benchmark_results[scenario_name]
			
			var meets_allocation_time = scenario_data.avg_allocation_time_us <= requirements.max_allocation_time_us
			var meets_throughput = scenario_data.allocations_per_second >= requirements.min_allocations_per_second
			
			validation_results[scenario_name] = {
				"meets_allocation_time": meets_allocation_time,
				"meets_throughput": meets_throughput,
				"avg_allocation_time_us": scenario_data.avg_allocation_time_us,
				"allocations_per_second": scenario_data.allocations_per_second
			}
			
			if not meets_allocation_time or not meets_throughput:
				all_requirements_met = false
	
	# Check pool efficiency for warmed scenarios
	if "warmed_pool" in benchmark_results:
		var warmed_data = benchmark_results.warmed_pool
		var meets_hit_rate = warmed_data.pool_hit_rate >= requirements.min_pool_hit_rate
		validation_results["pool_efficiency"] = {
			"meets_hit_rate": meets_hit_rate,
			"actual_hit_rate": warmed_data.pool_hit_rate
		}
		
		if not meets_hit_rate:
			all_requirements_met = false
	
	# Check mobile performance
	if "mobile_simulation" in benchmark_results:
		var mobile_data = benchmark_results.mobile_simulation
		var meets_mobile_requirement = mobile_data.duration_ms <= (requirements.max_mobile_allocation_ms * mobile_data.iterations)
		validation_results["mobile_performance"] = {
			"meets_requirement": meets_mobile_requirement,
			"total_duration_ms": mobile_data.duration_ms,
			"max_allowed_ms": requirements.max_mobile_allocation_ms * mobile_data.iterations
		}
		
		if not meets_mobile_requirement:
			all_requirements_met = false
	
	return {
		"meets_requirements": all_requirements_met,
		"requirements": requirements,
		"validation_results": validation_results,
		"summary": _generate_performance_summary(validation_results, all_requirements_met)
	}

func _generate_performance_summary(validation_results: Dictionary, meets_requirements: bool) -> Dictionary:
	var fastest_scenario = ""
	var slowest_scenario = ""
	var fastest_time_us = INF
	var slowest_time_us = 0.0
	
	for scenario_name in validation_results:
		if scenario_name in ["cold_start", "warmed_pool", "high_load", "mobile_simulation"]:
			var scenario_data = validation_results[scenario_name]
			var time_us = scenario_data.avg_allocation_time_us
			
			if time_us < fastest_time_us:
				fastest_time_us = time_us
				fastest_scenario = scenario_name
			
			if time_us > slowest_time_us:
				slowest_time_us = time_us
				slowest_scenario = scenario_name
	
	return {
		"overall_performance": "EXCELLENT" if meets_requirements else "NEEDS_IMPROVEMENT",
		"fastest_scenario": fastest_scenario,
		"fastest_time_us": fastest_time_us,
		"slowest_scenario": slowest_scenario,
		"slowest_time_us": slowest_time_us,
		"performance_rating": _calculate_performance_rating(fastest_time_us, slowest_time_us)
	}

func _calculate_performance_rating(fastest_us: float, slowest_us: float) -> String:
	var avg_time = (fastest_us + slowest_us) / 2.0
	
	if avg_time <= 10.0:
		return "EXCELLENT"
	elif avg_time <= 50.0:
		return "GOOD"
	elif avg_time <= 100.0:
		return "ACCEPTABLE"
	else:
		return "POOR"