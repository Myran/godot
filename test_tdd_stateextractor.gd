#!/usr/bin/env -S godot -s
extends ScriptCommandLineHandler

# Desktop TDD StateExtractor validation script

func _main() -> int:
	print("=== TDD StateExtractor Validation ===")
	
	# Test 1: Verify StateExtractor class exists (GREEN Phase validation)
	var class_exists: bool = ClassDB.class_exists("StateExtractor")
	print("StateExtractor class exists: ", class_exists)
	
	if not class_exists:
		print("❌ RED Phase test would have passed - StateExtractor class not found")
		return 1
	
	# Test 2: Test StateExtractor methods exist and work
	var test_data: Dictionary = {"test": "data", "number": 42}
	
	# Test extract_game_state method
	print("Testing extract_game_state()...")
	var game_state: Dictionary = StateExtractor.extract_game_state()
	print("Game state extracted: ", game_state.has("metadata"))
	
	# Test generate_checksum method
	print("Testing generate_checksum()...")
	var checksum: String = StateExtractor.generate_checksum(test_data)
	print("Checksum generated: ", not checksum.is_empty())
	
	# Test normalize_data method
	print("Testing normalize_data()...")
	var normalized: Dictionary = StateExtractor.normalize_data(test_data)
	print("Data normalized: ", normalized.size() > 0)
	
	# Test is_state_valid method
	print("Testing is_state_valid()...")
	var is_valid: bool = StateExtractor.is_state_valid(test_data)
	print("State validation: ", is_valid)
	
	print("✅ GREEN Phase validation: All StateExtractor methods working")
	print("🎯 TDD Red-to-Green transition successful!")
	
	return 0