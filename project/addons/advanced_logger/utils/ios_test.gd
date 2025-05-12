@tool
class_name IosLoggerTest
extends RefCounted
## Test utility for iOS logger formatting

## Run a test to verify iOS formatting handling
static func test_ios_formatting():
	print("\n=== iOS LOGGER FORMATTING TEST ===")

	# Load helpers
	var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
	if not ios_helper:
		print("ERROR: Could not load iOS helper")
		return

	# Test messages with various formatting
	var test_messages = [
		"[color=#ff0000]This has BBCode formatting[/color]",
		"[38;2;216;166;87m]This has ANSI color codes[39m",
		"Normal message with no formatting",
		"Mixed [color=#00ff00]BBCode[/color] and [38;2;216;166;87m]ANSI codes[39m",
		"[color=#ff0000]Nested [color=#00ff00]BBCode[/color] formatting[/color]"
	]

	print("Testing iOS formatting stripping...")
	for msg in test_messages:
		var stripped = ios_helper.strip_formatting(msg)
		print("Original: " + msg)
		print("Stripped: " + stripped)
		print("---")

	print("Testing iOS message processing...")
	var test_contexts = [
		{},
		{"status": "ok"},
		{"error_code": 404, "message": "Not found"}
	]

	for i in range(test_messages.size()):
		var msg = test_messages[i]
		var ctx = test_contexts[i % test_contexts.size()]
		var processed = ios_helper.process_log_message(1, msg, ctx)
		print("Original: " + msg + " | Context: " + str(ctx))
		print("Processed: " + processed)
		print("---")

	print("=== END iOS LOGGER FORMATTING TEST ===\n")

	return "Test completed successfully"

## Entry point - run all tests
static func run_tests():
	var result = test_ios_formatting()
	return result
