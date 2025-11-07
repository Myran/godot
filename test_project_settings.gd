extends SceneTree

func _ready():
	print("=== TEST_PROJECT_SETTINGS: Starting ===")

	# Test the exact ProjectSettings structure from project.godot
	var all_settings = ProjectSettings.get_setting("")
	print("=== TEST_PROJECT_SETTINGS: All settings count: ", ProjectSettings.get_setting("").size(), " ===")

	# Try different patterns
	var dsn1 = ProjectSettings.get_setting("sentry/android/dsn", "NOT_FOUND_1")
	var dsn2 = ProjectSettings.get_setting("android/dsn", "NOT_FOUND_2")
	var dsn3 = ProjectSettings.get_setting("sentry/dsn", "NOT_FOUND_3")

	print("=== TEST_PROJECT_SETTINGS: sentry/android/dsn: ", dsn1, " ===")
	print("=== TEST_PROJECT_SETTINGS: android/dsn: ", dsn2, " ===")
	print("=== TEST_PROJECT_SETTINGS: sentry/dsn: ", dsn3, " ===")

	# Test if the sentry section exists
	var sentry_settings = ProjectSettings.get_setting("sentry", null)
	if sentry_settings:
		print("=== TEST_PROJECT_SETTINGS: sentry section exists: ", sentry_settings, " ===")
	else:
		print("=== TEST_PROJECT_SETTINGS: sentry section NOT found ===")

	quit()