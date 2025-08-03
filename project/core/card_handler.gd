class_name CardHandler extends Node


func change_health(card: Card, health_amount: int) -> void:
	var current_health_before: int = card.unit_info.current_health
	var new_health: int = current_health_before + health_amount

	Log.debug(
		"CARD HANDLER: Direct health change bypassing StatEffect system",
		{
			"card_id": card.card_info.id,
			"health_before": current_health_before,
			"health_change": health_amount,
			"health_after": new_health,
			"effects_perm_count": card.unit_info.effects_perm.size(),
			"bypass_warning": "This bypasses apply_permanent_effects_to_current_stats()"
		},
		[Log.TAG_CARD, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh", "bypass_warning"]
	)

	card.unit_info.current_health = new_health
	card.base.set_card_health(new_health)


func change_attack(card: Card, attack_amount: int) -> void:
	var current_attack_before: int = card.unit_info.current_attack
	var new_attack: int = current_attack_before + attack_amount

	Log.debug(
		"CARD HANDLER: Direct attack change bypassing StatEffect system",
		{
			"card_id": card.card_info.id,
			"attack_before": current_attack_before,
			"attack_change": attack_amount,
			"attack_after": new_attack,
			"effects_perm_count": card.unit_info.effects_perm.size(),
			"bypass_warning": "This bypasses apply_permanent_effects_to_current_stats()"
		},
		[Log.TAG_CARD, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh", "bypass_warning"]
	)

	card.unit_info.current_attack = new_attack
	card.base.set_card_attack(new_attack)
