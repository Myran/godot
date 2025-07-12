# Enhanced Testing with Comprehensive Log Error Detection
# Automatically enhances existing test commands to include error analysis
# Makes validation part of ordinary testing without new commands

# ================================
# SHARED ERROR ANALYSIS LOGIC
# ================================

# Unified error analysis that works for both Android and Desktop
_analyze-test-errors test_id platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    
    echo "🔍 Analyzing test errors for: $TEST_ID ($PLATFORM)"
    echo "================================================"
    
    # Get logs based on platform
    case "$PLATFORM" in
        "android")
            if ! command -v adb >/dev/null 2>&1; then
                echo "⚠️  adb not available - skipping Android log analysis"
                exit 0
            fi
            
            LOGS=$(adb logcat -d 2>/dev/null | tail -1000)
            if [[ -z "$LOGS" ]]; then
                echo "⚠️  No Android logs available"
                exit 0
            fi
            ;;
            
        "desktop")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            
            if [[ ! -d "$LOGS_DIR" ]]; then
                echo "⚠️  No desktop logs directory: $LOGS_DIR"
                exit 0
            fi
            
            LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
            if [[ -z "$LATEST_LOG" ]]; then
                echo "⚠️  No desktop log files available"
                exit 0
            fi
            
            LOGS=$(cat "$LATEST_LOG")
            echo "📄 Analyzing: $(basename "$LATEST_LOG")"
            ;;
            
        *)
            echo "❌ Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    # Count errors using shared patterns
    CRITICAL_ERRORS=$(echo "$LOGS" | grep -c -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" || echo "0")
    ALL_ERRORS=$(echo "$LOGS" | grep -c -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error|Invalid|Failed to|Cannot|Unable to" || echo "0")
    WARNINGS=$(echo "$LOGS" | grep -c -E "WARNING|WARN|Deprecated|Missing" || echo "0")
    
    # Subtract errors from warnings to avoid double counting
    WARNINGS=$((WARNINGS - ALL_ERRORS))
    if [[ $WARNINGS -lt 0 ]]; then
        WARNINGS=0
    fi
    
    echo ""
    echo "📊 Error Analysis Results:"
    echo "   Critical Errors: $CRITICAL_ERRORS"
    echo "   Total Errors: $ALL_ERRORS"
    echo "   Warnings: $WARNINGS"
    
    # Show sample errors if found
    if [[ $CRITICAL_ERRORS -gt 0 ]]; then
        echo ""
        echo "🚨 Critical Errors Found:"
        echo "$LOGS" | grep -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" | head -3 | sed 's/^/   /'
    fi
    
    if [[ $ALL_ERRORS -gt $CRITICAL_ERRORS ]]; then
        echo ""
        echo "❌ Other Errors Found:"
        echo "$LOGS" | grep -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error|Invalid|Failed to|Cannot|Unable to" | grep -v -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" | head -3 | sed 's/^/   /'
    fi
    
    if [[ $WARNINGS -gt 0 ]] && [[ $WARNINGS -lt 10 ]]; then
        echo ""
        echo "⚠️  Warnings Found: $WARNINGS (non-critical)"
    fi
    
    # Determine result
    if [[ $ALL_ERRORS -gt 0 ]]; then
        echo ""
        echo "❌ ERROR ANALYSIS FAILED"
        echo "💡 Found $ALL_ERRORS errors in test logs"
        echo ""
        case "$PLATFORM" in
            "android")
                echo "🔧 Debug: just logs-errors-tagged $TEST_ID"
                ;;
            "desktop") 
                echo "🔧 Debug: just logs-desktop-errors"
                ;;
        esac
        exit 1
    else
        echo ""
        echo "✅ ERROR ANALYSIS PASSED"
        echo "💡 No critical errors found in logs"
        exit 0
    fi

# ================================
# TEST COMMAND ENHANCEMENT HOOKS
# ================================

# Hook that can be called after any test execution to add error analysis
_post-test-validation test_id platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    
    echo ""
    echo "🔍 Running Post-Test Error Analysis..."
    echo "====================================="
    
    ERROR_ANALYSIS_RESULT=0
    just _analyze-test-errors "$TEST_ID" "$PLATFORM" || ERROR_ANALYSIS_RESULT=$?
    
    if [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
        echo ""
        echo "❌ TEST FAILED DUE TO ERRORS IN LOGS"
        echo "💡 Test execution may have succeeded, but logs contain failures"
        echo "💡 This indicates issues that need to be addressed"
        exit 1
    fi
    
    echo ""
    echo "✅ Test validation complete - no issues found"

# ================================
# ENHANCED EXISTING COMMANDS
# ================================

# Enhanced version of test-android-target that includes automatic error analysis
test-android-target config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    echo "🎯 Android Testing with Error Analysis: $CONFIG_NAME"
    echo "=================================================="
    
    # Generate test ID for tracking
    TEST_ID="${CONFIG_NAME}_$(date +%s)"
    export TEST_ID
    
    echo "🔍 Test ID: $TEST_ID"
    echo ""
    
    # Call the original test implementation from testing-core
    echo "📱 Running Android test execution..."
    echo "==================================="
    
    TEST_RESULT=0
    just _test-android-target-original "$CONFIG_NAME" || TEST_RESULT=$?
    
    echo ""
    echo "📊 Test Execution: $(if [[ $TEST_RESULT -eq 0 ]]; then echo "✅ PASSED"; else echo "❌ FAILED"; fi)"
    
    # Always run error analysis (even if test failed)
    if [[ $TEST_RESULT -eq 0 ]]; then
        just _post-test-validation "$TEST_ID" "android"
    else
        echo ""
        echo "❌ OVERALL RESULT: FAILED"
        echo "💡 Test execution failed - skipping error analysis"
        exit 1
    fi

# Enhanced version of test-desktop-target that includes automatic error analysis  
test-desktop-target config_name duration="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    echo "🎯 Desktop Testing with Error Analysis: $CONFIG_NAME"
    echo "==================================================="
    
    # Generate test ID for tracking
    TEST_ID="${CONFIG_NAME}_desktop_$(date +%s)"
    export TEST_ID
    
    echo "🔍 Test ID: $TEST_ID"
    echo ""
    
    # Call the original test implementation from semantic-replay-commands
    echo "🖥️  Running desktop test execution..."
    echo "===================================="
    
    TEST_RESULT=0
    just _test-desktop-target-original "$CONFIG_NAME" "{{duration}}" || TEST_RESULT=$?
    
    echo ""
    echo "📊 Test Execution: $(if [[ $TEST_RESULT -eq 0 ]]; then echo "✅ PASSED"; else echo "❌ FAILED"; fi)"
    
    # Always run error analysis (even if test failed)
    if [[ $TEST_RESULT -eq 0 ]]; then
        just _post-test-validation "$TEST_ID" "desktop"
    else
        echo ""
        echo "❌ OVERALL RESULT: FAILED"  
        echo "💡 Test execution failed - skipping error analysis"
        exit 1
    fi

# ================================
# ORIGINAL COMMAND PRESERVATION
# ================================

# Preserved original Android test command (renamed to avoid recursion)
_test-android-target-original config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Testing target: $CONFIG_NAME"
    echo "==============================="
    
    # Clear Android test cache first to prevent stale state contamination
    echo "🧹 Clearing Android test cache to ensure fresh state..."
    just clear-android-test-cache
    echo ""
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        echo "Please connect a device and enable USB debugging"
        exit 1
    fi
    
    # Check if configuration has checksum validation
    HAS_CHECKSUM=false
    if [[ -f "$CONFIG_PATH" ]] && jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        HAS_CHECKSUM=true
        
        # Get checksum configuration
        STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
        EXPECTED_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_PATH")
        
        echo "📸 Checksum Test Detected"
        echo "State Type: $STATE_TYPE"
        echo "Expected Checksum: $EXPECTED_CHECKSUM"
        
        # Check if baseline is set
        if [[ -z "$EXPECTED_CHECKSUM" ]]; then
            echo ""
            echo "ℹ️  No baseline checksum set - this will be the first run"
            echo "   A baseline will be automatically created and saved"
            echo "   The test will automatically restart to validate the baseline"
        else
            echo ""
            echo "✅ Baseline checksum found - will validate against it"
        fi
    fi
    
    # Generate unique test ID
    TEST_ID="${CONFIG_NAME}_$(date +%s)"
    export TEST_ID
    
    echo ""
    echo "🔍 Test ID: $TEST_ID"
    echo "📱 Device: $(adb devices | grep 'device$' | head -1 | cut -f1)"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
    # Clear logcat buffer
    adb logcat -c
    
    # Get current app state
    APP_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    if [[ -n "$APP_PID" ]]; then
        echo "🔍 App running (PID: $APP_PID)"
    else
        echo "⚠️  App not running - will start"
    fi
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="
    
    # Use config-restart to properly deploy config and start app
    echo "📱 Deploying configuration and starting app..."
    just config-restart-android "$CONFIG_NAME"
    echo ""
    
    # Wait for app initialization
    sleep 3
    
    # Monitor test execution
    echo ""
    echo "🔍 Monitoring test execution..."
    echo "==============================="
    
    # Start log monitoring
    LOGCAT_PID=""
    (
        adb logcat | grep -E "(TEST_|ERROR|CRITICAL|CHECKSUM)" | while read -r line; do
            echo "$line"
            # Check for test completion
            if echo "$line" | grep -q "TEST_COMPLETE.*$TEST_ID"; then
                echo "✅ Test execution completed"
            fi
            # Check for checksum events
            if echo "$line" | grep -q "CHECKSUM"; then
                echo "📸 Checksum event detected"
            fi
        done
    ) &
    LOGCAT_PID=$!
    
    # Wait for test completion
    TIMEOUT=180  # Extended timeout for checksum tests
    ELAPSED=0
    TEST_COMPLETED=false
    CHECKSUM_SAVED=false
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        # Check for test completion
        if adb logcat -d | grep -q "TEST_COMPLETE.*$TEST_ID"; then
            TEST_COMPLETED=true
            break
        fi
        
        # Check for checksum save event (first run scenario)
        if [[ $HAS_CHECKSUM == true ]] && adb logcat -d | grep -q "CHECKSUM_SAVED.*$TEST_ID"; then
            CHECKSUM_SAVED=true
            echo ""
            echo "📸 Checksum baseline saved - test will restart automatically"
        fi
        
        # Check for errors
        if adb logcat -d | grep -q "TEST_ERROR.*$TEST_ID"; then
            echo ""
            echo "❌ Test failed with error"
            break
        fi
        
        # Check app status
        CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
        if [[ -z "$CURRENT_PID" ]]; then
            echo ""
            echo "⚠️  App stopped"
            break
        fi
        
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        
        # Progress indicator
        if [[ $((ELAPSED % 20)) -eq 0 ]]; then
            echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
        fi
    done
    
    # Stop monitoring
    if [[ -n "$LOGCAT_PID" ]]; then
        kill $LOGCAT_PID 2>/dev/null || true
    fi
    
    echo ""
    echo "📊 Test Results"
    echo "==============="
    echo "Test ID: $TEST_ID"
    echo "Configuration: $CONFIG_NAME"
    echo "Duration: ${ELAPSED}s"
    
    # Determine test result
    if [[ $TEST_COMPLETED == true ]]; then
        echo "Status: ✅ COMPLETED"
        
        # Check for checksum validation results
        if [[ $HAS_CHECKSUM == true ]]; then
            echo ""
            echo "📸 Checksum Validation:"
            echo "======================"
            
            if adb logcat -d | grep -q "CHECKSUM_MATCH.*$TEST_ID"; then
                echo "✅ Checksum validation PASSED"
            elif adb logcat -d | grep -q "CHECKSUM_MISMATCH.*$TEST_ID"; then
                echo "❌ Checksum validation FAILED"
                echo ""
                echo "Expected vs Actual checksum mismatch detected"
                echo "This could indicate:"
                echo "  • Legitimate changes requiring baseline update"
                echo "  • Regression in game state consistency"
                echo "  • Non-deterministic behavior in game logic"
                echo ""
                echo "Use 'just test-android-update $CONFIG_NAME' to update baseline if changes are legitimate"
            elif [[ $CHECKSUM_SAVED == true ]]; then
                echo "📸 Baseline checksum created - test restarted automatically"
                echo "✅ Baseline validation completed"
            else
                echo "⚠️  No checksum validation events found"
            fi
        fi
    else
        echo "Status: ❌ FAILED/TIMEOUT"
        exit 1
    fi
    
    echo ""
    echo "✅ Test execution completed"

# Preserved original Desktop test command (renamed to avoid recursion)
_test-desktop-target-original config_name duration="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{config_name}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running desktop test: {{config_name}} (automated mode - quits automatically)"
    echo "   Config: $CONFIG_FILE"
    echo ""
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup
    STARTUP_CONFIG="{{PROJECT_PATH}}/debug_startup_actions.json"
    echo "📋 Copying config for desktop startup: $STARTUP_CONFIG"
    cp "$CONFIG_FILE" "$STARTUP_CONFIG"
    
    # Run desktop Godot with debug actions (automated mode with quit)
    echo "🚀 Starting desktop test in automated mode..."
    GAMETWO_TEST_MODE=automated ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
        && echo "✅ Desktop test completed successfully" \
        || echo "⚠️  Desktop test completed with exit code $?"
    
    echo ""
    
    # Check for checksum validation if config has checksum_config
    if jq -e '.checksum_config' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "🔍 Checksum validation enabled - validating replay..."
        just _validate-checksums-from-logs "$CONFIG_FILE" "$LOGS_DIR/godot.log" \
            && echo "✅ Checksum validation passed!" \
            || echo "❌ Checksum validation failed!"
        echo ""
    fi
    
    echo "🎉 Desktop test execution complete!"
    echo "💡 Check logs with: just logs-desktop-last"