extends Node

# Simplified ActionRecorder singleton for recording player actions
# Focuses on core functionality without complex file management

# Recording configuration
const MAX_ACTIONS: int = 1000  # Simplified limit (not circular buffer)
const RECORDINGS_DIR: String = "user://recordings/"

# Recording state
var recorded_actions: Array[RecordedAction] = []
var current_sequence: int = 0
var initial_seed: int = -1
var is_recording: bool = false
var is_replaying: bool = false


func _ready() -> void:
	Log.info(
		"ActionRecorder initialized - simplified recording system active",
		{},
		["debug", "action_recorder", "init"]
	)
	_ensure_recordings_directory()
	_capture_initial_seed()

	# Connect to core event system to record player actions
	if core and core.event:
		core.event.connect(_on_core_event)
		Log.info(
			"Connected to core event system", {}, ["debug", "action_recorder", "init", "connection"]
		)
	else:
		Log.error(
			"Failed to connect to core event system",
			{},
			["debug", "action_recorder", "init", "error"]
		)


func start_recording() -> bool:
	if is_recording:
		Log.warning("Recording already in progress", {}, ["debug", "action_recorder"])
		return false

	# Clear previous recording
	recorded_actions.clear()
	current_sequence = 0
	is_recording = true
	_capture_initial_seed()

	Log.info(
		"Recording started", {"initial_seed": initial_seed}, ["debug", "action_recorder", "start"]
	)
	return true


func stop_recording() -> bool:
	if not is_recording:
		Log.warning("No recording in progress", {}, ["debug", "action_recorder"])
		return false

	is_recording = false

	Log.info(
		"Recording stopped",
		{"total_actions": recorded_actions.size(), "sequences": current_sequence},
		["debug", "action_recorder", "stop"]
	)
	return true


func record_action(event: core.CoreEvent) -> bool:
	if not event:
		Log.error("Cannot record null event", {}, ["debug", "action_recorder", "error"])
		return false

	if not is_recording or is_replaying:
		return false

	# Only record player-initiated actions
	if event.source != core.EventSource.PLAYER:
		Log.debug(
			"Skipping non-player action",
			{"event_type": event.get_class(), "source": core.EventSource.keys()[event.source]},
			["debug", "action_recorder", "filter"]
		)
		return false

	# Check action limit
	if recorded_actions.size() >= MAX_ACTIONS:
		Log.warning(
			"Recording buffer full, stopping recording",
			{"max_actions": MAX_ACTIONS},
			["debug", "action_recorder", "limit"]
		)
		stop_recording()
		return false

	# Create recorded action with strong typing
	var recorded: RecordedAction = RecordedAction.new(event, current_sequence)
	recorded_actions.append(recorded)
	current_sequence += 1

	Log.debug(
		"Action recorded",
		{
			"sequence": recorded.sequence_number,
			"event_type": recorded.event_class,
			"total_actions": recorded_actions.size()
		},
		["debug", "action_recorder", "record"]
	)
	return true


func save_recording(recording_name: String = "") -> String:
	if recorded_actions.is_empty():
		Log.warning(
			"No actions recorded - saving empty recording for test validation",
			{},
			["debug", "action_recorder", "save", "warning"]
		)
		# Continue with empty recording for test purposes

	# Generate filename with timestamp if no name provided
	if recording_name.is_empty():
		var timestamp: String = (
			Time
			. get_datetime_string_from_system()
			. replace(":", "")
			. replace("-", "")
			. replace("T", "_")
		)
		recording_name = timestamp + "_recording"

	var filename: String = recording_name + ".json"
	var filepath: String = RECORDINGS_DIR + filename

	# Create recording data
	var recording_data: Dictionary = {
		"version": "1.0",
		"recording_name": recording_name,
		"total_actions": recorded_actions.size(),
		"start_sequence": 0,
		"end_sequence": current_sequence - 1,
		"recording_timestamp": Time.get_datetime_string_from_system(),
		"initial_seed": initial_seed,
		"actions": []
	}

	# Serialize actions with type safety
	for action: RecordedAction in recorded_actions:
		recording_data.actions.append(action.to_dictionary())

	# Write to file
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		Log.error(
			"Failed to create recording file",
			{"filepath": filepath, "error": FileAccess.get_open_error()},
			["debug", "action_recorder", "save", "error"]
		)
		return ""

	var json_string: String = JSON.stringify(recording_data, "\t")
	file.store_string(json_string)
	file.close()

	Log.info(
		"Recording saved successfully",
		{
			"filename": filename,
			"filepath": filepath,
			"total_actions": recorded_actions.size(),
			"file_size_bytes": json_string.length()
		},
		["debug", "action_recorder", "save"]
	)

	return filepath


func load_recording(filepath: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		Log.error(
			"Recording file not found",
			{"filepath": filepath},
			["debug", "action_recorder", "load", "error"]
		)
		return {}

	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		Log.error(
			"Failed to open recording file",
			{"filepath": filepath, "error": FileAccess.get_open_error()},
			["debug", "action_recorder", "load", "error"]
		)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)
	if result != OK:
		Log.error(
			"Failed to parse recording JSON",
			{
				"filepath": filepath,
				"error": result,
				"error_line": json.error_line,
				"error_string": json.error_string
			},
			["debug", "action_recorder", "load", "error"]
		)
		return {}

	var data: Dictionary = json.data
	Log.info(
		"Recording loaded successfully",
		{
			"filepath": filepath,
			"total_actions": data.get("total_actions", 0),
			"version": data.get("version", "unknown"),
			"initial_seed": data.get("initial_seed", -1)
		},
		["debug", "action_recorder", "load"]
	)

	return data


func set_seed_for_replay(replay_seed: int) -> bool:
	if not rng:
		Log.error(
			"RNG singleton not available",
			{"seed": replay_seed},
			["debug", "action_recorder", "replay", "error"]
		)
		return false

	if rng.seeded_rng:
		rng.seeded_rng.reset(replay_seed)
		Log.info(
			"RNG seed set for replay",
			{"seed": replay_seed},
			["debug", "action_recorder", "replay", "seed"]
		)
		return true
	else:
		Log.error(
			"Could not set seed for replay - RNG not available",
			{"seed": replay_seed},
			["debug", "action_recorder", "replay", "seed", "error"]
		)
		return false


func start_replay_mode() -> void:
	is_replaying = true
	Log.info("Replay mode started", {}, ["debug", "action_recorder", "replay"])


func stop_replay_mode() -> void:
	is_replaying = false
	Log.info("Replay mode ended", {}, ["debug", "action_recorder", "replay"])


func get_recording_stats() -> Dictionary:
	return {
		"is_recording": is_recording,
		"is_replaying": is_replaying,
		"total_actions": recorded_actions.size(),
		"current_sequence": current_sequence,
		"initial_seed": initial_seed,
		"max_actions": MAX_ACTIONS
	}


func _on_core_event(event: core.CoreEvent) -> void:
	# Forward events to record_action for filtering and recording
	record_action(event)


func _capture_initial_seed() -> void:
	if not rng:
		Log.error(
			"RNG singleton not available for seed capture",
			{},
			["debug", "action_recorder", "seed", "error"]
		)
		initial_seed = -1
		return

	if rng.seeded_rng:
		initial_seed = rng.seeded_rng._initial_seed
		Log.debug(
			"Initial seed captured", {"seed": initial_seed}, ["debug", "action_recorder", "seed"]
		)
	else:
		initial_seed = -1
		Log.warning(
			"Could not capture seed - RNG not available",
			{"seed": initial_seed},
			["debug", "action_recorder", "seed", "warning"]
		)


func _ensure_recordings_directory() -> void:
	if not DirAccess.dir_exists_absolute(RECORDINGS_DIR):
		DirAccess.make_dir_recursive_absolute(RECORDINGS_DIR)
		Log.info(
			"Created recordings directory",
			{"path": RECORDINGS_DIR},
			["debug", "action_recorder", "init"]
		)
