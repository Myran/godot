#!/usr/bin/env bash
set -euo pipefail

# Smart test script for database testing
CONFIG_NAME="database-testing"
DURATION=30
ANDROID_DEVICE_ID="246d2c533a037ece"
ANDROID_PACKAGE_NAME="com.primaryhive.gametwo"

# Generate unique test ID
TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"

echo "🧪 Smart Test: $CONFIG_NAME"
echo "🆔 Test ID: $TEST_ID"
echo "⏱️  Duration: $DURATION seconds"
echo ""

# Validate config first
CONFIG_FILE="project/debug_configs/$CONFIG_NAME.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check prerequisites
if ! adb -s $ANDROID_DEVICE_ID shell echo "Connected" >/dev/null 2>&1; then
    echo "❌ Device not connected"
    exit 1
fi

if ! adb -s $ANDROID_DEVICE_ID shell pm list packages | grep -q "$ANDROID_PACKAGE_NAME"; then
    echo "❌ App not installed"
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
    "$CONFIG_FILE" > "$enhanced_config"

# Push enhanced config using existing push logic
TEMP_CONFIG="/sdcard/temp_debug_config_$TEST_ID.json"
adb -s $ANDROID_DEVICE_ID push "$enhanced_config" "$TEMP_CONFIG"

# Update the pushed config with test metadata in user:// directory
if adb -s $ANDROID_DEVICE_ID shell "run-as $ANDROID_PACKAGE_NAME echo 'Access OK'" 2>/dev/null | grep -q "Access OK"; then
    adb -s $ANDROID_DEVICE_ID shell "run-as $ANDROID_PACKAGE_NAME cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null || true
fi
adb -s $ANDROID_DEVICE_ID shell "rm $TEMP_CONFIG" 2>/dev/null || true
rm "$enhanced_config"

# Restart app
echo "🚀 Starting test..."
adb -s $ANDROID_DEVICE_ID shell am force-stop $ANDROID_PACKAGE_NAME
sleep 1
adb -s $ANDROID_DEVICE_ID shell am start -a android.intent.action.MAIN -n $ANDROID_PACKAGE_NAME/com.godot.game.GodotApp

# Wait for app to start
sleep 3

# Start smart log monitoring
log_file="$test_dir/test_logs.log"

echo "📊 Monitoring test execution..."
echo "   Looking for test ID: $TEST_ID"

# Start logcat with test ID filtering
adb -s $ANDROID_DEVICE_ID logcat -v time -s 'System.out:*' 'GameTwo:*' 'GodotIO:*' 'godot:*' | \
grep --line-buffered "$TEST_ID\|DEBUG_TEST_\|debug.*startup\|action.*executed\|completed successfully\|Successfully.*value" > "$log_file" &
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
        
        # Count interim results
        success_count=$(($(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null || echo "0") + 0))
        failure_count=$(($(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null || echo "0") + 0))
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
    # Parse final results
    success_count=$(($(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null || echo "0") + 0))
    failure_count=$(($(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null || echo "0") + 0))
    startup_count=$(($(grep -c "debug.*startup.*$TEST_ID\|DEBUG_TEST_START.*$TEST_ID" "$log_file" 2>/dev/null || echo "0") + 0))
    
    # Special handling for RTDB actions - look for completion patterns
    rtdb_completed=$(($(grep -c "completed successfully\|Successfully.*value\|Failed.*value" "$log_file" 2>/dev/null || echo "0") + 0))
    rtdb_actions=$(($(grep -c "Executing.*RTDB" "$log_file" 2>/dev/null || echo "0") + 0))
    
    # If we have RTDB actions, use RTDB completion count as success count
    if [ "$rtdb_actions" -gt 0 ] && [ "$rtdb_completed" -gt 0 ]; then
        echo "🔧 RTDB test detected: $rtdb_actions actions, $rtdb_completed completed"
        success_count=$rtdb_completed
    fi
    
    echo "🆔 Test ID: $TEST_ID"
    echo "📊 Startup events: $startup_count"
    echo "📊 Successful actions: $success_count"
    echo "📊 Failed actions: $failure_count"
    echo "🔧 RTDB completions: $rtdb_completed"
    
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
    
    echo ""
    echo "💾 Test artifacts saved:"
    echo "   📄 Logs: $test_dir/test_logs.log"
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