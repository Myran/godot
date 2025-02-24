# res://addons/advanced_logger/logger_test.gd
extends Node


func _ready() -> void:
	print("\n=== Starting Log.Self-Test ===\n")

	# Test basic logging levels
	Log.debug("Testing debug level")
	Log.info("Testing info level")
	Log.warning("Testing warning level")

	# Test context data
	Log.info(
		"Testing context data",
		{"number": 42, "text": "Hello", "vector": Vector2(100, 200), "array": [1, 2, 3]}
	)

	# Test tag system
	Log.add_tag("test")
	Log.add_tag("system")

	Log.info("Message with tags", {"test_id": 1}, ["test"])

	Log.info("Message with multiple tags", {"system_status": "ok"}, ["test", "system"])

	# Test error with retroactive display
	Log.debug("This message will appear in retroactive display")
	Log.info("This message will also appear in retroactive display")
	Log.error(
		"Testing error - should trigger retroactive display",
		{"error_code": 404, "details": "Not found"}
	)

	# Test tag removal
	Log.remove_tag("test")
	Log.info("This message won't show with 'test' tag", {}, ["test"])
	Log.info("But this one will show with 'system' tag", {}, ["system"])

	# Test critical error
	Log.critical(
		"Testing critical error",
		{"error_code": 500, "details": "Server error", "stacktrace": "..."},
		["system"]
	)

	Log.clear_tags()
	print("\n=== Log.Self-Test Complete ===\n")
