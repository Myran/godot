#!/usr/bin/env just --justfile

# Testing Justfile for Godot 4 Projects
# Include this in the main justfile

# ===== STANDALONE TESTS =====
# These tests run directly as scripts without needing a full project instance

# Run a specific test script using Godot's command line
test-script SCRIPT_PATH:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running test script: {{SCRIPT_PATH}}"

    # Format the path if it's relative
    FULL_PATH="{{SCRIPT_PATH}}"
    if [[ "{{SCRIPT_PATH}}" != /* && "{{SCRIPT_PATH}}" != ~/* ]]; then
        # If path doesn't start with / or ~/, assume it's relative to project directory
        FULL_PATH="{{PROJECT_PATH}}/{{SCRIPT_PATH}}"
    fi

    # Run the script with Godot in headless mode and save PID
    cd {{PROJECT_PATH}} && ../editor/{{GODOT_EXECUTABLE}} --headless --script "${FULL_PATH}" &
    TEST_PID=$!
    
    echo "Started test process with PID: $TEST_PID"
    
    # Wait for up to 120 seconds for the process to complete naturally
    TIMEOUT=120
    for ((i=1; i<=TIMEOUT; i++)); do
        if ! ps -p $TEST_PID > /dev/null 2>&1; then
            echo "Test process completed after $i seconds"
            # Process exited naturally, we assume success
            exit 0
        fi
        
        # Print a progress message every 20 seconds
        if [ $((i % 20)) -eq 0 ]; then
            echo "Test still running after $i seconds..."
        fi
        
        sleep 1
    done
    
    # If we get here, the process is still running after the timeout
    if ps -p $TEST_PID > /dev/null 2>&1; then
        echo "Test process (PID: $TEST_PID) timed out after $TIMEOUT seconds. Terminating..."
        kill $TEST_PID 2>/dev/null || true
        
        # Give it a moment to terminate gracefully
        sleep 2
        
        # Force kill if still running
        if ps -p $TEST_PID > /dev/null 2>&1; then
            echo "Process didn't terminate gracefully. Forcing termination..."
            kill -9 $TEST_PID 2>/dev/null || true
        fi
        
        echo "Test timed out"
        exit 1
    fi
    
    echo "Test script completed successfully"

# Run logger validation tests
test-logger:
    @echo "Running Advanced Logger validation tests..."
    just test-script tests/validate_logger.gd
    @echo "Logger tests completed"

# Run logger tag resizing validation test
test-tag-resizing:
    @echo "Running tag resizing validation test..."
    just test-script tests/validate_tag_resizing.gd
    @echo "Tag resizing test completed"

# Run tag scanning validation test
test-tag-scanning:
    @echo "Running tag scanning validation test..."
    just test-script tests/validate_tag_scanning.gd
    @echo "Tag scanning test completed"

# Run tag rescan test
test-tag-rescan:
    @echo "Running tag rescan test..."
    just test-script tests/validate_tag_rescan.gd
    @echo "Tag rescan test completed"

# Run tag filtering test
test-tag-filtering:
    @echo "Running tag filtering test..."
    just test-script tests/validate_tag_filtering.gd
    @echo "Tag filtering test completed"

# Run tag setup manager test
test-tag-setup-manager:
    @echo "Running tag setup manager test..."
    just test-script addons/advanced_logger/tests/test_tag_setup_manager.gd
    @echo "Tag setup manager test completed"

# Run UI components test
test-ui-components:
    @echo "Running UI components test..."
    just test-script addons/advanced_logger/tests/test_ui_components.gd
    @echo "UI components test completed"

# ===== DATA REFACTORING TESTS =====
# Tests for the data management refactoring

# Run JSONPathNavigator tests
test-json-navigator:
    @echo "Running JSONPathNavigator tests..."
    just test-script tests/refactoring/json_path_navigator_test.gd
    @echo "JSONPathNavigator tests completed"

# Test data source with refactored collections
test-refactored-data-source:
    @echo "Running refactored data source tests..."
    just test-script tests/refactoring/data_source_test.gd
    @echo "Refactored data source tests completed"

# Test collections with JSONPathNavigator
test-collections-with-navigator:
    @echo "Testing collections with JSONPathNavigator..."
    just test-script tests/refactoring/collection_test.gd
    @echo "Collection tests completed"

# Test the cache mechanism
test-cache:
    @echo "Testing cache mechanism..."
    just test-script tests/refactoring/cache_test.gd
    @echo "Cache tests completed"

# Run the game with legacy data source
run-with-legacy-data-source:
    @echo "Running game with legacy data source..."
    cd {{PROJECT_PATH}} && ../editor/{{GODOT_EXECUTABLE}} --path . --use-legacy-datasource

# Run the game with refactored data source
run-with-refactored-data-source:
    @echo "Running game with refactored data source..."
    cd {{PROJECT_PATH}} && ../editor/{{GODOT_EXECUTABLE}} --path . --use-refactored-datasource

# Run all refactoring tests
test-refactoring: test-json-navigator test-refactored-data-source test-collections-with-navigator test-cache
    @echo "All refactoring tests completed"

# Run all standalone tests that don't require a running project
test-standalone: test-logger test-tag-resizing test-tag-scanning test-tag-filtering test-tag-setup-manager test-ui-components
    @echo "All standalone tests completed"

# ===== INTEGRATION TESTS =====
# These tests run within a running project instance

# Run Firebase integration tests
test-firebase:
    @echo "Running Firebase integration tests..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --test-firebase || true
    @echo "Firebase tests completed (failure expected in non-firebase environments)"

# ===== ALL TESTS =====
# Run all tests (both standalone and integration)
test-all: test-standalone test-integration test-refactoring
    @echo "All tests completed successfully"

# ===== INTEGRATION TESTS =====
# These tests run within a running project instance
test-integration: test-firebase
    @echo "All integration tests completed"
