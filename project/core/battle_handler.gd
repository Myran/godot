class_name BattleHandler extends Node
var holder_allies
var holder_enemy


func setup(_allies, _enemies) -> void:
	holder_allies = _allies
	holder_enemy = _enemies


func create_battle():
	var allies = holder_allies.get_current_lineup()
	var enemies = holder_enemy.get_current_lineup()

	var battle_instance = Battle.new()
	var prep_allies = Battle.prepare_lineup_from_holder(allies)
	var prep_enemies = Battle.prepare_lineup_from_holder(enemies)
	return battle_instance.battle_start(prep_allies, prep_enemies)
