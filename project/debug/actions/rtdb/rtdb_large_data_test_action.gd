# project/debug/actions/rtdb/rtdb_large_data_test_action.gd
@tool
class_name RTDBLargeDataTestAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Large Data Test"
	group = "Advanced"
	description = "Tests RTDB with a substantial data payload to verify performance and limits."


func execute() -> Array:
# Check if Firebase backend is available
	var db = get_firebase_database()
	if not db:
		return get_last_error_result()

	# Note: This action previously used data_source pattern but now uses direct instantiation
	# for consistency with other RTDB debug actions

	var path_suffix: Array[Variant] = ["large_data_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)

	_update_status("Generating large test dataset...")

# Create a substantial test dataset
	var large_data: Dictionary = _generate_large_test_data()
	var data_size_estimate: int = JSON.stringify(large_data).length()

	_update_status(
		"Setting large data (~%d bytes) at path '%s'..." % [data_size_estimate, str(full_path)]
	)

	var start_time: int = Time.get_ticks_msec()

# Use the Firebase backend's set_data method with large data
	#var result: bool = await db.set_data(full_path, "", large_data)

	var result: Dictionary = await execute_firebase_operation(
		db, "set_value_async", [full_path, large_data]
	)

	var end_time: int = Time.get_ticks_msec()
	var duration_ms: int = end_time - start_time

	if result.success:
		_update_status(
			"Successfully set large data (%d bytes) in %d ms" % [data_size_estimate, duration_ms]
		)

		# Now test retrieval
		_update_status("Testing retrieval of large data...")
		var retrieve_start: int = Time.get_ticks_msec()
		#var retrieved_data: Variant = await db.get_data(full_path, "")
		var retrieved_data: Variant = await execute_firebase_operation(
			db, "get_value_async", [full_path, large_data]
		)
		var retrieve_end: int = Time.get_ticks_msec()
		var retrieve_duration: int = retrieve_end - retrieve_start

		var success_data: Dictionary = {
			"operation": "large_data_test",
			"path": full_path,
			"data_size_bytes": data_size_estimate,
			"write_duration_ms": duration_ms,
			"retrieve_duration_ms": retrieve_duration,
			"timestamp": Time.get_ticks_msec()
		}

		if retrieved_data != null:
			_update_status(
				(
					"Large data test completed: Write %dms, Read %dms"
					% [duration_ms, retrieve_duration]
				)
			)
			success_data["retrieval_success"] = true

			# Verify data integrity
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

		return _success(success_data)
	else:
		var error_msg: String = "Failed to set large data at path '%s'" % str(full_path)
		_update_status(error_msg, true)
		return _failure(
			error_msg,
			{
				"path": full_path,
				"data_size_bytes": data_size_estimate,
				"duration_ms": duration_ms,
				"operation": "large_data_test"
			}
		)


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

# Generate user data (simulate 100 users)
	for i in range(100):
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

# Generate session data (simulate 200 sessions)
	for i in range(200):
		var session_id: String = "session_%d" % i
		data.sessions[session_id] = {
			"id": session_id,
			"user_id": "user_%d" % (randi() % 100),
			"start_time": Time.get_ticks_msec() - (randi() % 86400000),  # Random time in last 24h
			"duration_ms": randi() % 3600000,  # Up to 1 hour
			"actions": randi() % 50,
			"score": randi() % 1000
		}

# Generate event data (simulate 500 events)
	for i in range(500):
		data.events.append(
			{
				"event_id": "event_%d" % i,
				"type": ["click", "navigation", "achievement", "error"][randi() % 4],
				"timestamp": Time.get_ticks_msec() - (randi() % 86400000),
				"user_id": "user_%d" % (randi() % 100),
				"data": {"value": randi() % 100, "category": "test_category_%d" % (randi() % 10)}
			}
		)

# Generate configuration data
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

# Add feature flags
	for i in range(20):
		var flag_name: String = "feature_flag_%d" % i
		data.configuration.feature_flags[flag_name] = randi() % 2 == 0

	return data


func _generate_achievements(user_index: int) -> Array[String]:
	var achievements: Array[String] = []
	var possible_achievements: Array[String] = [
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

# Give users random achievements based on their index
	var achievement_count: int = (user_index % 5) + 1
	for i in range(achievement_count):
		var achievement: String = possible_achievements[
			(user_index + i) % possible_achievements.size()
		]
		if not achievements.has(achievement):
			achievements.append(achievement)

	return achievements
