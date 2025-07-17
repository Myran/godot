# Enhanced Testing with Comprehensive Log Error Detection
# Automatically enhances existing test commands to include error analysis
# Makes validation part of ordinary testing without new commands

# ================================
# UNIFIED METADATA INJECTION FUNCTIONS
# ================================

# Helper function to inject auto_quit metadata into config JSON
_inject-auto-quit-metadata source_config target_config auto_quit_value:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SOURCE_CONFIG="{{source_config}}"
    TARGET_CONFIG="{{target_config}}"
    AUTO_QUIT="{{auto_quit_value}}"
    
    # Read the original config
    if [ ! -f "$SOURCE_CONFIG" ]; then
        echo "❌ Source config not found: $SOURCE_CONFIG"
        exit 1
    fi
    
    # Use jq to inject/update the auto_quit metadata
    jq --arg auto_quit "$AUTO_QUIT" '
        .metadata = (.metadata // {}) | 
        .metadata.auto_quit = ($auto_quit | test("true"))
    ' "$SOURCE_CONFIG" > "$TARGET_CONFIG"
    
    echo "✅ Config updated with auto_quit: $AUTO_QUIT"
    echo "   Source: $SOURCE_CONFIG"
    echo "   Target: $TARGET_CONFIG"


# ================================
# CHECKSUM VALIDATION FUNCTIONS
# ================================

# Extract checksums from Android logcat output
_extract-checksums-from-logcat test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    
    # Get the full logcat output
    LOGCAT_OUTPUT=$(adb logcat -d 2>/dev/null || echo "")
    
    if [[ -z "$LOGCAT_OUTPUT" ]]; then
        echo "No logcat output available" >&2
        return 0
    fi
    
    # Extract checksums from the actual log format
    # Look for StateExtractor checksum generation
    CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "StateExtractor.*checksum.*generated" | \
               sed -n 's/.*"checksum": *"\([^"]*\)".*/\1/p' | \
               grep -v "^$" | sort | uniq || echo "")
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 1: look for final state checksums
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "FINAL_STATE_CAPTURED.*final_checksum" | \
                   sed -n 's/.*"final_checksum": *"\([^"]*\)".*/\1/p' | \
                   grep -v "^$" | sort | uniq || echo "")
    fi
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 2: look for pre-action checksums from SessionManager
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "pre_action_checksum" | \
                   sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                   grep -v "^$" | sort | uniq || echo "")
    fi
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 3: look for any checksum patterns in the logs
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "checksum.*[a-f0-9]{32,}" | \
                   sed -n 's/.*checksum[^a-f0-9]*\([a-f0-9]\{32,\}\).*/\1/p' | \
                   sort | uniq || echo "")
    fi
    
    # Debug: show what we found in the logs
    if [[ -z "$CHECKSUMS" ]]; then
        echo "🔍 Debug: Searching for checksum patterns in logs..." >&2
        CHECKSUM_LINES=$(echo "$LOGCAT_OUTPUT" | grep -i checksum | head -5 || echo "")
        if [[ -n "$CHECKSUM_LINES" ]]; then
            echo "Found checksum-related lines:" >&2
            echo "$CHECKSUM_LINES" | sed 's/^/  /' >&2
        else
            echo "No checksum-related lines found in logcat output" >&2
        fi
    fi
    
    echo "$CHECKSUMS"

# Save checksums to configuration file
_save-checksums-to-config config_path checksums:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_PATH="{{config_path}}"
    CHECKSUMS="{{checksums}}"
    
    # Create backup
    cp "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%s)"
    
    # Convert checksums to JSON array
    CHECKSUMS_JSON=$(echo "$CHECKSUMS" | jq -R -s 'split("\n") | map(select(length > 0))')
    
    # Update the config file
    jq --argjson checksums "$CHECKSUMS_JSON" \
       '.checksum_config.expected_checksums = $checksums' \
       "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"
    
    # Validate the JSON and replace original
    if jq -e . "${CONFIG_PATH}.tmp" >/dev/null 2>&1; then
        mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
        echo "✅ Checksums saved to $CONFIG_PATH"
    else
        echo "❌ Failed to update JSON file"
        rm -f "${CONFIG_PATH}.tmp"
        exit 1
    fi

# Compare extracted checksums with expected ones
_compare-checksums extracted_checksums expected_checksums:
    #!/usr/bin/env bash
    set -euo pipefail
    
    EXTRACTED="{{extracted_checksums}}"
    EXPECTED="{{expected_checksums}}"
    
    # Sort both sets for comparison
    EXTRACTED_SORTED=$(echo "$EXTRACTED" | sort)
    EXPECTED_SORTED=$(echo "$EXPECTED" | sort)
    
    if [[ "$EXTRACTED_SORTED" == "$EXPECTED_SORTED" ]]; then
        echo "MATCH"
    else
        echo "MISMATCH"
        echo "Expected:"
        echo "$EXPECTED_SORTED" | sed 's/^/  /'
        echo "Actual:"
        echo "$EXTRACTED_SORTED" | sed 's/^/  /'
        echo "Differences:"
        diff <(echo "$EXPECTED_SORTED") <(echo "$EXTRACTED_SORTED") | sed 's/^/  /' || true
    fi

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
    
    # Count errors using shared patterns (ensure clean single numbers)
    CRITICAL_ERRORS=$(echo "$LOGS" | grep -c -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" 2>/dev/null || echo "0")
    CRITICAL_ERRORS=$(echo "$CRITICAL_ERRORS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    ALL_ERRORS=$(echo "$LOGS" | grep -c -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error|Invalid|Failed to|Cannot|Unable to" 2>/dev/null || echo "0")
    ALL_ERRORS=$(echo "$ALL_ERRORS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    WARNINGS=$(echo "$LOGS" | grep -c -E "WARNING|WARN|Deprecated|Missing" 2>/dev/null || echo "0")
    WARNINGS=$(echo "$WARNINGS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    # Subtract errors from warnings to avoid double counting (with safe arithmetic)
    if [[ "$WARNINGS" =~ ^[0-9]+$ ]] && [[ "$ALL_ERRORS" =~ ^[0-9]+$ ]]; then
        WARNINGS=$((WARNINGS - ALL_ERRORS))
        if [[ $WARNINGS -lt 0 ]]; then
            WARNINGS=0
        fi
    else
        echo "⚠️  Warning: Error count parsing issue, setting warnings to 0" >&2
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
    export CURRENT_CONFIG_NAME="$CONFIG_NAME"
    
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

# Manual mode test commands that inject auto_quit: false
test-android-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Android Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "==========================================================="
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Create temporary config with auto_quit=false for manual mode
    echo "📱 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_manual"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"
    
    # Deploy config and start app using standard config-push-android
    echo "📱 Deploying configuration and starting app..."
    just config-push-android "$TEMP_CONFIG_NAME"
    rm -f "$TEMP_CONFIG_PATH"
    just restart-android-app
    
    echo "✅ Android test started in manual mode (app will stay open for verification)"

test-desktop-manual config_name duration="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{config_name}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running desktop test: {{config_name}} (manual mode - stays open)"
    echo "   Config: $CONFIG_FILE"
    echo ""
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup (user directory)
    USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/gametwo"
    mkdir -p "$USER_DIR"
    STARTUP_CONFIG="$USER_DIR/debug_startup_actions.json"
    
    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi
    
    echo "📋 Injecting auto_quit=false and copying config for desktop startup: $STARTUP_CONFIG"
    just _inject-auto-quit-metadata "$CONFIG_FILE" "$STARTUP_CONFIG" "false"
    
    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi
    
    # Verify the file has content
    if [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Created config file is empty: $STARTUP_CONFIG"
        exit 1
    fi
    
    echo "✅ Config file created with auto_quit=false ($(wc -c < "$STARTUP_CONFIG") bytes)"
    
    # Run desktop Godot with debug actions (manual mode without quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting desktop test in manual mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
        && echo "✅ Desktop test completed (app stayed open for verification)" \
        || echo "⚠️  Desktop test completed with exit code $?"
    
    echo ""
    echo "🎉 Desktop test execution complete! (App should have stayed open for verification)"

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
        EXPECTED_CHECKSUMS=$(jq -r '.checksum_config.expected_checksums // []' "$CONFIG_PATH")
        EXPECTED_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
        
        echo "📸 Checksum Test Detected"
        echo "State Type: $STATE_TYPE"
        echo "Expected Checksums: $EXPECTED_CHECKSUMS_COUNT checksums"
        
        # Check if baseline is set
        if [[ "$EXPECTED_CHECKSUMS_COUNT" -eq 0 ]]; then
            echo ""
            echo "ℹ️  No baseline checksums set - this will be the first run"
            echo "   A baseline will be automatically created and saved"
            echo "   The test will automatically restart to validate the baseline"
        else
            echo ""
            echo "✅ Baseline checksums found - will validate against them"
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
    
    # Create temporary config with auto_quit=true for automated mode
    echo "📱 Creating temporary config with auto_quit=true for automated mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_automated"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "true"
    
    # Deploy config and start app using standard config-push-android
    echo "📱 Deploying configuration and starting app..."
    just config-push-android "$TEMP_CONFIG_NAME"
    rm -f "$TEMP_CONFIG_PATH"
    just restart-android-app
    echo ""
    
    # Brief pause for app startup, then start monitoring immediately
    sleep 1
    
    # Monitor test execution
    echo ""
    echo "🔍 Monitoring test execution..."
    echo "==============================="
    
    # Skip background monitoring for now - it's causing the hang
    # The main detection loop below will handle completion detection
    echo "🔍 Background monitoring disabled - using polling detection"
    
    # Wait for test completion
    TIMEOUT=60   # Reasonable timeout for automated tests
    ELAPSED=0
    TEST_COMPLETED=false
    CHECKSUM_SAVED=false
    
    echo "🔍 Starting monitoring loop with timeout $TIMEOUT..."
    echo "🔍 Initial values: ELAPSED=$ELAPSED, TIMEOUT=$TIMEOUT, TEST_COMPLETED=$TEST_COMPLETED"
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        echo "🔍 Loop iteration: ELAPSED=$ELAPSED, checking for completion..."
        # Check for test completion (standard pattern) - safe grep
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE.*$TEST_ID" 2>/dev/null || false; then
            TEST_COMPLETED=true
            break
        fi
        
        # Check for test completion (fallback pattern for automated mode) - safe grep  
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE_${CONFIG_NAME}_" 2>/dev/null || false; then
            TEST_COMPLETED=true
            echo "✅ Test completed with automated mode fallback signal"
            break
        fi
        
        # Check for any TEST_COMPLETE signal with automated completion (broader fallback) - safe grep
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE_.*automated_completion.*true" 2>/dev/null || false; then
            TEST_COMPLETED=true
            echo "✅ Test completed with generic automated mode signal"
            break
        fi
        
        # Check for any recent TEST_COMPLETE signal (even more flexible) - safe grep
        RECENT_COMPLETE=$(adb logcat -d 2>/dev/null | grep "TEST_COMPLETE" 2>/dev/null | tail -1 || echo "")
        if [[ -n "$RECENT_COMPLETE" ]] && [[ "$RECENT_COMPLETE" =~ automated_completion.*true ]]; then
            TEST_COMPLETED=true
            echo "✅ Test completed with recent automated signal"
            break
        fi
        
        # Debug: Check what we're actually seeing
        if [[ $((ELAPSED % 4)) -eq 0 ]]; then
            echo "🔍 Debug: Checking for completion... (${ELAPSED}s)"
            RECENT_TEST_LOG=$(adb logcat -d 2>/dev/null | grep "TEST_COMPLETE" 2>/dev/null | tail -1 || echo "")
            if [[ -n "$RECENT_TEST_LOG" ]]; then
                echo "🔍 Last TEST_COMPLETE: $RECENT_TEST_LOG"
                # Test the pattern right here
                if echo "$RECENT_TEST_LOG" | grep -q "automated_completion.*true" 2>/dev/null; then
                    echo "🔍 Pattern MATCHES - should have been detected!"
                else
                    echo "🔍 Pattern does NOT match"
                fi
            else
                echo "🔍 No TEST_COMPLETE logs found yet"
            fi
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
        
        # Check app status - if app has quit, consider test complete
        CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
        if [[ -z "$CURRENT_PID" ]]; then
            echo ""
            echo "✅ App quit - test completed"
            TEST_COMPLETED=true
            break
        fi
        
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        
        # Progress indicator
        if [[ $((ELAPSED % 20)) -eq 0 ]]; then
            echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
        fi
    done
    
    # No background monitoring to cleanup (disabled above)
    echo "✅ Monitoring completed"
    
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
            
            # Extract actual checksums from logcat
            EXTRACTED_CHECKSUMS=""
            if just _extract-checksums-from-logcat "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
            else
                echo "⚠️  Checksum extraction failed:"
                cat /tmp/checksum_extraction.log | sed 's/^/  /'
            fi
            
            if [[ -z "$EXTRACTED_CHECKSUMS" ]]; then
                echo "⚠️  No checksums found in test logs"
                echo "This could indicate:"
                echo "  • Test completed too quickly for checksum capture"
                echo "  • SessionManager not logging checksums properly"
                echo "  • Debug actions not being executed"
                echo ""
                echo "💡 Try running the test manually to debug:"
                echo "   just test-android $CONFIG_NAME"
            else
                echo "📸 Extracted $(echo "$EXTRACTED_CHECKSUMS" | wc -l) checksums from logs"
                
                # Check if this is first run (no baseline)
                if [[ "$EXPECTED_CHECKSUMS_COUNT" -eq 0 ]]; then
                    echo ""
                    echo "📝 Creating baseline checksums..."
                    just _save-checksums-to-config "$CONFIG_PATH" "$EXTRACTED_CHECKSUMS"
                    echo "✅ Baseline checksums created and saved"
                    echo ""
                    echo "Next run will validate against this baseline"
                else
                    # Compare with expected checksums
                    EXPECTED_CHECKSUMS_LIST=$(jq -r '.checksum_config.expected_checksums[]' "$CONFIG_PATH")
                    COMPARISON_RESULT=$(just _compare-checksums "$EXTRACTED_CHECKSUMS" "$EXPECTED_CHECKSUMS_LIST")
                    
                    if [[ "$COMPARISON_RESULT" == "MATCH" ]]; then
                        echo "✅ Checksum validation PASSED"
                        echo "All checksums match expected baseline"
                    else
                        echo "❌ Checksum validation FAILED"
                        echo ""
                        echo "$COMPARISON_RESULT"
                        echo ""
                        echo "This could indicate:"
                        echo "  • Legitimate changes requiring baseline update"
                        echo "  • Regression in game state consistency"
                        echo "  • Non-deterministic behavior in game logic"
                        echo ""
                        echo "Use 'just test-android-target-update $CONFIG_NAME' to update baseline if changes are legitimate"
                        # Set a flag to indicate checksum validation failure
                        export CHECKSUM_VALIDATION_FAILED=1
                    fi
                fi
            fi
        fi
    else
        echo "Status: ❌ FAILED/TIMEOUT"
        exit 1
    fi
    
    echo ""
    echo "✅ Test execution completed"
    
    # Check if checksum validation failed
    if [[ "${CHECKSUM_VALIDATION_FAILED:-0}" == "1" ]]; then
        exit 1
    fi


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
    
    # Copy config to the expected location for desktop startup (user directory)
    USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/gametwo"
    mkdir -p "$USER_DIR"
    STARTUP_CONFIG="$USER_DIR/debug_startup_actions.json"
    
    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi
    
    echo "📋 Injecting auto_quit metadata and copying config for desktop startup: $STARTUP_CONFIG"
    just _inject-auto-quit-metadata "$CONFIG_FILE" "$STARTUP_CONFIG" "true"
    
    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi
    
    # Verify the file has content
    if [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Created config file is empty: $STARTUP_CONFIG"
        exit 1
    fi
    
    echo "✅ Config file created with auto_quit=true ($(wc -c < "$STARTUP_CONFIG") bytes)"
    
    # Run desktop Godot with debug actions (automated mode with quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting desktop test in automated mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
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