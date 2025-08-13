class_name UnitContext extends RefCounted

# Standalone context class encapsulating all unit-related battle event data
# with object pooling for mobile performance optimization

var position: int
var is_allied: bool
var battle_context: BattleContext
var event: Context.Event
var phase: core.Tempus

# Object Pool Implementation
static var _pool: Array[UnitContext] = []
static var _pool_mutex: Mutex = Mutex.new()
static var _max_pool_size: int = 100
static var _pool_stats: Dictionary = {
	"created": 0,
	"reused": 0,
	"pool_hits": 0,
	"pool_misses": 0,
	"current_pool_size": 0,
	"peak_pool_size": 0
}

func _init(pos: int = -1, allied: bool = false, context: BattleContext = null, evt: Context.Event = null, ph: core.Tempus = core.Tempus.PRE):
	position = pos
	is_allied = allied
	battle_context = context
	event = evt
	phase = ph

# ===== OBJECT POOL MANAGEMENT =====

static func create(pos: int, allied: bool, context: BattleContext, evt: Context.Event, ph: core.Tempus) -> UnitContext:
	"""Factory method that uses object pooling for performance optimization"""
	_pool_mutex.lock()
	
	var unit_context: UnitContext
	
	if _pool.size() > 0:
		# Reuse from pool
		unit_context = _pool.pop_back()
		_pool_stats.reused += 1
		_pool_stats.pool_hits += 1
	else:
		# Create new instance
		unit_context = UnitContext.new()
		_pool_stats.created += 1
		_pool_stats.pool_misses += 1
	
	# Update current pool size
	_pool_stats.current_pool_size = _pool.size()
	_pool_mutex.unlock()
	
	# Initialize/reset the context
	unit_context._reset_and_initialize(pos, allied, context, evt, ph)
	
	return unit_context

static func release(unit_context: UnitContext) -> void:
	"""Return a UnitContext to the object pool for reuse"""
	if not unit_context:
		return
	
	_pool_mutex.lock()
	
	# Only pool if under max size
	if _pool.size() < _max_pool_size:
		# Clear references to prevent memory leaks
		unit_context._clear_references()
		_pool.append(unit_context)
		
		# Update stats
		_pool_stats.current_pool_size = _pool.size()
		_pool_stats.peak_pool_size = max(_pool_stats.peak_pool_size, _pool_stats.current_pool_size)
	
	_pool_mutex.unlock()

static func configure_pool(max_size: int) -> void:
	"""Configure the object pool parameters"""
	_pool_mutex.lock()
	_max_pool_size = max_size
	
	# Trim pool if necessary
	while _pool.size() > _max_pool_size:
		_pool.pop_back()
	
	_pool_stats.current_pool_size = _pool.size()
	_pool_mutex.unlock()

static func get_pool_stats() -> Dictionary:
	"""Get current pool statistics for monitoring and debugging"""
	_pool_mutex.lock()
	var stats_copy = _pool_stats.duplicate()
	_pool_mutex.unlock()
	
	# Calculate derived stats
	var total_requests = stats_copy.pool_hits + stats_copy.pool_misses
	stats_copy["hit_rate_percent"] = (float(stats_copy.pool_hits) / float(total_requests)) * 100.0 if total_requests > 0 else 0.0
	stats_copy["total_requests"] = total_requests
	
	return stats_copy

static func clear_pool() -> void:
	"""Clear the entire object pool - useful for testing and cleanup"""
	_pool_mutex.lock()
	_pool.clear()
	_pool_stats.current_pool_size = 0
	_pool_mutex.unlock()

func _reset_and_initialize(pos: int, allied: bool, context: BattleContext, evt: Context.Event, ph: core.Tempus) -> void:
	"""Reset and initialize this context for reuse"""
	position = pos
	is_allied = allied
	battle_context = context
	event = evt
	phase = ph

func _clear_references() -> void:
	"""Clear all references to prevent memory leaks when pooled"""
	battle_context = null
	event = null
	position = -1
	is_allied = false
	phase = core.Tempus.PRE

# ===== INTELLIGENT TARGETING METHODS =====

func is_event_targeting_this_unit() -> bool:
	"""Check if the current event is targeting this specific unit"""
	if event is BattleContext.DamageEvent:
		var dmg_event = event as BattleContext.DamageEvent
		return dmg_event.target_position == position and dmg_event.is_allied_side == is_allied
	elif event is BattleContext.StatChangeEvent:
		var stat_event = event as BattleContext.StatChangeEvent
		return stat_event.target_position == position and stat_event.is_allied_side == is_allied
	elif event is BattleContext.ShieldEvent:
		var shield_event = event as BattleContext.ShieldEvent
		return shield_event.target_position == position and shield_event.is_allied_side == is_allied
	return false

func is_event_from_this_unit() -> bool:
	"""Check if the current event originated from this specific unit"""
	if event is BattleContext.CombatEvent:
		var combat_event = event as BattleContext.CombatEvent
		return combat_event.attacker_position == position and combat_event.is_allied_attack == is_allied
	elif event is BattleContext.SelectActiveUnitEvent:
		var select_event = event as BattleContext.SelectActiveUnitEvent
		return select_event.selected_unit_position == position and select_event.is_allied_side == is_allied
	return false

# ===== GAME RULES DELEGATION =====
# These methods automatically delegate to BattleRules with proper context

func get_ally_positions() -> Array[int]:
	"""Get positions of all allied units (delegates to BattleRules)"""
	return BattleRules.get_ally_positions(battle_context, is_allied)

func get_enemy_positions() -> Array[int]:
	"""Get positions of all enemy units (delegates to BattleRules)"""
	return BattleRules.get_enemy_positions(battle_context, is_allied)

func count_allies_alive() -> int:
	"""Count number of living allied units (delegates to BattleRules)"""
	return BattleRules.count_allies_alive(battle_context, is_allied)

func count_enemies_alive() -> int:
	"""Count number of living enemy units (delegates to BattleRules)"""
	return BattleRules.count_enemies_alive(battle_context, is_allied)

func get_random_enemy_position() -> int:
	"""Get a random enemy position (delegates to BattleRules)"""
	return BattleRules.get_random_enemy_position(battle_context, is_allied)

func get_random_ally_position(exclude_self: bool = true) -> int:
	"""Get a random ally position, optionally excluding self (delegates to BattleRules)"""
	var exclude_pos = position if exclude_self else -1
	return BattleRules.get_random_ally_position(battle_context, is_allied, exclude_pos)

func is_position_valid(pos: int, allied: bool) -> bool:
	"""Check if a position is valid and occupied (delegates to BattleRules)"""
	return BattleRules.is_position_valid(battle_context, pos, allied)

# ===== CONVENIENCE METHODS =====

func get_unit_at_position(pos: int, allied: bool) -> UnitData:
	"""Get the unit at a specific position"""
	return battle_context.get_unit_at_position(pos, allied)

func get_self_unit() -> UnitData:
	"""Get the UnitData for this context's unit"""
	return get_unit_at_position(position, is_allied)

func is_battle_ongoing() -> bool:
	"""Check if the battle is still ongoing"""
	return battle_context.is_battle_ongoing()

func add_event(new_event: BattleContext.BaseEvent) -> void:
	"""Add an event to the battle context"""
	battle_context.add_event(new_event)

# ===== DEBUGGING AND VALIDATION =====

func is_valid() -> bool:
	"""Check if this context is in a valid state"""
	return (
		battle_context != null and 
		event != null and 
		position >= 0
	)

func get_debug_info() -> Dictionary:
	"""Get debug information about this context"""
	return {
		"position": position,
		"is_allied": is_allied,
		"phase": phase,
		"event_type": event.get_script().get_global_name() if event else "null",
		"battle_context_valid": battle_context != null,
		"is_valid": is_valid()
	}