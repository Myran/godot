class_name Battle extends Node

enum BattleAction { ATTACK_REGULAR }

const UNIT_HEALTH: String = "current_health"
const UNIT_ATTACK: String = "current_attack"
const NO_UNIT_FOUND: int = -1


# Data class to hold battle results
class BattleResult:
	var events: Array[Context.Event]
	var final_allied_units: Dictionary[int, UnitData]
	var final_enemy_units: Dictionary[int, UnitData]
	var final_dead_allied_units: Dictionary[int, UnitData]
	var final_dead_enemy_units: Dictionary[int, UnitData]

	func _init(
		_events: Array[Context.Event],
		_allied: Dictionary[int, UnitData],
		_enemy: Dictionary[int, UnitData],
		_dead_allied: Dictionary[int, UnitData] = {},
		_dead_enemy: Dictionary[int, UnitData] = {}
	) -> void:
		events = _events
		final_allied_units = _allied
		final_enemy_units = _enemy
		final_dead_allied_units = _dead_allied
		final_dead_enemy_units = _dead_enemy


func battle_start(
	allies_lineup: Dictionary[int, UnitData], enemies_lineup: Dictionary[int, UnitData]
) -> BattleResult:
	return battle_solver(allies_lineup, enemies_lineup)


func battle_solver(
	allied_lineup: Dictionary[int, UnitData], enemies_lineup: Dictionary[int, UnitData]
) -> BattleResult:
	var context: BattleContext = BattleContext.new(self)
	_initialize_battle(context, allied_lineup, enemies_lineup)

	while context.is_battle_ongoing():
		solve_win_conditions(context)
		if context.is_battle_ongoing():
			process_turn(context)

	# Return both events and final unit states for reconciliation
	# Note: Temporary abilities are preserved in final state so reconciliation
	# can see what abilities influenced the battle outcome
	# Include dead units so permanent effects on dead units are not lost
	return BattleResult.new(
		context.event_list,
		context.allied_side.lineup,
		context.enemy_side.lineup,
		context.allied_side.dead_units,
		context.enemy_side.dead_units
	)


static func _initialize_battle(
	context: BattleContext,
	allied_lineup: Dictionary[int, UnitData],
	enemies_lineup: Dictionary[int, UnitData]
) -> void:
	Log.debug(
		"Initializing battle",
		{"allied_count": allied_lineup.size(), "enemy_count": enemies_lineup.size()},
		[Log.TAG_BATTLE, Log.TAG_INITIALIZATION]
	)
	var dup_allies: Dictionary[int, UnitData] = duplicate_lineup_with_references(allied_lineup)
	var allies_event: BattleContext.AddLineupEvent = BattleContext.AddLineupEvent.new(
		true, dup_allies
	)
	var dup_enemies: Dictionary[int, UnitData] = duplicate_lineup_with_references(enemies_lineup)
	var enemies_event: BattleContext.AddLineupEvent = BattleContext.AddLineupEvent.new(
		false, dup_enemies
	)
	context.add_event(allies_event)
	context.add_event(enemies_event)
	context.solve_events()


# Turn processing
static func process_turn(context: BattleContext) -> void:
	Log.debug(
		"Processing battle turn",
		{"side": context.is_allied_turn},
		[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
	)
	start_of_turn(context)
	find_next_unit(context)
	context.solve_events()
	activate_current_unit(context)
	context.solve_events()
	solve_death_test(context)
	context.solve_events()
	context.switch_turn()
	end_of_turn(context)


# Event solvers
static func solve_event(event: Context.Event, context: BattleContext) -> void:
	if event is BattleContext.FindNextUnitEvent:
		var active_side: Side = context.get_active_side()
		var sel_unit_pos: int = find_next_unactive_on_side(active_side)
		if sel_unit_pos == NO_UNIT_FOUND:
			Log.debug(
				"All units activated, clearing activated units list",
				{},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
			)
			active_side.clear_activated()
			sel_unit_pos = find_next_unactive_on_side(active_side)
		var select_event: BattleContext.SelectActiveUnitEvent = (
			BattleContext.SelectActiveUnitEvent.new(sel_unit_pos, context.is_allied_turn)
		)
		context.add_event(select_event)

	elif event is BattleContext.AddLineupEvent:
		var allied_side: bool = event.is_allied_side
		var side: Side = context.get_side(allied_side)
		side.lineup = event.lineup_data
		Log.debug(
			"Lineup added to battle",
			{"side": allied_side, "lineup_size": side.lineup.size()},
			[Log.TAG_BATTLE, Log.TAG_INITIALIZATION]
		)

	elif event is BattleContext.SelectActiveUnitEvent:
		var data: BattleContext.SelectActiveUnitEvent = event as BattleContext.SelectActiveUnitEvent
		if data.selected_unit_position == NO_UNIT_FOUND:
			return
		var side: Side = context.get_side(data.is_allied_side)
		if !side.lineup.has(data.selected_unit_position):
			return
		var sel_unit: UnitData = side.lineup[data.selected_unit_position]
		context.mark_unit_activated(sel_unit)
		Log.debug(
			"Unit activated",
			{
				"unit": sel_unit.card_info.get("id", "unknown"),
				"position": data.selected_unit_position
			},
			[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
		)
		context.active_unit = sel_unit

	elif event is BattleContext.CombatEvent:
		var allied_attack: bool = event.is_allied_attack
		var attacking_side: Side = context.get_side(allied_attack)
		var defending_side: Side = context.get_side(!allied_attack)
		var attacker: UnitData = attacking_side.lineup[event.attacker_position]
		var defender: UnitData = defending_side.lineup[event.defender_position]
		var attacker_current_attack: int = attacker.current_attack
		var event_defender: int = event.defender_position
		var event_attacker: int = event.attacker_position
		var defender_current_attack: int = defender.current_attack
		var attacker_damage: BattleContext.DamageEvent = BattleContext.DamageEvent.new(
			attacker_current_attack, event_defender, !allied_attack
		)
		var defender_damage: BattleContext.DamageEvent = BattleContext.DamageEvent.new(
			defender_current_attack, event_attacker, allied_attack
		)
		Log.debug(
			"Combat damage calculated",
			{
				"attacker_damage": attacker_current_attack,
				"defender_damage": defender_current_attack
			},
			[Log.TAG_BATTLE, Log.TAG_COMBAT]
		)
		context.add_event(attacker_damage)
		context.add_event(defender_damage)

	elif event is BattleContext.DamageEvent:
		var target: int = event.target_position
		var side: bool = event.is_allied_side
		var damage_amount: int = event.damage_amount
		if event.damage_effects.size():
			for effect: Dictionary in event.damage_effects:
				match effect.effect_type:
					"shield":
						var shield_ability: DamageShieldAbility = effect.ability
						if shield_ability.shield_used == false:
							context.add_event(BattleContext.ShieldEvent.new(target, side, false))
							shield_ability.shield_used = true
							Log.debug(
								"Shield ability activated, damage prevented",
								{"target": target, "side": side},
								[Log.TAG_BATTLE, Log.TAG_COMBAT]
							)
							return

		var stat_change: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			UNIT_HEALTH, target, side, -damage_amount
		)
		context.add_event(stat_change)

	elif event is BattleContext.StatChangeEvent:
		if event.change_value == 0:
			return
		var event_side: bool = event.is_allied_side
		var side: Side = context.get_side(event_side)
		var stat: StringName = event.stat_name
		if !side.lineup.has(event.target_position):
			Log.warning(
				"Target unit not found during stat change",
				{"target_position": event.target_position, "side": event_side},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ERROR]
			)
			return
		var unit: UnitData = side.lineup[event.target_position]
		var current_stat: int = unit.get(stat)
		if current_stat == null:
			Log.warning(
				"Stats change error during battle",
				{"event": event},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STAT, Log.TAG_ERROR]
			)
			return
		var new_value: int = current_stat + event.change_value
		unit.set(stat, new_value)
		var target: int = event.target_position
		var follow_up_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			UNIT_HEALTH, target, event_side, 0, new_value
		)
		context.add_event(follow_up_event)

	elif event is BattleContext.DeathEvent:
		var pos: int = event.unit_position
		var side: bool = event.is_allied_side
		context.remove_unit(pos, side)
	elif event is BattleContext.StartOfTurnEvent:
		Log.debug(
			"Start of battle turn",
			{"side": context.is_allied_turn},
			[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
		)
	elif event is BattleContext.EndOfTurnEvent:
		Log.debug(
			"End of battle turn",
			{"side": context.is_allied_turn},
			[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
		)


static func find_next_unactive_on_side(side: Side) -> int:
	Log.debug(
		"Finding next unactivated unit",
		{"side_units": side.lineup.size()},
		[Log.TAG_BATTLE, Log.TAG_COMBAT]
	)
	for pos: int in side.lineup:
		var unit: UnitData = side.lineup[pos]
		if !side.has_unit(unit):
			return pos
	return NO_UNIT_FOUND


# Combat helpers
static func create_combat_event(attacker_unit: UnitData, context: BattleContext) -> Context.Event:
	Log.debug(
		"Creating combat event",
		{"attacker": attacker_unit.card_info.get("id", "unknown")},
		[Log.TAG_BATTLE, Log.TAG_COMBAT]
	)
	var target_lineup: Dictionary[int, UnitData] = context.get_inactive_side().lineup
	var attacker_lineup: Dictionary[int, UnitData] = context.get_active_side().lineup
	var opposing_unit: UnitData = find_combat_target(target_lineup)

	return BattleContext.CombatEvent.new(
		get_pos_for_unit(attacker_lineup, attacker_unit),
		get_pos_for_unit(target_lineup, opposing_unit),
		context.is_allied_turn
	)


static func start_of_turn(context: BattleContext) -> void:
	context.add_event(BattleContext.StartOfTurnEvent.new())


static func end_of_turn(context: BattleContext) -> void:
	context.add_event(BattleContext.EndOfTurnEvent.new())


static func find_next_unit(context: BattleContext) -> void:
	context.add_event(BattleContext.FindNextUnitEvent.new())


static func activate_current_unit(context: BattleContext) -> void:
	var selected_action: Dictionary = context.active_unit.select_action(context)
	var event: Context.Event

	match selected_action.action:
		BattleAction.ATTACK_REGULAR:
			event = create_combat_event(context.active_unit, context)
		_:
			Log.warning(
				"No action selected for unit in battle",
				{},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_VALIDATION, Log.TAG_ERROR]
			)

	if event:
		context.add_event(event)


# Death handling
static func solve_death_test(context: BattleContext) -> void:
	Log.debug("Testing for unit deaths", {}, [Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_RULES])
	for is_allied: bool in [true, false]:
		var side: Side = context.get_side(is_allied)
		for pos: int in side.lineup:
			var unit: UnitData = side.lineup[pos]
			if unit.current_health <= 0:
				var event: BattleContext.DeathEvent = BattleContext.DeathEvent.new(is_allied, pos)
				context.add_event(event)


static func solve_win_conditions(context: BattleContext) -> void:
	if context.is_side_empty(true) and context.is_side_empty(false):
		Log.info(
			"Battle ended in a draw",
			{},
			[Log.TAG_BATTLE, Log.TAG_WIN_CONDITION, Log.TAG_STATE_TRANSITION]
		)
		context.end_battle()
	elif context.is_side_empty(true):
		Log.info(
			"Battle ended - Allied side lost",
			{},
			[Log.TAG_BATTLE, Log.TAG_WIN_CONDITION, Log.TAG_STATE_TRANSITION]
		)
		context.end_battle()
	elif context.is_side_empty(false):
		Log.info(
			"Battle ended - Enemy side lost",
			{},
			[Log.TAG_BATTLE, Log.TAG_WIN_CONDITION, Log.TAG_STATE_TRANSITION]
		)
		context.end_battle()
	else:
		Log.debug(
			"Win conditions not met, continuing battle",
			{
				"allied_units": context.get_side(true).lineup.size(),
				"enemy_units": context.get_side(false).lineup.size()
			},
			[Log.TAG_BATTLE, Log.TAG_WIN_CONDITION]
		)


# Utility functions
static func duplicate_resource(res: Variant) -> Variant:
	if res is Resource:
		# Use Godot's proper deep copy for Resources
		return res.duplicate(true)  # true = deep copy
	else:
		# Fallback for non-Resource types
		return str_to_var(var_to_str(res))


# Duplicate lineup while setting original references on battle copies
static func duplicate_lineup_with_references(
	lineup: Dictionary[int, UnitData]
) -> Dictionary[int, UnitData]:
	var duplicated_lineup: Dictionary[int, UnitData] = {}

	for position: int in lineup.keys():
		var original_unit: UnitData = lineup[position]
		var battle_copy: UnitData = duplicate_resource(original_unit)

		# Set the reference to the original unit
		battle_copy.battle_original_reference = original_unit

		# Manually copy effects_perm reference and current stats
		battle_copy.effects_perm = original_unit.effects_perm
		battle_copy.current_attack = original_unit.current_attack
		battle_copy.current_health = original_unit.current_health

		duplicated_lineup[position] = battle_copy

		# Simple logging that won't crash the battle system
		if OS.is_debug_build():
			print(
				"Battle copy: pos=",
				position,
				" orig=",
				original_unit.current_attack,
				"/",
				original_unit.current_health,
				" copy=",
				battle_copy.current_attack,
				"/",
				battle_copy.current_health,
				" effects=",
				battle_copy.effects_perm.size()
			)

	return duplicated_lineup


static func find_combat_target(lineup: Dictionary[int, UnitData]) -> UnitData:
	for pos: int in lineup:
		return lineup[pos]
	return null


static func get_pos_for_unit(lineup: Dictionary[int, UnitData], unit: UnitData) -> int:
	for pos: int in lineup:
		if lineup[pos] == unit:
			return pos
	return NO_UNIT_FOUND


static func prepare_lineup_from_holder(lineup: Dictionary) -> Dictionary[int, UnitData]:
	return abstract_lineup(lineup)


static func abstract_lineup(lineup: Dictionary) -> Dictionary[int, UnitData]:
	var abs_lineup: Dictionary[int, UnitData] = {}
	for pos: int in lineup.keys():
		var card: Card = lineup[pos]
		var unit_data: UnitData = card.unit_info

		# Ensure UnitData has the current display stats from the card
		# This is critical for enhanced/modified cards to show correct stats in battle
		if card.base != null:
			# Read the actual displayed values from the UI labels
			var attack_label: Label = card.base.get_node("%label_attack")
			var health_label: Label = card.base.get_node("%label_health")

			if attack_label != null and attack_label.text != "":
				unit_data.current_attack = int(attack_label.text)
			if health_label != null and health_label.text != "":
				unit_data.current_health = int(health_label.text)

		# Log the sync for debugging
		Log.debug(
			"Battle copy sync",
			{
				"position": pos,
				"original_stats":
				str(unit_data.current_attack) + "/" + str(unit_data.current_health),
				"display_synced": "true"
			},
			[Log.TAG_BATTLE, Log.TAG_INITIALIZATION, Log.TAG_CARD]
		)

		abs_lineup[pos] = unit_data
	return abs_lineup
