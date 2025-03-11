#!/usr/bin/env just --justfile

# Testing Justfile for Godot 4 Projects
# Include this in the main justfile

# Run Firebase integration tests
test-firebase:
    @echo "Running Firebase integration tests..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --test-firebase
    @echo "Firebase tests completed with exit code: $?"

# Run all tests
test-all: test-firebase
    @echo "All tests completed"
