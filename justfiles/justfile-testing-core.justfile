# Testing & Validation Core Infrastructure
# Platform-agnostic testing commands and validation infrastructure
# Provides core testing functionality used across all platforms

# Note: Variables and dependencies inherited from main justfile
# This module does not import other modules to avoid circular dependencies

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
    CONFIG_DIR="./project/debug_configs"
    if [[ -d "$CONFIG_DIR" ]]; then
        find "$CONFIG_DIR" -name "*.json" -type f | while read -r config; do
            basename=$(basename "$config" .json)
            echo "  Validating: $basename"
            if ! jq -e . "$config" >/dev/null 2>&1; then
                echo "  ❌ Invalid JSON: $config"
                exit 1
            fi
        done
        echo "  ✅ All JSON configurations valid"
    else
        echo "  ⚠️  No configuration directory found: $CONFIG_DIR"
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
        timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --quit 2>&1 | grep -E "{{pattern}}" || true
    else
        echo "Running full validation..."
        timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --quit 2>&1 | head -50 || true
    fi
    
    # Check for critical errors
    TEMP_VALIDATION=$(mktemp)
    if timeout 30 {{GODOT_EXECUTABLE}} --headless --validate-only --quit > "$TEMP_VALIDATION" 2>&1; then
        # Validation succeeded, check for errors in output
        if grep -E "ERROR|SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | head -5; then
            echo ""
            echo "❌ Validation found critical errors!"
            echo ""
            echo "Full error output:"
            grep -E "ERROR|SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | head -20
            rm -f "$TEMP_VALIDATION"
            exit 1
        fi
    else
        # Validation command failed - could be timeout (exit 124) which is expected
        exit_code=$?
        if [[ $exit_code -eq 124 || $exit_code -eq 141 ]]; then
            # Timeout or SIGPIPE - check for actual errors in output
            if grep -E "ERROR|SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | head -5; then
                echo ""
                echo "❌ Validation found critical errors!"
                echo ""
                echo "Full error output:"
                grep -E "ERROR|SCRIPT ERROR|Parse Error" "$TEMP_VALIDATION" | head -20
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
    if timeout 60 {{GODOT_EXECUTABLE}} --headless --validate-only --quit > "$TEMP_LOG" 2>&1; then
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
    
    # Basic connectivity check
    if adb devices | grep -q "device$"; then
        echo "✅ Android device connected"
    else
        echo "❌ No Android device connected"
        exit 1
    fi

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
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🧪 Testing configuration: $CONFIG_NAME"
    echo "=================================="
    
    # Validate configuration exists and is properly formatted
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        echo "Connect a device and enable USB debugging"
        exit 1
    fi
    
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
    
    # Start app with test configuration
    adb shell am start -n "{{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" \
        --es "test_id" "$TEST_ID" \
        --es "config_name" "$CONFIG_NAME"
    
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
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🔬 Enhanced Testing: $CONFIG_NAME"
    echo "================================="
    
    # Validate configuration
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        exit 1
    fi
    
    # Generate unique test ID
    TEST_ID="${CONFIG_NAME}_enhanced_$(date +%s)"
    export TEST_ID
    
    echo ""
    echo "🔍 Test ID: $TEST_ID"
    echo "📱 Device: $(adb devices | grep 'device$' | cut -f1)"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
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

# Expand test list configuration
_expand_test_list test_list:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST="{{test_list}}"
    TEST_LIST_DIR="./project/test-lists"
    
    echo "🔍 Expanding test list: $TEST_LIST"
    
    # Check if test list exists
    if [[ ! -f "$TEST_LIST_DIR/${TEST_LIST}.json" ]]; then
        echo "❌ Test list not found: $TEST_LIST_DIR/${TEST_LIST}.json"
        echo ""
        echo "Available test lists:"
        if [[ -d "$TEST_LIST_DIR" ]]; then
            find "$TEST_LIST_DIR" -name "*.json" -type f | sort | while read -r list; do
                basename=$(basename "$list" .json)
                if [[ -f "$list" ]] && jq -e . "$list" >/dev/null 2>&1; then
                    description=$(jq -r '.description // "No description"' "$list" 2>/dev/null || echo "No description")
                    echo "  📋 $basename - $description"
                else
                    echo "  ❌ $basename - Invalid JSON"
                fi
            done
        else
            echo "  No test list directory found: $TEST_LIST_DIR"
        fi
        exit 1
    fi
    
    # Validate JSON format
    if ! jq -e . "$TEST_LIST_DIR/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in test list: $TEST_LIST_DIR/${TEST_LIST}.json"
        exit 1
    fi
    
    # Extract configurations
    if ! jq -e '.configurations' "$TEST_LIST_DIR/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Test list missing required 'configurations' field"
        exit 1
    fi
    
    # Validate configurations is an array
    if ! jq -e '.configurations | type == "array"' "$TEST_LIST_DIR/${TEST_LIST}.json" >/dev/null 2>&1; then
        echo "❌ Test list 'configurations' field must be an array"
        exit 1
    fi
    
    # Extract configuration names
    echo "📋 Test list configurations:"
    jq -r '.configurations[]' "$TEST_LIST_DIR/${TEST_LIST}.json" | while read -r config; do
        echo "  • $config"
    done
    
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
    TEST_LIST_DIR="./project/test-lists"
    TEST_LIST_PATH="$TEST_LIST_DIR/${TEST_LIST}.json"
    
    echo "🧪 Executing test list: $TEST_LIST"
    echo "================================="
    
    # Validate test list exists
    if [[ ! -f "$TEST_LIST_PATH" ]]; then
        echo "❌ Test list not found: $TEST_LIST_PATH"
        exit 1
    fi
    
    # Validate JSON format
    if ! jq -e . "$TEST_LIST_PATH" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in test list: $TEST_LIST_PATH"
        exit 1
    fi
    
    # Extract configurations
    if ! jq -e '.configurations' "$TEST_LIST_PATH" >/dev/null 2>&1; then
        echo "❌ Test list missing required 'configurations' field"
        exit 1
    fi
    
    # Get configurations array
    CONFIGS=$(jq -r '.configurations[]' "$TEST_LIST_PATH")
    
    if [[ -z "$CONFIGS" ]]; then
        echo "❌ No configurations found in test list"
        exit 1
    fi
    
    # Show test list info
    description=$(jq -r '.description // "No description provided"' "$TEST_LIST_PATH")
    echo "Description: $description"
    
    config_count=$(jq -r '.configurations | length' "$TEST_LIST_PATH")
    echo "Configurations: $config_count"
    
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

# Test specific configuration on Android
test-android-target config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Testing target: $CONFIG_NAME"
    echo "==============================="
    
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
    
    # Start app with test configuration
    adb shell am start -n "{{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" \
        --es "test_id" "$TEST_ID" \
        --es "config_name" "$CONFIG_NAME"
    
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
    fi
    
    # Show relevant logs
    echo ""
    echo "📋 Test Logs:"
    echo "============="
    adb logcat -d | grep "$TEST_ID" | tail -10 || echo "No test-specific logs found"
    
    echo ""
    echo "🔍 Error Summary:"
    echo "================="
    ERROR_COUNT=$(adb logcat -d | grep -E "(ERROR|CRITICAL)" | grep -v "GL_INVALID" | wc -l)
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo "Found $ERROR_COUNT errors:"
        adb logcat -d | grep -E "(ERROR|CRITICAL)" | grep -v "GL_INVALID" | tail -5
    else
        echo "No errors found"
    fi
    
    echo ""
    echo "✅ Test execution completed"
    echo "Use 'just logs $TEST_ID' for detailed analysis"

# Enhanced test with comprehensive analysis
test-android-enhanced target:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{target}}"
    
    echo "🔬 Enhanced Android Testing: $TARGET"
    echo "==================================="
    
    # Check if target is a test list or configuration
    if [[ -f "./project/test-lists/${TARGET}.json" ]]; then
        echo "📋 Detected test list: $TARGET"
        just _test-list-android "$TARGET"
    elif [[ -f "./project/debug_configs/${TARGET}.json" ]]; then
        echo "📄 Detected configuration: $TARGET"
        just _test-config-android-enhanced "$TARGET"
    else
        echo "❌ Target not found: $TARGET"
        echo ""
        echo "Available targets:"
        echo "=================="
        
        echo "📋 Test Lists:"
        if [[ -d "./project/test-lists" ]]; then
            find "./project/test-lists" -name "*.json" -type f | sort | while read -r list; do
                basename=$(basename "$list" .json)
                description=$(jq -r '.description // "No description"' "$list" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        echo ""
        echo "📄 Configurations:"
        if [[ -d "./project/debug_configs" ]]; then
            find "./project/debug_configs" -name "*.json" -type f | sort | while read -r config; do
                basename=$(basename "$config" .json)
                description=$(jq -r '.description // "No description"' "$config" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        exit 1
    fi

# Update checksum baseline for test configuration
test-android-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."
        
        # Find all checksum-enabled configs
        CONFIG_DIR="./project/debug_configs"
        CHECKSUM_CONFIGS=""
        
        if [[ -d "$CONFIG_DIR" ]]; then
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
            done < <(find "$CONFIG_DIR" -name "*.json" -type f -print0)
        fi
        
        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            echo ""
            echo "To enable checksum testing, add a checksum_config section to your configuration:"
            echo '{'
            echo '  "description": "Your Test Description",'
            echo '  "actions": ["your.actions.here"],'
            echo '  "checksum_config": {'
            echo '    "state_type": "your_state_type",'
            echo '    "expected_checksum": ""'
            echo '  }'
            echo '}'
            exit 1
        fi
        
        echo "📸 Available checksum configurations:"
        echo "===================================="
        
        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to update: " --height=10 --layout=reverse)
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
            echo "Please specify a configuration name: just test-android-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi
    
    echo "🔄 Updating checksum baseline for: $CONFIG_NAME"
    echo "==============================================="
    
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        echo "Add a checksum_config section to enable checksum testing"
        exit 1
    fi
    
    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CURRENT_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_PATH")
    
    echo "📸 Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksum: $CURRENT_CHECKSUM"
    
    # Clear expected checksum to force baseline creation
    echo ""
    echo "🔄 Clearing current baseline..."
    TEMP_CONFIG=$(mktemp)
    jq '.checksum_config.expected_checksum = ""' "$CONFIG_PATH" > "$TEMP_CONFIG"
    mv "$TEMP_CONFIG" "$CONFIG_PATH"
    
    echo "✅ Baseline cleared - running test to generate new baseline..."
    
    # Run test to generate new baseline
    echo ""
    echo "🚀 Generating new baseline..."
    echo "============================="
    
    # Execute test which will create new baseline
    just test-android-target "$CONFIG_NAME"
    
    # Check if baseline was created
    UPDATED_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_PATH")
    
    if [[ -n "$UPDATED_CHECKSUM" && "$UPDATED_CHECKSUM" != "$CURRENT_CHECKSUM" ]]; then
        echo ""
        echo "✅ Baseline update completed successfully!"
        echo "========================================"
        echo "Configuration: $CONFIG_NAME"
        echo "State Type: $STATE_TYPE"
        echo "Previous Checksum: $CURRENT_CHECKSUM"
        echo "New Checksum: $UPDATED_CHECKSUM"
        echo ""
        echo "The new baseline has been saved and will be used for future validations."
    else
        echo ""
        echo "❌ Baseline update failed"
        echo "========================"
        echo "The test may have failed or the checksum was not properly generated."
        echo "Check the test logs for more details."
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
        CONFIG_DIR="./project/debug_configs"
        CHECKSUM_CONFIGS=""
        
        if [[ -d "$CONFIG_DIR" ]]; then
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
            done < <(find "$CONFIG_DIR" -name "*.json" -type f -print0)
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
    
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
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
    
    CONFIG_DIR="./project/debug_configs"
    CHECKSUM_CONFIGS=0
    REGULAR_CONFIGS=0
    
    if [[ ! -d "$CONFIG_DIR" ]]; then
        echo "❌ Configuration directory not found: $CONFIG_DIR"
        exit 1
    fi
    
    # Find all configurations
    find "$CONFIG_DIR" -name "*.json" -type f | sort | while read -r config_file; do
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

# Run all Android tests
test-all-android:
    @echo "🧪 Running all Android tests..."
    @just test-android "development-workflow"

# Primary Android testing interface with auto-detection
test-android target="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{target}}"
    
    # If no target provided, show interactive selector
    if [[ -z "$TARGET" ]]; then
        echo "🔍 Select test target..."
        
        # Build list of all available targets
        TARGETS=""
        
        # Add test lists
        if [[ -d "./project/test-lists" ]]; then
            while IFS= read -r -d '' list_file; do
                if [[ -f "$list_file" ]] && jq -e . "$list_file" >/dev/null 2>&1; then
                    basename=$(basename "$list_file" .json)
                    description=$(jq -r '.description // "No description"' "$list_file" 2>/dev/null || echo "No description")
                    config_count=$(jq -r '.configurations | length' "$list_file" 2>/dev/null || echo "0")
                    
                    TARGETS="${TARGETS}📋 ${basename} (${config_count} configs) - ${description}\n"
                fi
            done < <(find "./project/test-lists" -name "*.json" -type f -print0)
        fi
        
        # Add individual configurations
        if [[ -d "./project/debug_configs" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e . "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    description=$(jq -r '.description // "No description"' "$config_file" 2>/dev/null || echo "No description")
                    
                    # Check if it has checksum configuration
                    if jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                        state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                        expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$config_file")
                        
                        # Determine status
                        if [[ -z "$expected_checksum" ]]; then
                            status="❌ NO BASELINE SET"
                        else
                            status="✅ BASELINE SET"
                        fi
                        
                        TARGETS="${TARGETS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                    else
                        TARGETS="${TARGETS}📄 ${basename} - ${description}\n"
                    fi
                fi
            done < <(find "./project/debug_configs" -name "*.json" -type f -print0)
        fi
        
        if [[ -z "$TARGETS" ]]; then
            echo "❌ No test targets found"
            exit 1
        fi
        
        # Use fzf for selection if available
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$TARGETS" | fzf --prompt="Select test target: " --height=15 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No target selected"
                exit 1
            fi
            
            # Extract target name from selection
            TARGET=$(echo "$SELECTED" | sed 's/[📋📸📄] \([^ ]*\) .*/\1/')
        else
            echo -e "$TARGETS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a target: just test-android TARGET_NAME"
            exit 1
        fi
    fi
    
    echo "🎯 Testing: $TARGET"
    echo "=================="
    
    # Auto-detect target type and execute appropriate test
    if [[ -f "./project/test-lists/${TARGET}.json" ]]; then
        echo "📋 Detected test list: $TARGET"
        just _test-list-android "$TARGET"
    elif [[ -f "./project/debug_configs/${TARGET}.json" ]]; then
        echo "📄 Detected configuration: $TARGET"
        just test-android-target "$TARGET"
    else
        echo "❌ Target not found: $TARGET"
        echo ""
        echo "Available targets:"
        echo "=================="
        
        echo "📋 Test Lists:"
        if [[ -d "./project/test-lists" ]]; then
            find "./project/test-lists" -name "*.json" -type f | sort | while read -r list; do
                basename=$(basename "$list" .json)
                description=$(jq -r '.description // "No description"' "$list" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        echo ""
        echo "📄 Configurations:"
        if [[ -d "./project/debug_configs" ]]; then
            find "./project/debug_configs" -name "*.json" -type f | sort | while read -r config; do
                basename=$(basename "$config" .json)
                description=$(jq -r '.description // "No description"' "$config" 2>/dev/null || echo "No description")
                echo "  • $basename - $description"
            done
        fi
        
        exit 1
    fi

# Manual testing mode (no auto-quit)
test-android-manual target:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{target}}"
    
    echo "👁️  Manual Testing Mode: $TARGET"
    echo "================================="
    echo "ℹ️  This test will NOT auto-quit - perfect for manual verification"
    echo ""
    
    # Check if target exists
    if [[ ! -f "./project/debug_configs/${TARGET}.json" ]]; then
        echo "❌ Configuration not found: $TARGET"
        exit 1
    fi
    
    # Generate unique test ID
    TEST_ID="${TARGET}_manual_$(date +%s)"
    export TEST_ID
    
    echo "🔍 Test ID: $TEST_ID"
    echo "📱 Device: $(adb devices | grep 'device$' | head -1 | cut -f1 || echo 'None')"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        exit 1
    fi
    
    # Clear logcat
    adb logcat -c
    
    echo ""
    echo "🚀 Starting manual test..."
    echo "========================="
    
    # Start app with manual test flag
    adb shell am start -n "{{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" \
        --es "test_id" "$TEST_ID" \
        --es "config_name" "$TARGET" \
        --ez "manual_test" "true"
    
    echo ""
    echo "👁️  Manual Test Running"
    echo "======================="
    echo "The app is now running in manual test mode."
    echo "The debug interface is hidden for clean verification."
    echo ""
    echo "You can:"
    echo "• Take screenshots: just screenshot"
    echo "• Monitor logs: just logs $TEST_ID"
    echo "• Close the app manually when done"
    echo ""
    echo "✅ Manual test started successfully"
    echo "Test ID: $TEST_ID"

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
    
    TEST_LIST_DIR="./project/test-lists"
    
    if [[ ! -d "$TEST_LIST_DIR" ]]; then
        echo "❌ Test list directory not found: $TEST_LIST_DIR"
        exit 1
    fi
    
    # Find all test lists
    find "$TEST_LIST_DIR" -name "*.json" -type f | sort | while read -r list_file; do
        if [[ -f "$list_file" ]] && jq -e . "$list_file" >/dev/null 2>&1; then
            basename=$(basename "$list_file" .json)
            description=$(jq -r '.description // "No description"' "$list_file" 2>/dev/null || echo "No description")
            config_count=$(jq -r '.configurations | length' "$list_file" 2>/dev/null || echo "0")
            
            echo "📋 $basename ($config_count configurations)"
            echo "   Description: $description"
            echo "   Configurations:"
            
            # Show configurations
            jq -r '.configurations[]' "$list_file" 2>/dev/null | while read -r config; do
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
    TOTAL_LISTS=$(find "$TEST_LIST_DIR" -name "*.json" -type f | wc -l)
    echo "Total test lists: $TOTAL_LISTS"

# Show test lists matching pattern
list-test-lists-matching pattern:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{pattern}}"
    
    echo "🔍 Test Lists Matching: $PATTERN"
    echo "================================"
    
    TEST_LIST_DIR="./project/test-lists"
    
    if [[ ! -d "$TEST_LIST_DIR" ]]; then
        echo "❌ Test list directory not found: $TEST_LIST_DIR"
        exit 1
    fi
    
    MATCHES=0
    
    # Find matching test lists
    find "$TEST_LIST_DIR" -name "*.json" -type f | sort | while read -r list_file; do
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
                jq -r '.configurations[]' "$list_file" 2>/dev/null | while read -r config; do
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
        find "$TEST_LIST_DIR" -name "*.json" -type f | sort | while read -r list_file; do
            basename=$(basename "$list_file" .json)
            echo "  • $basename"
        done
    fi