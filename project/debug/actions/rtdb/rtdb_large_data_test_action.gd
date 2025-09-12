class_name RTDBLargeDataTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.testing.large_data"
	group = "Advanced"
	description = "Tests RTDB with a substantial data payload to verify performance and limits."
	auto_continue = false  # Sequential execution required - large data operations need isolation


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var path_suffix: Array[Variant] = ["large_data_test"]
	var test_path: Array[Variant] = create_test_path(path_suffix)

	_update_status("Generating large test dataset...")

	var large_data: Dictionary = _generate_large_test_data()
	var data_size_estimate: int = JSON.stringify(large_data).length()

	_update_status("Setting large data (~%d bytes)..." % [data_size_estimate])

	var start_time: int = Time.get_ticks_msec()

	var write_success: bool = await execute_simple_operation(
		"set_value_async", test_path, large_data, action_name + " (Write)"
	)

	var end_time: int = Time.get_ticks_msec()
	var write_duration: int = end_time - start_time

	if not write_success:
		_update_status("ERROR: Failed to write large data", true)
		return false

	_update_status(
		"Successfully wrote large data (%d bytes) in %d ms" % [data_size_estimate, write_duration]
	)

	_update_status("Testing retrieval of large data...")
	var retrieve_start: int = Time.get_ticks_msec()

	var retrieved_data: Variant = await execute_simple_operation(
		"get_value_async", test_path, null, action_name + " (Read)"
	)

	var retrieve_end: int = Time.get_ticks_msec()
	var retrieve_duration: int = retrieve_end - retrieve_start

	var success_data: Dictionary = {
		"operation": "large_data_test",
		"data_size_bytes": data_size_estimate,
		"write_duration_ms": write_duration,
		"retrieve_duration_ms": retrieve_duration,
		"timestamp": Time.get_ticks_msec()
	}

	if retrieved_data != null:
		_update_status(
			"Large data test completed: Write %dms, Read %dms" % [write_duration, retrieve_duration]
		)
		success_data["retrieval_success"] = true

		if retrieved_data is Dictionary and retrieved_data.has("metadata"):
			success_data["data_integrity_check"] = "passed"
		else:
			success_data["data_integrity_check"] = "failed"
	else:
		success_data["retrieval_success"] = false
		success_data["data_integrity_check"] = "not_tested"

	Log.info(
		"RTDBLargeDataTestAction executed successfully",
		success_data,
		["test", "rtdb", "performance"]
	)

	return true


func _generate_large_test_data() -> Dictionary:
	var data: Dictionary = {
		"metadata":
		{
			"test_type": "large_data_performance",
			"created_at": Time.get_ticks_msec(),
			"generator": "RTDBLargeDataTestAction"
		},
		"users": {},
		"sessions": {},
		"events": [],
		"configuration": {}
	}

	for i: int in range(100):
		var user_id: String = "user_%d" % i
		data.users[user_id] = {
			"id": user_id,
			"name": "Test User %d" % i,
			"email": "user%d@test.com" % i,
			"level": randi() % 100 + 1,
			"experience": randi() % 10000,
			"achievements": _generate_achievements(i),
			"stats":
			{
				"games_played": randi() % 500,
				"games_won": randi() % 250,
				"total_score": randi() % 100000,
				"play_time_hours": randi() % 1000
			},
			"preferences":
			{
				"theme": ["light", "dark"][randi() % 2],
				"sound_enabled": randi() % 2 == 0,
				"notifications": randi() % 2 == 0,
				"language": ["en", "es", "fr", "de"][randi() % 4]
			}
		}

	for i: int in range(200):
		var session_id: String = "session_%d" % i
		data.sessions[session_id] = {
			"id": session_id,
			"user_id": "user_%d" % (randi() % 100),
			"start_time": Time.get_ticks_msec() - (randi() % 86400000),  # Random time in last 24h
			"duration_ms": randi() % 3600000,  # Up to 1 hour
			"actions": randi() % 50,
			"score": randi() % 1000
		}

	for i: int in range(500):
		data.events.append(
			{
				"event_id": "event_%d" % i,
				"type": ["click", "navigation", "achievement", "error"][randi() % 4],
				"timestamp": Time.get_ticks_msec() - (randi() % 86400000),
				"user_id": "user_%d" % (randi() % 100),
				"data": {"value": randi() % 100, "category": "test_category_%d" % (randi() % 10)}
			}
		)

	data.configuration = {
		"game_settings":
		{
			"max_players": 4,
			"round_duration": 300,
			"difficulty_levels": ["easy", "medium", "hard", "expert"],
			"default_theme": "classic"
		},
		"server_config":
		{
			"max_connections": 1000,
			"timeout_seconds": 30,
			"enable_compression": true,
			"log_level": "info"
		},
		"feature_flags": {}
	}

	for i: int in range(20):
		var flag_name: String = "feature_flag_%d" % i
		data.configuration.feature_flags[flag_name] = randi() % 2 == 0

	return data


func _generate_achievements(user_index: int) -> Array[Variant]:
	var achievements: Array[Variant] = []
	var possible_achievements: Array[Variant] = [
		"first_game",
		"ten_games",
		"hundred_games",
		"first_win",
		"ten_wins",
		"hundred_wins",
		"high_scorer",
		"speed_demon",
		"marathon_player",
		"perfectionist",
		"explorer",
		"collector",
		"social_butterfly",
		"lone_wolf"
	]

	var achievement_count: int = (user_index % 5) + 1
	for i: int in range(achievement_count):
		var achievement: String = possible_achievements[
			(user_index + i) % possible_achievements.size()
		]
		if not achievements.has(achievement):
			achievements.append(achievement)

	return achievements
