class_name SentryHelper
extends RefCounted
## Utility class for safe SentrySDK singleton access across GameTwo systems.
##
## Provides defensive access patterns to prevent crashes when Sentry unavailable.
## Used by Advanced Logger, Firebase Auth, and debug actions for consistent
## Sentry integration across the codebase.
##
## Example usage:
## [codeblock]
## # Capture an error message
## if SentryHelper.capture_message("Database connection failed", "error"):
##     print("Error sent to Sentry")
##
## # Set user context from Firebase auth
## var user_dict = {"id": firebase_uid, "email": user_email}
## SentryHelper.set_user(user_dict)
## [/codeblock]


static func is_available() -> bool:
	## Check if SentrySDK singleton is available.
	##
	## Returns true if SentrySDK is loaded and accessible, false otherwise.
	## Use this before calling other methods if you need to know availability.
	return Engine.has_singleton("SentrySDK")


static func get_sdk() -> Variant:
	## Get SentrySDK singleton instance. Returns null if unavailable.
	##
	## Prefer using the specific helper methods (capture_message, set_user, etc.)
	## over accessing the SDK directly. This method is provided for advanced use cases.
	if not is_available():
		return null
	return Engine.get_singleton("SentrySDK")


static func _level_to_enum(level: String) -> int:
	## Convert string level to SentrySDK enum value.
	## Internal helper for capture_message().
	var sentry: Variant = get_sdk()
	if not sentry:
		return 0  # Default to DEBUG if SDK unavailable

	# Map string levels to SentrySDK enum constants
	match level.to_lower():
		"debug":
			return sentry.LEVEL_DEBUG
		"info":
			return sentry.LEVEL_INFO
		"warning":
			return sentry.LEVEL_WARNING
		"error":
			return sentry.LEVEL_ERROR
		"fatal":
			return sentry.LEVEL_FATAL
		_:
			return sentry.LEVEL_ERROR  # Default to ERROR for unknown levels


static func capture_message(message: String, level: String = "error") -> bool:
	## Capture a message event in Sentry.
	##
	## Args:
	##     message: The message to send to Sentry
	##     level: Severity level - "debug", "info", "warning", "error", "fatal"
	##
	## Returns:
	##     true if message was sent, false if Sentry unavailable or method missing
	var sentry: Variant = get_sdk()
	if not sentry:
		return false

	if not sentry.has_method("capture_message"):
		return false

	# Convert string level to enum value
	var level_enum: int = _level_to_enum(level)
	sentry.capture_message(message, level_enum)
	return true


static func set_user(user_dict: Dictionary) -> bool:
	## Set user context for all future Sentry events.
	##
	## User context helps correlate errors with specific users for debugging.
	##
	## Args:
	##     user_dict: Dictionary with keys "id", "email", "username"
	##                Pass empty dict {} to clear user context
	##
	## Returns:
	##     true if user context set, false if Sentry unavailable
	##
	## Example:
	## [codeblock]
	## SentryHelper.set_user({
	##     "id": "firebase_uid_123",
	##     "email": "user@example.com",
	##     "username": "player_name"
	## })
	## [/codeblock]
	var sentry: Variant = get_sdk()
	if not sentry:
		return false

	# Handle empty dict case (clear user context)
	if user_dict.is_empty():
		if sentry.has_method("remove_user"):
			sentry.remove_user()
		return true

	if not sentry.has_method("set_user"):
		return false

	# Create SentryUser object from Dictionary (fixes type conversion error)
	var user: SentryUser = SentryUser.new()
	if user_dict.has("id"):
		user.id = user_dict.get("id", "")
	if user_dict.has("email"):
		user.email = user_dict.get("email", "")
	if user_dict.has("username"):
		user.username = user_dict.get("username", "")

	sentry.set_user(user)
	return true


static func set_tag(key: String, value: String) -> bool:
	## Set a tag on all future Sentry events.
	##
	## Tags are searchable/filterable metadata attached to events.
	## Use for categorical data like platform, auth state, game mode, etc.
	##
	## Args:
	##     key: Tag key (e.g., "auth_state", "platform", "game_mode")
	##     value: Tag value (should be relatively low cardinality)
	##
	## Returns:
	##     true if tag set, false if Sentry unavailable
	##
	## Example:
	## [codeblock]
	## SentryHelper.set_tag("auth_state", "signed_in")
	## SentryHelper.set_tag("platform", "android")
	## [/codeblock]
	var sentry: Variant = get_sdk()
	if not sentry:
		return false

	if not sentry.has_method("set_tag"):
		return false

	sentry.set_tag(key, value)
	return true


static func set_tags(tags_dict: Dictionary) -> bool:
	## Set multiple tags at once.
	##
	## More efficient than calling set_tag() multiple times.
	##
	## Args:
	##     tags_dict: Dictionary of tag key-value pairs
	##
	## Returns:
	##     true if tags set, false if Sentry unavailable
	##
	## Example:
	## [codeblock]
	## SentryHelper.set_tags({
	##     "auth_state": "signed_in",
	##     "platform": "android",
	##     "game_mode": "battle"
	## })
	## [/codeblock]
	var sentry: Variant = get_sdk()
	if not sentry:
		return false

	if not sentry.has_method("set_tags"):
		return false

	sentry.set_tags(tags_dict)
	return true


static func set_context(context_name: String, context_data: Dictionary) -> bool:
	## Set contextual data for all future Sentry events.
	##
	## Context provides structured additional data attached to events.
	## Use for data that doesn't fit well as tags (high cardinality, nested data).
	##
	## Args:
	##     context_name: Context category (e.g., "log_context", "game_state", "device")
	##     context_data: Dictionary of context data
	##
	## Returns:
	##     true if context set, false if Sentry unavailable
	##
	## Example:
	## [codeblock]
	## SentryHelper.set_context("game_state", {
	##     "level": 5,
	##     "score": 12500,
	##     "lives_remaining": 3
	## })
	## [/codeblock]
	var sentry: Variant = get_sdk()
	if not sentry:
		return false

	if not sentry.has_method("set_context"):
		return false

	sentry.set_context(context_name, context_data)
	return true
