#!/usr/bin/env bash
set -euo pipefail

# Smart test script for GameTwo debug configurations
# Usage: ./config-test-smart.sh CONFIG_NAME DURATION

CONFIG_NAME="${1:-minimal-testing}"
DURATION="${2:-30}"
ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-246d2c533a037ece}"
ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-com.primaryhive.gametwo}"

# Generate unique test ID
TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"

echo "🧪 Smart Test: $CONFIG_NAME"
echo "🆔 Test ID: $TEST_ID"
echo "⏱️  Duration: $DURATION seconds"
echo ""

# Check prerequisites
if ! adb -s "$ANDROID_DEVICE_ID" shell echo "Connected" >/dev/null 2>&1; then
    echo "❌ Device not connected"
    exit 1
fi

if ! adb -s "$ANDROID_DEVICE_ID" shell pm list packages | grep -q "$ANDROID_PACKAGE_NAME"; then
    echo "❌ App not installed"
    exit 1
fi

if [ ! -f "project/debug_configs/$CONFIG_NAME.json" ]; then
    echo "❌ Config file not found: project/debug_configs/$CONFIG_NAME.json"
    exit 1
fi

echo "✅ Prerequisites satisfied"
echo ""

# Create results directory
timestamp=$(date +%Y%m%d_%H%M%S)
test_dir="test_results/smart_${CONFIG_NAME}_$timestamp"
mkdir -p "$test_dir"

# Apply config with test ID
echo "🔄 Applying config with test ID..."

# Create enhanced config with test ID metadata
enhanced_config=$(mktemp)
jq --arg test_id "$TEST_ID" '. + {"test_metadata": {"test_id": $test_id, "config": "'$CONFIG_NAME'", "timestamp": "'$timestamp'"}}' \
    "project/debug_configs/$CONFIG_NAME.json" > "$enhanced_config"

# Push enhanced config to device
TEMP_CONFIG="/sdcard/temp_debug_config_$TEST_ID.json"
adb -s "$ANDROID_DEVICE_ID" push "$enhanced_config" "$TEMP_CONFIG"
adb -s "$ANDROID_DEVICE_ID" shell "run-as $ANDROID_PACKAGE_NAME cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null || true
adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
rm "$enhanced_config"

# Restart app
echo "🚀 Starting test..."
adb -s "$ANDROID_DEVICE_ID" shell am force-stop "$ANDROID_PACKAGE_NAME"
sleep 1
adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME/com.godot.game.GodotApp"

# Wait for app to start
sleep 3

# Start smart log monitoring
log_file="$test_dir/test_logs.log"

echo "📊 Monitoring test execution..."
echo "   Looking for test ID: $TEST_ID"

# Start logcat with test ID filtering - capture more patterns
adb -s "$ANDROID_DEVICE_ID" logcat -v time -s 'System.out:*' 'GameTwo:*' 'GodotIO:*' 'godot:*' | \
grep --line-buffered "$TEST_ID\|DEBUG_TEST_\|debug.*startup\|Test context set\|action.*executed\|Executing.*action" > "$log_file" &
logcat_pid=$!

# Monitor for test completion or timeout
test_complete=false
success_count=0
failure_count=0

for ((i=1; i<=DURATION; i++)); do
    if [ -f "$log_file" ]; then
        # Check for test completion signal
        if grep -q "DEBUG_TEST_COMPLETE.*$TEST_ID" "$log_file" 2>/dev/null; then
            test_complete=true
            break
        fi
        
        # Count interim results (clean output)
        success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
    fi
    
    # Progress indicator
    if [ $((i % 5)) -eq 0 ]; then
        echo "   Progress: $i/${DURATION}s (✅$success_count ❌$failure_count)"
    fi
    
    sleep 1
done

# Stop monitoring
kill $logcat_pid 2>/dev/null || true

# Final analysis
echo ""
echo "📋 Test Results Analysis"
echo "========================"

test_result=1  # Default to failure

if [ -f "$log_file" ]; then
    # Parse final results (clean output)
    success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
    failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
    startup_count=$(grep -c "debug.*startup.*$TEST_ID\|DEBUG_TEST_START.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
    
    echo "🆔 Test ID: $TEST_ID"
    # Ensure variables are integers (strip any whitespace/newlines and validate)
    success_count=$(echo "$success_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
    failure_count=$(echo "$failure_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
    startup_count=$(echo "$startup_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
    
    echo "📊 Startup events: $startup_count"
    echo "📊 Successful actions: $success_count"
    echo "📊 Failed actions: $failure_count"
    
    # Determine overall result
    if [ "$test_complete" = true ]; then
        echo "✅ Test completed normally"
        
        if [ "$failure_count" -eq 0 ] && [ "$success_count" -gt 0 ]; then
            echo "🎉 OVERALL RESULT: PASS"
            test_result=0
        elif [ "$failure_count" -gt 0 ]; then
            echo "❌ OVERALL RESULT: FAIL (failures detected)"
            test_result=1
        else
            echo "⚠️  OVERALL RESULT: INCONCLUSIVE (no actions executed)"
            test_result=1
        fi
    else
        echo "⏰ Test timed out after $DURATION seconds"
        
        if [ "$startup_count" -eq 0 ]; then
            echo "❌ OVERALL RESULT: FAIL (no startup detected)"
            test_result=1
        elif [ "$failure_count" -gt 0 ]; then
            echo "❌ OVERALL RESULT: FAIL (failures + timeout)"
            test_result=1
        else
            echo "⚠️  OVERALL RESULT: PARTIAL (timeout but some success)"
            test_result=1
        fi
    fi
    
    # Save test metadata
    result_status="FAIL"
    if [ $test_result -eq 0 ]; then
        result_status="PASS"
    fi
    
    cat > "$test_dir/test_results.json" << EOF
{
    "test_id": "$TEST_ID",
    "config": "$CONFIG_NAME",
    "duration": $DURATION,
    "timestamp": "$timestamp",
    "test_complete": $test_complete,
    "startup_events": $startup_count,
    "successful_actions": $success_count,
    "failed_actions": $failure_count,
    "overall_result": "$result_status",
    "device_id": "$ANDROID_DEVICE_ID",
    "package": "$ANDROID_PACKAGE_NAME"
}
EOF
    
    echo ""
    echo "💾 Test artifacts saved:"
    echo "   📄 Logs: $log_file"
    echo "   📊 Results: $test_dir/test_results.json"
    echo "   🆔 Test ID: $TEST_ID"
    
else
    echo "❌ No log file generated"
    test_result=1
fi

echo ""
if [ $test_result -eq 0 ]; then
    echo "🎉 Test PASSED"
else
    echo "💥 Test FAILED"
fi

exit $test_result