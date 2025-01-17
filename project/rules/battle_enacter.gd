class_name BattleEnacter extends Node

var battle_layer
var holder_allies
var holder_enemy


func _init(_battle_layer, _holder_allies, _holder_enemy):
	battle_layer = _battle_layer
	holder_allies = _holder_allies
	holder_enemy = _holder_enemy


func enact(battle_events):
	printt("Start animating battle")
	printt("current battle events", battle_events)

	var back_tween
	var allies = holder_allies.get_current_lineup(true, battle_layer)
	var enemies = holder_enemy.get_current_lineup(true, battle_layer)
	holder_allies.hide_lineup()
	holder_enemy.hide_lineup()

	for event in battle_events:
		printt("current event:", event)
		if event is BattleContext.AddLineupEvent:
			print("Add lineup")
		elif event is BattleContext.FindNextUnitEvent:
			print("Find next unit")
		elif event is BattleContext.SelectActiveUnitEvent:
			print("Select active unit")
		elif event is BattleContext.CombatEvent:
			print("Combat")
			var attacker = (
				allies[event.attacker] if event.allied_attack else enemies[event.attacker]
			)
			var defender = (
				enemies[event.defender] if event.allied_attack else allies[event.defender]
			)
			printt("attacker", attacker)
			printt("defender", defender)
			var combat_tween = create_tween()

			var anim_speed = 0.2
			var attack_dist = 0.65
			var defence_dist = 0.25
			var highlight_size = Vector2(1.25, 1.25)
			var highlight_speed = 0.2
			var back_multiplier = 2
			var attacker_start_scale = attacker.scale
			var target_start_pos = defender.global_position
			var battle_pos = attacker.global_position.lerp(target_start_pos, attack_dist)
			var target_battle_pos = target_start_pos.lerp(battle_pos, defence_dist)
			var start_pos = attacker.global_position
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
			var u = allies[event.target] if event.side else enemies[event.target]
			printt("Damage target:", u, "Damage", event.damage_amount)
		elif event is BattleContext.ShieldEvent:
			print("Shield")
			var u = allies[event.target] if event.side else enemies[event.target]
			if event.new_shield_state:
				u.show_shield()
			else:
				u.hide_shield()
			print("shield removed / added on", u)

		elif event is BattleContext.StatChangeEvent:
			print("Stat Change", event)
			var unit_side = allies if event.side else enemies
			if !unit_side.has(event.target):
				continue
			if event.new_stat == 0:
				continue
			var u = unit_side[event.target]
			match event.stat:
				Battle.UNIT_HEALTH:
					u.base.set_card_health(event.new_stat)

		elif event is BattleContext.DeathEvent:
			print("Death")
			var side = allies if event.side else enemies
			var dying_u = side[event.pos]
			side.erase(event.pos)
			dying_u.shake(event.side)

		elif event is BattleContext.StartOfTurnEvent:
			await get_tree().create_timer(0.1).timeout
			print("start of turn")

		elif event is BattleContext.EndOfTurnEvent:
			print("end of turn")
			await back_tween.finished

	await get_tree().create_timer(1.25).timeout
	for side in [allies, enemies]:
		for k in side.keys():
			side[k].queue_free()
