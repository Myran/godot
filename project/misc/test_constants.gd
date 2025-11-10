class_name TestConstants
extends RefCounted

## Shared constants for debug action tests to eliminate repetition and typos
## Follows CLAUDE.md principles: strong typing, simple constants

# Test path prefixes (used across 40+ action files)
const FIREBASE_CPP_PREFIX: String = "cpp_tests"
const RTDB_PREFIX: String = "rtdb_tests"
const SYSTEM_PREFIX: String = "system_tests"
const FIREBASE_BACKEND_PREFIX: String = "backend_tests"

# Common log tags (for Log.info/error calls)
const LOG_TAGS: Dictionary = {
	"DEBUG": "debug",
	"BACKEND_FIREBASE": "backend_firebase",
	"ERROR": "error",
	"FIREBASE": "firebase",
	"CPP": "cpp"
}

# Common error codes (repeated across all action files)
const ERROR_DATABASE_UNAVAILABLE: String = "DATABASE_UNAVAILABLE"
const ERROR_OPERATION_FAILED: String = "OPERATION_FAILED"
const ERROR_SETUP_FAILED: String = "SETUP_FAILED"

const ERROR_CODES: Dictionary = {
	"SET_FAILED": "SET_OPERATION_FAILED",
	"GET_FAILED": "GET_OPERATION_FAILED",
	"REMOVE_FAILED": "REMOVE_OPERATION_FAILED",
	"UPDATE_FAILED": "UPDATE_OPERATION_FAILED",
	"LISTENER_FAILED": "LISTENER_PATH_OPERATION_FAILED",
	"TIMEOUT": "OPERATION_TIMEOUT",
	"BACKEND_UNAVAILABLE": "BACKEND_UNAVAILABLE",
	"BACKEND_NOT_INITIALIZED": "BACKEND_NOT_INITIALIZED",
	"VALIDATION_FAILED": "VALIDATION_FAILED",
	"CONCURRENT_FAILED": "CONCURRENT_OPERATION_FAILED",
	"SIGNAL_INTEGRITY_FAILED": "SIGNAL_INTEGRITY_FAILED",
	"TIMEOUT_BEHAVIOR_FAILED": "TIMEOUT_BEHAVIOR_FAILED",
	"LARGE_DATA_FAILED": "LARGE_DATA_FAILED",
	"FILE_WRITE_FAILED": "FILE_WRITE_FAILED",
	"FILE_READ_FAILED": "FILE_READ_FAILED",
	"REQUEST_TRACKING_INSUFFICIENT": "REQUEST_TRACKING_INSUFFICIENT",
	"TIMER_MANAGER_INSUFFICIENT": "TIMER_MANAGER_INSUFFICIENT"
}

# Firebase operation names (repeated patterns)
const FIREBASE_OPERATIONS: Dictionary = {
	"GET_VALUE": "get_value_async",
	"SET_VALUE": "set_value_async",
	"REMOVE_VALUE": "remove_value_async",
	"UPDATE_VALUE": "update_value_async"
}

# Common test type identifiers
const TEST_TYPES: Dictionary = {
	"CPP_GET_VALUE": "cpp_get_value",
	"CPP_SET_VALUE": "cpp_set_value",
	"CPP_REMOVE_VALUE": "cpp_remove_value",
	"CPP_CONCURRENT_OPS": "cpp_concurrent_operations",
	"CPP_SIGNAL_INTEGRITY": "cpp_signal_integrity",
	"CPP_TIMEOUT_BEHAVIOR": "cpp_timeout_behavior",
	"CPP_LARGE_DATA": "cpp_large_data",
	"RTDB_SET_SIMPLE": "rtdb_set_simple",
	"RTDB_GET_SIMPLE": "rtdb_get_simple_value",
	"RTDB_REMOVE_VALUE": "rtdb_remove_value",
	"RTDB_SINGLE_LISTENER": "rtdb_single_value_listener",
	"RTDB_SET_NESTED": "rtdb_set_nested",
	"RTDB_GET_NESTED": "rtdb_get_nested",
	"BACKEND_PERFORMANCE": "backend_performance",
	"BACKEND_ERROR_HANDLING": "backend_error_handling",
	"BACKEND_REQUEST_TRACKING": "backend_request_tracking",
	"BACKEND_TIMER_MANAGER": "backend_timer_manager",
	"SYSTEM_SAVE_GAMESTATE": "system_save_gamestate",
	"SYSTEM_LOAD_GAMESTATE": "system_load_gamestate",
	"SYSTEM_RESTART_GAME": "system_restart_game",
	"SYSTEM_VALIDATION": "system_validation"
}


# Simple helper for consistent test value creation
static func test_value(prefix: String) -> String:
	return "%s: %d" % [prefix, Time.get_ticks_msec()]


# Simple helper for consistent operation descriptions
static func operation_description(operation: String, context: String = "") -> String:
	if context.is_empty():
		return "C++ %s" % operation.capitalize()
	return "C++ %s (%s)" % [operation.capitalize(), context]

# =================================================================
# CRITICAL LOG MESSAGE CONSTANTS
# Used by test framework for validation - DO NOT CHANGE without updating tests
# =================================================================

# Debug test success/failure markers (used in justfile grep patterns)
const LOG_DEBUG_TEST_SUCCESS: String = "DEBUG_TEST_SUCCESS"
const LOG_DEBUG_TEST_FAILURE: String = "DEBUG_TEST_FAILURE"

# Session markers (used for test timing and validation)
const LOG_SESSION_START: String = "SESSION_START"
const LOG_SESSION_END: String = "SESSION_END"

# Test completion markers (used for automated validation)
const LOG_TEST_COMPLETE_PREFIX: String = "TEST_COMPLETE_"

# Quit event messages (used for desktop test validation)
const LOG_QUIT_EVENT_RECEIVED: String = "Quit event received"
const LOG_QUIT_EVENT_OLD_PATTERN: String = "Quit event received, exiting application"  # Legacy pattern
const LOG_QUIT_EVENT_NEW_PATTERN: String = "Quit event received - delegating to QuitApplicationEvent for centralized handling"  # New pattern

# Flush completion marker (used for Android log validation)
const LOG_DEBUG_TEST_FLUSH_COMPLETE: String = "DEBUG_TEST_FLUSH_COMPLETE"

# Checksum validation markers
const LOG_CHECKSUM_MISMATCH: String = "CHECKSUM_MISMATCH"
const LOG_STATE_CAPTURED: String = "STATE_CAPTURED"

# Error patterns (used for error analysis)
const LOG_ERROR_PATTERNS: Array[String] = [
	"SCRIPT ERROR",
	"Assertion failed",
	"CRITICAL",
	"Parse Error",
	"DEBUG_TEST_FAILURE",
	"CHECKSUM_MISMATCH"
]

# Buffer replay filter (used to exclude test framework internal messages)
const LOG_BUFFER_TAG: String = "[BUFFER]"

# Helper to get the correct quit event pattern for current version
static func get_quit_event_pattern() -> String:
	# Use the newer pattern that works with QuitApplicationEvent
	return LOG_QUIT_EVENT_RECEIVED

# Helper to get all critical log patterns for grep filtering
static func get_critical_log_patterns() -> String:
	var patterns: Array[String] = []
	patterns.append(LOG_DEBUG_TEST_SUCCESS)
	patterns.append(LOG_DEBUG_TEST_FAILURE)
	patterns.append(LOG_TEST_COMPLETE_PREFIX)
	patterns.append(LOG_SESSION_START)
	patterns.append(LOG_SESSION_END)
	patterns.append(LOG_CHECKSUM_MISMATCH)
	patterns.append(LOG_STATE_CAPTURED)

	return "|".join(patterns)
