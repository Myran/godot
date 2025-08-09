#!/usr/bin/env bash
set -euo pipefail

# Comment Cleanup Testing Baseline Script
# This script tests that all commands still work after removing comments
# (comments should not affect functionality, but let's be safe)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/comment_cleanup_baseline_results.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "💬 COMMENT CLEANUP TESTING BASELINE" | tee "$BASELINE_FILE"
echo "=====================================" | tee -a "$BASELINE_FILE"
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
    echo "   Output Length: $(echo "$output" | wc -l) lines" | tee -a "$BASELINE_FILE"
    echo "" | tee -a "$BASELINE_FILE"
    
    return $exit_code
}

# Test critical commands across all major justfile modules
echo "🧪 TESTING CORE FUNCTIONALITY" | tee -a "$BASELINE_FILE"
echo "==============================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run validate-all" "Complete validation pipeline"
test_command "just --dry-run run-desktop" "Desktop execution"
test_command "just --dry-run test-android-target system-testing" "Enhanced Android testing"
test_command "just --dry-run fastbuild-android" "Android fast build"
test_command "just --dry-run config-status-android" "Android config management"

echo "🎯 TESTING WILDCARD AND PATTERN COMMANDS" | tee -a "$BASELINE_FILE"
echo "=========================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run help-wildcards" "Wildcard pattern help"
test_command "just --dry-run logs-tree system-testing" "Log tree analysis"

echo "🔄 TESTING REPLAY AND SEMANTIC COMMANDS" | tee -a "$BASELINE_FILE"
echo "========================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run replay-list" "List replay configurations"
test_command "just --dry-run replay-generate-android test_session my-test" "Replay generation"

echo "🔨 TESTING BUILD AND SUPPORT COMMANDS" | tee -a "$BASELINE_FILE"
echo "=====================================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

test_command "just --dry-run build-status" "Build status check"
test_command "just --dry-run help" "Interactive help system"

# Document current comment statistics
echo "📊 CURRENT COMMENT STATISTICS" | tee -a "$BASELINE_FILE"
echo "==============================" | tee -a "$BASELINE_FILE"
echo "" | tee -a "$BASELINE_FILE"

total_comments=$(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')
echo "Total comment lines: $total_comments" | tee -a "$BASELINE_FILE"

obvious_comments=$(rg "# (Set |Get |Check |Run |Call |Execute )" justfiles/ --no-heading | wc -l | tr -d ' ')
echo "Obvious comments: $obvious_comments" | tee -a "$BASELINE_FILE"

temporary_comments=$(rg "# (TEMP|TEMPORARY|Quick|For now)" justfiles/ --no-heading | wc -l | tr -d ' ')
echo "Temporary comments: $temporary_comments" | tee -a "$BASELINE_FILE"

echo "" | tee -a "$BASELINE_FILE"
echo "🎉 BASELINE TESTING COMPLETED" | tee -a "$BASELINE_FILE"
echo "=============================" | tee -a "$BASELINE_FILE"
echo "Results saved to: $BASELINE_FILE" | tee -a "$BASELINE_FILE"
echo "You can now proceed with comment cleanup!" | tee -a "$BASELINE_FILE"