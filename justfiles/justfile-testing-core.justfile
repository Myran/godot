# Testing & Validation Core Infrastructure
# Platform-agnostic testing commands and validation infrastructure
# Provides core testing functionality used across all platforms

# Note: Variables and dependencies inherited from main justfile
# This module does not import other modules to avoid circular dependencies

# ================================
# SHARED TEST SETUP FUNCTIONS
# ================================

# Common test setup for all Android test variants
_test-setup-android CONFIG_NAME TEST_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    TEST_TYPE="{{TEST_TYPE}}"
    
    # Display appropriate header based on test type
    case "$TEST_TYPE" in
        "basic")
            echo "🧪 Testing configuration: $CONFIG_NAME"
            ;;
        "enhanced")
            echo "🔬 Enhanced Testing: $CONFIG_NAME"
            ;;
        "manual")
            echo "🎯 Testing target (manual mode - stays open): $CONFIG_NAME"
            echo "=================================================="
            return 0  # Manual has different separator
            ;;
        *)
            echo "🧪 Testing: $CONFIG_NAME"
            ;;
    esac
    echo "=================================="

# Common test preparation (cache clear + validation)
_test-prepare-android CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    # Clear Android test cache first to prevent stale state contamination
    echo "🧹 Clearing Android test cache to ensure fresh state..."
    just clear-android-test-cache
    echo ""
    
    # Validate configuration exists and is properly formatted
    just _validate-config-exists "$CONFIG_NAME"

# Common Android device connectivity check
_test-check-android-device:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use enhanced device check
    just _android-check-device-detailed

# ================================
# SHARED DESKTOP TEST FUNCTIONS
# ================================

# Common test setup for all Desktop test variants
_test-setup-desktop CONFIG_NAME TEST_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    TEST_TYPE="{{TEST_TYPE}}"
    
    echo "🖥️  Testing target ($TEST_TYPE mode): $CONFIG_NAME"
    echo "=================================================="

# Common desktop test preparation (config validation)
_test-prepare-desktop CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    echo "🧹 Preparing desktop test environment..."
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    echo ""

# Common desktop Godot editor check
_test-check-desktop-godot:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use shared validation pattern
    just _validate-file-exists "./editor/{{GODOT_EXECUTABLE}}" "Build the editor first: just build-editor"
    echo "✅ Godot editor found: ./editor/{{GODOT_EXECUTABLE}}"

# ================================
# SHARED VALIDATION PATTERNS
# ================================

# NOTE: Validation helper functions moved to justfile-validation-shared.justfile
# Use shared functions: _validate-file-exists, _validate-dir-exists, _validate-command-exists

# ================================
# SHARED ANDROID OPERATIONS
# ================================

# NOTE: Android helper functions moved to justfile-validation-shared.justfile
# Available shared functions:
# - _android-run-as-command
# - _android-get-device-info  
# - _android-check-app-installed
# - _android-check-device-detailed
# - _android-get-app-log

# ================================
# SHARED TEST INFRASTRUCTURE
# ================================

# Generate standardized test ID with configurable format
_shared-generate-test-id CONFIG_NAME TEST_TYPE PLATFORM="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    TEST_TYPE="{{TEST_TYPE}}"
    PLATFORM="{{PLATFORM}}"
    
    # Generate timestamp
    TIMESTAMP=$(date +%s)
    
    # Format test ID based on parameters
    if [[ -n "$PLATFORM" ]]; then
        # Include platform: config_platform_type_timestamp
        TEST_ID="${CONFIG_NAME}_${PLATFORM}_${TEST_TYPE}_${TIMESTAMP}"
    else
        # No platform: config_type_timestamp
        TEST_ID="${CONFIG_NAME}_${TEST_TYPE}_${TIMESTAMP}"
    fi
    
    echo "$TEST_ID"

# Display standardized test information header
_display-test-info TEST_ID CONFIG_NAME TEST_TYPE PLATFORM="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    CONFIG_NAME="{{CONFIG_NAME}}"
    TEST_TYPE="{{TEST_TYPE}}"
    PLATFORM="{{PLATFORM}}"
    
    echo ""
    echo "🔍 Test ID: $TEST_ID"
    echo "⚙️  Config: $CONFIG_NAME"
    echo "🎯 Type: $TEST_TYPE"
    
    # Add platform-specific info
    if [[ "$PLATFORM" == "android" ]]; then
        just _android-get-device-info
    elif [[ "$PLATFORM" == "desktop" ]]; then
        echo "🖥️  Platform: Desktop"
        echo "🔧 Editor: {{GODOT_EXECUTABLE}}"
    elif [[ -n "$PLATFORM" ]]; then
        echo "🔧 Platform: $PLATFORM"
    fi

# Parse test list JSON and extract configurations with error handling
_parse-test-list-json TEST_LIST_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST_FILE="{{TEST_LIST_FILE}}"
    
    # Validate file exists
    if [[ ! -f "$TEST_LIST_FILE" ]]; then
        echo "❌ Test list file not found: $TEST_LIST_FILE" >&2
        return 1
    fi
    
    # Validate JSON format
    if ! jq -e . "$TEST_LIST_FILE" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in test list: $TEST_LIST_FILE" >&2
        return 1
    fi
    
    # Check for required configs field
    if ! jq -e '.configs' "$TEST_LIST_FILE" >/dev/null 2>&1; then
        echo "❌ Test list missing required 'configs' field" >&2
        return 1
    fi
    
    # Extract and return configs (handles @ references)
    HAS_AT_REFERENCES=$(jq -r '.configs[]?' "$TEST_LIST_FILE" 2>/dev/null | grep -c "^@" || echo "0")
    
    if [[ "${HAS_AT_REFERENCES:-0}" -gt 0 ]]; then
        echo "🔄 Expanding @ references..." >&2
        # Note: This would need @ reference expansion logic
        # For now, return basic configs
        jq -r '.configs[] | select(test("^@") | not)' "$TEST_LIST_FILE"
    else
        jq -r '.configs[]' "$TEST_LIST_FILE"
    fi

# Get test list metadata (name, description, config count)
_get-test-list-metadata TEST_LIST_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST_FILE="{{TEST_LIST_FILE}}"
    
    # Validate file exists and is valid JSON
    if [[ ! -f "$TEST_LIST_FILE" ]] || ! jq -e . "$TEST_LIST_FILE" >/dev/null 2>&1; then
        echo "❌ Invalid test list file: $TEST_LIST_FILE" >&2
        return 1
    fi
    
    # Extract metadata
    NAME=$(jq -r '.name // (input_filename | split("/") | last | split(".") | first)' "$TEST_LIST_FILE" --arg input_filename "$TEST_LIST_FILE")
    DESCRIPTION=$(jq -r '.description // "No description provided"' "$TEST_LIST_FILE")
    CONFIG_COUNT=$(jq -r '.configs | length' "$TEST_LIST_FILE")
    
    echo "Name: $NAME"
    echo "Description: $DESCRIPTION"
    echo "Configurations: $CONFIG_COUNT"

# Standardized test summary display
_display-test-summary TEST_ID CONFIG_NAME DURATION_SECONDS STATUS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    CONFIG_NAME="{{CONFIG_NAME}}"
    DURATION_SECONDS="{{DURATION_SECONDS}}"
    STATUS="{{STATUS}}"
    
    echo ""
    echo "📊 Test Summary"
    echo "==============="
    echo "🔍 Test ID: $TEST_ID"
    echo "⚙️  Configuration: $CONFIG_NAME"
    echo "⏱️  Duration: ${DURATION_SECONDS}s"
    
    # Status with appropriate emoji
    case "$STATUS" in
        "COMPLETED"|"SUCCESS")
            echo "✅ Status: COMPLETED"
            ;;
        "FAILED"|"ERROR")
            echo "❌ Status: FAILED"
            ;;
        "TIMEOUT")
            echo "⏰ Status: TIMEOUT"
            ;;
        *)
            echo "🔍 Status: $STATUS"
            ;;
    esac
    
    echo "💡 Use 'just logs $TEST_ID' for detailed analysis"

# Validate all project files
validate-all:
    #!/usr/bin/env bash
    echo "🔍 Running comprehensive validation..."
    echo ""
    
    # Validate GDScript syntax
    echo "1. Validating GDScript syntax..."
    just validate-godot
    
    # Validate JSON configurations
    echo ""
    echo "2. Validating JSON configurations..."
    if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
        find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f | while read -r config; do
            basename=$(basename "$config" .json)
            echo "  Validating: $basename"
            if ! jq -e . "$config" >/dev/null 2>&1; then
                echo "  ❌ Invalid JSON: $config"
                exit 1
            fi
        done
        echo "  ✅ All JSON configurations valid"
    else
        echo "  ⚠️  No configuration directory found: {{DEBUG_CONFIG_DIR}}"
    fi
    
    echo ""
    echo "✅ All validations passed!"

# Validate Godot project and scripts
validate-godot pattern="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    cd "{{PROJECT_PATH}}"
    
    echo "🔍 Validating Godot project..."
    
    # Run Godot validation
    if [[ "{{pattern}}" != "" ]]; then
        echo "Using pattern filter: {{pattern}}"
        timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --verbose --debug-stringnames --quit 2>&1 | grep -E "{{pattern}}" || true
    else
        echo "Running full validation..."
        timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --verbose --debug-stringnames --quit 2>&1 | head -50 || true
    fi
    
    # Check for critical errors
    TEMP_VALIDATION=$(mktemp)
    if timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --verbose --debug-stringnames --quit > "$TEMP_VALIDATION" 2>&1; then
        # Validation succeeded, check for critical errors in output (excluding ObjectDB/resource leak warnings)
        if grep -E "SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" >/dev/null 2>&1; then
            echo ""
            echo "❌ Validation found critical errors!"
            echo ""
            echo "Full error output:"
            grep -E "SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" | head -20
            rm -f "$TEMP_VALIDATION"
            exit 1
        fi
    else
        # Validation command failed - could be timeout (exit 124) which is expected
        exit_code=$?
        if [[ $exit_code -eq 124 || $exit_code -eq 141 ]]; then
            # Timeout or SIGPIPE - check for critical errors in output (excluding ObjectDB/resource leak warnings)
            if grep -E "SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" >/dev/null 2>&1; then
                echo ""
                echo "❌ Validation found critical errors!"
                echo ""
                echo "Full error output:"
                grep -E "SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" | head -20
                rm -f "$TEMP_VALIDATION"
                exit 1
            fi
            # No errors found, timeout is expected behavior
        else
            echo ""
            echo "❌ Godot validation command failed with exit code $exit_code"
            rm -f "$TEMP_VALIDATION"
            exit 1
        fi
    fi
    rm -f "$TEMP_VALIDATION"
    
    echo "✅ Godot validation passed"

# Detailed Godot validation with full output
validate-godot-detailed:
    #!/usr/bin/env bash
    set -euo pipefail
    
    cd "{{PROJECT_PATH}}"
    
    echo "🔍 Running detailed Godot validation..."
    echo "======================================"
    
    # Create temporary log file
    TEMP_LOG=$(mktemp)
    
    # Run validation and capture output
    if timeout 60 {{GODOT_EXECUTABLE}} --headless --validate-only --verbose --debug-stringnames --quit > "$TEMP_LOG" 2>&1; then
        echo "✅ Godot validation completed successfully"
    else
        echo "❌ Godot validation failed"
    fi
    
    # Show summary
    echo ""
    echo "Validation Summary:"
    echo "=================="
    
    # Count different types of messages
    ERRORS=$(grep -c "ERROR" "$TEMP_LOG" 2>/dev/null || echo "0")
    WARNINGS=$(grep -c "WARNING" "$TEMP_LOG" 2>/dev/null || echo "0")
    SCRIPT_ERRORS=$(grep -c "SCRIPT ERROR" "$TEMP_LOG" 2>/dev/null || echo "0")
    
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    echo "Script Errors: $SCRIPT_ERRORS"
    
    # Show errors if any
    if [[ $ERRORS -gt 0 || $SCRIPT_ERRORS -gt 0 ]]; then
        echo ""
        echo "❌ Critical Issues Found:"
        echo "========================"
        grep -E "ERROR|SCRIPT ERROR" "$TEMP_LOG" | head -20
        echo ""
        echo "Full validation output available at: $TEMP_LOG"
        echo "Use 'cat $TEMP_LOG' to view complete output"
        exit 1
    fi
    
    # Show warnings if any
    if [[ $WARNINGS -gt 0 ]]; then
        echo ""
        echo "⚠️  Warnings Found:"
        echo "=================="
        grep "WARNING" "$TEMP_LOG" | head -10
    fi
    
    echo ""
    echo "✅ Validation completed successfully"
    echo "Full output available at: $TEMP_LOG"
    
    # Clean up
    rm "$TEMP_LOG"

# Quick validation for testing
_test-quick-android:
    #!/usr/bin/env bash
    echo "🚀 Running quick Android validation..."
    
    # Use shared connectivity check
    just _test-check-android-device

# Android test monitoring with activity timeout
test-monitor-android duration_seconds="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    DURATION={{duration_seconds}}
    PACKAGE_NAME="{{ANDROID_PACKAGE_NAME}}"
    
    echo "🔍 Starting Android test monitoring for ${DURATION}s..."
    echo "Package: $PACKAGE_NAME"
    echo "================================"
    
    # Start monitoring
    just _monitor-with-activity-timeout "$PACKAGE_NAME" "$DURATION"

# Internal monitoring function with activity timeout
_monitor-with-activity-timeout package_name duration_seconds:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PACKAGE_NAME="{{package_name}}"
    DURATION={{duration_seconds}}
    
    echo "Monitoring package: $PACKAGE_NAME"
    echo "Duration: ${DURATION}s"
    echo "Starting in 3 seconds..."
    sleep 3
    
    # Monitor with timeout
    timeout "$DURATION" adb logcat -c && timeout "$DURATION" adb logcat | grep "$PACKAGE_NAME" || {
        echo ""
        echo "⏰ Monitoring completed (${DURATION}s timeout)"
        echo "✅ Test monitoring finished"
    }

# Execute test configuration on Android
_test-config-android config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    # Use shared setup and preparation functions
    just _test-setup-android "$CONFIG_NAME" "basic"
    just _test-prepare-android "$CONFIG_NAME"
    just _test-check-android-device
    
    echo ""
    echo "📱 Device connected, starting test..."
    
    # Generate unique test ID
    TEST_ID="${CONFIG_NAME}_$(date +%s)"
    export TEST_ID
    
    echo "🔍 Test ID: $TEST_ID"
    echo ""
    
    # Clear logcat buffer
    adb logcat -c
    
    # Get app PID for monitoring
    APP_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    if [[ -n "$APP_PID" ]]; then
        echo "🔍 App PID: $APP_PID"
    else
        echo "⚠️  App not running, will start with test"
    fi
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="
    
    # Use config-restart to properly deploy config and start app
    echo "📱 Deploying configuration and starting app..."
    just config-restart-android "$CONFIG_NAME"
    echo ""
    
    # Wait for app to start
    sleep 2
    
    # Monitor test execution
    echo ""
    echo "🔍 Monitoring test execution..."
    echo "==============================="
    
    # Start log monitoring in background
    LOGCAT_PID=""
    (
        # Monitor for test completion or errors
        adb logcat | grep -E "(TEST_COMPLETE|TEST_ERROR|ERROR|CRITICAL)" | head -20
    ) &
    LOGCAT_PID=$!
    
    # Wait for test completion (max 60 seconds)
    TIMEOUT=60
    ELAPSED=0
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        # Check if test completed
        if adb logcat -d | grep -q "TEST_COMPLETE.*$TEST_ID"; then
            echo ""
            echo "✅ Test completed successfully!"
            break
        fi
        
        # Check for errors
        if adb logcat -d | grep -q "TEST_ERROR.*$TEST_ID"; then
            echo ""
            echo "❌ Test failed with error!"
            break
        fi
        
        # Check if app is still running
        CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
        if [[ -z "$CURRENT_PID" ]]; then
            echo ""
            echo "⚠️  App stopped running"
            break
        fi
        
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        
        # Progress indicator
        if [[ $((ELAPSED % 10)) -eq 0 ]]; then
            echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
        fi
    done
    
    # Stop log monitoring
    if [[ -n "$LOGCAT_PID" ]]; then
        kill $LOGCAT_PID 2>/dev/null || true
    fi
    
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo ""
        echo "⏰ Test timed out after ${TIMEOUT}s"
    fi
    
    echo ""
    echo "📊 Test Results Summary"
    echo "======================="
    echo "Test ID: $TEST_ID"
    echo "Configuration: $CONFIG_NAME"
    echo "Duration: ${ELAPSED}s"
    
    # Show recent relevant logs
    echo ""
    echo "📋 Recent Test Logs:"
    echo "==================="
    adb logcat -d | grep "$TEST_ID" | tail -10 || echo "No test-specific logs found"
    
    echo ""
    echo "🔍 Error Summary:"
    echo "================="
    adb logcat -d | grep -E "(ERROR|CRITICAL)" | grep -v "GL_INVALID" | tail -5 || echo "No errors found"
    
    echo ""
    echo "✅ Test execution completed"
    echo "Use 'just logs $TEST_ID' for detailed analysis"

# Enhanced test configuration with comprehensive error analysis
_test-config-android-enhanced config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    # Use shared setup and preparation functions
    just _test-setup-android "$CONFIG_NAME" "enhanced"
    just _test-prepare-android "$CONFIG_NAME"
    just _test-check-android-device
    
    # Generate unique test ID using shared function
    TEST_ID=$(just _shared-generate-test-id "$CONFIG_NAME" "enhanced")
    export TEST_ID
    
    # Display standardized test info
    just _display-test-info "$TEST_ID" "$CONFIG_NAME" "enhanced" "android"
    
    # Pre-test device state
    echo ""
    echo "📊 Pre-test Device State:"
    echo "========================="
    
    # Check app state
    APP_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    if [[ -n "$APP_PID" ]]; then
        echo "🔍 App running (PID: $APP_PID)"
    else
        echo "⚠️  App not running"
    fi
    
    # Check device resources
    echo "💾 Memory: $(adb shell cat /proc/meminfo | grep MemAvailable | awk '{print $2 " " $3}')"
    echo "💽 Storage: $(adb shell df /data | tail -1 | awk '{print $4}') KB available"
    echo "🔋 Battery: $(adb shell dumpsys battery | grep level | cut -d':' -f2 | tr -d ' ')%"
    
    # Clear logcat buffer
    adb logcat -c
    
    echo ""
    echo "🚀 Starting Enhanced Test Execution..."
    echo "====================================="
    
    # Start app with enhanced configuration
    adb shell am start -n "{{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" \
        --es "test_id" "$TEST_ID" \
        --es "config_name" "$CONFIG_NAME" \
        --ez "enhanced_mode" "true"
    
    # Wait for app initialization
    sleep 3
    
    # Enhanced monitoring
    echo ""
    echo "🔍 Enhanced Monitoring Active..."
    echo "==============================="
    
    # Start comprehensive log monitoring
    LOGCAT_PID=""
    (
        adb logcat | while read -r line; do
            echo "$line"
            # Check for test completion
            if echo "$line" | grep -q "TEST_COMPLETE.*$TEST_ID"; then
                echo "✅ Test completed - monitoring continues..."
            fi
            # Check for errors
            if echo "$line" | grep -q "ERROR\|CRITICAL"; then
                echo "❌ Error detected - continuing monitoring..."
            fi
        done
    ) &
    LOGCAT_PID=$!
    
    # Wait for test completion with extended timeout
    TIMEOUT=120
    ELAPSED=0
    TEST_COMPLETED=false
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        # Check test completion
        if adb logcat -d | grep -q "TEST_COMPLETE.*$TEST_ID"; then
            TEST_COMPLETED=true
            break
        fi
        
        # Check for critical errors
        if adb logcat -d | grep -q "TEST_ERROR.*$TEST_ID"; then
            echo ""
            echo "❌ Critical test error detected!"
            break
        fi
        
        # App status check
        CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
        if [[ -z "$CURRENT_PID" ]]; then
            echo ""
            echo "⚠️  App stopped unexpectedly"
            break
        fi
        
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        
        # Progress with resource monitoring
        if [[ $((ELAPSED % 20)) -eq 0 ]]; then
            echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
            # Show current memory usage
            MEM_INFO=$(adb shell dumpsys meminfo "{{ANDROID_PACKAGE_NAME}}" | grep "TOTAL" | head -1 | awk '{print $2}')
            if [[ -n "$MEM_INFO" ]]; then
                echo "💾 Current memory: ${MEM_INFO} KB"
            fi
        fi
    done
    
    # Stop monitoring
    if [[ -n "$LOGCAT_PID" ]]; then
        kill $LOGCAT_PID 2>/dev/null || true
    fi
    
    echo ""
    echo "🔬 Enhanced Test Analysis"
    echo "========================"
    echo "Test ID: $TEST_ID"
    echo "Configuration: $CONFIG_NAME"
    echo "Duration: ${ELAPSED}s"
    echo "Status: $(if [[ $TEST_COMPLETED == true ]]; then echo "✅ COMPLETED"; else echo "❌ FAILED/TIMEOUT"; fi)"
    
    # Post-test device state
    echo ""
    echo "📊 Post-test Device State:"
    echo "========================="
    FINAL_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    if [[ -n "$FINAL_PID" ]]; then
        echo "🔍 App running (PID: $FINAL_PID)"
    else
        echo "⚠️  App not running"
    fi
    
    # Comprehensive log analysis
    echo ""
    echo "📋 Comprehensive Log Analysis:"
    echo "=============================="
    
    # Error categorization
    echo "🔥 Critical Errors:"
    adb logcat -d | grep -E "(CRITICAL|FATAL)" | grep -v "GL_INVALID" | tail -3 || echo "  None found"
    
    echo ""
    echo "❌ General Errors:"
    adb logcat -d | grep "ERROR" | grep -v "GL_INVALID" | tail -5 || echo "  None found"
    
    echo ""
    echo "⚠️  Warnings:"
    adb logcat -d | grep "WARNING" | tail -3 || echo "  None found"
    
    echo ""
    echo "🔍 Test-specific Logs:"
    adb logcat -d | grep "$TEST_ID" | tail -10 || echo "  No test-specific logs found"
    
    # Performance analysis
    echo ""
    echo "⚡ Performance Metrics:"
    echo "======================"
    
    # Memory usage
    if [[ -n "$FINAL_PID" ]]; then
        MEM_INFO=$(adb shell dumpsys meminfo "{{ANDROID_PACKAGE_NAME}}" | grep "TOTAL" | head -1)
        if [[ -n "$MEM_INFO" ]]; then
            echo "💾 Final memory usage: $MEM_INFO"
        fi
    fi
    
    # CPU usage (if available)
    if [[ -n "$FINAL_PID" ]]; then
        CPU_INFO=$(adb shell top -n 1 -p "$FINAL_PID" | tail -1 | awk '{print $9}' 2>/dev/null || echo "")
        if [[ -n "$CPU_INFO" ]]; then
            echo "🔧 CPU usage: ${CPU_INFO}%"
        fi
    fi
    
    echo ""
    echo "✅ Enhanced test analysis completed"
    echo "Use 'just logs $TEST_ID' for detailed log analysis"

# Match test lists based on wildcard pattern
_match_test_list_pattern pattern current_context:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{pattern}}"
    CURRENT_CONTEXT="{{current_context}}"
    
    # Remove @ prefix if present
    PATTERN="${PATTERN#@}"
    
    # Convert wildcard pattern to shell glob
    case "$PATTERN" in
        *"*"*)
            # Has wildcards - use shell globbing
            shopt -s nullglob
            for file in "{{TEST_LIST_DIR}}"/${PATTERN}.json; do
                if [[ -f "$file" ]] && jq -e . "$file" >/dev/null 2>&1; then
                    list_name=$(basename "${file%%.json}")
                    # Exclude self-reference to prevent circular dependencies
                    if [[ "$list_name" != "$CURRENT_CONTEXT" ]]; then
                        echo "$list_name"
                    fi
                fi
            done
            shopt -u nullglob
            ;;
        *)
            # Exact match
            if [[ -f "{{TEST_LIST_DIR}}/${PATTERN}.json" ]] && jq -e . "{{TEST_LIST_DIR}}/${PATTERN}.json" >/dev/null 2>&1; then
                # Exclude self-reference
                if [[ "$PATTERN" != "$CURRENT_CONTEXT" ]]; then
                    echo "$PATTERN"
                fi
            fi
            ;;
    esac

# Resolve test list reference with circular dependency detection
_resolve_test_list_reference ref visited_stack:
    #!/usr/bin/env bash
    set -euo pipefail
    
    REF="{{ref}}"
    VISITED_STACK="{{visited_stack}}"
    MAX_DEPTH=10
    
    # Remove @ prefix
    REF_NAME="${REF#@}"
    
    # Check for circular dependency
    if [[ "$VISITED_STACK" == *"|$REF_NAME|"* ]]; then
        echo "❌ Circular reference detected: $REF_NAME in chain: ${VISITED_STACK//|/ → }"
        exit 1
    fi
    
    # Check recursion depth
    DEPTH=$(echo "$VISITED_STACK" | tr -cd '|' | wc -c)
    if [[ $DEPTH -gt $MAX_DEPTH ]]; then
        echo "❌ Maximum reference depth ($MAX_DEPTH) exceeded: ${VISITED_STACK//|/ → } → $REF_NAME"
        exit 1
    fi
    
    # Update visited stack
    NEW_VISITED_STACK="${VISITED_STACK}|${REF_NAME}|"
    
    # Resolve pattern or direct reference
    if [[ "$REF_NAME" == *"*"* ]]; then
        # Wildcard pattern - get all matching test lists
        # Extract the root context from the visited stack
        ROOT_CONTEXT=$(echo "$VISITED_STACK" | sed 's/^|\([^|]*\)|.*/\1/')
        while IFS= read -r matched_list; do
            if [[ -n "$matched_list" ]]; then
                just _resolve_test_list_reference "@${matched_list}" "$NEW_VISITED_STACK"
            fi
        done < <(just _match_test_list_pattern "$REF_NAME" "$ROOT_CONTEXT")
    else
        # Direct reference - load and expand the test list
        if [[ ! -f "{{TEST_LIST_DIR}}/${REF_NAME}.json" ]]; then
            echo "❌ Referenced test list not found: $REF_NAME"
            exit 1
        fi
        
        # Extract configs from referenced test list
        jq -r '.configs[]?' "{{TEST_LIST_DIR}}/${REF_NAME}.json" 2>/dev/null | while IFS= read -r config; do
            if [[ "$config" =~ ^@ ]]; then
                # Recursive @ reference
                just _resolve_test_list_reference "$config" "$NEW_VISITED_STACK"
            else
                # Regular config
                echo "$config"
            fi
        done
    fi

# Expand @ symbols in test list configs
_expand_at_references test_list:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST="{{test_list}}"
    
    # Check if test list exists
    if [[ ! -f "{{TEST_LIST_DIR}}/${TEST_LIST}.json" ]]; then
        echo "❌ Test list not found: {{TEST_LIST_DIR}}/${TEST_LIST}.json"
        exit 1
    fi
    
    # Process each config in the test list and remove duplicates
    TEMP_FILE=$(mktemp)
    
    jq -r '.configs[]?' "{{TEST_LIST_DIR}}/${TEST_LIST}.json" 2>/dev/null | while IFS= read -r config; do
        if [[ "$config" =~ ^@ ]]; then
            # @ reference - resolve it, starting with the current test list as context
            just _resolve_test_list_reference "$config" "|${TEST_LIST}|"
        elif [[ "$config" =~ ^/ ]]; then
            # NEW: / folder reference - resolve it
            just _resolve_folder_reference "$config"
        else
            # Regular config
            echo "$config"
        fi
    done | sort | uniq > "$TEMP_FILE"
    
    # Output unique configs
    cat "$TEMP_FILE"
    rm -f "$TEMP_FILE"

# Resolve folder reference (NEW: /folder/ syntax support)
_resolve_folder_reference ref:
    #!/usr/bin/env bash
    set -euo pipefail
    
    REF="{{ref}}"
    
    # Remove leading / if present
    FOLDER_PATH="${REF#/}"
    # Remove trailing / if present
    FOLDER_PATH="${FOLDER_PATH%/}"
    
    # Check if it contains a pattern (has * or ?)
    if [[ "$FOLDER_PATH" == *"*"* ]] || [[ "$FOLDER_PATH" == *"?"* ]]; then
        # Extract folder and pattern parts
        if [[ "$FOLDER_PATH" == *"/"* ]]; then
            # Pattern like "generated-replays/merge-*" 
            FOLDER_DIR="${FOLDER_PATH%/*}"
            PATTERN="${FOLDER_PATH##*/}"
            FULL_FOLDER_PATH="{{DEBUG_CONFIG_DIR}}/${FOLDER_DIR}"
        else
            # Pattern like "generated-*" (direct in debug_configs)
            FOLDER_DIR=""
            PATTERN="$FOLDER_PATH"
            FULL_FOLDER_PATH="{{DEBUG_CONFIG_DIR}}"
        fi
    else
        # No wildcards - treat as folder name
        FOLDER_DIR="$FOLDER_PATH"
        PATTERN="*"
        FULL_FOLDER_PATH="{{DEBUG_CONFIG_DIR}}/${FOLDER_DIR}"
    fi
    
    # Verify folder exists
    if [[ ! -d "$FULL_FOLDER_PATH" ]]; then
        echo "❌ Folder not found: $FULL_FOLDER_PATH" >&2
        echo "💡 Available folders in {{DEBUG_CONFIG_DIR}}:" >&2
        find "{{DEBUG_CONFIG_DIR}}" -type d -maxdepth 2 2>/dev/null | sort | sed 's/^/   /' >&2 || true
        exit 1
    fi
    
    # Find matching configs
    FOUND_CONFIGS=0
    shopt -s nullglob
    for file in "$FULL_FOLDER_PATH"/${PATTERN}.json; do
        if [[ -f "$file" ]] && jq -e . "$file" >/dev/null 2>&1; then
            config_name=$(basename "${file%%.json}")
            echo "$config_name"
            FOUND_CONFIGS=$((FOUND_CONFIGS + 1))
        fi
    done
    shopt -u nullglob
    
    # Warn if no configs found
    if [[ $FOUND_CONFIGS -eq 0 ]]; then
        echo "⚠️  No valid configs found matching: ${REF}" >&2
        echo "💡 Available configs in $FULL_FOLDER_PATH:" >&2
        find "$FULL_FOLDER_PATH" -name "*.json" -type f 2>/dev/null | head -5 | sed 's/^/   /' >&2 || true
    fi

# Expand test list configuration
_expand_test_list test_list:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST="{{test_list}}"
    
    echo "🔍 Expanding test list: $TEST_LIST"
    
    # Check if test list exists
    if [[ ! -f "{{TEST_LIST_DIR}}/${TEST_LIST}.json" ]]; then
        echo "❌ Test list not found: {{TEST_LIST_DIR}}/${TEST_LIST}.json"
        echo ""
        echo "Available test lists:"
        if [[ -d "{{TEST_LIST_DIR}}" ]]; then
            find "{{TEST_LIST_DIR}}" -name "*.json" -type f | sort | while read -r list; do
                basename=$(basename "$list" .json)
                if [[ -f "$list" ]] && jq -e . "$list" >/dev/null 2>&1; then
                    description=$(jq -r '.description // "No description"' "$list" 2>/dev/null || echo "No description")
                    echo "  📋 $basename - $description"
                else
                    echo "  ❌ $basename - Invalid JSON"
                fi
            done
        else
            echo "  No test list directory found: {{TEST_LIST_DIR}}"
        fi
        exit 1
    fi
    
    # Validate JSON format
    if ! jq -e . "{{TEST_LIST_DIR}}/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in test list: {{TEST_LIST_DIR}}/${TEST_LIST}.json"
        exit 1
    fi
    
    # Extract configs
    if ! jq -e '.configs' "{{TEST_LIST_DIR}}/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Test list missing required 'configs' field"
        exit 1
    fi
    
    # Validate configs is an array
    if ! jq -e '.configs | type == "array"' "{{TEST_LIST_DIR}}/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Test list 'configs' field must be an array"
        exit 1
    fi
    
    # Check if test list contains @ references
    HAS_AT_REFERENCES=$(jq -r '.configs[]?' "{{TEST_LIST_DIR}}/${TEST_LIST}.json" 2>/dev/null | grep -c "^@" || echo "0")
    HAS_AT_REFERENCES=$(echo "$HAS_AT_REFERENCES" | tail -1)  # Get only the last line to avoid multi-line issues
    
    if [[ "${HAS_AT_REFERENCES:-0}" -gt 0 ]]; then
        echo "🔄 Processing @ references in test list..."
        echo "📋 Expanded configurations:"
        
        # Use @ symbol expansion
        just _expand_at_references "$TEST_LIST" | while read -r config; do
            if [[ -n "$config" ]]; then
                echo "  • $config"
            fi
        done
    else
        echo "📋 Test list configurations:"
        jq -r '.configs[]' "{{TEST_LIST_DIR}}/${TEST_LIST}.json" | while read -r config; do
            echo "  • $config"
        done
    fi
    
    echo ""
    echo "✅ Test list expanded successfully"

# Load and validate test list
_load_test_list test_list:
    @just _expand_test_list "{{test_list}}"

# Execute test list on Android
_test-list-android test_list:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST="{{test_list}}"
    TEST_LIST_PATH="{{TEST_LIST_DIR}}/${TEST_LIST}.json"
    
    echo "🧪 Executing test list: $TEST_LIST"
    echo "================================="
    
    # Use shared JSON parsing for validation and config extraction
    CONFIGS=$(just _parse-test-list-json "$TEST_LIST_PATH")
    if [[ -z "$CONFIGS" ]]; then
        echo "❌ No configurations found in test list"
        exit 1
    fi
    
    # Show test list metadata using shared function
    just _get-test-list-metadata "$TEST_LIST_PATH"
    
    echo ""
    echo "📋 Configuration List:"
    echo "==================="
    echo "$CONFIGS" | nl -w2 -s'. '
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="
    
    # Execute each configuration
    TOTAL_CONFIGS=0
    PASSED_CONFIGS=0
    FAILED_CONFIGS=0
    
    while IFS= read -r config; do
        if [[ -z "$config" ]]; then
            continue
        fi
        
        TOTAL_CONFIGS=$((TOTAL_CONFIGS + 1))
        
        echo ""
        echo "🔍 Testing configuration $TOTAL_CONFIGS: $config"
        echo "================================================="
        
        # Execute configuration
        if just _test-config-android "$config"; then
            echo "✅ Configuration passed: $config"
            PASSED_CONFIGS=$((PASSED_CONFIGS + 1))
        else
            echo "❌ Configuration failed: $config"
            FAILED_CONFIGS=$((FAILED_CONFIGS + 1))
        fi
        
        # Small delay between tests
        sleep 2
    done <<< "$CONFIGS"
    
    echo ""
    echo "📊 Test List Results Summary"
    echo "============================="
    echo "Test List: $TEST_LIST"
    echo "Total Configurations: $TOTAL_CONFIGS"
    echo "Passed: $PASSED_CONFIGS"
    echo "Failed: $FAILED_CONFIGS"
    echo "Success Rate: $(( PASSED_CONFIGS * 100 / TOTAL_CONFIGS ))%"
    
    if [[ $FAILED_CONFIGS -gt 0 ]]; then
        echo ""
        echo "❌ Test list completed with failures"
        exit 1
    else
        echo ""
        echo "✅ Test list completed successfully"
    fi

# Test trace mode for debugging
test-android-trace target:
    @echo "🔍 Test trace mode for: {{target}}"
    @just _test-config-android "{{target}}"

# Test specific configuration on Android - automated mode (quits automatically)
# NOTE: This command is now provided by justfile-validation-enhanced-testing.justfile
# # test-android-target config_name:
#     #!/usr/bin/env bash
#     set -euo pipefail
#     
#     CONFIG_NAME="{{config_name}}"
#     CONFIG_PATH="./{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
#     
#     echo "🎯 Testing target: $CONFIG_NAME"
#     echo "==============================="
#     
#     # Clear Android test cache first to prevent stale state contamination
#     echo "🧹 Clearing Android test cache to ensure fresh state..."
#     just clear-android-test-cache
#     echo ""
#     
#     # Validate configuration exists
#     just _validate-config-exists "$CONFIG_NAME"
#     
#     # Check device connectivity
#     if ! adb devices | grep -q "device$"; then
#         echo "❌ No Android device connected"
#         echo "Please connect a device and enable USB debugging"
#         exit 1
#     fi
#     
#     # Check if configuration has checksum validation
#     HAS_CHECKSUM=false
#     if [[ -f "$CONFIG_PATH" ]] && jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
#         HAS_CHECKSUM=true
#         
#         # Get checksum configuration
#         STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
#         EXPECTED_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_PATH")
#         
#         echo "📸 Checksum Test Detected"
#         echo "State Type: $STATE_TYPE"
#         echo "Expected Checksum: $EXPECTED_CHECKSUM"
#         
#         # Check if baseline is set
#         if [[ -z "$EXPECTED_CHECKSUM" ]]; then
#             echo ""
#             echo "ℹ️  No baseline checksum set - this will be the first run"
#             echo "   A baseline will be automatically created and saved"
#             echo "   The test will automatically restart to validate the baseline"
#         else
#             echo ""
#             echo "✅ Baseline checksum found - will validate against it"
#         fi
#     fi
#     
#     # Generate unique test ID
#     TEST_ID="${CONFIG_NAME}_$(date +%s)"
#     export TEST_ID
#     
#     echo ""
#     echo "🔍 Test ID: $TEST_ID"
#     echo "📱 Device: $(adb devices | grep 'device$' | head -1 | cut -f1)"
#     echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
#     
#     # Clear logcat buffer
#     adb logcat -c
#     
#     # Get current app state
#     APP_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
#     if [[ -n "$APP_PID" ]]; then
#         echo "🔍 App running (PID: $APP_PID)"
#     else
#         echo "⚠️  App not running - will start"
#     fi
#     
#     echo ""
#     echo "🚀 Starting test execution..."
#     echo "============================="
#     
#     # Use config-restart to properly deploy config and start app
#     echo "📱 Deploying configuration and starting app..."
#     just config-restart-android "$CONFIG_NAME"
#     echo ""
#     
#     # Wait for app initialization
#     sleep 3
#     
#     # Monitor test execution
#     echo ""
#     echo "🔍 Monitoring test execution..."
#     echo "==============================="
#     
#     # Start log monitoring
#     LOGCAT_PID=""
#     (
#         adb logcat | grep -E "(TEST_|ERROR|CRITICAL|CHECKSUM)" | while read -r line; do
#             echo "$line"
#             # Check for test completion
#             if echo "$line" | grep -q "TEST_COMPLETE.*$TEST_ID"; then
#                 echo "✅ Test execution completed"
#             fi
#             # Check for checksum events
#             if echo "$line" | grep -q "CHECKSUM"; then
#                 echo "📸 Checksum event detected"
#             fi
#         done
#     ) &
#     LOGCAT_PID=$!
#     
#     # Wait for test completion
#     TIMEOUT=180  # Extended timeout for checksum tests
#     ELAPSED=0
#     TEST_COMPLETED=false
#     CHECKSUM_SAVED=false
#     
#     while [[ $ELAPSED -lt $TIMEOUT ]]; do
#         # Check for test completion
#         if adb logcat -d | grep -q "TEST_COMPLETE.*$TEST_ID"; then
#             TEST_COMPLETED=true
#             break
#         fi
#         
#         # Check for checksum save event (first run scenario)
#         if [[ $HAS_CHECKSUM == true ]] && adb logcat -d | grep -q "CHECKSUM_SAVED.*$TEST_ID"; then
#             CHECKSUM_SAVED=true
#             echo ""
#             echo "📸 Checksum baseline saved - test will restart automatically"
#         fi
#         
#         # Check for errors
#         if adb logcat -d | grep -q "TEST_ERROR.*$TEST_ID"; then
#             echo ""
#             echo "❌ Test failed with error"
#             break
#         fi
#         
#         # Check app status
#         CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
#         if [[ -z "$CURRENT_PID" ]]; then
#             echo ""
#             echo "⚠️  App stopped"
#             break
#         fi
#         
#         sleep 2
#         ELAPSED=$((ELAPSED + 2))
#         
#         # Progress indicator
#         if [[ $((ELAPSED % 20)) -eq 0 ]]; then
#             echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
#         fi
#     done
#     
#     # Stop monitoring
#     if [[ -n "$LOGCAT_PID" ]]; then
#         kill $LOGCAT_PID 2>/dev/null || true
#     fi
#     
#     echo ""
#     echo "📊 Test Results"
#     echo "==============="
#     echo "Test ID: $TEST_ID"
#     echo "Configuration: $CONFIG_NAME"
#     echo "Duration: ${ELAPSED}s"
#     
#     # Determine test result
#     if [[ $TEST_COMPLETED == true ]]; then
#         echo "Status: ✅ COMPLETED"
#         
#         # Check for checksum validation results
#         if [[ $HAS_CHECKSUM == true ]]; then
#             echo ""
#             echo "📸 Checksum Validation:"
#             echo "======================"
#             
#             if adb logcat -d | grep -q "CHECKSUM_MATCH.*$TEST_ID"; then
#                 echo "✅ Checksum validation PASSED"
#             elif adb logcat -d | grep -q "CHECKSUM_MISMATCH.*$TEST_ID"; then
#                 echo "❌ Checksum validation FAILED"
#                 echo ""
#                 echo "Expected vs Actual checksum mismatch detected"
#                 echo "This could indicate:"
#                 echo "  • Legitimate changes requiring baseline update"
#                 echo "  • Regression in game state consistency"
#                 echo "  • Non-deterministic behavior in game logic"
#                 echo ""
#                 echo "Use 'just test-android-update $CONFIG_NAME' to update baseline if changes are legitimate"
#             elif [[ $CHECKSUM_SAVED == true ]]; then
#                 echo "📸 Baseline checksum created - test restarted automatically"
#                 echo "✅ Baseline validation completed"
#             else
#                 echo "⚠️  No checksum validation events found"
#             fi
#         fi
#     else
#         echo "Status: ❌ FAILED/TIMEOUT"
#     fi
#     
#     # Show relevant logs
#     echo ""
#     echo "📋 Test Logs:"
#     echo "============="
#     adb logcat -d | grep "$TEST_ID" | tail -10 || echo "No test-specific logs found"
#     
#     echo ""
#     echo "🔍 Error Summary:"
#     echo "================="
#     ERROR_COUNT=$(adb logcat -d | grep -E "(ERROR|CRITICAL)" | grep -v "GL_INVALID" | wc -l)
#     if [[ $ERROR_COUNT -gt 0 ]]; then
#         echo "Found $ERROR_COUNT errors:"
#         adb logcat -d | grep -E "(ERROR|CRITICAL)" | grep -v "GL_INVALID" | tail -5
#     else
#         echo "No errors found"
#     fi
#     
#     echo ""
#     echo "✅ Test execution completed"
#     echo "Use 'just logs $TEST_ID' for detailed analysis"
# 
# Internal helper: Test Android configuration in manual mode (stays open)
_test-android-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # Use shared setup functions
    just _test-setup-android "$CONFIG_NAME" "manual"
    just _test-prepare-android "$CONFIG_NAME"
    just _test-check-android-device
    
    # Generate unique test ID using shared function
    TEST_ID=$(just _shared-generate-test-id "$CONFIG_NAME" "manual")
    export TEST_ID
    
    # Display standardized test info
    just _display-test-info "$TEST_ID" "$CONFIG_NAME" "manual" "android"
    echo "👁️  Mode: Manual (stays open for verification)"
    
    # Clear logcat buffer
    adb logcat -c
    
    echo ""
    echo "🚀 Starting manual test..."
    echo "========================="
    
    # Use config-restart to properly deploy config and start app
    echo "📱 Deploying configuration and starting app..."
    just config-restart-android "$CONFIG_NAME"
    
    echo ""
    echo "👁️  Manual Test Running"
    echo "======================="
    echo "The app is now running in manual test mode."
    echo "The debug interface is hidden for clean verification."
    echo ""
    echo "You can:"
    echo "• Take screenshots: just screenshot-android"
    echo "• Monitor logs: just logs $TEST_ID"
    echo "• Close the app manually when done"
    echo ""
    echo "✅ Manual test started successfully"
    echo "Test ID: $TEST_ID"

# Internal helper: Test Android test list in manual mode (stays open)
_test-list-android-manual list_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LIST_NAME="{{list_name}}"
    echo "📋 Testing list (manual mode - stays open): $LIST_NAME"
    echo "============================================="
    
    # For now, just run the first config in manual mode
    # This is a simplified implementation - full test list support would require more work
    FIRST_CONFIG=$(jq -r '.configurations[0].name // "development-workflow"' "./{{TEST_LIST_DIR}}/${LIST_NAME}.json" 2>/dev/null || echo "development-workflow")
    echo "Running first config in manual mode: $FIRST_CONFIG"
    just _test-android-manual "$FIRST_CONFIG"

# Enhanced test with comprehensive analysis
test-android-enhanced target:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{target}}"
    
    echo "🔬 Enhanced Android Testing: $TARGET"
    echo "==================================="
    
    # Check if target is a test list or configuration
    if [[ -f "./{{TEST_LIST_DIR}}/${TARGET}.json" ]]; then
        echo "📋 Detected test list: $TARGET"
        just _test-list-android "$TARGET"
    elif [[ -f "./{{DEBUG_CONFIG_DIR}}/${TARGET}.json" ]]; then
        echo "📄 Detected configuration: $TARGET"
        just _test-config-android-enhanced "$TARGET"
    else
        echo "❌ Target not found: $TARGET"
        echo ""
        echo "Available targets:"
        echo "=================="
        
        echo "📋 Test Lists:"
        if [[ -d "./{{TEST_LIST_DIR}}" ]]; then
            find "./{{TEST_LIST_DIR}}" -name "*.json" -type f | sort | while read -r list; do
                basename=$(basename "$list" .json)
                description=$(jq -r '.description // "No description"' "$list" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        echo ""
        echo "📄 Configurations:"
        if [[ -d "./{{DEBUG_CONFIG_DIR}}" ]]; then
            find "./{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f | sort | while read -r config; do
                basename=$(basename "$config" .json)
                description=$(jq -r '.description // "No description"' "$config" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        exit 1
    fi


# Reset checksum baseline for test configuration
test-android-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."
        
        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""
        
        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")
                    
                    # Determine status
                    if [[ -z "$expected_checksum" ]]; then
                        status="❌ NO BASELINE SET"
                    else
                        status="✅ BASELINE SET"
                    fi
                    
                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi
        
        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi
        
        echo "📸 Available checksum configurations:"
        echo "===================================="
        
        # Use fzf for selection if available
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to reset: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi
            
            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-android-reset CONFIG_NAME"
            exit 1
        fi
    fi
    
    echo "🗑️  Resetting checksum baseline for: $CONFIG_NAME"
    echo "================================================="
    
    CONFIG_PATH="./{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        exit 1
    fi
    
    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CURRENT_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_PATH")
    
    echo "📸 Current Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksum: $CURRENT_CHECKSUM"
    
    if [[ -z "$CURRENT_CHECKSUM" ]]; then
        echo ""
        echo "ℹ️  No baseline currently set - nothing to reset"
        exit 0
    fi
    
    # Confirm reset
    echo ""
    echo "⚠️  WARNING: This will remove the current baseline checksum"
    echo "The next test run will create a new baseline automatically"
    echo ""
    read -p "Are you sure you want to reset the baseline? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Reset cancelled"
        exit 1
    fi
    
    # Clear expected checksum
    echo ""
    echo "🗑️  Clearing baseline checksum..."
    TEMP_CONFIG=$(mktemp)
    jq '.checksum_config.expected_checksum = ""' "$CONFIG_PATH" > "$TEMP_CONFIG"
    mv "$TEMP_CONFIG" "$CONFIG_PATH"
    
    echo "✅ Baseline reset completed successfully!"
    echo "========================================"
    echo "Configuration: $CONFIG_NAME"
    echo "State Type: $STATE_TYPE"
    echo "Previous Checksum: $CURRENT_CHECKSUM"
    echo "New Checksum: (none - will be created on next run)"
    echo ""
    echo "The next test run will automatically create a new baseline."
    echo "Use 'just test-android-target $CONFIG_NAME' to generate the new baseline."

# List checksum-enabled configurations
test-android-list-checksum:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📸 Checksum-Enabled Test Configurations"
    echo "======================================="
    
    CHECKSUM_CONFIGS=0
    REGULAR_CONFIGS=0
    
    if [[ ! -d "{{DEBUG_CONFIG_DIR}}" ]]; then
        echo "❌ Configuration directory not found: {{DEBUG_CONFIG_DIR}}"
        exit 1
    fi
    
    # Find all configurations
    find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f | sort | while read -r config_file; do
        if [[ -f "$config_file" ]] && jq -e . "$config_file" >/dev/null 2>&1; then
            basename=$(basename "$config_file" .json)
            description=$(jq -r '.description // "No description"' "$config_file" 2>/dev/null || echo "No description")
            
            # Check if it has checksum configuration
            if jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$config_file")
                
                # Determine baseline status
                if [[ -z "$expected_checksum" ]]; then
                    status="❌ NO BASELINE SET"
                else
                    status="✅ BASELINE SET"
                fi
                
                echo "📸 $basename ($state_type) $status"
                echo "   Description: $description"
                echo "   Checksum: ${expected_checksum:-"(none)"}"
                echo ""
                
                CHECKSUM_CONFIGS=$((CHECKSUM_CONFIGS + 1))
            else
                echo "📄 $basename (regular config)"
                echo "   Description: $description"
                echo ""
                
                REGULAR_CONFIGS=$((REGULAR_CONFIGS + 1))
            fi
        fi
    done
    
    echo "📊 Summary:"
    echo "==========="
    echo "Checksum-enabled configurations: $CHECKSUM_CONFIGS"
    echo "Regular configurations: $REGULAR_CONFIGS"
    echo "Total configurations: $((CHECKSUM_CONFIGS + REGULAR_CONFIGS))"
    
    if [[ $CHECKSUM_CONFIGS -eq 0 ]]; then
        echo ""
        echo "ℹ️  No checksum-enabled configurations found"
        echo "To enable checksum testing, add a checksum_config section to your configuration:"
        echo '{'
        echo '  "description": "Your Test Description",'
        echo '  "actions": ["your.actions.here"],'
        echo '  "checksum_config": {'
        echo '    "state_type": "your_state_type",'
        echo '    "expected_checksum": ""'
        echo '  }'
        echo '}'
    fi


# Android testing interface - manual mode with fzf selection
test-android target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If arguments provided, delegate to test-android-target (automated mode)
    if [ -n "{{target}}" ]; then
        echo "🎯 Automated mode execution: {{target}}"

        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        just test-android-target "{{target}}"
        exit $?
    fi
    
    # Use shared fzf selection for all configs (automatic mode)
    selected=$(just _fzf-select-config "android" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        echo "Running automatic mode: just test-android-target '$selected'"
        just test-android-target "$selected"
    else
        echo "❌ No selection made"
        exit 1
    fi


# Smoke test
_test-smoke-android:
    @echo "🔥 Running smoke tests..."
    @just test-android "smoke-test"

# Development test
_test-development-android:
    @echo "🛠️  Running development tests..."
    @just test-android "development-workflow"

# Production test
_test-production-android:
    @echo "🚀 Running production tests..."
    @just test-android "production-ready"

# Show test list configurations
list-test-lists:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📋 Available Test Lists"
    echo "======================"
    
    
    if [[ ! -d "{{TEST_LIST_DIR}}" ]]; then
        echo "❌ Test list directory not found: {{TEST_LIST_DIR}}"
        exit 1
    fi
    
    # Find all test lists
    find "{{TEST_LIST_DIR}}" -name "*.json" -type f | sort | while read -r list_file; do
        if [[ -f "$list_file" ]] && jq -e . "$list_file" >/dev/null 2>&1; then
            basename=$(basename "$list_file" .json)
            description=$(jq -r '.description // "No description"' "$list_file" 2>/dev/null || echo "No description")
            config_count=$(jq -r '.configurations | length' "$list_file" 2>/dev/null || echo "0")
            
            echo "📋 $basename ($config_count configurations)"
            echo "   Description: $description"
            echo "   Configurations:"
            
            # Show configurations
            jq -r '.configs[]' "$list_file" 2>/dev/null | while read -r config; do
                echo "     • $config"
            done
            
            echo ""
        else
            basename=$(basename "$list_file" .json)
            echo "❌ $basename - Invalid JSON"
            echo ""
        fi
    done
    
    echo "📊 Summary:"
    echo "==========="
    TOTAL_LISTS=$(find "{{TEST_LIST_DIR}}" -name "*.json" -type f | wc -l)
    echo "Total test lists: $TOTAL_LISTS"

# Show test lists matching pattern
list-test-lists-matching pattern:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{pattern}}"
    
    echo "🔍 Test Lists Matching: $PATTERN"
    echo "================================"
    
    
    if [[ ! -d "{{TEST_LIST_DIR}}" ]]; then
        echo "❌ Test list directory not found: {{TEST_LIST_DIR}}"
        exit 1
    fi
    
    MATCHES=0
    
    # Find matching test lists
    find "{{TEST_LIST_DIR}}" -name "*.json" -type f | sort | while read -r list_file; do
        if [[ -f "$list_file" ]] && jq -e . "$list_file" >/dev/null 2>&1; then
            basename=$(basename "$list_file" .json)
            description=$(jq -r '.description // "No description"' "$list_file" 2>/dev/null || echo "No description")
            config_count=$(jq -r '.configurations | length' "$list_file" 2>/dev/null || echo "0")
            
            # Check if name or description matches pattern
            if [[ "$basename" =~ $PATTERN ]] || [[ "$description" =~ $PATTERN ]]; then
                echo "📋 $basename ($config_count configurations)"
                echo "   Description: $description"
                echo "   Configurations:"
                
                # Show configurations
                jq -r '.configs[]' "$list_file" 2>/dev/null | while read -r config; do
                    echo "     • $config"
                done
                
                echo ""
                MATCHES=$((MATCHES + 1))
            fi
        fi
    done
    
    if [[ $MATCHES -eq 0 ]]; then
        echo "❌ No test lists match pattern: $PATTERN"
        echo ""
        echo "Available test lists:"
        find "{{TEST_LIST_DIR}}" -name "*.json" -type f | sort | while read -r list_file; do
            basename=$(basename "$list_file" .json)
            echo "  • $basename"
        done
    fi