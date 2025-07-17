class_name DebugConfigReader
extends RefCounted

# Shared utility for reading debug configuration files
# Used by both RNG autoload and debug startup coordinator
#
# CRITICAL: This enables autonomous RNG seed initialization during autoload phase
# Seeds are specified in JSON configs using: checksum_config.initial_seed
# This eliminates timing dependencies and ensures cross-platform determinism


static func get_debug_seed() -> int:
	"""Get debug seed from config file. Returns default (12345) if not found or invalid."""
	var config_data: Dictionary = _read_config_file()

	# Check for checksum_config.initial_seed (primary)
	if config_data.has("checksum_config"):
		var checksum_config: Dictionary = config_data.checksum_config
		if checksum_config.has("initial_seed"):
			var _seed: int = checksum_config.initial_seed
			# Log at info level since this affects determinism
			if Log:
				Log.info(
					"Debug seed loaded from checksum_config.initial_seed",
					{"seed": _seed},
					["debug", "rng", "config", "seed"]
				)
			return _seed

	# Fallback to legacy seed field
	if config_data.has("seed"):
		var _seed: int = config_data.seed
		if Log:
			Log.info(
				"Debug seed loaded from legacy seed field",
				{"seed": _seed},
				["debug", "rng", "config", "seed"]
			)
		return _seed

	# No seed found - use default
	var default_seed: int = 12345
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
		# Mobile: Check external config first, fallback to embedded
		var external_path: String = "user://debug_startup_actions.json"
		if FileAccess.file_exists(external_path):
			return external_path
		return "res://debug_startup_actions.json"
	else:
		# Desktop: Use external config
		return "user://debug_startup_actions.json"
