class_name LogSourceProvider
extends RefCounted

# Unified log source provider - abstracts platform-specific log access
# Provides consistent interface for accessing logs on Android (adb logcat) and Desktop (file system)

enum Platform { ANDROID, DESKTOP, UNKNOWN }


# Platform detection
static func get_platform() -> Platform:
	"""Detect current platform based on OS features"""
	if OS.has_feature("android"):
		return Platform.ANDROID
	elif OS.has_feature("desktop"):
		return Platform.DESKTOP
	else:
		return Platform.UNKNOWN


# Main log access methods
static func get_latest_logs() -> String:
	"""Get the most recent logs from the platform-appropriate source"""
	match get_platform():
		Platform.ANDROID:
			return _get_android_latest_logs()
		Platform.DESKTOP:
			return _get_desktop_latest_logs()
		_:
			Log.error(
				"Unsupported platform for log access",
				{"platform": get_platform()},
				["log_source", "error"]
			)
			return ""


static func find_logs_containing(search_term: String) -> String:
	"""Find logs containing a specific term (e.g., test_id, session_id)"""
	match get_platform():
		Platform.ANDROID:
			return _find_android_logs_containing(search_term)
		Platform.DESKTOP:
			return _find_desktop_logs_containing(search_term)
		_:
			Log.error(
				"Unsupported platform for log search",
				{"platform": get_platform(), "search_term": search_term},
				["log_source", "error"]
			)
			return ""


static func get_logs_since_timestamp(timestamp: String) -> String:
	"""Get logs since a specific timestamp"""
	match get_platform():
		Platform.ANDROID:
			return _get_android_logs_since(timestamp)
		Platform.DESKTOP:
			return _get_desktop_logs_since(timestamp)
		_:
			Log.error(
				"Unsupported platform for timestamp log access",
				{"platform": get_platform(), "timestamp": timestamp},
				["log_source", "error"]
			)
			return ""


# Android-specific log access
static func _get_android_latest_logs() -> String:
	"""Get latest Android logs using adb logcat - equivalent to logs-last command"""
	var output: Array = []
	var exit_code: int = OS.execute("adb", ["logcat", "-d"], output)

	if exit_code != 0:
		Log.error(
			"Failed to get Android logs via adb",
			{"exit_code": exit_code},
			["log_source", "android", "error"]
		)
		return ""

	var full_logs: String = "\n".join(output)

	# Find the most recent app start (equivalent to logs-last logic)
	var lines: PackedStringArray = full_logs.split("\n")
	var last_start_line: int = -1

	for i in range(lines.size() - 1, -1, -1):
		if (
			lines[i].contains("ActivityManager")
			and lines[i].contains("Start proc")
			and lines[i].contains("gametwo")
		):
			last_start_line = i
			break

	if last_start_line >= 0:
		var recent_lines: PackedStringArray = lines.slice(last_start_line)
		return "\n".join(recent_lines)
	else:
		# Fallback: return last 1000 lines
		var fallback_lines: PackedStringArray = lines.slice(max(0, lines.size() - 1000))
		return "\n".join(fallback_lines)


static func _find_android_logs_containing(search_term: String) -> String:
	"""Find Android logs containing specific term"""
	var output: Array = []
	var exit_code: int = OS.execute("adb", ["logcat", "-d"], output)

	if exit_code != 0:
		return ""

	var full_logs: String = "\n".join(output)
	var matching_lines: PackedStringArray = []

	for line: String in full_logs.split("\n"):
		if line.contains(search_term):
			matching_lines.append(line)

	return "\n".join(matching_lines)


static func _get_android_logs_since(timestamp: String) -> String:
	"""Get Android logs since timestamp (simplified implementation)"""
	# For now, return recent logs - could be enhanced with timestamp parsing
	return _get_android_latest_logs()


# Desktop-specific log access
static func _get_desktop_latest_logs() -> String:
	"""Get latest Desktop logs from Godot user data directory"""
	var logs_dir: String = _get_desktop_logs_directory()

	if not DirAccess.dir_exists_absolute(logs_dir):
		Log.warning(
			"Desktop logs directory not found", {"logs_dir": logs_dir}, ["log_source", "desktop"]
		)
		return ""

	# Find the most recent log file
	var dir: DirAccess = DirAccess.open(logs_dir)
	if dir == null:
		Log.error(
			"Cannot access desktop logs directory",
			{"logs_dir": logs_dir},
			["log_source", "desktop", "error"]
		)
		return ""

	var log_files: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".log"):
			log_files.append(logs_dir + "/" + file_name)
		file_name = dir.get_next()

	if log_files.is_empty():
		Log.warning(
			"No log files found in desktop logs directory",
			{"logs_dir": logs_dir},
			["log_source", "desktop"]
		)
		return ""

	# Sort by modification time (most recent first)
	log_files.sort_custom(_compare_file_modification_time)

	# Read the most recent log file
	var latest_log_file: String = log_files[0]
	var file: FileAccess = FileAccess.open(latest_log_file, FileAccess.READ)

	if file == null:
		Log.error(
			"Cannot read desktop log file",
			{"file": latest_log_file},
			["log_source", "desktop", "error"]
		)
		return ""

	var content: String = file.get_as_text()
	file.close()

	return content


static func _find_desktop_logs_containing(search_term: String) -> String:
	"""Find Desktop logs containing specific term"""
	var logs_dir: String = _get_desktop_logs_directory()

	if not DirAccess.dir_exists_absolute(logs_dir):
		return ""

	var dir: DirAccess = DirAccess.open(logs_dir)
	if dir == null:
		return ""

	var matching_lines: PackedStringArray = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".log"):
			var file_path: String = logs_dir + "/" + file_name
			var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

			if file != null:
				var content: String = file.get_as_text()
				file.close()

				for line: String in content.split("\n"):
					if line.contains(search_term):
						matching_lines.append(line)

		file_name = dir.get_next()

	return "\n".join(matching_lines)


static func _get_desktop_logs_since(timestamp: String) -> String:
	"""Get Desktop logs since timestamp (simplified implementation)"""
	# For now, return recent logs - could be enhanced with timestamp parsing
	return _get_desktop_latest_logs()


# Helper methods
static func _get_desktop_logs_directory() -> String:
	"""Get the desktop logs directory path (handles self-contained mode)"""
	var user_data_dir: String = OS.get_user_data_dir()

	# In self-contained mode, user data dir is relative to executable
	# Check if we're in self-contained mode by looking for logs in project directory
	var project_logs_dir: String = ProjectSettings.globalize_path("res://logs")
	var user_logs_dir: String = user_data_dir + "/logs"

	# Check which logs directory exists and has files
	if DirAccess.dir_exists_absolute(project_logs_dir):
		var dir: DirAccess = DirAccess.open(project_logs_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".log"):
					Log.info(
						"Using self-contained logs directory",
						{"path": project_logs_dir},
						["log_source", "desktop"]
					)
					return project_logs_dir
				file_name = dir.get_next()

	# Fallback to user data directory
	Log.info("Using user data logs directory", {"path": user_logs_dir}, ["log_source", "desktop"])
	return user_logs_dir


static func _compare_file_modification_time(a: String, b: String) -> bool:
	"""Compare file modification times for sorting (most recent first)"""
	var file_a: FileAccess = FileAccess.open(a, FileAccess.READ)
	var file_b: FileAccess = FileAccess.open(b, FileAccess.READ)

	if file_a == null or file_b == null:
		return false

	var time_a: int = file_a.get_modified_time()
	var time_b: int = file_b.get_modified_time()

	file_a.close()
	file_b.close()

	return time_a > time_b


# Session extraction utilities
static func extract_recent_sessions(max_sessions: int = 5) -> Array[Dictionary]:
	"""Extract recent semantic sessions from logs"""
	var logs: String = get_latest_logs()
	return SemanticLogParser.extract_sessions_from_log(logs).values().slice(0, max_sessions)


static func find_session_by_id(session_id: String) -> Dictionary:
	"""Find a specific session by ID"""
	var logs: String = find_logs_containing(session_id)
	var sessions: Dictionary = SemanticLogParser.extract_sessions_from_log(logs)
	return sessions.get(session_id, {})


# Platform info utilities
static func get_platform_name() -> String:
	"""Get human-readable platform name"""
	match get_platform():
		Platform.ANDROID:
			return "Android"
		Platform.DESKTOP:
			return "Desktop"
		_:
			return "Unknown"


static func get_logs_location_info() -> Dictionary:
	"""Get information about where logs are stored on this platform"""
	match get_platform():
		Platform.ANDROID:
			return {
				"platform": "Android",
				"source": "adb logcat",
				"access_method": "ADB command",
				"location": "Device logcat buffer"
			}
		Platform.DESKTOP:
			return {
				"platform": "Desktop",
				"source": "File system",
				"access_method": "Direct file access",
				"location": _get_desktop_logs_directory()
			}
		_:
			return {
				"platform": "Unknown",
				"source": "Not available",
				"access_method": "Not supported",
				"location": "N/A"
			}
