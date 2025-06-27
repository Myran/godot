class_name RecordingCaptureAction
extends CaptureActionBase

# Capture action for recording system state validation
# Captures recording metadata and validates recording integrity


func capture_data() -> Dictionary:
	if not ActionRecorder:
		Log.error(
			"ActionRecorder singleton not available", {}, ["debug", "recording", "capture", "error"]
		)
		return {}

	var game: Game = _get_game_node()
	var recording_stats: Dictionary = ActionRecorder.get_recording_stats()
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	# Get capture configuration from test config
	var capture_config: Dictionary = _get_capture_config()
	var recording_data: Dictionary = {}

	# Capture game state based on configuration
	if game:
		# Capture lineup data if enabled
		if capture_config.get("capture_lineup", true):
			var allies_lineup: Dictionary = game.holder_allies.get_current_lineup()
			var enemy_lineup: Dictionary = game.holder_enemy.get_current_lineup()
			recording_data["allies_lineup"] = extract_lineup_data(allies_lineup)
			recording_data["enemy_lineup"] = extract_lineup_data(enemy_lineup)

		# Capture clicker state if enabled
		if capture_config.get("capture_clicker", false):
			recording_data["clicker_state"] = _capture_clicker_state(game)

		# Capture recording metadata if enabled
		if capture_config.get("capture_recording_meta", false):
			recording_data["recording_meta"] = {
				"total_actions": recording_stats.get("total_actions", 0),
				"current_sequence": recording_stats.get("current_sequence", 0),
				"is_recording": ActionRecorder.is_recording,
				"is_replaying": ActionRecorder.is_replaying
			}

		# Capture RNG state if enabled
		if capture_config.get("capture_rng", false):
			recording_data["rng_state"] = {
				"initial_seed": _get_current_rng_seed(), "available": _check_rng_availability()
			}
	else:
		Log.warning(
			"Game node not found - cannot capture game state",
			{},
			["debug", "recording", "capture", "warning"]
		)
		# Initialize empty state based on configuration
		if capture_config.get("capture_lineup", true):
			recording_data["allies_lineup"] = {}
			recording_data["enemy_lineup"] = {}
		if capture_config.get("capture_clicker", false):
			recording_data["clicker_state"] = {}

	# Log essential recording state capture
	var capture_summary: Array[String] = []
	if recording_data.has("allies_lineup"):
		capture_summary.append("lineup")
	if recording_data.has("clicker_state"):
		capture_summary.append("clicker")
	if recording_data.has("recording_meta"):
		capture_summary.append("recording_meta")
	if recording_data.has("rng_state"):
		capture_summary.append("rng")

	Log.info(
		"Recording state captured",
		{
			"has_game_state": game != null,
			"data_size": JSON.stringify(recording_data).length(),
			"capture_types": capture_summary,
			"allies_count": recording_data.get("allies_lineup", {}).size(),
			"enemy_count": recording_data.get("enemy_lineup", {}).size(),
			"clicker_available": recording_data.has("clicker_state")
		},
		["debug", "recording", "capture"]
	)

	return recording_data


func get_state_type() -> String:
	return "recording_state"


func extract_lineup_data(lineup: Dictionary) -> Dictionary:
	var lineup_data: Dictionary = {}

	# Use existing DictUtils for deterministic iteration
	for item: Dictionary in DictUtils.get_sorted_items(lineup):
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
	if not root:
		Log.error("No current scene available", {}, ["debug", "recording", "error"])
		return null

	var game_node: Node = root.find_child("Game", true, false)
	if not game_node:
		Log.warning("Game node not found in scene", {}, ["debug", "recording", "warning"])
		return null

	if not game_node is Game:
		Log.error(
			"Found node 'Game' but it's not a Game instance",
			{"node_type": game_node.get_class()},
			["debug", "recording", "error"]
		)
		return null

	return game_node


func _get_capture_config() -> Dictionary:
	# Get capture configuration from external config file
	var config_file_path: String = "user://debug_startup_actions.json"
	var file: FileAccess = FileAccess.open(config_file_path, FileAccess.READ)
	var recording_config: Dictionary = {}

	if file:
		var json_text: String = file.get_as_text()
		file.close()

		var json: JSON = JSON.new()
		var parse_result: Error = json.parse(json_text)

		if parse_result == OK:
			if not json.data is Dictionary:
				Log.error(
					"JSON data is not a Dictionary",
					{"type": typeof(json.data)},
					["debug", "recording", "config", "error"]
				)
				return {}
			var config_data: Dictionary = json.data
			recording_config = config_data.get("recording_config", {})

	# Log configuration for debugging
	Log.debug(
		"Capture configuration loaded",
		{
			"capture_lineup": recording_config.get("capture_lineup", true),
			"capture_clicker": recording_config.get("capture_clicker", false),
			"capture_recording_meta": recording_config.get("capture_recording_meta", false),
			"capture_rng": recording_config.get("capture_rng", false),
			"config_file_exists": file != null,
			"raw_recording_config": recording_config
		},
		["debug", "recording", "config"]
	)

	# Return capture configuration with defaults
	return {
		"capture_lineup": recording_config.get("capture_lineup", true),
		"capture_clicker": recording_config.get("capture_clicker", false),
		"capture_recording_meta": recording_config.get("capture_recording_meta", false),
		"capture_rng": recording_config.get("capture_rng", false)
	}


func _get_current_rng_seed() -> int:
	if rng and rng.seeded_rng:
		return rng.seeded_rng._initial_seed
	else:
		return -1


func _capture_clicker_state(game: Game) -> Dictionary:
	# Capture complete clicker state using var2str for deterministic serialization
	var clicker_state: Dictionary = {}

	# Get clicker directly from game
	if game.clicker:
		# Use var2str to capture the complete clicker state deterministically
		# This includes all properties, block grid, and nested state
		var clicker_serialized: String = var_to_str(game.clicker)

		# Store as both serialized string and parsed subset for debugging
		clicker_state = {
			"clicker_var2str": clicker_serialized,
			"level_name": game.clicker.level.current_level_name if game.clicker.level else "",
			"block_count":
			(
				game.clicker.level.block_grid.size()
				if game.clicker.level and game.clicker.level.block_grid
				else 0
			),
			"refill_counter_size":
			game.clicker.refill_counter.size() if game.clicker.refill_counter else 0,
			"columns_locked_size":
			game.clicker.columns_locked.size() if game.clicker.columns_locked else 0
		}

		Log.info(
			"Clicker state captured with var2str",
			{
				"serialized_length": clicker_serialized.length(),
				"level_name": clicker_state.level_name,
				"block_count": clicker_state.block_count
			},
			["debug", "recording", "capture", "clicker"]
		)
	else:
		Log.warning("Clicker not found in game", {}, ["debug", "recording", "capture", "warning"])
		clicker_state = {"clicker_var2str": "", "error": "clicker_not_found"}

	return clicker_state


func _check_rng_availability() -> bool:
	# Check if RNG singleton is properly available
	return rng != null and rng.seeded_rng != null


# Override the restart trigger for recording system
func _should_trigger_restart() -> bool:
	# For recording system, we might not always want to restart
	# Only restart if we're capturing for checksum validation
	var current_test_id: String = DebugAction.get_current_test_id()
	return current_test_id.contains("checksum") or current_test_id.contains("recording")
