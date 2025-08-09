@tool
class_name LoggerPlatformTest
extends RefCounted

static func test_platforms() -> void:
	print("\n=== Advanced Logger Platform Test ===")
	print("Current platform: ", OS.get_name())

	var android_helper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
	if android_helper:
		print("Android helper loaded - is_android: ", android_helper.is_android())
		print("Android config path: ", android_helper.get_config_path())
	else:
		print("Android helper not found")

	var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
	if ios_helper:
		print("iOS helper loaded - is_ios: ", ios_helper.is_ios())
		print("iOS config path: ", ios_helper.get_config_path())
	else:
		print("iOS helper not found")

	print("=== End Platform Test ===\n")

static func test_message_formatting() -> void:
	print("\n=== Advanced Logger Message Formatting Test ===")

	var original = "[color=#ff0000]ERROR[/color] Test message [color=#00ff00]with colors[/color]"

	print("Original message: ", original)

	var android_helper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
	if android_helper:
		var android_formatted = android_helper.strip_formatting(original)
		print("Android formatted: ", android_formatted)

	var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
	if ios_helper:
		var ios_formatted = ios_helper.strip_formatting(original)
		print("iOS formatted: ", ios_formatted)

		var ios_processed = ios_helper.process_log_message(
			3, # ERROR level
			"Test error message",
			{"key": "value"}
		)
		print("iOS processed: ", ios_processed)

	print("=== End Message Formatting Test ===\n")

static func run_all_tests() -> void:
	test_platforms()
	test_message_formatting()
