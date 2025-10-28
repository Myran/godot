class_name BattleEnacter extends Node

var battle_layer: Node
var allied_holder: HolderContainer
var enemy_holder: HolderContainer


func _init(layer: Node, allies: HolderContainer, enemies: HolderContainer) -> void:
	battle_layer = layer
	allied_holder = allies
	enemy_holder = enemies


func enact(battle_events: Array[Context.Event], battle_result: Battle.BattleResult = null) -> void:
	Log.info(
		"Starting battle animation sequence",
		{
			"event_count": battle_events.size(),
			"battle_result_provided": battle_result != null,
			"battle_result_type": str(type_string(typeof(battle_result)))
		},
		[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_INITIALIZATION]
	)
	Log.debug(
		"Battle events to animate", {"events": battle_events}, [Log.TAG_BATTLE, Log.TAG_ANIMATION]
	)

	var return_tween: Tween
	var allied_units: Dictionary[int, Card] = allied_holder.get_reenactment_lineup(battle_layer)
	var enemy_units: Dictionary[int, Card] = enemy_holder.get_reenactment_lineup(battle_layer)

	allied_holder.hide_lineup()
	enemy_holder.hide_lineup()

	for event: Context.Event in battle_events:
		Log.debug(
			"Processing battle event",
			{"event_type": Utils.get_type(event)},
			[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_STATE_TRANSITION]
		)

		if event is BattleContext.AddLineupEvent:
			Log.debug(
				"Adding lineup to battle",
				{"allied": event.is_allied_side},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_INITIALIZATION]
			)

		elif event is BattleContext.FindNextUnitEvent:
			Log.debug(
				"Finding next active unit", {}, [Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_COMBAT]
			)

		elif event is BattleContext.SelectActiveUnitEvent:
			Log.debug(
				"Selected active unit",
				{"position": event.selected_unit_position, "allied": event.is_allied_side},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_COMBAT, Log.TAG_STATE_TRANSITION]
			)

		elif event is BattleContext.CombatEvent:
			Log.debug(
				"Combat event",
				{
					"attacker_position": event.attacker_position,
					"defender_position": event.defender_position,
					"allied_attack": event.is_allied_attack
				},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ANIMATION, Log.TAG_STATE_TRANSITION]
			)
			var attacker: Card
			if event.is_allied_attack:
				attacker = allied_units[event.attacker_position]
			else:
				attacker = enemy_units[event.attacker_position]

			var defender: Card
			if event.is_allied_attack:
				defender = enemy_units[event.defender_position]
			else:
				defender = allied_units[event.defender_position]
			var attacker_name: String = "unknown"
			var defender_name: String = "unknown"

			if attacker != null:
				attacker_name = attacker.get_card_name()
			if defender != null:
				defender_name = defender.get_card_name()

			Log.debug(
				"Combat participants",
				{"attacker": attacker_name, "defender": defender_name},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ANIMATION, Log.TAG_CARD]
			)

			var combat_tween: Tween = create_tween()

			var anim_speed: float = 0.2
			var attack_distance: float = 0.65
			var defense_distance: float = 0.25
			var highlight_scale: Vector2 = Vector2(1.25, 1.25)
			var highlight_speed: float = 0.2
			var return_multiplier: float = 2.0

			var attacker_start_scale: Vector2 = attacker.scale
			var defender_start_pos: Vector2 = defender.global_position
			var battle_pos: Vector2 = attacker.global_position.lerp(
				defender_start_pos, attack_distance
			)
			var defender_battle_pos: Vector2 = defender_start_pos.lerp(battle_pos, defense_distance)
			var attacker_start_pos: Vector2 = attacker.global_position

			(
				combat_tween
				. tween_property(defender, "scale", highlight_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)

			(
				combat_tween
				. parallel()
				. tween_property(attacker, "scale", highlight_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)

			(
				combat_tween
				. tween_property(defender, "global_position", defender_battle_pos, anim_speed)
				. set_trans(Tween.TRANS_QUINT)
				. set_ease(Tween.EASE_IN)
			)

			(
				combat_tween
				. tween_property(attacker, "global_position", battle_pos, anim_speed)
				. set_trans(Tween.TRANS_QUINT)
				. set_ease(Tween.EASE_OUT)
			)

			combat_tween.play()
			await combat_tween.finished

			return_tween = create_tween()
			var return_speed: float = anim_speed * return_multiplier

			(
				return_tween
				. chain()
				. tween_property(attacker, "global_position", attacker_start_pos, return_speed)
				. set_trans(Tween.TRANS_QUINT)
			)

			(
				return_tween
				. parallel()
				. tween_property(defender, "global_position", defender_start_pos, return_speed)
				. set_trans(Tween.TRANS_QUINT)
			)

			(
				return_tween
				. chain()
				. tween_property(attacker, "scale", attacker_start_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)

			(
				return_tween
				. parallel()
				. tween_property(defender, "scale", attacker_start_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)

			return_tween.play()

		elif event is BattleContext.DamageEvent:
			Log.debug(
				"Damage event",
				{
					"target_position": event.target_position,
					"damage_amount": event.damage_amount,
					"allied_side": event.is_allied_side
				},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ANIMATION]
			)
			var target: Card
			if event.is_allied_side:
				target = allied_units[event.target_position]
			else:
				target = enemy_units[event.target_position]
			var target_name: String = "unknown"
			if target != null:
				target_name = target.get_card_name()

			Log.debug(
				"Applying damage to target",
				{"target": target_name, "damage": event.damage_amount},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ANIMATION, Log.TAG_CARD]
			)

		elif event is BattleContext.ShieldEvent:
			Log.debug(
				"Shield event",
				{
					"target_position": event.target_position,
					"shield_active": event.shield_active,
					"allied_side": event.is_allied_side
				},
				[Log.TAG_BATTLE, Log.TAG_COMBAT, Log.TAG_ANIMATION]
			)
			var target: Card
			if event.is_allied_side:
				target = allied_units[event.target_position]
			else:
				target = enemy_units[event.target_position]
			if event.shield_active:
				target.show_shield()
			else:
				target.hide_shield()
			var target_name: String = "unknown"
			if target != null:
				target_name = target.get_card_name()

			Log.debug(
				"Shield status changed",
				{"target": target_name, "shield_active": event.shield_active},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_COMBAT, Log.TAG_CARD]
			)

		elif event is BattleContext.StatChangeEvent:
			Log.debug(
				"Stat change event",
				{
					"stat": event.stat_name,
					"target_position": event.target_position,
					"new_value": event.new_stat_value,
					"allied_side": event.is_allied_side
				},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_STAT, Log.TAG_COMBAT]
			)
			var unit_side: Dictionary[int, Card]
			if event.is_allied_side:
				unit_side = allied_units
			else:
				unit_side = enemy_units
			if !unit_side.has(event.target_position):
				continue
			if event.new_stat_value == 0:
				continue

			var target: Card = unit_side[event.target_position]
			match event.stat_name:
				Battle.UNIT_HEALTH:
					var health_value: int = event.new_stat_value
					target.base.set_card_health(health_value)
				Battle.UNIT_ATTACK:
					var attack_value: int = event.new_stat_value
					target.base.set_card_attack(attack_value)

		elif event is BattleContext.DeathEvent:
			Log.debug(
				"Death event",
				{"unit_position": event.unit_position, "allied_side": event.is_allied_side},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_COMBAT]
			)
			var side: Dictionary[int, Card]
			if event.is_allied_side:
				side = allied_units
			else:
				side = enemy_units
			var target: Card = side[event.unit_position]
			side.erase(event.unit_position)
			var is_allied: bool = event.is_allied_side
			target.shake(is_allied)

		elif event is BattleContext.StartOfTurnEvent:
			Log.debug(
				"Start of turn event",
				{},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_STATE_TRANSITION, Log.TAG_COMBAT]
			)

		elif event is BattleContext.EndOfTurnEvent:
			Log.debug(
				"End of turn event",
				{},
				[Log.TAG_BATTLE, Log.TAG_ANIMATION, Log.TAG_STATE_TRANSITION, Log.TAG_COMBAT]
			)
			await return_tween.finished

	await get_tree().create_timer(GameConstants.NetworkTiming.BATTLE_SEQUENCE_DELAY_SEC).timeout
	for side: Dictionary[int, Card] in [allied_units, enemy_units]:
		var positions: Array[int] = DictUtils.keys_typed_sorted(side, TYPE_INT)
		for pos: int in positions:
			var unit: Card = side[pos]
			unit.queue_free()
