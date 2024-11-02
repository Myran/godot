class_name CardHandler extends Node


func change_health(card, health_amount):
	var current_health = card.unit_info.current_health
	var new_health = current_health + health_amount
	card.unit_info.current_health = new_health
	card.card_base.set_card_health(new_health)


func change_attack(card, attack_amount):
	var current_attack = card.unit_info.current_attack
	var new_attack = current_attack + attack_amount
	card.unit_info.current_attack = new_attack
	card.card_base.set_card_attack(new_attack)
