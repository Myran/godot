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

# Replay state
var replay_actions: Array[RecordedAction] = []
var replay_index: int = 0
var replay_initial_checksum: String = ""
var replay_config: Dictionary = {}


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

	# Connect to UI event system to record UI state transitions
	if ui and ui.event:
		ui.event.connect(_on_ui_event)
		Log.info(
			"Connected to UI event system", {}, ["debug", "action_recorder", "init", "connection"]
		)
	else:
		Log.error(
			"Failed to connect to UI event system",
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

	# Create recorded action with strong typing and error handling
	var recorded: RecordedAction = RecordedAction.new(event, current_sequence)
	if (
		not recorded
		or recorded.event_class == "NullEvent"
		or recorded.event_class == "UnknownEvent"
	):
		Log.error(
			"Failed to create valid recorded action",
			{"event_type": event.get_class(), "sequence": current_sequence},
			["debug", "action_recorder", "record", "error"]
		)
		return false

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
	_hide_debug_menu_during_replay()
	Log.info("Replay mode started", {}, ["debug", "action_recorder", "replay"])


func stop_replay_mode() -> void:
	is_replaying = false
	replay_actions.clear()
	replay_index = 0
	replay_initial_checksum = ""
	replay_config.clear()
	_show_debug_menu_after_replay()
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


func _on_ui_event(event: ui.UIEvent) -> void:
	# Forward UI events to record_action for filtering and recording
	# UI events extend core.CoreEvent, so they can be handled by the same function
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


func replay_recording(filepath: String, config: Dictionary = {}) -> bool:
	# Validate input parameters
	if filepath.is_empty():
		Log.error(
			"Cannot replay with empty filepath", {}, ["debug", "action_recorder", "replay", "error"]
		)
		return false

	if is_recording:
		Log.error(
			"Cannot replay while recording", {}, ["debug", "action_recorder", "replay", "error"]
		)
		return false

	if is_replaying:
		Log.warning(
			"Replay already in progress, stopping current replay",
			{},
			["debug", "action_recorder", "replay"]
		)
		stop_replay_mode()

	# Load recording data
	var recording_data: Dictionary = load_recording(filepath)
	if recording_data.is_empty():
		Log.error(
			"Failed to load recording for replay",
			{"filepath": filepath},
			["debug", "action_recorder", "replay", "error"]
		)
		return false

	# Parse actions from recording
	replay_actions.clear()
	var actions_data: Array = recording_data.get("actions", [])
	for action_dict: Dictionary in actions_data:
		var recorded_action: RecordedAction = RecordedAction.from_dictionary(action_dict)
		if recorded_action:
			replay_actions.append(recorded_action)
		else:
			Log.error(
				"Failed to parse recorded action",
				{"action_dict": action_dict},
				["debug", "action_recorder", "replay", "error"]
			)
			return false

	# Setup replay state
	replay_index = 0
	replay_config = config
	replay_initial_checksum = config.get("expected_checksum", "")
	start_replay_mode()

	# Set seed for deterministic replay
	var replay_seed: int = recording_data.get("initial_seed", -1)
	if replay_seed != -1:
		set_seed_for_replay(replay_seed)

	# Reset game state if requested
	if config.get("reset_game", true):
		_reset_game_state()

	Log.info(
		"Replay started",
		{
			"filepath": filepath,
			"total_actions": replay_actions.size(),
			"replay_seed": replay_seed,
			"reset_game": config.get("reset_game", true),
			"expected_checksum": replay_initial_checksum
		},
		["debug", "action_recorder", "replay"]
	)

	# Start replay execution using SystemIdleActionEvent pattern
	_queue_next_replay_action()
	return true


func _queue_next_replay_action() -> void:
	if not is_replaying or replay_index >= replay_actions.size():
		# Replay completed - validate checksum
		_complete_replay_with_validation()
		return

	# Get next action to replay
	var recorded_action: RecordedAction = replay_actions[replay_index]
	replay_index += 1

	# Create callable that will deserialize and emit the event
	var replay_callable: Callable = func() -> void: _execute_replay_action(recorded_action)

	# Queue using SystemIdleActionEvent (proven pattern)
	core.action(core.SystemIdleActionEvent.new(replay_callable))


func _execute_replay_action(recorded_action: RecordedAction) -> void:
	# Deserialize and emit the event
	var event: core.CoreEvent = recorded_action.from_serialized_data()
	if not event:
		Log.error(
			"Failed to deserialize recorded action",
			{"sequence": recorded_action.sequence_number, "class": recorded_action.event_class},
			["debug", "action_recorder", "replay", "error"]
		)
		# Continue with next action even if this one fails
		_queue_next_replay_action()
		return

	Log.debug(
		"Replaying action",
		{
			"sequence": recorded_action.sequence_number,
			"event_type": recorded_action.event_class,
			"progress": str(replay_index) + "/" + str(replay_actions.size())
		},
		["debug", "action_recorder", "replay", "action"]
	)

	# Create a callable that will emit the event and then queue the next action
	# This ensures each event is fully processed and cascaded before the next one
	var emit_and_queue_next: Callable = func() -> void:
		# Emit the event to the correct system based on type
		if recorded_action.event_class.begins_with("ui."):
			# UI events go to ui.action() - cast to UIEvent for type safety
			var ui_event: ui.UIEvent = event as ui.UIEvent
			if ui_event:
				ui.action(ui_event)
			else:
				Log.error(
					"Failed to cast event to UIEvent",
					{"event_class": recorded_action.event_class},
					["debug", "action_recorder", "replay", "error"]
				)
		else:
			# Core events go to core.action()
			core.action(event)

		# Queue the next action AFTER this event has been emitted and processed
		_queue_next_replay_action()

	# Use SystemIdleActionEvent to ensure this event completes before next one
	core.action(core.SystemIdleActionEvent.new(emit_and_queue_next))


func _complete_replay_with_validation() -> void:
	Log.info(
		"Replay completed, starting validation",
		{"total_actions_replayed": replay_index},
		["debug", "action_recorder", "replay", "complete"]
	)

	# Capture final game state for validation
	var validate_callable: Callable = func() -> void: _validate_replay_checksum()

	# Queue validation using SystemIdleActionEvent
	core.action(core.SystemIdleActionEvent.new(validate_callable))


func _validate_replay_checksum() -> void:
	# Create capture action to get current game state checksum
	var capture_action: RecordingCaptureAction = RecordingCaptureAction.new()
	var capture_result: DebugAction.Result = capture_action.execute()

	if not capture_result.success:
		Log.error(
			"Failed to capture game state for replay validation",
			{"error": capture_result.error_message},
			["debug", "action_recorder", "replay", "validation", "error"]
		)
		stop_replay_mode()
		return

	# Get the checksum from capture result
	var current_checksum: String = capture_result.data.get("checksum", "")

	if current_checksum.is_empty():
		Log.error(
			"No checksum found in capture result",
			{"capture_data": capture_result.data},
			["debug", "action_recorder", "replay", "validation", "error"]
		)
		stop_replay_mode()
		return

	# Compare checksums
	if replay_initial_checksum.is_empty():
		Log.warning(
			"No expected checksum for validation - replay completed without validation",
			{"final_checksum": current_checksum},
			["debug", "action_recorder", "replay", "validation", "warning"]
		)
	else:
		var validation_success: bool = current_checksum == replay_initial_checksum

		if validation_success:
			Log.info(
				"✅ REPLAY VALIDATION PASSED - Checksums match",
				{
					"expected_checksum": replay_initial_checksum,
					"actual_checksum": current_checksum,
					"actions_replayed": replay_index
				},
				["debug", "action_recorder", "replay", "validation", "success"]
			)
		else:
			Log.error(
				"❌ REPLAY VALIDATION FAILED - Checksum mismatch",
				{
					"expected_checksum": replay_initial_checksum,
					"actual_checksum": current_checksum,
					"actions_replayed": replay_index
				},
				["debug", "action_recorder", "replay", "validation", "error"]
			)

	stop_replay_mode()


func _reset_game_state() -> void:
	# Reset game state for deterministic replay
	var game: Game = _get_game_node()
	if game:
		# Clear lineups
		if game.holder_allies:
			game.holder_allies.clear_lineup()
		if game.holder_enemy:
			game.holder_enemy.clear_lineup()

		# Reset clicker state if available
		if game.clicker and game.clicker.has_method("reset_state"):
			game.clicker.reset_state()

		Log.info("Game state reset for replay", {}, ["debug", "action_recorder", "replay", "reset"])
	else:
		Log.warning(
			"Could not find game node for state reset",
			{},
			["debug", "action_recorder", "replay", "reset", "warning"]
		)


func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if not root:
		return null

	var game_node: Node = root.find_child("Game", true, false)
	if not game_node or not game_node is Game:
		return null

	return game_node


func list_recordings() -> Array[String]:
	# List available recording files
	var recordings: Array[String] = []

	if not DirAccess.dir_exists_absolute(RECORDINGS_DIR):
		return recordings

	var dir: DirAccess = DirAccess.open(RECORDINGS_DIR)
	if not dir:
		return recordings

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json") and not dir.current_is_dir():
			recordings.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	recordings.sort()

	return recordings


func _ensure_recordings_directory() -> void:
	if not DirAccess.dir_exists_absolute(RECORDINGS_DIR):
		DirAccess.make_dir_recursive_absolute(RECORDINGS_DIR)
		Log.info(
			"Created recordings directory",
			{"path": RECORDINGS_DIR},
			["debug", "action_recorder", "init"]
		)


func _hide_debug_menu_during_replay() -> void:
	# Hide debug menu to prevent user interaction during replay
	# Use the existing debug menu action through DebugManager
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU)
		Log.info(
			"Debug menu hidden during replay using DebugManager",
			{},
			["debug", "action_recorder", "replay", "ui"]
		)
	else:
		Log.warning(
			"DebugManager not available to hide debug menu",
			{},
			["debug", "action_recorder", "replay", "ui", "warning"]
		)


func _show_debug_menu_after_replay() -> void:
	# Show debug menu after replay completes
	# Use the existing debug menu action through DebugManager
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)
		Log.info(
			"Debug menu shown after replay completion using DebugManager",
			{},
			["debug", "action_recorder", "replay", "ui"]
		)
	else:
		Log.warning(
			"DebugManager not available to show debug menu",
			{},
			["debug", "action_recorder", "replay", "ui", "warning"]
		)
