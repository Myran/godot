class_name BattleEnacter extends Node

var battle_layer: Node
var allied_holder: HolderContainer
var enemy_holder: HolderContainer


func _init(layer: Node, allies: HolderContainer, enemies: HolderContainer) -> void:
	battle_layer = layer
	allied_holder = allies
	enemy_holder = enemies


func enact(battle_events: Array[Context.Event]) -> void:
	printt("Start animating battle")
	printt("current battle events", battle_events)

	var return_tween: Tween
	var allied_units: Dictionary = allied_holder.get_current_lineup(true, battle_layer)
	var enemy_units: Dictionary = enemy_holder.get_current_lineup(true, battle_layer)
	allied_holder.hide_lineup()
	enemy_holder.hide_lineup()

	for event: Context.Event in battle_events:
		printt("current event:", event)

		if event is BattleContext.AddLineupEvent:
			print("Add lineup")

		elif event is BattleContext.FindNextUnitEvent:
			print("Find next unit")

		elif event is BattleContext.SelectActiveUnitEvent:
			print("Select active unit")

		elif event is BattleContext.CombatEvent:
			print("Combat")
			var attacker: Node2D = (
				allied_units[event.attacker_position]
				if event.is_allied_attack
				else enemy_units[event.attacker_position]
			)
			var defender: Node2D = (
				enemy_units[event.defender_position]
				if event.is_allied_attack
				else allied_units[event.defender_position]
			)
			printt("attacker", attacker)
			printt("defender", defender)

			var combat_tween: Tween = create_tween()

			# Animation timing configuration
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

			# Highlight animation
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

			# Movement animation
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

			# Return animation
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
			print("Damage", event)
			var target: Node2D = (
				allied_units[event.target_position]
				if event.is_allied_side
				else enemy_units[event.target_position]
			)
			printt("Damage target:", target, "Damage", event.damage_amount)

		elif event is BattleContext.ShieldEvent:
			print("Shield")
			var target: Node2D = (
				allied_units[event.target_position]
				if event.is_allied_side
				else enemy_units[event.target_position]
			)
			if event.shield_active:
				target.show_shield()
			else:
				target.hide_shield()
			print("shield removed / added on", target)

		elif event is BattleContext.StatChangeEvent:
			print("Stat Change", event)
			var unit_side: Dictionary = allied_units if event.is_allied_side else enemy_units
			if !unit_side.has(event.target_position):
				continue
			if event.new_stat_value == 0:
				continue

			var target: Node2D = unit_side[event.target_position]
			match event.stat_name:
				Battle.UNIT_HEALTH:
					target.base.set_card_health(event.new_stat_value)

		elif event is BattleContext.DeathEvent:
			print("Death")
			var side: Dictionary = allied_units if event.is_allied_side else enemy_units
			var target: Node2D = side[event.unit_position]
			side.erase(event.unit_position)
			target.shake(event.is_allied_side)

		elif event is BattleContext.StartOfTurnEvent:
			await get_tree().create_timer(0.1).timeout
			print("start of turn")

		elif event is BattleContext.EndOfTurnEvent:
			print("end of turn")
			await return_tween.finished

	# Cleanup phase
	await get_tree().create_timer(1.25).timeout
	for side: Dictionary in [allied_units, enemy_units]:
		for pos: int in side.keys():
			var unit: Node2D = side[pos]
			unit.queue_free()
