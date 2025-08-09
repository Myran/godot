class_name SemanticLogParser


static func parse_semantic_actions_from_log(log_data: String) -> Array:
	"""Parse semantic action entries from raw log data"""
	var actions: Array[Dictionary] = []
	var lines: PackedStringArray = log_data.split("\n")

	for line: String in lines:
		var action: Dictionary = _parse_semantic_action_line(line)
		if not action.is_empty():
			actions.append(action)

	return actions


static func extract_sessions_from_log(log_data: String) -> Dictionary:
	"""Group semantic actions by session_id and structure as complete session objects"""
	var sessions: Dictionary = {}
	var lines: PackedStringArray = log_data.split("\n")

	for line: String in lines:
		if line.contains("SESSION_START") or line.contains("SEMANTIC_SESSION_START"):
			var event_type: String = (
				"SESSION_START" if line.contains("SESSION_START") else "SEMANTIC_SESSION_START"
			)
			var start_data: Dictionary = _parse_session_event_line(line, event_type)
			if not start_data.is_empty():
				var session_id: String = start_data.get("session_id", "unknown")
				if not sessions.has(session_id):
					sessions[session_id] = {
						"start_event": start_data, "actions": [], "end_event": {}
					}
				else:
					sessions[session_id]["start_event"] = start_data

		elif line.contains("SESSION_END") or line.contains("SEMANTIC_SESSION_END"):
			var event_type: String = (
				"SESSION_END" if line.contains("SESSION_END") else "SEMANTIC_SESSION_END"
			)
			var end_data: Dictionary = _parse_session_event_line(line, event_type)
			if not end_data.is_empty():
				var session_id: String = end_data.get("session_id", "unknown")
				if not sessions.has(session_id):
					sessions[session_id] = {"start_event": {}, "actions": [], "end_event": end_data}
				else:
					sessions[session_id]["end_event"] = end_data

		elif line.contains("SEMANTIC_ACTION"):
			var action: Dictionary = _parse_semantic_action_line(line)
			if not action.is_empty():
				var session_id: String = action.get("session_id", "unknown")
				if not sessions.has(session_id):
					sessions[session_id] = {"start_event": {}, "actions": [], "end_event": {}}
				sessions[session_id]["actions"].append(action)

	return sessions


static func parse_session_actions(log_data: String, session_id: String) -> Array:
	"""Extract actions for a specific session"""
	var sessions: Dictionary = extract_sessions_from_log(log_data)
	var session_data: Dictionary = sessions.get(session_id, {})
	return session_data.get("actions", [])


static func filter_actions_by_tags(actions: Array, tags: Array[String]) -> Array:
	"""Filter actions that contain any of the specified tags"""
	var filtered: Array[Dictionary] = []

	for action: Dictionary in actions:
		var action_tags: Array = action.get("tags", [])
		var has_matching_tag: bool = false

		for tag: String in tags:
			if tag in action_tags:
				has_matching_tag = true
				break

		if has_matching_tag:
			filtered.append(action)

	return filtered


static func get_session_sequence(log_data: String, session_id: String) -> Array:
	"""Get ordered sequence of actions for a session"""
	var session_actions: Array = parse_session_actions(log_data, session_id)

	session_actions.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("sequence", 0) < b.get("sequence", 0)
	)

	return session_actions


static func validate_log_format(log_data: String) -> bool:
	"""Validate that log data contains semantic action entries"""
	return log_data.contains("SEMANTIC_ACTION") and log_data.contains("semantic_action")


static func _parse_semantic_action_line(line: String) -> Dictionary:
	"""Parse a single log line for semantic action data"""
	if not line.contains("SEMANTIC_ACTION"):
		return {}

	var json_start: int = line.find("{")
	var json_end: int = line.rfind("}")

	if json_start == -1 or json_end == -1 or json_end <= json_start:
		return {}

	var json_text: String = line.substr(json_start, json_end - json_start + 1)

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		return {}

	if not json.data is Dictionary:
		return {}

	var parsed_data: Dictionary = json.data as Dictionary

	var enhanced_data: Dictionary = parsed_data.duplicate()
	enhanced_data["log_timestamp"] = _extract_log_timestamp(line)
	enhanced_data["tags"] = _extract_log_tags(line)

	return enhanced_data


static func _parse_session_event_line(line: String, event_type: String) -> Dictionary:
	"""Parse session start/end event lines"""
	if not line.contains(event_type):
		return {}

	var json_start: int = line.find("{")
	var json_end: int = line.rfind("}")

	if json_start == -1 or json_end == -1 or json_end <= json_start:
		return {}

	var json_text: String = line.substr(json_start, json_end - json_start + 1)

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		return {}

	if not json.data is Dictionary:
		return {}

	return json.data as Dictionary


static func _extract_log_timestamp(line: String) -> String:
	"""Extract timestamp from log line prefix"""
	var regex: RegEx = RegEx.new()
	regex.compile(r"(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")
	var result: RegExMatch = regex.search(line)

	if result:
		return result.get_string(1)

	return ""


static func _extract_log_tags(line: String) -> Array[String]:
	"""Extract tags from log line - look for [tag1, tag2] pattern"""
	var tags: Array[String] = []

	if line.contains("semantic_action"):
		tags.append("semantic_action")
	if line.contains("gameplay"):
		tags.append("gameplay")
	if line.contains("test"):
		tags.append("test")
	if line.contains("debug"):
		tags.append("debug")

	return tags
