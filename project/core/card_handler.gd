class_name CardHandler extends Node


func change_health(card: Card, health_amount: int) -> void:
	var current_health: int = card.unit_info.current_health
	var new_health: int = current_health + health_amount
	card.unit_info.current_health = new_health
	card.base.set_card_health(new_health)


func change_attack(card: Card, attack_amount: int) -> void:
	var current_attack: int = card.unit_info.current_attack
	var new_attack: int = current_attack + attack_amount
	card.unit_info.current_attack = new_attack
	card.base.set_card_attack(new_attack)
