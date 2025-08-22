class_name DebugConfigReader
extends RefCounted

# CRITICAL: This enables autonomous RNG seed initialization during autoload phase


static func get_debug_seed() -> int:
	"""Get debug seed from config file. Returns default GameConstants.RandomSystem.DEFAULT_SEED if not found or invalid."""
	var config_data: Dictionary = _read_config_file()

	if config_data.has("checksum_config"):
		var checksum_config: Dictionary = config_data.checksum_config
		if checksum_config.has("initial_seed"):
			var _seed: int = checksum_config.initial_seed
			if Log:
				Log.info(
					"Debug seed loaded from checksum_config.initial_seed",
					{"seed": _seed},
					["debug", "rng", "config", "seed"]
				)
			return _seed

	if config_data.has("seed"):
		var _seed: int = config_data.seed
		if Log:
			Log.info(
				"Debug seed loaded from legacy seed field",
				{"seed": _seed},
				["debug", "rng", "config", "seed"]
			)
		return _seed

	var default_seed: int = GameConstants.RandomSystem.DEFAULT_SEED
	if Log:
		Log.debug(
			"No debug seed found in config, using default",
			{"default_seed": default_seed},
			["debug", "rng", "config", "seed"]
		)
	return default_seed


static func get_full_config() -> Dictionary:
	"""Get complete debug configuration. Used by debug startup coordinator."""
	return _read_config_file()


static func get_metadata() -> Dictionary:
	"""Get metadata section from debug configuration. Returns empty dict if not found."""
	var config_data: Dictionary = _read_config_file()

	if config_data.has("metadata"):
		var metadata: Dictionary = config_data.metadata
		if Log:
			Log.debug(
				"Debug config metadata accessed",
				{"metadata_keys": metadata.keys(), "size": metadata.size()},
				["debug", "config", "metadata"]
			)
		return metadata

	if Log:
		Log.debug("No metadata found in debug config", {}, ["debug", "config", "metadata"])
	return {}


static func has_gamestate_loading_action() -> bool:
	"""Check if debug config contains gamestate loading action to prevent tilemap block creation."""
	var config_data: Dictionary = _read_config_file()
	var actions: Array = config_data.get("actions", [])

	for action in actions:
		if action == "system.debug.load_gamestate":
			if Log:
				Log.debug(
					"Gamestate loading action detected in debug config",
					{},
					["debug", "gamestate", "initialization"]
				)
			return true

	return false


# ================================
# PATH MANAGEMENT
# ================================

static func get_saved_states_dir() -> String:
	"""Get the saved states directory path. Centralized path management for all gamestate files."""
	return "res://debug/saved_states/"

static func get_saved_state_path(filename: String) -> String:
	"""Get full path for a saved state file. Automatically adds .json extension if missing."""
	var clean_filename: String = filename
	if not clean_filename.ends_with(".json"):
		clean_filename += ".json"
	return get_saved_states_dir() + clean_filename


static func _read_config_file() -> Dictionary:
	"""Internal method to read and parse debug config file."""
	var config_path: String = _get_config_path()

	if not FileAccess.file_exists(config_path):
		if Log:
			Log.debug(
				"Debug config file not found", {"path": config_path}, ["debug", "config", "file"]
			)
		return {}

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		if Log:
			Log.warning(
				"Could not open debug config file",
				{"path": config_path},
				["debug", "config", "file", "error"]
			)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)

	if result != OK:
		if Log:
			Log.warning(
				"Invalid JSON in debug config file",
				{
					"path": config_path,
					"error": json.get_error_message(),
					"line": json.get_error_line()
				},
				["debug", "config", "file", "json", "error"]
			)
		return {}

	var data: Dictionary = json.data
	if Log:
		Log.debug(
			"Debug config loaded successfully",
			{"path": config_path, "keys": data.keys(), "size": data.size()},
			["debug", "config", "file"]
		)

	return data


static func _get_config_path() -> String:
	"""Get the appropriate config file path based on platform."""
	if OS.has_feature("mobile"):
		var external_path: String = "user://debug_startup_actions.json"
		if FileAccess.file_exists(external_path):
			return external_path
		return "res://debug_startup_actions.json"

	return "user://debug_startup_actions.json"
