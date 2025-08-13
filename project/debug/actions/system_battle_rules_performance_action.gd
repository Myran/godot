class_name BattleRulesPerformanceAction
extends DebugAction

func _init() -> void:
	super("system.battle.rules_performance", _execute_action_logic)
	set_category("System")
	set_group("Battle System")
	set_description("Performance benchmarks for BattleRules static methods")

func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Benchmarking BattleRules static method performance...")
	
	var benchmark_results: Dictionary = {}
	var total_duration: int = 0
	
	# Create multiple contexts of different sizes for realistic benchmarking
	var small_context = _create_battle_context(2, 2)  # 2v2
	var medium_context = _create_battle_context(4, 4)  # 4v4  
	var large_context = _create_battle_context(6, 6)  # 6v6
	
	var contexts: Array[Dictionary] = [
		{"name": "small_2v2", "context": small_context},
		{"name": "medium_4v4", "context": medium_context},
		{"name": "large_6v6", "context": large_context}
	]
	
	for context_data in contexts:
		var context_name: String = context_data.name
		var context: BattleContext = context_data.context
		benchmark_results[context_name] = {}
		
		# Benchmark position queries (most frequent operations)
		benchmark_results[context_name]["get_ally_positions"] = _benchmark_method(
			func(): BattleRules.get_ally_positions(context, true), 
			10000  # High iteration count for micro-benchmarks
		)
		
		benchmark_results[context_name]["get_enemy_positions"] = _benchmark_method(
			func(): BattleRules.get_enemy_positions(context, true), 
			10000
		)
		
		benchmark_results[context_name]["count_allies_alive"] = _benchmark_method(
			func(): BattleRules.count_allies_alive(context, true), 
			10000
		)
		
		benchmark_results[context_name]["count_enemies_alive"] = _benchmark_method(
			func(): BattleRules.count_enemies_alive(context, true), 
			10000
		)
		
		# Benchmark utility methods (medium frequency)
		benchmark_results[context_name]["get_random_enemy_position"] = _benchmark_method(
			func(): BattleRules.get_random_enemy_position(context, true), 
			5000
		)
		
		benchmark_results[context_name]["is_position_valid"] = _benchmark_method(
			func(): BattleRules.is_position_valid(context, 0, true), 
			10000
		)
		
		# Benchmark multi-target operations (lower frequency, higher cost)
		benchmark_results[context_name]["deal_damage_to_random_enemies"] = _benchmark_method(
			func(): BattleRules.deal_damage_to_random_enemies(context, true, 5, 2), 
			1000
		)
		
		benchmark_results[context_name]["grant_bonuses_to_all_allies"] = _benchmark_method(
			func(): BattleRules.grant_bonuses_to_all_allies(context, 0, true, 1, 1), 
			1000
		)
		
		# Calculate context total
		var context_total_ms: float = 0.0
		for method_name in benchmark_results[context_name]:
			context_total_ms += benchmark_results[context_name][method_name]["avg_microseconds"]
		benchmark_results[context_name]["total_avg_microseconds"] = context_total_ms
	
	total_duration = Time.get_ticks_msec() - start_time
	
	# Performance analysis
	var performance_analysis = _analyze_performance(benchmark_results)
	
	_update_status("BattleRules performance benchmark completed in %d ms" % total_duration)
	
	var result_data: Dictionary = {
		"benchmark_results": benchmark_results,
		"performance_analysis": performance_analysis,
		"benchmark_duration_ms": total_duration
	}
	
	# Performance thresholds (microseconds)
	var acceptable_thresholds: Dictionary = {
		"position_queries_max_us": 10.0,      # Position queries should be < 10μs
		"utility_methods_max_us": 15.0,       # Utility methods should be < 15μs  
		"multi_target_max_us": 100.0          # Multi-target ops should be < 100μs
	}
	
	var performance_acceptable = _validate_performance_thresholds(benchmark_results, acceptable_thresholds)
	
	if performance_acceptable:
		return DebugAction.Result.new_success({
			"message": "BattleRules performance benchmark passed all thresholds",
			"benchmark_results": benchmark_results,
			"performance_analysis": performance_analysis,
			"benchmark_duration_ms": total_duration
		})
	else:
		return DebugAction.Result.new_failure(
			"BattleRules performance benchmark exceeded acceptable thresholds",
			"BATTLE_RULES_PERFORMANCE_THRESHOLD_EXCEEDED", 
			DebugAction.Result.ErrorCategory.PERFORMANCE
		)

func _create_battle_context(allied_units: int, enemy_units: int) -> BattleContext:
	var context = BattleContext.new(null)
	
	# Add allied units
	for i in range(allied_units):
		context.allied_side.add_unit(i, _create_mock_unit("Allied%d" % i, 10, 5))
	
	# Add enemy units 
	for i in range(enemy_units):
		context.enemy_side.add_unit(i, _create_mock_unit("Enemy%d" % i, 8, 4))
	
	return context

func _create_mock_unit(name: String, health: int, attack: int) -> UnitData:
	var unit = UnitData.new()
	unit.unit_name = name
	unit.current_health = health
	unit.current_attack = attack
	return unit

func _benchmark_method(method_callable: Callable, iterations: int) -> Dictionary:
	var start_time_us: int = Time.get_ticks_usec()
	
	for i in range(iterations):
		method_callable.call()
	
	var end_time_us: int = Time.get_ticks_usec()
	var total_microseconds: int = end_time_us - start_time_us
	var avg_microseconds: float = float(total_microseconds) / float(iterations)
	
	return {
		"total_microseconds": total_microseconds,
		"avg_microseconds": avg_microseconds,
		"iterations": iterations
	}

func _analyze_performance(benchmark_results: Dictionary) -> Dictionary:
	var analysis: Dictionary = {}
	
	# Find fastest and slowest methods across all contexts
	var all_methods: Dictionary = {}
	
	for context_name in benchmark_results:
		if context_name == "total_avg_microseconds":
			continue
			
		var context_results = benchmark_results[context_name]
		for method_name in context_results:
			if method_name == "total_avg_microseconds":
				continue
				
			var avg_time = context_results[method_name]["avg_microseconds"]
			if not all_methods.has(method_name):
				all_methods[method_name] = {"times": [], "contexts": []}
			all_methods[method_name]["times"].append(avg_time)
			all_methods[method_name]["contexts"].append(context_name)
	
	# Calculate method averages across contexts
	var method_averages: Array[Dictionary] = []
	for method_name in all_methods:
		var times = all_methods[method_name]["times"]
		var avg_across_contexts = times.reduce(func(sum, time): return sum + time, 0.0) / times.size()
		method_averages.append({
			"method": method_name,
			"avg_microseconds": avg_across_contexts
		})
	
	# Sort by performance (fastest first)
	method_averages.sort_custom(func(a, b): return a.avg_microseconds < b.avg_microseconds)
	
	analysis["fastest_method"] = method_averages[0] if method_averages.size() > 0 else null
	analysis["slowest_method"] = method_averages[-1] if method_averages.size() > 0 else null
	analysis["method_performance_ranking"] = method_averages
	
	# Scalability analysis
	var scalability: Dictionary = {}
	for method_name in all_methods:
		var times = all_methods[method_name]["times"]
		if times.size() >= 3:  # small, medium, large
			var growth_small_to_medium = times[1] / times[0] if times[0] > 0 else 1.0
			var growth_medium_to_large = times[2] / times[1] if times[1] > 0 else 1.0
			scalability[method_name] = {
				"small_to_medium_ratio": growth_small_to_medium,
				"medium_to_large_ratio": growth_medium_to_large,
				"overall_scalability": "good" if (growth_small_to_medium < 2.0 and growth_medium_to_large < 2.0) else "needs_attention"
			}
	
	analysis["scalability_analysis"] = scalability
	
	return analysis

func _validate_performance_thresholds(benchmark_results: Dictionary, thresholds: Dictionary) -> bool:
	var position_methods = ["get_ally_positions", "get_enemy_positions", "count_allies_alive", "count_enemies_alive"]
	var utility_methods = ["get_random_enemy_position", "is_position_valid"]
	var multi_target_methods = ["deal_damage_to_random_enemies", "grant_bonuses_to_all_allies"]
	
	for context_name in benchmark_results:
		if context_name == "total_avg_microseconds":
			continue
			
		var context_results = benchmark_results[context_name]
		
		# Check position query thresholds
		for method in position_methods:
			if context_results.has(method):
				var avg_time = context_results[method]["avg_microseconds"]
				if avg_time > thresholds.position_queries_max_us:
					return false
		
		# Check utility method thresholds
		for method in utility_methods:
			if context_results.has(method):
				var avg_time = context_results[method]["avg_microseconds"]
				if avg_time > thresholds.utility_methods_max_us:
					return false
		
		# Check multi-target thresholds
		for method in multi_target_methods:
			if context_results.has(method):
				var avg_time = context_results[method]["avg_microseconds"]
				if avg_time > thresholds.multi_target_max_us:
					return false
	
	return true