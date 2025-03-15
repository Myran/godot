@tool
extends Node
class_name TestLogFormatting

# This test validates log formatting functionality
# which is a candidate for refactoring

var Logger = preload("res://addons/advanced_logger/logger.gd")

func _ready():
	print("\n=== Running Log Formatting Tests ===")
	test_timestamp_formatting()
	test_log_level_formatting()
	test_tags_formatting()
	test_formatting_options()
	print("=== Log Formatting Tests Complete ===\n")

# Create a Logger instance with specific configurations
func create_logger_instance(options: Dictionary = {}) -> Logger:
	var logger = Logger.new()
	
	# Apply configuration options
	if options.has("show_timestamp"):
		logger.set_show_timestamp(options.show_timestamp)
	
	if options.has("show_tags"):
		logger.set_show_tags(options.show_tags)
	
	if options.has("use_colors"):
		logger.set_use_colors(options.use_colors)
	
	if options.has("show_source"):
		logger.set_show_source(options.show_source)
		
	return logger

# Helper to clean and normalize log output for testing
func clean_log_output(log_output: String) -> String:
	# Remove color codes and other formatting
	var regex = RegEx.new()
	regex.compile("\\[color=#[0-9a-fA-F]+\\]|\\[/color\\]")
	var cleaned = regex.sub(log_output, "", true)
	return cleaned.strip_edges()

# Test timestamp formatting
func test_timestamp_formatting():
	print("\nTesting timestamp formatting:")
	
	var logger = create_logger_instance({
		"show_timestamp": true,
		"use_colors": false
	})
	
	# Mock the _get_source_info to return consistent data
	logger._get_source_info = func():
		return {"file": "test_file.gd", "line": 42, "function": "test_func"}
	
	# Override to capture the output
	var captured_output = ""
	logger.print_rich = func(text: String) -> void:
		captured_output = text
	
	# Call the output function with test data
	logger._output_log(
		Logger.LogLevel.INFO,
		"Test message",
		{},
		[],
		logger._get_source_info.call()
	)
	
	# Verify timestamp format (YYYY-MM-DD HH:MM:SS)
	var timestamp_regex = RegEx.new()
	timestamp_regex.compile("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}")
	var has_timestamp = timestamp_regex.search(captured_output) != null
	
	print("- Contains timestamp: %s %s" % [has_timestamp, "✓" if has_timestamp else "✗"])
	
	# Now test without timestamp
	logger.set_show_timestamp(false)
	
	logger._output_log(
		Logger.LogLevel.INFO,
		"Test message",
		{},
		[],
		logger._get_source_info.call()
	)
	
	var has_no_timestamp = timestamp_regex.search(captured_output) == null
	
	print("- Omits timestamp when disabled: %s %s" % [has_no_timestamp, "✓" if has_no_timestamp else "✗"])
	
	print("Timestamp formatting test: %s" % ("PASSED" if has_timestamp && has_no_timestamp else "FAILED"))

# Test log level formatting
func test_log_level_formatting():
	print("\nTesting log level formatting:")
	
	var logger = create_logger_instance({
		"show_timestamp": false,
		"use_colors": false
	})
	
	# Mock the _get_source_info to return consistent data
	logger._get_source_info = func():
		return {"file": "test_file.gd", "line": 42, "function": "test_func"}
	
	# Test each log level
	var results = []
	var log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
	
	for i in range(log_levels.size()):
		# Override to capture the output
		var captured_output = ""
		logger.print_rich = func(text: String) -> void:
			captured_output = text
		
		# Call the output function with test data
		logger._output_log(
			i,  # Log level enum value
			"Test message",
			{},
			[],
			logger._get_source_info.call()
		)
		
		var cleaned_output = clean_log_output(captured_output)
		var level_name = log_levels[i]
		var contains_level = cleaned_output.begins_with(level_name) || cleaned_output.contains(" " + level_name + " ")
		
		results.append(contains_level)
		print("- %s level formatting: %s %s" % [level_name, contains_level, "✓" if contains_level else "✗"])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Log level formatting test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test tags formatting
func test_tags_formatting():
	print("\nTesting tags formatting:")
	
	var logger = create_logger_instance({
		"show_timestamp": false,
		"show_tags": true,
		"use_colors": false
	})
	
	# Mock the _get_source_info to return consistent data
	logger._get_source_info = func():
		return {"file": "test_file.gd", "line": 42, "function": "test_func"}
	
	# Test cases for tags
	var test_cases = [
		{"tags": ["network"], "description": "Single tag"},
		{"tags": ["database", "cache"], "description": "Multiple tags"}
	]
	
	var results = []
	for case in test_cases:
		# Override to capture the output
		var captured_output = ""
		logger.print_rich = func(text: String) -> void:
			captured_output = text
		
		# Call the output function with test data
		logger._output_log(
			Logger.LogLevel.INFO,
			"Test message",
			{},
			case.tags,
			logger._get_source_info.call()
		)
		
		var cleaned_output = clean_log_output(captured_output)
		
		# For single tag
		if case.tags.size() == 1:
			var contains_tag = cleaned_output.contains("[" + case.tags[0] + "]")
			results.append(contains_tag)
			print("- %s: %s %s" % [case.description, contains_tag, "✓" if contains_tag else "✗"])
		
		# For multiple tags
		elif case.tags.size() > 1:
			var tag_section = "[" + ", ".join(case.tags) + "]"
			var contains_tags = cleaned_output.contains(tag_section)
			results.append(contains_tags)
			print("- %s: %s %s" % [case.description, contains_tags, "✓" if contains_tags else "✗"])
	
	# Test with tags disabled
	logger.set_show_tags(false)
	
	var captured_output = ""
	logger.print_rich = func(text: String) -> void:
		captured_output = text
	
	logger._output_log(
		Logger.LogLevel.INFO,
		"Test message",
		{},
		["network", "database"],
		logger._get_source_info.call()
	)
	
	var cleaned_output = clean_log_output(captured_output)
	var tags_omitted = !cleaned_output.contains("[network, database]")
	results.append(tags_omitted)
	print("- Tags omitted when disabled: %s %s" % [tags_omitted, "✓" if tags_omitted else "✗"])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Tags formatting test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test formatting options combinations
func test_formatting_options():
	print("\nTesting formatting options combinations:")
	
	var options_sets = [
		{
			"description": "All formatting on",
			"options": {
				"show_timestamp": true,
				"show_tags": true,
				"use_colors": true,
				"show_source": true
			}
		},
		{
			"description": "All formatting off",
			"options": {
				"show_timestamp": false,
				"show_tags": false,
				"use_colors": false,
				"show_source": false
			}
		},
		{
			"description": "Mixed options (timestamp off, tags on)",
			"options": {
				"show_timestamp": false,
				"show_tags": true,
				"use_colors": true,
				"show_source": false
			}
		}
	]
	
	var results = []
	for option_set in options_sets:
		var logger = create_logger_instance(option_set.options)
		
		# Mock the _get_source_info to return consistent data
		logger._get_source_info = func():
			return {"file": "test_file.gd", "line": 42, "function": "test_func"}
		
		# Override to capture the output
		var captured_output = ""
		logger.print_rich = func(text: String) -> void:
			captured_output = text
		
		# Call the output function with test data
		logger._output_log(
			Logger.LogLevel.INFO,
			"Test message",
			{},
			["network", "database"],
			logger._get_source_info.call()
		)
		
		var test_valid = true
		
		# Check timestamp presence based on options
		var contains_timestamp = captured_output.contains("20") && captured_output.contains(":")
		if option_set.options.show_timestamp && !contains_timestamp:
			test_valid = false
		elif !option_set.options.show_timestamp && contains_timestamp:
			test_valid = false
			
		# Check source info presence based on options
		var contains_source = captured_output.contains("test_file.gd") && captured_output.contains("42")
		if option_set.options.show_source && !contains_source:
			test_valid = false
		elif !option_set.options.show_source && contains_source:
			test_valid = false
			
		# Check tags presence based on options
		var contains_tags = captured_output.contains("[network, database]") || captured_output.contains("[database, network]")
		if option_set.options.show_tags && !contains_tags:
			test_valid = false
		
		results.append(test_valid)
		print("- %s: %s %s" % [
			option_set.description,
			test_valid,
			"✓" if test_valid else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Formatting options test: %s" % ("PASSED" if all_passed else "FAILED"))
