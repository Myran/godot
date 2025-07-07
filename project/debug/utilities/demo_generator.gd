class_name DemoGenerator

# Generates demo configurations from semantic action logs
# Uses platform-agnostic log access and semantic action mapping

# Load required dependencies
const LogSourceProvider = preload("res://project/debug/utilities/log_source_provider.gd")
const SemanticLogParser = preload("res://project/debug/utilities/semantic_log_parser.gd")
const SemanticActionMapper = preload("res://project/debug/utilities/semantic_action_mapper.gd")

static func generate_demo_from_session(
	session_id: String,
	demo_name: String,
	mode: String = "demo"
) -> Dictionary:
	"""Generate a demo config from a specific semantic session
	
	Args:
		session_id: The semantic session ID to extract actions from
		demo_name: Name for the demo
		mode: "demo" (manual verification) or "automated" (auto-quit)
		
	Returns:
		Dictionary with success status and result data
	"""
	# Get platform-agnostic log data
	var log_data: String = LogSourceProvider.get_latest_logs()
	if log_data.is_empty():
		return _error_result("No logs available", "no_logs")
	
	# Parse semantic actions for the session
	var semantic_actions: Array = SemanticLogParser.parse_session_actions(log_data, session_id)
	if semantic_actions.is_empty():
		return _error_result("No semantic actions found for session: " + session_id, "no_actions")
	
	# Generate debug action sequence
	var debug_sequence: Array[Dictionary] = SemanticActionMapper.generate_debug_action_sequence(semantic_actions)
	if debug_sequence.is_empty():
		return _error_result("No mappable debug actions generated", "no_mappings")
	
	# Create demo metadata
	var metadata: Dictionary = {
		"demo_name": demo_name,
		"generation_method": "semantic_to_debug_mapping",
		"creation_timestamp": Time.get_datetime_string_from_system().replace(":", "").replace("-", "").substr(0, 15),
		"semantic_action_count": semantic_actions.size(),
		"debug_action_count": debug_sequence.size()
	}
	
	# Generate replay config using the mapper
	var config: Dictionary = SemanticActionMapper.create_replay_config(
		session_id,
		debug_sequence,
		metadata,
		mode
	)
	
	# Add demo-specific fields
	config["type"] = "demo"
	config["generation_timestamp"] = Time.get_datetime_string_from_system()
	
	# Update description to reflect actual action count
	config["description"] = "Demo from gameplay session: %s (%d actions)" % [session_id, semantic_actions.size()]
	
	return {
		"success": true,
		"config": config,
		"semantic_actions": semantic_actions,
		"debug_actions": debug_sequence,
		"session_id": session_id
	}


static func generate_demo_from_latest_session(demo_name: String, mode: String = "demo") -> Dictionary:
	"""Generate demo from the most recent semantic session found in logs"""
	
	# Get platform-agnostic log data
	var log_data: String = LogSourceProvider.get_latest_logs()
	if log_data.is_empty():
		return _error_result("No logs available", "no_logs")
	
	# Extract all sessions and find the latest one
	var sessions: Dictionary = SemanticLogParser.extract_sessions_from_log(log_data)
	if sessions.is_empty():
		return _error_result("No semantic sessions found in logs", "no_sessions")
	
	# Find the most recent session (latest timestamp)
	var latest_session_id: String = ""
	var latest_timestamp: float = 0.0
	
	for session_id: String in sessions.keys():
		var session_data: Dictionary = sessions[session_id]
		var actions: Array = session_data.get("actions", [])
		
		# Skip sessions with no actions
		if actions.is_empty():
			continue
			
		# Find latest action timestamp in this session
		var session_latest: float = 0.0
		for action: Dictionary in actions:
			var timestamp: float = action.get("timestamp_ms", 0.0)
			if timestamp > session_latest:
				session_latest = timestamp
		
		# Update latest session if this is newer
		if session_latest > latest_timestamp:
			latest_timestamp = session_latest
			latest_session_id = session_id
	
	if latest_session_id.is_empty():
		return _error_result("No sessions with actions found", "no_actionable_sessions")
	
	# Generate demo from the latest session
	return generate_demo_from_session(latest_session_id, demo_name, mode)


static func write_demo_config(config_data: Dictionary, output_path: String) -> Dictionary:
	"""Write demo configuration to JSON file"""
	
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		return _error_result("Cannot create output file: " + output_path, "file_error")
	
	var json := JSON.new()
	var json_text := json.stringify(config_data, "\t")
	file.store_string(json_text)
	file.close()
	
	return {"success": true, "path": output_path}


static func get_mapping_report(semantic_actions: Array) -> Dictionary:
	"""Generate a report on how semantic actions map to debug actions"""
	return SemanticActionMapper.get_mapping_coverage_report(semantic_actions)


static func _error_result(message: String, error_type: String) -> Dictionary:
	"""Create standardized error result"""
	return {
		"success": false,
		"error": message,
		"error_type": error_type
	}


# Command-line interface for use from justfile
static func main() -> void:
	"""Main entry point for command-line usage"""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	
	if args.size() < 1:
		print("Usage: demo_generator.gd <demo_name> [mode]")
		print("  demo_name: Name for the generated demo")
		print("  mode: 'demo' (default) or 'automated'")
		return
	
	var demo_name: String = args[0]
	var mode: String = args[1] if args.size() > 1 else "demo"
	
	print("🎬 Generating demo from latest session...")
	print("   Demo Name: " + demo_name)
	print("   Mode: " + mode)
	
	var result: Dictionary = generate_demo_from_latest_session(demo_name, mode)
	
	if not result.success:
		print("❌ Error: " + result.error)
		return
	
	var config: Dictionary = result.config
	var semantic_actions: Array = result.semantic_actions
	var debug_actions: Array = result.debug_actions
	var session_id: String = result.session_id
	
	print("✅ Found session ID: " + session_id)
	print("✅ Parsed " + str(semantic_actions.size()) + " semantic actions")
	print("✅ Generated " + str(debug_actions.size()) + " debug actions")
	
	# Generate mapping report
	var report: Dictionary = get_mapping_report(semantic_actions)
	print("📊 Mapping coverage: " + str(report.mapped_actions) + "/" + str(report.total_actions) + " actions mapped")
	
	if report.unmapped_actions > 0:
		print("⚠️  Unmapped action types: " + str(report.unmapped_types))
	
	# Output config as JSON for justfile to capture
	var json := JSON.new()
	print("JSON_OUTPUT_START")
	print(json.stringify(config))
	print("JSON_OUTPUT_END")
	
	print("✅ Demo generation complete!")