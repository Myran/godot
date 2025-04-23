class_name BattleHandler extends Node

var holder_allies: HolderContainer
var holder_enemy: HolderContainer


func setup(_allies: HolderContainer, _enemies: HolderContainer) -> void:
	holder_allies = _allies
	holder_enemy = _enemies


func create_battle() -> Array[Context.Event]:
	var allies: Dictionary[int, Card] = holder_allies.get_current_lineup()
	var enemies: Dictionary[int, Card] = holder_enemy.get_current_lineup()

	var battle_instance: Battle = Battle.new()
	var prep_allies: Dictionary = Battle.prepare_lineup_from_holder(allies)
	var prep_enemies: Dictionary = Battle.prepare_lineup_from_holder(enemies)
	return battle_instance.battle_start(prep_allies, prep_enemies)
