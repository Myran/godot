class_name BattleEnacter extends Node

var battle_layer: Node
var holder_allies: Node
var holder_enemy: Node


func _init(_battle_layer: Node, _holder_allies: Node, _holder_enemy: Node) -> void:
	battle_layer = _battle_layer
	holder_allies = _holder_allies
	holder_enemy = _holder_enemy


func enact(battle_events: Array) -> void:
	printt("Start animating battle")
	printt("current battle events", battle_events)

	var back_tween: Tween
	var allies: Dictionary = holder_allies.get_current_lineup(true, battle_layer)
	var enemies: Dictionary = holder_enemy.get_current_lineup(true, battle_layer)
	holder_allies.hide_lineup()
	holder_enemy.hide_lineup()

	for event: BattleContext.BaseEvent in battle_events:
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
				allies[event.attacker] if event.allied_attack else enemies[event.attacker]
			)
			var defender: Node2D = (
				enemies[event.defender] if event.allied_attack else allies[event.defender]
			)
			printt("attacker", attacker)
			printt("defender", defender)
			var combat_tween: Tween = create_tween()

			var anim_speed: float = 0.2
			var attack_dist: float = 0.65
			var defence_dist: float = 0.25
			var highlight_size: Vector2 = Vector2(1.25, 1.25)
			var highlight_speed: float = 0.2
			var back_multiplier: int = 2
			var attacker_start_scale: Vector2 = attacker.scale
			var target_start_pos: Vector2 = defender.global_position
			var battle_pos: Vector2 = attacker.global_position.lerp(target_start_pos, attack_dist)
			var target_battle_pos: Vector2 = target_start_pos.lerp(battle_pos, defence_dist)
			var start_pos: Vector2 = attacker.global_position
			(
				combat_tween
				. tween_property(defender, "scale", highlight_size, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			(
				combat_tween
				. parallel()
				. tween_property(attacker, "scale", highlight_size, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)

			(
				combat_tween
				. tween_property(defender, "global_position", target_battle_pos, anim_speed)
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

			back_tween = create_tween()
			(
				back_tween
				. chain()
				. tween_property(
					attacker, "global_position", start_pos, anim_speed * back_multiplier
				)
				. set_trans(Tween.TRANS_QUINT)
			)
			(
				back_tween
				. parallel()
				. tween_property(
					defender, "global_position", target_start_pos, anim_speed * back_multiplier
				)
				. set_trans(Tween.TRANS_QUINT)
			)
			(
				back_tween
				. chain()
				. tween_property(attacker, "scale", attacker_start_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			(
				back_tween
				. parallel()
				. tween_property(defender, "scale", attacker_start_scale, highlight_speed)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			back_tween.play()

		elif event is BattleContext.DamageEvent:
			print("Damage", event)
			var u: Node2D = allies[event.target] if event.side else enemies[event.target]
			printt("Damage target:", u, "Damage", event.damage_amount)
		elif event is BattleContext.ShieldEvent:
			print("Shield")
			var u: Node2D = allies[event.target] if event.side else enemies[event.target]
			if event.new_shield_state:
				u.show_shield()
			else:
				u.hide_shield()
			print("shield removed / added on", u)

		elif event is BattleContext.StatChangeEvent:
			print("Stat Change", event)
			var unit_side: Dictionary = allies if event.side else enemies
			if !unit_side.has(event.target):
				continue
			if event.new_stat == 0:
				continue
			var u: Node2D = unit_side[event.target]
			match event.stat:
				Battle.UNIT_HEALTH:
					u.base.set_card_health(event.new_stat)

		elif event is BattleContext.DeathEvent:
			print("Death")
			var side: Dictionary = allies if event.side else enemies
			var dying_u: Node2D = side[event.pos]
			side.erase(event.pos)
			dying_u.shake(event.side)

		elif event is BattleContext.StartOfTurnEvent:
			await get_tree().create_timer(0.1).timeout
			print("start of turn")

		elif event is BattleContext.EndOfTurnEvent:
			print("end of turn")
			await back_tween.finished

	await get_tree().create_timer(1.25).timeout
	for side: Dictionary in [allies, enemies]:
		for k: int in side.keys():
			side[k].queue_free()
