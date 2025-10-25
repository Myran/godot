class_name LoadEnemyLineupAction extends DebugAction

var _file_path: String = ""


func _init(file_path: String = "") -> void:
	_file_path = file_path
	super("system.debug.load_enemy_lineup", _execute_load_enemy_lineup)
	set_category("System")
	set_group("Lineup")
	set_description("Load saved lineup into enemy positions for battle testing")
	use_auto_semantic_logging = false


func _execute_load_enemy_lineup(params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	# Use provided file path or get from params
	var actual_file_path: String = _file_path
	if params.has("file") and not params["file"].is_empty():
		var filename: String = params["file"]
		actual_file_path = DebugConfigReader.get_saved_state_path(filename)

	if actual_file_path.is_empty():
		return DebugActionResult.new_failure("No lineup file path provided")

	Log.info(
		"Loading enemy lineup for testing",
		{"file_path": actual_file_path},
		[Log.TAG_DEBUG, "lineup", "enemy", "load"]
	)

	# Read and validate lineup file
	var lineup_data: Dictionary = _load_lineup_file(actual_file_path)
	if lineup_data.is_empty():
		return DebugActionResult.new_failure("Failed to load lineup file: " + actual_file_path)

	# Get game instance for surgical replacement
	var game_instance: Game = _get_game_instance()
	if not game_instance:
		return DebugActionResult.new_failure("Game instance not found")

	# Perform surgical enemy lineup replacement
	var replacement_success: bool = await _replace_enemy_lineup_surgical(game_instance, lineup_data)
	if not replacement_success:
		return DebugActionResult.new_failure("Failed to replace enemy lineup")

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Enemy lineup loaded successfully via surgical replacement",
		{
			"file": actual_file_path.get_file(),
			"units_loaded": _get_enemy_unit_count(lineup_data),
			"duration_ms": duration,
			"replacement_method": "surgical_enemy_only"
		},
		[Log.TAG_DEBUG, "lineup", "enemy", "load"]
	)

	return DebugActionResult.new_success(
		{
			"message": "Enemy lineup replaced successfully",
			"lineup_file": actual_file_path.get_file(),
			"units_loaded": _get_enemy_unit_count(lineup_data),
			"replacement_method": "surgical_enemy_only"
		},
		duration
	)


func _load_lineup_file(file_path: String) -> Dictionary:
	"""Load and validate lineup data from file"""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot open lineup file",
			{"file_path": file_path},
			[Log.TAG_DEBUG, "lineup", "load", "error"]
		)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		Log.error(
			"Failed to parse lineup JSON",
			{"file_path": file_path, "error": parse_result},
			[Log.TAG_DEBUG, "lineup", "load", "error"]
		)
		return {}

	var file_data: Dictionary = json.data

	# Handle both lineup-specific saves and full gamestate saves
	if file_data.has("lineup_data"):
		# This is a lineup-specific save
		return file_data.lineup_data

	if file_data.has("gamestate"):
		# This is a full gamestate save, extract lineup data
		var gamestate: Dictionary = file_data.gamestate
		return gamestate.get("lineup", {})

	Log.error(
		"Invalid lineup file format - no lineup data found",
		{"file_path": file_path},
		[Log.TAG_DEBUG, "lineup", "load", "error"]
	)
	return {}


func _replace_enemy_lineup_surgical(game: Game, lineup_data: Dictionary) -> bool:
	"""Surgically replace only the enemy lineup without affecting other game state"""
	Log.info(
		"Performing surgical enemy lineup replacement",
		{"available_units": _get_enemy_unit_count(lineup_data)},
		[Log.TAG_DEBUG, "lineup", "enemy", "surgical"]
	)

	if not game.holder_enemy:
		Log.error(
			"Enemy holder container not available", {}, [Log.TAG_DEBUG, "lineup", "enemy", "error"]
		)
		return false

	# Step 1: Clear existing enemy lineup (surgical)
	var cleared_count: int = _clear_holder_container_surgical(game.holder_enemy)
	Log.debug(
		"Enemy lineup cleared for replacement",
		{"cards_cleared": cleared_count},
		[Log.TAG_DEBUG, "lineup", "enemy", "surgical"]
	)

	# Step 2: Determine which lineup data to use (flexible loading)
	var source_data: Dictionary = {}
	var data_source: String = ""

	if lineup_data.has("enemies") and not lineup_data.enemies.is_empty():
		source_data = lineup_data.enemies
		data_source = "enemy_data"
	elif lineup_data.has("allies") and not lineup_data.allies.is_empty():
		source_data = lineup_data.allies
		data_source = "allied_data_as_enemy"

	if source_data.is_empty():
		Log.warning(
			"No lineup data found to load as enemy",
			{"lineup_keys": lineup_data.keys()},
			[Log.TAG_DEBUG, "lineup", "enemy", "surgical"]
		)
		return false

	# Step 3: Restore lineup data into enemy positions (reuse GamestateLoader logic)
	await GamestateLoader._restore_lineup_positions(source_data, game.holder_enemy, "enemies")

	Log.info(
		"Enemy lineup surgical replacement completed",
		{
			"units_restored": source_data.size(),
			"data_source": data_source,
			"flexible_loading": data_source == "allied_data_as_enemy"
		},
		[Log.TAG_DEBUG, "lineup", "enemy", "surgical"]
	)
	return true


func _get_enemy_unit_count(lineup_data: Dictionary) -> int:
	"""Get count of enemy units from lineup data (handles both allied/enemy saves)"""
	if lineup_data.has("enemies"):
		return lineup_data.enemies.size()

	if lineup_data.has("allies"):
		# This is an allied save being loaded as enemy
		return lineup_data.allies.size()

	return 0


func _clear_holder_container_surgical(holder_container: HolderContainer) -> int:
	"""Clear holder container using GamestateLoader's proven method"""
	return GamestateLoader._clear_holder_container(holder_container)


func _get_game_instance() -> Game:
	"""Get the current Game instance"""
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene.has_node("Game"):
		return current_scene.get_node("Game") as Game
	return null


static func create_for_file(file_path: String) -> LoadEnemyLineupAction:
	"""Create a LoadEnemyLineupAction with a specific file path"""
	return LoadEnemyLineupAction.new(file_path)
