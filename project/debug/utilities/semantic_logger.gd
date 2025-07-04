class_name SemanticLogger
extends RefCounted

# Enhanced semantic action logging with parameter capture
# Provides convenient methods for logging player actions with full parameter data


# Draft action logging
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


# Lineup action logging
static func log_lineup_move_card(card_id: String, from_position: int, to_position: int) -> void:
	"""Log lineup card move action with parameters"""
	var data: Dictionary = {
		"card_id": card_id, "from_position": from_position, "to_position": to_position
	}
	SessionManager.log_semantic_action("lineup.move_card", data)


static func log_lineup_add_card(
	card_id: String, target_position: int, source_position: Vector2i = Vector2i(-1, -1)
) -> void:
	"""Log lineup card addition action with parameters"""
	var data: Dictionary = {
		"card_id": card_id,
		"target_position": target_position,
		"source_position": {"x": source_position.x, "y": source_position.y}
	}
	SessionManager.log_semantic_action("lineup.add_card", data)


static func log_lineup_remove_card(card_id: String, position: int) -> void:
	"""Log lineup card removal action with parameters"""
	var data: Dictionary = {"card_id": card_id, "position": position}
	SessionManager.log_semantic_action("lineup.remove_card", data)


# State transition logging
static func log_state_transition(from_state: String, to_state: String) -> void:
	"""Log game state transition with parameters"""
	var data: Dictionary = {"from_state": from_state, "to_state": to_state}

	# Check if this transition should end current session
	if SessionManager.should_end_session_on_state_change(from_state, to_state):
		SessionManager.end_current_session("state_transition")
		# Start new session with transition context
		var context: Dictionary = {
			"triggered_by": "state_transition", "from": from_state, "to": to_state
		}
		SessionManager.start_new_session("state_transition", context)

	SessionManager.log_semantic_action("transition.change_state", data)


# Battle action logging
static func log_battle_start(player_lineup: Array = [], enemy_lineup: Array = []) -> void:
	"""Log battle start action with parameters"""
	var data: Dictionary = {
		"player_lineup_count": player_lineup.size(),
		"enemy_lineup_count": enemy_lineup.size(),
		"player_cards": _extract_card_ids(player_lineup),
		"enemy_cards": _extract_card_ids(enemy_lineup)
	}

	# Update session context for battle phase
	SessionManager.update_session_context("game_phase", "battle")
	SessionManager.update_session_context("battle_data", data)

	SessionManager.log_semantic_action("battle.start", data)


# Helper methods
static func _extract_card_ids(lineup: Array) -> Array[String]:
	"""Extract card IDs from lineup for logging"""
	var card_ids: Array[String] = []
	for card: Variant in lineup:
		if card and card.has_method("get_id"):
			var card_id_method: String = card.get_id()
			card_ids.append(card_id_method)
		elif card and card.has("id"):
			var card_id_prop: String = str(card.id)
			card_ids.append(card_id_prop)
		else:
			card_ids.append("unknown_card")
	return card_ids


# Session control methods
static func start_draft_session(level: int = 1) -> String:
	"""Start a new session for draft phase"""
	var context: Dictionary = SessionManager.create_draft_context(level)
	return SessionManager.start_new_session("draft_start", context)


static func start_battle_session(player_lineup: Array = [], enemy_lineup: Array = []) -> String:
	"""Start a new session for battle phase"""
	var context: Dictionary = SessionManager.create_battle_context(player_lineup, enemy_lineup)
	return SessionManager.start_new_session("battle_start", context)


static func end_current_session(reason: String = "manual") -> void:
	"""End current session"""
	SessionManager.end_current_session(reason)


# Integration helpers for existing game systems
static func log_action_with_automatic_session_management(
	action_type: String, data: Dictionary = {}
) -> void:
	"""Log semantic action with automatic session management"""
	# Check if action should start new session
	if SessionManager.should_start_new_session_on_action(action_type):
		var context: Dictionary = {"triggered_by": action_type}
		SessionManager.start_new_session("action_trigger", context)

	# Log the action
	SessionManager.log_semantic_action(action_type, data)


# Debug and validation helpers
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
	"""Validate that session is active and not expired"""
	return (
		not SessionManager.current_session_id.is_empty()
		and not SessionManager._is_session_expired()
	)
