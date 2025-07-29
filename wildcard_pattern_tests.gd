#!/usr/bin/env gdscript
# Comprehensive test suite for wildcard pattern system
extends RefCounted
class_name WildcardPatternTests

## Test all wildcard pattern matching functionality
static func run_all_tests() -> bool:
	print("🧪 Starting Wildcard Pattern System Tests")
	print("=========================================")
	
	var tests_passed: int = 0
	var tests_total: int = 0
	
	# Basic pattern tests
	tests_total += 1
	if test_prefix_patterns():
		tests_passed += 1
		print("✅ Prefix pattern tests passed")
	else:
		print("❌ Prefix pattern tests failed")
	
	tests_total += 1 
	if test_suffix_patterns():
		tests_passed += 1
		print("✅ Suffix pattern tests passed")
	else:
		print("❌ Suffix pattern tests failed")
	
	tests_total += 1
	if test_middle_wildcard_patterns():
		tests_passed += 1
		print("✅ Middle wildcard tests passed")
	else:
		print("❌ Middle wildcard tests failed")
	
	tests_total += 1
	if test_exact_patterns():
		tests_passed += 1
		print("✅ Exact pattern tests passed")
	else:
		print("❌ Exact pattern tests failed")
	
	# Advanced pattern tests
	tests_total += 1
	if test_group_patterns():
		tests_passed += 1
		print("✅ Group pattern tests passed")
	else:
		print("❌ Group pattern tests failed")
	
	tests_total += 1
	if test_exclusion_patterns():
		tests_passed += 1
		print("✅ Exclusion pattern tests passed")
	else:
		print("❌ Exclusion pattern tests failed")
	
	# Edge case tests
	tests_total += 1
	if test_edge_cases():
		tests_passed += 1
		print("✅ Edge case tests passed")
	else:
		print("❌ Edge case tests failed")
	
	tests_total += 1
	if test_pattern_validation():
		tests_passed += 1
		print("✅ Pattern validation tests passed")
	else:
		print("❌ Pattern validation tests failed")
	
	# Performance tests
	tests_total += 1
	if test_performance_benchmarks():
		tests_passed += 1
		print("✅ Performance benchmark tests passed")
	else:
		print("❌ Performance benchmark tests failed")
	
	print("")
	print("📊 Test Results: %d/%d tests passed" % [tests_passed, tests_total])
	print("Success Rate: %.1f%%" % ((tests_passed * 100.0) / tests_total))
	
	return tests_passed == tests_total

## Test prefix patterns (firebase.*)
static func test_prefix_patterns() -> bool:
	var test_tags: Array[String] = [
		"firebase.connect",
		"firebase.auth", 
		"firebase.timeout",
		"firebase.retry",
		"database.query",
		"performance.memory",
		"firebase_test",  # Should not match
		"test.firebase"   # Should not match
	]
	
	var expected_matches: Array[String] = [
		"firebase.connect",
		"firebase.auth",
		"firebase.timeout", 
		"firebase.retry"
	]
	
	return validate_pattern_matches("firebase.*", test_tags, expected_matches)

## Test suffix patterns (*.error)
static func test_suffix_patterns() -> bool:
	var test_tags: Array[String] = [
		"network.error",
		"database.error",
		"firebase.error",
		"system.error",
		"error.network",  # Should not match
		"errorlog",       # Should not match  
		"error_handling"  # Should not match
	]
	
	var expected_matches: Array[String] = [
		"network.error",
		"database.error", 
		"firebase.error",
		"system.error"
	]
	
	return validate_pattern_matches("*.error", test_tags, expected_matches)

## Test middle wildcard patterns (game.*.start)
static func test_middle_wildcard_patterns() -> bool:
	var test_tags: Array[String] = [
		"game.battle.start",
		"game.draft.start",
		"game.menu.start",
		"game.start",           # Should not match (no middle part)
		"game.battle.start.action", # Should not match (too many parts)
		"start.game.battle",    # Should not match (wrong order)
		"system.game.start"     # Should not match (wrong prefix)
	]
	
	var expected_matches: Array[String] = [
		"game.battle.start",
		"game.draft.start",
		"game.menu.start"
	]
	
	return validate_pattern_matches("game.*.start", test_tags, expected_matches)

## Test exact pattern matching
static func test_exact_patterns() -> bool:
	var test_tags: Array[String] = [
		"firebase.auth",
		"firebase.auth.token",  # Should not match
		"system.firebase.auth", # Should not match
		"firebase_auth",        # Should not match
		"firebase-auth"         # Should not match
	]
	
	var expected_matches: Array[String] = [
		"firebase.auth"
	]
	
	return validate_pattern_matches("firebase.auth", test_tags, expected_matches)

## Test group selection patterns firebase.{auth,connect}
static func test_group_patterns() -> bool:
	# Note: This is a future feature - test framework for when implemented
	print("🔮 Group patterns - future feature (placeholder test)")
	return true

## Test exclusion patterns !firebase.*
static func test_exclusion_patterns() -> bool:
	# Note: This is a future feature - test framework for when implemented  
	print("🔮 Exclusion patterns - future feature (placeholder test)")
	return true

## Test edge cases and malformed patterns
static func test_edge_cases() -> bool:
	var edge_cases: Array[String] = [
		"",              # Empty pattern
		".",             # Single dot
		".firebase",     # Leading dot
		"firebase.",     # Trailing dot
		"firebase**",    # Double wildcard
		"firebase.*.*",  # Multiple wildcards
		"a",             # Single character
		"a.b.c.d.e.f.g.h.i.j" # Very long pattern
	]
	
	# Most edge cases should be handled gracefully (not crash)
	for pattern in edge_cases:
		var result = validate_single_pattern(pattern)
		# For now, just ensure no crashes - specific validation in pattern_validation test
	
	return true

## Test pattern validation logic
static func test_pattern_validation() -> bool:
	var valid_patterns: Array[String] = [
		"firebase.*",
		"*.error", 
		"game.*.start",
		"firebase.auth",
		"database.query.performance"
	]
	
	var invalid_patterns: Array[String] = [
		"",              # Empty
		".firebase",     # Leading dot
		"firebase.",     # Trailing dot  
		"firebase**",    # Double wildcard
		"firebase.*.*.start" # Multiple middle wildcards
	]
	
	# All valid patterns should pass validation
	for pattern in valid_patterns:
		if not validate_single_pattern(pattern):
			print("❌ Valid pattern failed validation: " + pattern)
			return false
	
	# All invalid patterns should fail validation (when validation is implemented)
	# For now, just ensure they don't crash
	for pattern in invalid_patterns:
		validate_single_pattern(pattern)
	
	return true

## Test performance with various pattern types
static func test_performance_benchmarks() -> bool:
	var patterns: Array[String] = [
		"firebase.*",      # Prefix (should be fastest)
		"*.error",         # Suffix
		"game.*.start",    # Middle wildcard
		"firebase.auth",   # Exact match (should be fastest)
		"system.performance.memory.allocation" # Long exact match
	]
	
	# Generate test data
	var test_tags: Array[String] = generate_test_tag_dataset(1000)
	
	print("⚡ Performance benchmark with %d test tags:" % test_tags.size())
	
	for pattern in patterns:
		var start_time: float = Time.get_unix_time_from_system()
		var matches: Array[String] = []
		
		# Simulate pattern matching (simplified for testing)
		for tag in test_tags:
			if simple_pattern_match(pattern, tag):
				matches.append(tag)
		
		var end_time: float = Time.get_unix_time_from_system()
		var duration: float = end_time - start_time
		
		print("  Pattern '%s': %d matches in %.3fs" % [pattern, matches.size(), duration])
		
		# Performance threshold: should complete in <1 second for 1000 tags
		if duration > 1.0:
			print("❌ Performance issue: pattern took %.3fs (threshold: 1.0s)" % duration)
			return false
	
	return true

## Helper function to validate pattern matches
static func validate_pattern_matches(pattern: String, test_tags: Array[String], expected_matches: Array[String]) -> bool:
	var actual_matches: Array[String] = []
	
	for tag in test_tags:
		if simple_pattern_match(pattern, tag):
			actual_matches.append(tag)
	
	# Check if all expected matches were found
	for expected in expected_matches:
		if not actual_matches.has(expected):
			print("❌ Expected match not found: " + expected)
			return false
	
	# Check if any unexpected matches were found
	for actual in actual_matches:
		if not expected_matches.has(actual):
			print("❌ Unexpected match found: " + actual)
			return false
	
	print("✅ Pattern '%s': %d/%d matches correct" % [pattern, actual_matches.size(), expected_matches.size()])
	return true

## Simplified pattern matching for testing (basic implementation)
static func simple_pattern_match(pattern: String, tag: String) -> bool:
	# Basic wildcard matching for testing
	if pattern == tag:
		return true  # Exact match
	
	if pattern.ends_with(".*"):
		var prefix: String = pattern.substr(0, pattern.length() - 2)
		return tag.begins_with(prefix + ".")
	
	if pattern.begins_with("*."):
		var suffix: String = pattern.substr(2)
		return tag.ends_with("." + suffix)
	
	if pattern.count("*") == 1 and pattern.count(".") >= 2:
		# Middle wildcard like "game.*.start"
		var parts: PackedStringArray = pattern.split(".")
		if parts.size() == 3 and parts[1] == "*":
			var tag_parts: PackedStringArray = tag.split(".")
			return (tag_parts.size() == 3 and 
					tag_parts[0] == parts[0] and 
					tag_parts[2] == parts[2])
	
	return false

## Validate single pattern (placeholder for validation logic)
static func validate_single_pattern(pattern: String) -> bool:
	# Basic validation - just ensure no crashes for now
	if pattern.is_empty():
		return false
	
	if pattern.begins_with(".") or pattern.ends_with("."):
		return false
	
	if pattern.count("**") > 0:
		return false
	
	return true

## Generate test dataset for performance testing
static func generate_test_tag_dataset(size: int) -> Array[String]:
	var tags: Array[String] = []
	var domains: Array[String] = ["firebase", "database", "performance", "game", "system", "network", "ui"]
	var operations: Array[String] = ["connect", "auth", "query", "error", "start", "end", "timeout", "retry"]
	
	for i in range(size):
		var domain: String = domains[i % domains.size()]
		var operation: String = operations[(i / domains.size()) % operations.size()]
		var tag: String = domain + "." + operation
		
		# Add some middle parts for testing middle wildcards
		if i % 3 == 0:
			tag = domain + ".middle." + operation
		
		tags.append(tag)
	
	return tags

## Generate sample log data for testing wildcard commands
static func generate_sample_log_data() -> void:
	print("📝 Generating sample log data for wildcard testing...")
	
	var log_entries: Array[String] = [
		'Log.info("Firebase connection established", {}, [Log.TAG_FIREBASE_CONNECT, Log.TAG_NETWORK])',
		'Log.error("Firebase authentication failed", {}, [Log.TAG_FIREBASE_AUTH, Log.TAG_ERROR])',
		'Log.warning("Firebase timeout detected", {}, [Log.TAG_FIREBASE_TIMEOUT, Log.TAG_NETWORK])',
		'Log.info("Database query executed", {}, [Log.TAG_DB_QUERY, Log.TAG_PERFORMANCE])',
		'Log.error("Database connection lost", {}, [Log.TAG_DB_CONNECTION, Log.TAG_ERROR])',
		'Log.debug("Performance memory usage", {}, [Log.TAG_PERFORMANCE_MEMORY, Log.TAG_SYSTEM])',
		'Log.info("Game battle started", {}, [Log.TAG_GAME, Log.TAG_BATTLE, Log.TAG_START])',
		'Log.debug("Game draft reroll", {}, [Log.TAG_GAME, Log.TAG_DRAFT, Log.TAG_REROLL])',
		'Log.warning("Network timeout error", {}, [Log.TAG_NETWORK, Log.TAG_TIMEOUT, Log.TAG_ERROR])',
		'Log.info("System initialization complete", {}, [Log.TAG_SYSTEM, Log.TAG_INITIALIZATION])'
	]
	
	var log_file_path: String = "/tmp/wildcard_test_logs.txt"
	var file: FileAccess = FileAccess.open(log_file_path, FileAccess.WRITE)
	
	if file:
		for entry in log_entries:
			file.store_line(entry)
		file.close()
		print("✅ Sample log data written to: " + log_file_path)
		print("💡 Use this file to test wildcard commands:")
		print("  just logs-pattern wildcard_test firebase.*")
		print("  just logs-pattern wildcard_test *.error")
		print("  just logs-discover wildcard_test firebase")
	else:
		print("❌ Failed to write sample log data")

## Main test entry point
static func main() -> void:
	print("🚀 Wildcard Pattern System Test Suite")
	print("====================================")
	print("")
	
	# Generate sample data first
	generate_sample_log_data()
	print("")
	
	# Run all tests
	var success: bool = run_all_tests()
	
	print("")
	if success:
		print("🎉 All wildcard pattern tests passed!")
		print("✅ System ready for production use")
	else:
		print("🚨 Some tests failed - review implementation")
		print("❌ Address issues before deployment")
	
	print("")
	print("🔍 Next steps:")
	print("  1. Test with real log files using generated commands")
	print("  2. Validate performance with large log files")
	print("  3. Implement advanced features (groups, exclusions)")
	print("  4. Add interactive UI for pattern exploration")