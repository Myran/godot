extends Node
class_name battle_enacter
var battle_layer
var holder_allies
var holder_enemy

func _init(_battle_layer,_holder_allies,_holder_enemy):
	battle_layer = _battle_layer
	holder_allies = _holder_allies
	holder_enemy = _holder_enemy
	
func enact(battle_events):
	printt("Start animating battle")
	printt("current battle events",battle_events)
	
	var back_tween
	var allies = holder_allies.get_current_lineup(true,battle_layer)
	var enemies = holder_enemy.get_current_lineup(true,battle_layer)
	holder_allies.hide_lineup()
	holder_enemy.hide_lineup()
	
	for event in battle_events:
		printt("current event:",event)
		match event.type:
			battle.EVENT_TYPE.ADD_LINEUP:
				print("Add lineup")
			battle.EVENT_TYPE.FIND_NEXT_UNIT:
				print("Find next unit")
			battle.EVENT_TYPE.SELECT_ACTIVE_UNIT:
				print("Select active unit")
			battle.EVENT_TYPE.COMBAT:
				print("Combat")
				var attacker = allies[event.attacker] if event.allied_attack else enemies[event.attacker]
				var defender = enemies[event.defender] if event.allied_attack else allies[event.defender]
				printt("attacker",attacker)
				printt("defender",defender)
				var combat_tween = create_tween()
				#combat_tween.set_parallel(false)
				var anim_speed = 0.2
				var attack_dist = 0.65
				var defence_dist = 0.25
				var highlight_size = Vector2(1.25,1.25)
				var highlight_speed = 0.2
				var back_multiplier = 2
				var attacker_start_scale = attacker.scale
				var target_start_pos = defender.global_position
				var battle_pos = attacker.global_position.lerp(target_start_pos,attack_dist)
				var target_battle_pos = target_start_pos.lerp(battle_pos,defence_dist)
				var start_pos = attacker.global_position
				combat_tween.tween_property(defender,"scale",highlight_size,highlight_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				combat_tween.parallel().tween_property(attacker,"scale",highlight_size,highlight_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				combat_tween.tween_property(defender,"global_position",target_battle_pos,anim_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
				combat_tween.tween_property(attacker,"global_position",battle_pos,anim_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
				combat_tween.play()
				await combat_tween.finished

				back_tween = create_tween()
				back_tween.chain().tween_property(attacker,"global_position",start_pos,anim_speed*back_multiplier).set_trans(Tween.TRANS_QUINT)
				back_tween.parallel().tween_property(defender,"global_position",target_start_pos,anim_speed*back_multiplier).set_trans(Tween.TRANS_QUINT)
				back_tween.chain().tween_property(attacker,"scale",attacker_start_scale,highlight_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				back_tween.parallel().tween_property(defender,"scale",attacker_start_scale,highlight_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				back_tween.play()


			battle.EVENT_TYPE.DAMAGE:
				print("Damage",event)
				var u = allies[event.target] if event.side else enemies[event.target]
				printt("Damage target:",u,"Damage",event.damage_amount)


			battle.EVENT_TYPE.STAT_CHANGE:
				print("Stat Change",event)
				if !event.has("new_stat"): continue
				var unit_side = allies if event.side else enemies
				if !unit_side.has(event.target): continue
				var u = unit_side[event.target]
				match event.stat:
					"current_health":
						u.card_base.set_card_health(event.new_stat)

			battle.EVENT_TYPE.DEATH:
				print("Death")
				var side = allies if event.side else enemies
				var dying_u = side[event.pos]
				side.erase(event.pos)
				dying_u.shake(event.side)
			battle.EVENT_TYPE.START_OF_TURN:
				await get_tree().create_timer(0.1).timeout
				print("start of turn")
				pass
			battle.EVENT_TYPE.END_OF_TURN:
				print("end of turn")
				await back_tween.finished
	await get_tree().create_timer(1.25).timeout
	for side in [allies,enemies]:
		for k in side.keys():
			side[k].queue_free()
	core.emit_signal("event",core.EVENT_TYPE.GAME_STATE_TRANSITION,[core.GAME_STATE.POSTBATTLE])
