#!/usr/bin/env bash
set -euo pipefail

# Legacy Code Cleanup Testing Baseline Script
# This script tests all commands that might be affected by removing legacy/dead code
# before removing _removed_* functions and dead code blocks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/legacy_cleanup_baseline_results.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "🧹 LEGACY CODE CLEANUP TESTING BASELINE" | tee "$BASELINE_FILE"
echo "========================================" | tee -a "$BASELINE_FILE"
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

# Test active config commands that might be affected by legacy cleanup
echo "⚙️  TESTING ACTIVE CONFIG COMMANDS" | tee -a "$BASELINE_FILE"
echo "===================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run config-status-android" "Check Android configuration status"
test_command "just --dry-run config-clear-android" "Clear external Android configuration"
test_command "just --dry-run config-android-reset" "Reset Android logger config to defaults"
test_command "just --dry-run config-push-android system-testing" "Deploy config to Android device"

# Test validation and enhanced testing commands
echo "🧪 TESTING VALIDATION AND ENHANCED TESTING COMMANDS" | tee -a "$BASELINE_FILE"
echo "====================================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run validate-all" "Validate all project files"
test_command "just --dry-run test-android-target system-testing" "Enhanced Android testing"
test_command "just --dry-run test-desktop-target system-testing" "Enhanced desktop testing"

# Test build and support commands
echo "🔨 TESTING BUILD AND SUPPORT COMMANDS" | tee -a "$BASELINE_FILE"
echo "======================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run build-status" "Check build status"
test_command "just --dry-run quick-build-all" "Quick build for all platforms"

# Document current _removed_ functions and dead code locations
echo "🗑️  CURRENT LEGACY CODE LOCATIONS" | tee -a "$BASELINE_FILE"
echo "==================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

echo "Scanning for _removed_ functions..." | tee -a "$BASELINE_FILE"
rg "_removed_[a-zA-Z_-]+:" justfiles/ --no-heading | sort | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "Scanning for REMOVED comment blocks..." | tee -a "$BASELINE_FILE"
rg "# REMOVED:" justfiles/ --no-heading | head -10 | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "Scanning for legacy fallback comments..." | tee -a "$BASELINE_FILE"
rg "# Legacy approach.*fallback" justfiles/ --no-heading | head -5 | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "🎉 BASELINE TESTING COMPLETED" | tee -a "$BASELINE_FILE"
echo "=============================" | tee -a "$BASELINE_FILE"
echo "Results saved to: $BASELINE_FILE" | tee -a "$BASELINE_FILE"
echo "You can now proceed with legacy code removal!" | tee -a "$BASELINE_FILE"
echo "Re-run this script after changes to detect any regressions." | tee -a "$BASELINE_FILE"