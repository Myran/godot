# res://addons/advanced_logger/logger_test.gd
extends Node

signal tests_completed

var _should_run_tests: bool = true
var _logger_ready: bool = false
var _initialization_attempts: int = 0
var _max_attempts: int = 10
var _check_interval: float = 0.2  # seconds
var _tests_already_run: bool = false

func _ready() -> void:
	print("Logger test script initialized")

	# If max_attempts is 0, we're being run manually
	if _max_attempts == 0:
		print("Manual test run detected, skipping initialization checks")
		_logger_ready = true
		if _should_run_tests and not _tests_already_run:
			run_tests()
		return

	# Otherwise, perform regular initialization
	# Check if tests should run
	_should_run_tests = LoggerSettings.should_run_tests()

	if _should_run_tests and not _tests_already_run:
		# Start checking if logger is ready
		_check_logger_readiness()
	else:
		print_rich("[color=gray]Logger self-tests disabled. Enable in Logger panel settings.[/color]")

func _check_logger_readiness() -> void:
	# Try to get the Log singleton
	var logger = Engine.get_singleton("Log")

	# More robust check for logger readiness
	if logger and logger._buffer and logger._buffer.buffer.size() > 0:
		# Logger appears ready
		_logger_ready = true
		print("Logger instance verified as ready")
		run_tests()
	else:
		# Print diagnostic information
		print("Logger readiness check " + str(_initialization_attempts) + ": " +
			"Logger null? " + str(logger == null) +
			", Buffer null? " + str(logger and logger._buffer == null))

		# Logger not ready yet, try again
		_initialization_attempts += 1
		if _initialization_attempts < _max_attempts:
			print_rich("[color=yellow]Waiting for Logger to initialize (attempt %d/%d)...[/color]" %
				[_initialization_attempts, _max_attempts])
			get_tree().create_timer(_check_interval).timeout.connect(_check_logger_readiness)
		else:
			push_error("Logger not ready after %d attempts. Skipping tests." % _max_attempts)


func run_tests() -> void:
	if _tests_already_run:
		print("Tests have already been run, skipping repeat execution")
		tests_completed.emit()
		return

	_tests_already_run = true
	print_rich("\n[color=green]=== Starting Log.Self-Test ===\n[/color]")

	# Ensure logger is in testing mode for reliable output
	var logger = Engine.get_singleton("Log")
	if logger:
		if logger.has_method("enable_testing_mode"):
			logger.enable_testing_mode()

	# Simple test to verify rich text works
	print("Plain text test")
	print_rich("[color=red]This should be red[/color]")

	# Test basic logging levels - add direct prints to see if logs are generated
	print_rich("[color=gray]Testing debug level[/color]")
	Log.debug("Testing debug level")

	print_rich("[color=blue]Testing info level[/color]")
	Log.info("Testing info level")

	print_rich("[color=yellow]Testing warning level[/color]")
	Log.warning("Testing warning level")

	# Test context data
	print_rich("[color=blue]Testing context data[/color]")
	Log.info(
		"Testing context data",
		{"number": 42, "text": "Hello", "vector": Vector2(100, 200), "array": [1, 2, 3]}
	)

	# Continue with rest of the tests...

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

	# Restore normal mode if supported
	if logger and logger.has_method("disable_testing_mode"):
		logger.disable_testing_mode()

	print_rich("\n[color=green]=== Log.Self-Test Complete ===\n[/color]")

	# Signal that tests are complete
	tests_completed.emit()
