#!/usr/bin/env bash
set -euo pipefail

# Validation Function Testing Baseline Script
# This script tests all validation-dependent just commands to establish baseline behavior
# before refactoring duplicate validation functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/validation_baseline_results.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "🧪 VALIDATION FUNCTION TESTING BASELINE" | tee "$BASELINE_FILE"
echo "=======================================" | tee -a "$BASELINE_FILE"
echo "Timestamp: $TIMESTAMP" | tee -a "$BASELINE_FILE"
echo "Working Directory: $SCRIPT_DIR" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

# Test function to capture command behavior
test_command() {
    local cmd="$1"
    local description="$2"
    
    echo "🔍 Testing: $cmd" | tee -a "$BASELINE_FILE"
    echo "   Description: $description" | tee -a "$BASELINE_FILE"
    
    # Capture exit code and output
    set +e  # Temporarily allow non-zero exit codes
    local output
    local exit_code
    
    output=$(timeout 30s $cmd 2>&1)
    exit_code=$?
    
    set -e  # Re-enable strict error handling
    
    echo "   Exit Code: $exit_code" | tee -a "$BASELINE_FILE"
    echo "   Output Preview: $(echo "$output" | head -3 | tr '\n' '; ')" | tee -a "$BASELINE_FILE"
    echo "   Output Length: $(echo "$output" | wc -l) lines" | tee -a "$BASELINE_FILE"
    echo "" | tee -a "$BASELINE_FILE"
    
    return $exit_code
}

# Test validation functions directly (dry-run mode)
echo "📋 TESTING VALIDATION FUNCTIONS DIRECTLY" | tee -a "$BASELINE_FILE"
echo "=========================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run _validate-android-device" "Basic Android device validation (lenient)"
test_command "just --dry-run _validate-godot-editor" "Validate Godot editor is available"  
test_command "just --dry-run _validate-android-workflow" "Combined validation for Android workflow requirements"

# Test user-facing commands that depend on validation functions
echo "🎯 TESTING USER-FACING COMMANDS WITH VALIDATION DEPENDENCIES" | tee -a "$BASELINE_FILE"
echo "============================================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run run-desktop" "Launch in Godot editor (depends on _validate-godot-editor)"
test_command "just --dry-run fastbuild-android" "Fast Android rebuild (depends on _validate-android-workflow + _validate-godot-editor)"
test_command "just --dry-run launch-android" "Launch Android app (depends on _validate-android-workflow)"
test_command "just --dry-run restart-android-app" "Restart Android app (depends on _validate-android-workflow)" 
test_command "just --dry-run export-apk-android" "Export Android APK (depends on _validate-godot-editor)"

# Test config and status commands
echo "⚙️  TESTING CONFIGURATION AND STATUS COMMANDS" | tee -a "$BASELINE_FILE"
echo "===============================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run config-status-android" "Check current Android configuration status"
test_command "just --dry-run check-android-debug-status" "Check Android debug connection and app status"
test_command "just --dry-run validate-env" "Validate environment variables"

# Test build system commands
echo "🔨 TESTING BUILD SYSTEM COMMANDS" | tee -a "$BASELINE_FILE"
echo "=================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run build-editor" "Build custom Godot editor from source"
test_command "just --dry-run pre-build" "Pre-build hook"

# Document current validation function locations
echo "📍 CURRENT VALIDATION FUNCTION LOCATIONS" | tee -a "$BASELINE_FILE"
echo "=========================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

echo "Scanning for validation function definitions..." | tee -a "$BASELINE_FILE"
rg "_validate-[a-zA-Z-]+:" justfiles/ --no-heading | sort | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "Scanning for validation function usages..." | tee -a "$BASELINE_FILE"
rg "^[a-zA-Z0-9_-]+:.*_validate-" justfiles/ --no-heading | sort | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "🎉 BASELINE TESTING COMPLETED" | tee -a "$BASELINE_FILE"
echo "=============================" | tee -a "$BASELINE_FILE"
echo "Results saved to: $BASELINE_FILE" | tee -a "$BASELINE_FILE"
echo "You can now proceed with validation function consolidation!" | tee -a "$BASELINE_FILE"
echo "Re-run this script after changes to detect any regressions." | tee -a "$BASELINE_FILE"