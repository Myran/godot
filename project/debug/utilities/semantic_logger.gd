class_name SemanticLogger
extends RefCounted


static func log_draft_reroll(
	cost: int = 0, previous_cards: Array = [], seed_before: int = -1
) -> void:
	"""Log draft reroll action with parameters"""
	var data: Dictionary = {
		"cost": cost, "previous_cards": previous_cards, "seed_before": seed_before
	}
	SessionManager.log_semantic_action("draft.reroll", data)


static func log_draft_upgrade(level: int, cost: int = 0, target_card: String = "") -> void:
	"""Log draft upgrade action with parameters"""
	var data: Dictionary = {"level": level, "cost": cost, "target_card": target_card}
	SessionManager.log_semantic_action("draft.upgrade", data)


static func log_draft_toggle_line(column_index: int, new_state: bool) -> void:
	"""Log draft line toggle action with parameters"""
	var data: Dictionary = {"column_index": column_index, "new_state": new_state}
	SessionManager.log_semantic_action("draft.toggle_line", data)


static func log_draft_remove_card(card_id: String, position: Vector2i = Vector2i(-1, -1)) -> void:
	"""Log draft card removal action with parameters"""
	var data: Dictionary = {"card_id": card_id, "position": {"x": position.x, "y": position.y}}
	SessionManager.log_semantic_action("draft.remove_card", data)


static func log_lineup_move_card(card_id: String, from_position: int, to_position: int) -> void:
	"""Log lineup card move action with parameters"""
	var data: Dictionary = {
		"card_id": card_id, "from_position": from_position, "to_position": to_position
	}
	SessionManager.log_semantic_action("lineup.move_card", data)


static func log_draft_to_lineup_move(
	card_id: String, from_position: Vector2i, to_position: int
) -> void:
	"""Log complete draft-to-lineup move operation with atomic semantics"""
	var data: Dictionary = {
		"card_id": card_id,
		"from_position": {"x": from_position.x, "y": from_position.y},
		"to_position": to_position,
		"move_type": "draft_to_lineup"
	}
	SessionManager.log_semantic_action("card.move", data)


static func log_state_transition(from_state: String, to_state: String) -> void:
	"""Log game state transition with parameters"""
	var data: Dictionary = {"from_state": from_state, "to_state": to_state}

	SessionManager.update_session_context("current_state", to_state)
	SessionManager.update_session_context("last_transition", from_state + "_to_" + to_state)

	SessionManager.log_semantic_action("transition.change_state", data)


static func log_battle_start(player_lineup: Array = [], enemy_lineup: Array = []) -> void:
	"""Log battle start action with parameters"""

	var player_cards_typed: Array[Card] = []
	player_cards_typed.assign(player_lineup)
	var enemy_cards_typed: Array[Card] = []
	enemy_cards_typed.assign(enemy_lineup)

	var data: Dictionary = {
		"player_lineup_count": player_lineup.size(),
		"enemy_lineup_count": enemy_lineup.size(),
		"player_cards": _extract_card_ids(player_cards_typed),
		"enemy_cards": _extract_card_ids(enemy_cards_typed)
	}

	SessionManager.update_session_context("game_phase", "battle")
	SessionManager.update_session_context("battle_data", data)

	SessionManager.log_semantic_action("battle.start", data)


static func _extract_card_ids(lineup: Array[Card]) -> Array[String]:
	"""Extract card IDs from lineup for logging"""
	var card_ids: Array[String] = []
	for card: Card in lineup:
		if card and card.card_definition:
			var card_id: String = card.card_definition.id
			card_ids.append(card_id if card_id != "" else "unknown_card")
		else:
			card_ids.append("unknown_card")
	return card_ids


static func start_gameplay_session() -> String:
	"""Start a new full gameplay session"""
	return SessionManager.start_gameplay_session()


static func end_gameplay_session() -> void:
	"""End current gameplay session"""
	SessionManager.end_gameplay_session()


static func log_action(action_type: String, data: Dictionary = {}) -> void:
	"""Log semantic action to current session"""
	SessionManager.log_semantic_action(action_type, data)


static func get_current_session_info() -> Dictionary:
	"""Get current session information for debugging"""
	return {
		"session_id": SessionManager.get_current_session_id(),
		"action_count": SessionManager.session_action_count,
		"context": SessionManager.get_session_context(),
		"elapsed_ms":
		(Time.get_unix_time_from_system() * 1000.0) - SessionManager.session_start_time
	}


static func validate_session_active() -> bool:
	"""Validate that session is active"""
	return not SessionManager.current_session_id.is_empty()
