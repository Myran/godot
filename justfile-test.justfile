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
    
    # Run the script with Godot in headless mode
    cd {{PROJECT_PATH}} && ../editor/{{GODOT_EXECUTABLE}} --headless --script "${FULL_PATH}"
    EXIT_CODE=$?
    
    echo "Test script completed with exit code: ${EXIT_CODE}"
    exit ${EXIT_CODE}

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

# Run all standalone tests that don't require a running project
test-standalone: test-logger test-tag-resizing test-tag-scanning test-tag-filtering test-tag-setup-manager
    @echo "All standalone tests completed"

# ===== INTEGRATION TESTS =====
# These tests run within a running project instance

# Run Firebase integration tests
test-firebase:
    @echo "Running Firebase integration tests..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --test-firebase || true
    @echo "Firebase tests completed (failure expected in non-firebase environments)"

# Run all integration tests that require a running project
test-integration: test-firebase
    @echo "All integration tests completed"

# ===== ALL TESTS =====
# Run all tests (both standalone and integration)
test-all: test-standalone test-integration
    @echo "All tests completed successfully"
