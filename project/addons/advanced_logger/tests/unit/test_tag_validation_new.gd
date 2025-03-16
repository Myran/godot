@tool
extends Node
class_name TestTagValidationNew

# This test validates tag validation functionality using the TagManager
# Note: This replaces the old test that used LoggerSettings directly

var TagManager = preload("res://addons/advanced_logger/tag_manager.gd")

func _ready():
	print("\n=== Running Tag Validation Tests (TagManager) ===")
	test_valid_tags()
	test_invalid_tags()
	test_edge_cases()
	print("=== Tag Validation Tests Complete ===\n")

func test_valid_tags():
	print("\nTesting valid tags:")

	var valid_tags = [
		"network",
		"database",
		"cache",
		"user_auth",
		"api_calls",
		"game_logic",
		"physics-engine",
		"ai_behavior",
		"ui_events",
		"performance",
		"debug123",
		"networK_ALL"
	]

	var validation_results = []
	for tag in valid_tags:
		var is_valid = TagManager.is_valid_tag(tag)
		validation_results.append(is_valid)
		print("- Tag: '%s' | Valid: %s %s" % [
			tag,
			is_valid,
			"✓" if is_valid else "✗"
		])

	var all_passed = true
	for result in validation_results:
		if result == false:
			all_passed = false
			break
	print("Valid tags test: %s" % ("PASSED" if all_passed else "FAILED"))

func test_invalid_tags():
	print("\nTesting invalid tags:")

	var invalid_tags = [
		"", # empty
		" ", # space
		"network space", # contains space
		"database!", # contains special character
		"cache#123", # contains special character
		"user@auth", # contains special character
		"api.calls", # contains period
		"game/logic", # contains slash
		"physics>engine", # contains comparison operator
	]

	# Also test non-string values using a safe wrapper approach
	var non_string_values = [
		123, # integer
		null # null
	]

	# Test regular invalid strings first
	var validation_results = []
	for tag in invalid_tags:
		var is_valid = TagManager.is_valid_tag(tag)
		validation_results.append(!is_valid) # Expecting to be invalid
		print("- Tag: '%s' | Invalid: %s %s" % [
			tag,
			!is_valid,
			"✓" if !is_valid else "✗"
		])

	# Now test non-string values safely
	for value in non_string_values:
		# Create a safe wrapper to handle type errors
		var is_valid = false

		# In GDScript 4, try-except is more limited, so we'll test more directly
		# This approach assumes is_valid_tag properly returns false for non-string values
		is_valid = TagManager.is_valid_tag(value)
		validation_results.append(!is_valid) # Non-string should be invalid

		print("- Non-string value: '%s' | Invalid: %s %s" % [
			str(value),
			!is_valid,
			"✓" if !is_valid else "✗"
		])

	var all_passed = true
	for result in validation_results:
		if result == false:
			all_passed = false
			break
	print("Invalid tags test: %s" % ("PASSED" if all_passed else "FAILED"))

func test_edge_cases():
	print("\nTesting edge cases:")

	var edge_cases = [
		{"tag": "a", "expected": true, "description": "Single character"},
		{"tag": "A", "expected": true, "description": "Single uppercase character"},
		{"tag": "1", "expected": true, "description": "Single digit"},
		{"tag": "_", "expected": true, "description": "Single underscore"},
		{"tag": "-", "expected": true, "description": "Single hyphen"},
		{"tag": "a".repeat(100), "expected": true, "description": "Very long tag (100 chars)"}
	]

	var validation_results = []
	for case in edge_cases:
		var is_valid = TagManager.is_valid_tag(case.tag)
		var passed = is_valid == case.expected
		validation_results.append(passed)
		print("- %s: '%s' | Valid: %s | Expected: %s %s" % [
			case.description,
			case.tag,
			is_valid,
			case.expected,
			"✓" if passed else "✗"
		])

	var all_passed = true
	for result in validation_results:
		if result == false:
			all_passed = false
			break
	print("Edge cases test: %s" % ("PASSED" if all_passed else "FAILED"))
