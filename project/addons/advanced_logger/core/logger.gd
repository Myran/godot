@tool
class_name ALogger extends Node
enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

# Signal emitted when Android chunk processing is complete
signal android_chunks_processing_complete
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
const LogFormatter = preload("res://addons/advanced_logger/core/log_formatter.gd")
const SentryHelper = preload("res://utils/sentry_helper.gd")
var AndroidLoggerHelper: Variant = null
var IosLoggerHelper: Variant = null



const TAG_DB: String = "database"
const TAG_CACHE: String = "cache"
const TAG_FIREBASE: String = "firebase"
const TAG_LOCAL: String = "local_data"
const TAG_ERROR: String = "error"
const TAG_NETWORK: String = "network"

const TAG_DB_QUERY: String = "database.query"
const TAG_DB_INSERT: String = "database.insert"
const TAG_DB_UPDATE: String = "database.update"
const TAG_DB_DELETE: String = "database.delete"
const TAG_DB_CONNECTION: String = "database.connection"

const TAG_CACHE_HIT: String = "cache.hit"
const TAG_CACHE_MISS: String = "cache.miss"
const TAG_CACHE_INVALIDATE: String = "cache.invalidate"
const TAG_CACHE_POPULATE: String = "cache.populate"

const TAG_FIREBASE_CONNECT: String = "firebase.connect"
const TAG_FIREBASE_DISCONNECT: String = "firebase.disconnect"
const TAG_FIREBASE_TIMEOUT: String = "firebase.timeout"
const TAG_FIREBASE_AUTH: String = "firebase.auth"
const TAG_FIREBASE_RTDB: String = "firebase.rtdb"
const TAG_FIREBASE_READ: String = "firebase.read"
const TAG_FIREBASE_WRITE: String = "firebase.write"
const TAG_FIREBASE_RETRY: String = "firebase.retry"

const TAG_NETWORK_REQUEST: String = "network.request"
const TAG_NETWORK_RESPONSE: String = "network.response"
const TAG_NETWORK_TIMEOUT: String = "network.timeout"
const TAG_NETWORK_ERROR: String = "network.error"
const TAG_NETWORK_RETRY: String = "network.retry"

const TAG_QUIT: String = 'quit'
const TAG_MOVE: String = "move"
const TAG_UI: String = "ui"
const TAG_UI_INPUT: String = "ui_input"
const TAG_UI_ANIMATION: String = "ui_animation"
const TAG_DEBUG_UI: String = 'debug_ui'
const TAG_MERGE: String = "merge"
const TAG_CARD: String = "card"
const TAG_LEVEL: String = "level"
const TAG_ITEM: String = "item"
const TAG_BATTLE: String = "battle"
const TAG_COMBAT: String = "combat"
const TAG_GAME: String = "game"
const TAG_GAME_STATE: String = "game_state"
const TAG_RNG: String = "rng"
const TAG_RULE: String = "rule"
const TAG_RULES: String = "rules"
const TAG_EVENT: String = "event"
const TAG_PLAYER: String = "player"
const TAG_INPUT: String = "input"
const TAG_SYSTEM: String = "system"
const TAG_DEBUG: String = "debug"
const TAG_DATA: String = "data"
const TAG_DRAFT: String = "draft"
const TAG_LINEUP: String = "lineup"
const TAG_INITIALIZATION: String = "initialization"
const TAG_PERFORMANCE: String = "performance"
const TAG_VALIDATION: String = "validation"
const TAG_ANIMATION: String = "animation"
const TAG_STATE_TRANSITION: String = "state_transition"
const TAG_WIN_CONDITION: String = "win_condition"
const TAG_STAT: String = "stat"
const TAG_TEST: String = "test"
const TAG_GRID: String = "grid"
const TAG_CLICKER: String = "clicker"
const TAG_AUTH: String = "auth"
const TAG_FACEBOOK: String = "facebook"
const TAG_APPLE: String = "apple"
const TAG_RECONCILIATION : String = 'reconciliation'
const TAG_ABILITY : String = 'ability'
const TAG_EFFECT : String = 'effect'
const TAG_DEEP_COPY : String = 'deep_copy'

const TAG_AUTH_LOGIN: String = "auth.login"
const TAG_AUTH_LOGOUT: String = "auth.logout"
const TAG_AUTH_REFRESH: String = "auth.refresh"
const TAG_AUTH_VALIDATE: String = "auth.validate"
const TAG_AUTH_EXPIRE: String = "auth.expire"

const TAG_PERFORMANCE_MEMORY: String = "performance.memory"
const TAG_PERFORMANCE_CPU: String = "performance.cpu"
const TAG_PERFORMANCE_RENDER: String = "performance.render"
const TAG_PERFORMANCE_TIMING: String = "performance.timing"

const TAG_DEBUG_ACTION: String = "debug.action"
const TAG_DEBUG_REGISTRY: String = "debug.registry"
const TAG_DEBUG_MENU: String = "debug.menu"
const TAG_DEBUG_AUTOMATION: String = "debug.automation"
const TAG_DEBUG_MANUAL: String = "debug.manual"

const TAG_TEST_START: String = "test.start"
const TAG_TEST_END: String = "test.end"
const TAG_TEST_PASS: String = "test.pass"
const TAG_TEST_FAIL: String = "test.fail"
const TAG_TEST_SETUP: String = "test.setup"

const TAG_SEMANTIC: String = "semantic"
const TAG_SEMANTIC_ACTION: String = "semantic.action"
const TAG_SESSION: String = "session"
const TAG_SESSION_START: String = "session.start"
const TAG_SESSION_END: String = "session.end"

const TAG_STATS: String = "stats"
const TAG_REGISTRY: String = "registry"
const TAG_REPLAY: String = "replay"
const TAG_AUTOMATED: String = "automated"
const TAG_MANUAL: String = "manual"
const TAG_COMPLETE: String = "complete"
const TAG_GAMEPLAY: String = "gameplay"
const TAG_BOARD: String = "board"
const TAG_RESET: String = "reset"
const TAG_WORKFLOW: String = "workflow"
const TAG_INTEGRATION: String = "integration"
const TAG_FINAL_STATE: String = "final_state"
const TAG_CHECKSUM: String = "checksum"
const TAG_DIAGNOSTIC: String = "diagnostic"
const TAG_IDLE_ACTION: String = "idle_action"
const TAG_ATOMIC_TRANSITION: String = "atomic_transition"

const TAG_GAME_DRAFT_REROLL: String = "game.draft.reroll"
const TAG_GAME_DRAFT_UPGRADE: String = "game.draft.upgrade"
const TAG_GAME_DRAFT_TOGGLE_LINE: String = "game.draft.toggle_line"
const TAG_GAME_DRAFT_REMOVE_CARD: String = "game.draft.remove_card"
const TAG_GAME_LINEUP_MOVE_CARD: String = "game.lineup.move_card"
const TAG_GAME_CARD_MOVE: String = "game.card.move"
const TAG_GAME_TRANSITION_CHANGE_STATE: String = "game.transition.change_state"
const TAG_GAME_BATTLE_START: String = "game.battle.start"

const TAG_DRAFT_REROLL: String = "draft.reroll"
const TAG_DRAFT_UPGRADE: String = "draft.upgrade"
const TAG_DRAFT_TOGGLE_LINE: String = "draft.toggle_line"
const TAG_DRAFT_REMOVE_CARD: String = "draft.remove_card"
const TAG_LINEUP_MOVE_CARD: String = "lineup.move_card"
const TAG_CARD_MOVE: String = "card.move"
const TAG_TRANSITION_CHANGE_STATE: String = "transition.change_state"
const TAG_BATTLE_START: String = "battle.start"

# Platform and system tags
const TAG_ANDROID: String = "android"

# Debug and validation tags
const TAG_INJECTION: String = "injection"
const TAG_ACTION_INJECTION: String = "action_injection"
const TAG_GENERATION_ERROR: String = "generation_error"
const TAG_PLACEHOLDER: String = "placeholder"
const TAG_WILDCARD: String = "wildcard"
const TAG_ABORTION: String = "abortion"
const TAG_RUN_ALL: String = "run_all"
const TAG_WARNING: String = "warning"
const TAG_STAT_REFRESH: String = "stat_refresh"
const TAG_BYPASS_WARNING: String = "bypass_warning"

const TAG_LEVEL_PREFIX: String = "level:"
const TAG_LEVEL_DEBUG: String = "level:debug"
const TAG_LEVEL_INFO: String = "level:info"
const TAG_LEVEL_WARNING: String = "level:warning"
const TAG_LEVEL_ERROR: String = "level:error"
const TAG_LEVEL_CRITICAL: String = "level:critical"

const LEVEL_TAGS: Dictionary = {
	LogLevel.DEBUG: TAG_LEVEL_DEBUG,
	LogLevel.INFO: TAG_LEVEL_INFO,
	LogLevel.WARNING: TAG_LEVEL_WARNING,
	LogLevel.ERROR: TAG_LEVEL_ERROR,
	LogLevel.CRITICAL: TAG_LEVEL_CRITICAL
}

const LEVEL_COLORS: Dictionary = {
	LogLevel.DEBUG: LoggerColors.DEBUG_COLOR,
	LogLevel.INFO: LoggerColors.INFO_COLOR,
	LogLevel.WARNING: LoggerColors.WARNING_COLOR,
	LogLevel.ERROR: LoggerColors.ERROR_COLOR,
	LogLevel.CRITICAL: LoggerColors.CRITICAL_COLOR
}

const LEVEL_HTML_COLORS: Dictionary = {
	LogLevel.DEBUG: LoggerColors.DEBUG_HTML,
	LogLevel.INFO: LoggerColors.INFO_HTML,
	LogLevel.WARNING: LoggerColors.WARNING_HTML,
	LogLevel.ERROR: LoggerColors.ERROR_HTML,
	LogLevel.CRITICAL: LoggerColors.CRITICAL_HTML
}

var _current_level: LogLevel = LogLevel.INFO
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true
var _show_source: bool = true
var _debug_filter_logging: bool = false

var _log_buffer: Array[Dictionary] = []
var _buffer_size: int = ConfigManager.DEFAULT_BUFFER_SIZE
var _enable_buffer_dump: bool = ConfigManager.DEFAULT_ENABLE_BUFFER_DUMP
var _buffer_dumped_recently: bool = false
var _has_custom_buffer_size: bool = false
var _has_custom_buffer_dump: bool = false

var _config: ConfigManager = null


func _init() -> void:
	_config = ConfigManager.get_instance()

	if _config != null:
		_config.config_changed.connect(_on_config_changed)

	_load_settings()

	_configure_for_platform()

func _on_config_changed(section: String, key: String, value: Variant) -> void:
	if section == ConfigManager.SECTION_LOGGER:
		if key == ConfigManager.KEY_LOG_LEVEL:
			_current_level = value
		elif key == ConfigManager.KEY_ACTIVE_TAGS:
			_active_tags = value
		elif key == ConfigManager.KEY_IGNORED_TAGS:
			_ignored_tags = value
		elif key == ConfigManager.KEY_BUFFER_SIZE and not _has_custom_buffer_size:
			_buffer_size = int(value)
			_trim_buffer() # Adjust buffer immediately if size changed
		elif key == ConfigManager.KEY_ENABLE_BUFFER_DUMP and not _has_custom_buffer_dump:
			_enable_buffer_dump = bool(value)
	elif section == ConfigManager.SECTION_FORMAT:
		if key == ConfigManager.KEY_SHOW_TIMESTAMP:
			_show_timestamp = value
		elif key == ConfigManager.KEY_SHOW_TAGS:
			_show_tags = value
		elif key == ConfigManager.KEY_USE_COLORS:
			_use_colors = value
		elif key == ConfigManager.KEY_SHOW_SOURCE:
			_show_source = value

func _load_settings() -> void:
	if _config == null:
		print("[ALogger] No config manager available, using defaults")
		return

	print("[ALogger] Loading settings from ConfigManager")

	_current_level = _config.get_log_level()
	print("[ALogger] Loaded log level: %d (%s)" % [_current_level, ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][_current_level]])

	_buffer_size = _config.get_buffer_size()
	_enable_buffer_dump = _config.get_enable_buffer_dump()

	_active_tags = _config.get_active_tags()
	_ignored_tags = _config.get_ignored_tags()
	print("[ALogger] Loaded active tags: " + str(_active_tags))
	print("[ALogger] Loaded ignored tags: " + str(_ignored_tags))

	_show_timestamp = _config.get_show_timestamp()
	_show_tags = _config.get_show_tags()
	_use_colors = _config.get_use_colors()
	_show_source = _config.get_show_source()

	print("[ALogger] Settings loaded - Level: %s, Colors: %s, Timestamp: %s" % [["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][_current_level], _use_colors, _show_timestamp])


func debug(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.DEBUG, message, context, tags)


func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.INFO, message, context, tags)


func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.WARNING, message, context, tags)


func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.ERROR, message, context, tags)
	_forward_to_sentry(message, "error", context, tags)


func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.CRITICAL, message, context, tags)
	_forward_to_sentry(message, "fatal", context, tags)


func _validate_message(message: String) -> bool:
	if message.is_empty():
		push_warning("Empty log message provided")
		return false
	return true


func _forward_to_sentry(message: String, level: String, context: Dictionary, tags: Array) -> void:
	## Forward error/critical logs to Sentry if available.
	##
	## This method is called automatically by error() and critical() methods.
	## It silently fails if Sentry is unavailable.

	# Capture message with level
	if not SentryHelper.capture_message(message, level):
		return  # Sentry not available

	# Add context if available
	if context.size() > 0:
		SentryHelper.set_context("log_context", context)

	# Add tags if available
	if tags.size() > 0:
		var tag_dict: Dictionary = {}
		for tag in tags:
			tag_dict[tag] = true
		SentryHelper.set_tags(tag_dict)


func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	if not _validate_message(message):
		return

	var validated_tags := TagManager.validate_tags(tags)
	var log_entry_data := _create_log_entry_data(level, message, context, validated_tags)

	_handle_buffering(log_entry_data)

	if not _should_output_log(level, validated_tags):
		return

	# Fire and forget async logging to avoid blocking main thread
	_print_formatted_log_async(log_entry_data)

func _create_log_entry_data(level: LogLevel, message: String, context: Dictionary, validated_tags: Array[String]) -> Dictionary:
	return {
		"level": level,
		"message": message,
		"context": context.duplicate(true), # Deep duplicate
		"tags": validated_tags.duplicate(), # Shallow duplicate is fine for array of strings
		"source_info": _get_source_info()   # Get source info
	}

func _handle_buffering(log_entry_data: Dictionary) -> void:
	_add_to_buffer(log_entry_data)

	var level: int = log_entry_data.level
	if level >= LogLevel.ERROR and _enable_buffer_dump and not _buffer_dumped_recently:
		_dump_buffer_async()  # Fire and forget async buffer dump
		_buffer_dumped_recently = true # Prevent immediate re-dumping
	elif level < LogLevel.ERROR:
		_buffer_dumped_recently = false # Reset dump flag if not high severity

func _should_output_log(level: LogLevel, validated_tags: Array[String]) -> bool:
	if not _should_show_level(level):
		return false

	if not _should_show_tags(validated_tags):
		return false

	return true


func _should_show_level(level: LogLevel) -> bool:
	var level_tag: String = LEVEL_TAGS.get(level, "") # Use .get() for safety
	if level_tag.is_empty():
		push_warning("Invalid log level provided to _should_show_level: %d" % level)
		return false # Should not happen with enum, but good practice

	_debug_print_filter_check_start(level, level_tag)

	if _ignored_tags.has(level_tag):
		_debug_print_filter_result(level_tag, "Ignored Level Tag", false)
		return false

	var active_level_tags: Array[String] = _get_active_level_tags()
	var has_active_level_filter: bool = not active_level_tags.is_empty()

	if has_active_level_filter:
		var show_based_on_active_level: bool = _active_tags.has(level_tag) # Exact match required
		_debug_print_filter_result(level_tag, "Active Level Tag Filter", show_based_on_active_level)
		return show_based_on_active_level
	else:
		var show_based_on_threshold: bool = level >= _current_level
		_debug_print_filter_result(LogLevel.keys()[level], "Standard Level Threshold", show_based_on_threshold)
		return show_based_on_threshold

func _should_show_tags(log_tags: Array[String]) -> bool:
	_debug_print_tag_check_start(log_tags)

	for tag in log_tags:
		if _ignored_tags.has(tag):
			_debug_print_tag_result(log_tags, "Ignored Topic Tag", false)
			return false

	var active_topic_tags: Array[String] = _get_active_topic_tags()

	if active_topic_tags.is_empty():
		_debug_print_tag_result(log_tags, "No Active Topic Tags", true)
		return true

	for tag in log_tags:
		if active_topic_tags.has(tag):
			_debug_print_tag_result(log_tags, "Active Topic Tag Match", true)
			return true

	_debug_print_tag_result(log_tags, "No Active Topic Tag Match", false)
	return false

func _get_active_level_tags() -> Array[String]:
	var level_tags: Array[String] = []
	for tag in _active_tags:
		if tag.begins_with(TAG_LEVEL_PREFIX):
			level_tags.append(tag)
	return level_tags

func _get_active_topic_tags() -> Array[String]:
	var topic_tags: Array[String] = []
	for tag in _active_tags:
		if not tag.begins_with(TAG_LEVEL_PREFIX):
			topic_tags.append(tag)
	return topic_tags


func _debug_print_filter_check_start(level: LogLevel, level_tag: String) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Filtering check for level %s (tag: %s)[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[level], level_tag])
		print_rich("[color=#%s]  Current State: _current_level=%s, _active_tags=%s, _ignored_tags=%s[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[_current_level], _active_tags, _ignored_tags])

func _debug_print_filter_result(identifier: String, reason: String, result: bool) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]  Filter Decision (%s): %s -> %s[/color]" %
			[LoggerColors.DEBUG_HTML, reason, identifier, "SHOW" if result else "SKIP"])

func _debug_print_tag_check_start(log_tags: Array[String]) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Tag filtering check for log_tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, log_tags])
		print_rich("[color=#%s]  Current State: _active_tags=%s, _ignored_tags=%s[/color]" %
			[LoggerColors.DEBUG_HTML, _active_tags, _ignored_tags])

func _debug_print_tag_result(log_tags: Array[String], reason: String, result: bool) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]  Tag Filter Decision (%s): %s -> %s[/color]" %
			[LoggerColors.DEBUG_HTML, reason, log_tags, "SHOW" if result else "SKIP"])


func _add_to_buffer(log_data: Dictionary) -> void:
	_log_buffer.append(log_data)
	if _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

func _trim_buffer() -> void:
	var original_size: int = _log_buffer.size()
	while _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

	if original_size > _buffer_size:
		print_rich("[color=#%s]DEBUG: Buffer trimmed from %d to %d entries (max: %d)[/color]" %
			[LoggerColors.DEBUG_HTML, original_size, _log_buffer.size(), _buffer_size])

func _dump_buffer_async() -> void:
	var header_footer_color: String = LoggerColors.WARNING_HTML # Yellow for visibility
	var separator: String = "═".repeat(80) # Use double lines for more emphasis

	var platform: String = OS.get_name()
	var use_plain_formatting: bool = platform == "iOS" or platform == "Android"

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var dump_timestamp: String = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]

	if use_plain_formatting:
		print("\n" + separator)
		print("=== BUFFER DUMP (" + dump_timestamp + ") - Last " + str(_log_buffer.size()) + " entries ===")
		print(separator)
	else:
		print_rich("\n[color=#%s]%s[/color]" % [header_footer_color, separator])
		print_rich("[color=#%s]=== BUFFER DUMP (%s) - Last %d entries ===[/color]" %
			[header_footer_color, dump_timestamp, _log_buffer.size()])
		print_rich("[color=#%s]%s[/color]" % [header_footer_color, separator])

	var buffer_copy: Array = _log_buffer.duplicate(true) # Use deep copy for safety
	if buffer_copy.is_empty():
		if use_plain_formatting:
			print("  (Buffer is empty)")
		else:
			print_rich("[color=#%s]  (Buffer is empty)[/color]" % LoggerColors.TIMESTAMP_HTML)
	else:
		for entry_data in buffer_copy:
			var data_to_print: Dictionary = entry_data.duplicate(true)
			data_to_print["is_buffer_dump"] = true

			await _print_formatted_log_async(data_to_print)

	if use_plain_formatting:
		print(separator)
		print("=== END BUFFER DUMP ===")
		print(separator + "\n")
	else:
		print_rich("[color=#%s]%s[/color]" % [header_footer_color, separator])
		print_rich("[color=#%s]=== END BUFFER DUMP ===[/color]" % header_footer_color)
		print_rich("[color=#%s]%s[/color]\n" % [header_footer_color, separator])


func _get_source_info() -> Dictionary:
	var source_info := _create_default_source_info()
	var stack := get_stack()

	if stack.is_empty():
		return source_info

	var frame := _find_non_logger_frame(stack)
	if frame != null && !frame.is_empty():
		_update_source_info_from_frame(source_info, frame)

	return source_info


func _create_default_source_info() -> Dictionary:
	return {
		"file": "unknown",
		"line": 0,
		"function": "unknown"
	}


func _find_non_logger_frame(stack: Array) -> Dictionary:
	const SOURCE_KEY: String = "source"

	for frame in stack:
		if not frame.has(SOURCE_KEY):
			continue

		var source: String = frame.get(SOURCE_KEY)
		if not source.ends_with("logger.gd"):
			return frame

	return {}


func _update_source_info_from_frame(source_info: Dictionary, frame: Dictionary) -> void:
	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"
	const FUNCTION_KEY: String = "function"
	const SOURCE_KEY: String = "source"

	if frame.has(SOURCE_KEY):
		source_info[FILE_KEY] = frame.get(SOURCE_KEY)

	if frame.has(LINE_KEY):
		source_info[LINE_KEY] = int(frame.get(LINE_KEY, 0))

	if frame.has(FUNCTION_KEY):
		source_info[FUNCTION_KEY] = String(frame.get(FUNCTION_KEY, "unknown"))


func _configure_for_platform() -> void:
	var platform: String = OS.get_name()

	if platform == "Android":
		AndroidLoggerHelper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
		if AndroidLoggerHelper:
			AndroidLoggerHelper.configure_for_android(self)

	elif platform == "iOS":
		IosLoggerHelper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
		if IosLoggerHelper:
			IosLoggerHelper.configure_for_ios(self)
		else:
			if not Engine.is_editor_hint():
				_use_colors = false
				print("[Advanced Logger] Running on iOS - colors disabled")

func _print_formatted_log_async(log_data: Dictionary) -> void:
	var level: int = log_data.level
	var message: String = log_data.message
	var context: Dictionary = log_data.context
	var tags: Array[String] = log_data.tags
	var source_info: Dictionary = log_data.source_info
	var is_buffer_dump_entry: bool = log_data.get("is_buffer_dump", false)

	var timestamp_color_override: String = ""
	if is_buffer_dump_entry:
		timestamp_color_override = LoggerColors.WARNING_HTML # Use the header/footer color

	var formatted_log: String = LogFormatter.format_log(
		level,
		message,
		context,
		tags,
		source_info,
		_show_timestamp,
		_show_tags,
		_use_colors,
		_show_source,
		timestamp_color_override # Pass the override color
	)

	var platform: String = OS.get_name()

	if platform == "Android":
		if AndroidLoggerHelper:
			var processed_message: String
			if is_buffer_dump_entry:
				processed_message = AndroidLoggerHelper.process_log_message(
					level,
					"[BUFFER] " + message,
					context,
					tags
				)
			else:
				processed_message = AndroidLoggerHelper.process_log_message(
					level,
					message,
					context,
					tags
				)

			# Handle potentially chunked messages (multiple lines)
			var lines: PackedStringArray = processed_message.split('\n')
			_print_android_chunks_deferred(lines, 0)
		else:
			var plain_text = formatted_log.replace("[/color]", "").replace("[color=#", ">[")
			var regex: RegEx = RegEx.new()
			regex.compile("\\[color=#[0-9a-fA-F]+\\]")
			plain_text = regex.sub(plain_text, "", true)
			print(plain_text)

	elif platform == "iOS":
		if IosLoggerHelper:
			var ios_formatted = IosLoggerHelper.process_log_message(
				level,
				message,
				context,
				tags
			)
			print(ios_formatted)
		else:
			var plain_text = formatted_log.replace("[/color]", "").replace("[color=#", ">[")
			var regex: RegEx = RegEx.new()
			regex.compile("\\[color=#[0-9a-fA-F]+\\]")
			plain_text = regex.sub(plain_text, "", true)
			regex.compile("\\[(\\d+;)*\\d+m")
			plain_text = regex.sub(plain_text, "", true)
			print(plain_text)

	else:
		print_rich(formatted_log)


func set_level(level: LogLevel) -> Error:
	if !_is_valid_level(level):
		push_warning("Invalid log level: %d" % level)
		return Error.FAILED

	_current_level = level

	if _config != null:
		_config.set_log_level(level)

	return OK


func _is_valid_level(level: int) -> bool:
	return level >= LogLevel.DEBUG and level <= LogLevel.CRITICAL


func get_level() -> LogLevel:
	return _current_level


func add_tag(tag: String) -> Error:
	if not TagManager.is_valid_tag(tag):
		push_warning("Cannot add invalid tag: '%s'" % tag)
		return Error.ERR_INVALID_PARAMETER
	if _active_tags.has(tag):
		return Error.ERR_ALREADY_EXISTS

	var was_ignored = _ignored_tags.has(tag)
	if was_ignored:
		_ignored_tags.erase(tag)

	_active_tags.append(tag)

	_update_active_tags_in_config()
	if was_ignored: # Update ignored config only if it was actually removed
		_update_ignored_tags_in_config()

	return OK

func remove_tag(tag: String) -> Error:
	if not _active_tags.has(tag):
		return Error.ERR_DOES_NOT_EXIST # Tag wasn't active

	_active_tags.erase(tag)

	_update_active_tags_in_config()

	return OK

func clear_tags() -> void:
	_active_tags.clear()
	_update_active_tags_in_config()

func add_ignored_tag(tag: String) -> Error:
	if not TagManager.is_valid_tag(tag):
		push_warning("Cannot add invalid ignored tag: '%s'" % tag)
		return Error.ERR_INVALID_PARAMETER
	if _ignored_tags.has(tag):
		return Error.ERR_ALREADY_EXISTS

	var was_active = _active_tags.has(tag)
	if was_active:
		_active_tags.erase(tag)

	_ignored_tags.append(tag)

	_update_ignored_tags_in_config()
	if was_active: # Update active config only if it was actually removed
		_update_active_tags_in_config()

	return OK

func remove_ignored_tag(tag: String) -> Error:
	if not _ignored_tags.has(tag):
		return Error.ERR_DOES_NOT_EXIST # Tag wasn't ignored

	_ignored_tags.erase(tag)

	_update_ignored_tags_in_config()

	return OK

func clear_ignored_tags() -> void:
	_ignored_tags.clear()
	_update_ignored_tags_in_config()


func _update_active_tags_in_config() -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Updating active tags in config: %s[/color]" %
			[LoggerColors.DEBUG_HTML, _active_tags])

	if _config != null:
		_config.set_active_tags(_active_tags)


func _update_ignored_tags_in_config() -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Updating ignored tags in config: %s[/color]" %
			[LoggerColors.DEBUG_HTML, _ignored_tags])

	if _config != null:
		_config.set_ignored_tags(_ignored_tags)


func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show
	_update_format_setting(ConfigManager.KEY_SHOW_TIMESTAMP, show)


func set_show_tags(show: bool) -> void:
	_show_tags = show
	_update_format_setting(ConfigManager.KEY_SHOW_TAGS, show)


func set_use_colors(use: bool) -> void:
	_use_colors = use
	_update_format_setting(ConfigManager.KEY_USE_COLORS, use)


func set_show_source(show: bool) -> void:
	_show_source = show
	_update_format_setting(ConfigManager.KEY_SHOW_SOURCE, show)

func set_buffer_size(size: int) -> Error:
	if size < 1:
		push_warning("Invalid buffer size: %d. Buffer size must be at least 1." % size)
		return Error.FAILED

	_buffer_size = size
	_trim_buffer() # Adjust buffer immediately

	_has_custom_buffer_size = true

	if _config != null:
		_config.set_buffer_size(size)

	return OK

func get_buffer_size() -> int:
	return _buffer_size

func set_enable_buffer_dump(enable: bool) -> void:
	_enable_buffer_dump = enable
	_has_custom_buffer_dump = true

	if _config != null:
		_config.set_enable_buffer_dump(enable)

func get_enable_buffer_dump() -> bool:
	return _enable_buffer_dump

func set_debug_filter_logging(enable: bool) -> void:
	_debug_filter_logging = enable

	print("============================================")
	if enable:
		print_rich("[color=#%s]Advanced Logger debug filter logging ENABLED[/color]" %
			LoggerColors.SUCCESS_HTML)

		print_rich("[color=#%s]Current state: log level=%s, active_tags=%s, ignored_tags=%s[/color]" %
			[LoggerColors.INFO_HTML, LogLevel.keys()[_current_level], _active_tags, _ignored_tags])
	else:
		print_rich("[color=#%s]Advanced Logger debug filter logging DISABLED[/color]" %
			LoggerColors.INFO_HTML)
	print("============================================")

	if enable:
		print_rich("[color=#%s]TESTING: Debug filter logging is active. This message should appear.[/color]" %
			LoggerColors.WARNING_HTML)


func _update_format_setting(key: String, value: bool) -> void:
	if _config != null:
		_config.set_value(ConfigManager.SECTION_FORMAT, key, value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _config != null:
			if is_instance_valid(_config) and _config.has_signal("config_changed"):
				if _config.config_changed.is_connected(_on_config_changed):
					_config.config_changed.disconnect(_on_config_changed)
			_config = null

# Android chunk processing queue - stores chunks to be printed across frames
var _android_chunk_queue: Array = []
var _chunk_timer = null  # Processing flag - null when idle, non-null when processing chunks

# Process Android chunks with frame spacing to avoid rate limiting (non-blocking)
func _print_android_chunks_deferred(lines: Array, index: int) -> void:
	# Add all remaining chunks to queue
	for i in range(index, lines.size()):
		var line = lines[i]
		if not line.is_empty():
			_android_chunk_queue.append(line)

	# Start processing first chunk if queue isn't already being processed
	if not _android_chunk_queue.is_empty() and _chunk_timer == null:
		# Use a flag to prevent multiple concurrent processing chains
		_chunk_timer = self  # Use as a processing flag
		call_deferred("_process_next_android_chunk")

# Process one chunk from queue per frame using call_deferred (non-blocking)
func _process_next_android_chunk() -> void:
	if _android_chunk_queue.is_empty():
		# Queue empty - clear processing flag
		_chunk_timer = null
		# Emit completion signal when all chunks are processed
		android_chunks_processing_complete.emit()
		return

	# Print next chunk
	var line = _android_chunk_queue.pop_front()
	print(line)

	# Process next chunk on next frame if queue isn't empty
	if not _android_chunk_queue.is_empty():
		call_deferred("_process_next_android_chunk")
	else:
		# Queue empty - clear processing flag
		_chunk_timer = null
		# Emit completion signal when all chunks are processed
		android_chunks_processing_complete.emit()

# Chunk processing status methods for automated test logging
func has_pending_android_chunks() -> bool:
	"""Check if there are pending Android chunks waiting to be processed"""
	return not _android_chunk_queue.is_empty() or _chunk_timer != null

func get_android_chunk_count() -> int:
	"""Get the number of pending Android chunks in the processing queue"""
	return _android_chunk_queue.size()

func wait_for_chunk_processing_complete_signal() -> void:
	"""Wait for Android chunk processing to complete using signal - no timeout

	IMPORTANT: This function must be completely silent (no logging) because:
	1. Any logging creates new chunks in the queue
	2. This creates a recursive problem where waiting for chunks generates more chunks
	3. The function is called after every action, so logging here would break DEBUG_TEST_SUCCESS
	"""
	if not has_pending_android_chunks():
		# No chunks pending - immediate return
		return

	# Wait for the completion signal silently
	await android_chunks_processing_complete

func wait_for_chunk_processing_complete(timeout_seconds: float = 2.0) -> void:
	"""Wait for Android chunk processing queue to complete with timeout (DEPRECATED - use signal version)

	This function blocks execution until all Android chunks have been processed,
	ensuring DEBUG_TEST_SUCCESS logs are not lost during automated test termination.
	Only waits if chunks are pending to avoid unnecessary delays in manual testing.
	"""
	if not has_pending_android_chunks():
		# No chunks pending - immediate return
		return

	var start_time: float = Time.get_ticks_msec() / 1000.0
	var timeout_reached: bool = false

	debug(
		"Waiting for Android chunk processing to complete",
		{
			"initial_chunk_count": get_android_chunk_count(),
			"timeout_seconds": timeout_seconds,
			"start_time": start_time
		},
		[TAG_ANDROID, TAG_TEST, TAG_AUTOMATED]
	)

	# Wait for chunk processing to complete
	while has_pending_android_chunks() and not timeout_reached:
		# Process one frame to allow chunk timer to execute
		await Engine.get_main_loop().process_frame

		# Check timeout
		var elapsed_time: float = (Time.get_ticks_msec() / 1000.0) - start_time
		timeout_reached = elapsed_time >= timeout_seconds

		if timeout_reached:
			warning(
				"Android chunk processing timeout reached",
				{
					"remaining_chunks": get_android_chunk_count(),
					"elapsed_seconds": elapsed_time,
					"timeout_seconds": timeout_seconds
				},
				[TAG_ANDROID, TAG_TEST, TAG_AUTOMATED]
			)
			break

	var final_elapsed: float = (Time.get_ticks_msec() / 1000.0) - start_time

	if not timeout_reached:
		debug(
			"Android chunk processing completed successfully",
			{
				"elapsed_seconds": final_elapsed,
				"all_chunks_processed": not has_pending_android_chunks()
			},
			[TAG_ANDROID, TAG_TEST, TAG_AUTOMATED]
		)
	else:
		error(
			"Android chunk processing incomplete due to timeout",
			{
				"elapsed_seconds": final_elapsed,
				"remaining_chunks": get_android_chunk_count(),
				"chunks_still_pending": has_pending_android_chunks()
			},
			[TAG_ANDROID, TAG_TEST, TAG_AUTOMATED, TAG_ERROR]
		)


# Graceful shutdown method that encapsulates all platform-specific logging cleanup
func shutdown_gracefully(timeout_seconds: float = 2.0) -> void:
	"""Gracefully shutdown logger with platform-specific chunk processing completion

	This method encapsulates all platform-specific logging cleanup logic, providing
	a clean interface for quit sequences. It handles Android chunk processing
	internally without exposing implementation details to callers.

	Args:
		timeout_seconds: Maximum time to wait for chunk processing (default: 2.0)
	"""
	var platform: String = OS.get_name()

	info(
		"Logger shutdown initiated",
		{
			"platform": platform,
			"timeout_seconds": timeout_seconds,
			"timestamp": Time.get_unix_time_from_system()
		},
		[TAG_QUIT, TAG_SYSTEM, TAG_DEBUG]
	)

	if platform == "Android":
		info(
			"Android platform detected - ensuring chunk processing completion",
			{
				"chunks_pending": get_android_chunk_count(),
				"has_pending": has_pending_android_chunks(),
				"platform": "Android"
			},
			[TAG_ANDROID, TAG_QUIT, TAG_DEBUG]
		)

		# Use signal-based mechanism - wait for all chunks to complete
		if has_pending_android_chunks():
			await android_chunks_processing_complete

			# Note: Do NOT log completion here - any logging (even print) goes through chunk queue
			# and creates a recursive problem. Silent completion is the correct approach.
		else:
			info(
				"No Android chunks pending - immediate completion",
				{"platform": "Android"},
				[TAG_ANDROID, TAG_QUIT, TAG_DEBUG]
			)
	else:
		info(
			"Desktop platform detected - no chunk processing required",
			{"platform": platform},
			[TAG_QUIT, TAG_DEBUG]
		)

	info(
		"Logger shutdown completed gracefully",
		{
			"platform": platform,
			"logging_synchronized": true,
			"final_timestamp": Time.get_unix_time_from_system()
		},
		[TAG_QUIT, TAG_SYSTEM, TAG_DEBUG]
	)
