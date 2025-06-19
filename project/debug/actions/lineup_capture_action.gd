class_name LineupCaptureAction
extends CaptureActionBase


func capture_data() -> Dictionary:
	var game: Game = _get_game_node()
	if not game:
		return {}

	# Use existing lineup functions to get current state
	var allies_lineup: Dictionary = game.holder_allies.get_current_lineup()
	var enemy_lineup: Dictionary = game.holder_enemy.get_current_lineup()

	return {
		"allies": extract_lineup_data(allies_lineup), "enemy": extract_lineup_data(enemy_lineup)
	}


func get_state_type() -> String:
	return "lineup_state"


func extract_lineup_data(lineup: Dictionary) -> Dictionary:
	var lineup_data: Dictionary = {}

	# Use existing DictUtils for deterministic iteration
	for item: Dictionary in DictUtils.get_sorted_items(lineup as Dictionary):
		var position: int = item.key
		var card: Card = item.value

		if card:
			lineup_data[position] = {
				"card_id": card.card_info.id,
				"level": card.level,
				"health": card.unit_info.current_health,
				"attack": card.unit_info.current_attack
			}

	return lineup_data


func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		return root.find_child("Game", true, false) as Game
	return null
