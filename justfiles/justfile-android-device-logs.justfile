# Android Device Log Commands - Real adb logcat monitoring
# These commands read ACTUAL Android device logs, not saved test result files

# Live Android device error monitoring with app filtering
android-logs-errors DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔥 Monitoring Android device errors for {{DURATION}} seconds..."
    echo "📱 Device: {{ANDROID_DEVICE_ID}}"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    echo "💡 Press Ctrl+C to stop early"
    echo ""
    
    # Clear existing logs for clean monitoring
    adb -s {{ANDROID_DEVICE_ID}} logcat -c
    
    # Monitor errors with timeout and app filtering
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat \
        --pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} || echo "0") \
        -v time "*:E" \
        | grep -E "({{ANDROID_PACKAGE_NAME}}|E/godot|SCRIPT ERROR|ERROR:|FAILED|DEBUG_TEST_FAILURE)" \
        || echo "✅ No errors detected during monitoring period"

# Live Android device logs with app filtering
android-logs-live DURATION="60" LEVEL="*:I" LINES="50":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Live Android device logs for {{DURATION}} seconds..."
    echo "📱 Device: {{ANDROID_DEVICE_ID}}"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    echo "📊 Level: {{LEVEL}}"
    echo "💡 Press Ctrl+C to stop early"
    echo ""
    
    # Monitor live logs with app filtering + token-efficient filtering
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat \
        --pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} || echo "0") \
        -v time "{{LEVEL}}" \
        | grep -E "({{ANDROID_PACKAGE_NAME}}|godot|firebase|debug|error|test)" \
        | grep -v -E "(OpenGL|GL_|font|Buffer|VSYNC|Touch|Input)" \
        | head -{{LINES}} \
        || echo "📱 Monitoring completed"

# Android device logs with Firebase/Battle/System tag filtering 
android-logs-tagged TAGS DURATION="30" LINES="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Monitoring Android logs for tags: {{TAGS}}"
    echo "📱 Device: {{ANDROID_DEVICE_ID}}" 
    echo "⏱️  Duration: {{DURATION}} seconds"
    echo ""
    
    # Convert space-separated tags to grep pattern
    tag_pattern=$(echo "{{TAGS}}" | tr ' ' '|')
    
    # Monitor with tag filtering + token-efficient filtering
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat \
        --pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} || echo "0") \
        -v time "*:I" \
        | grep -iE "($tag_pattern)" \
        | grep -v -E "(OpenGL|GL_|font|Buffer|VSYNC|Touch|Input)" \
        | head -{{LINES}} \
        || echo "✅ No matching tagged logs found"




# Android device performance monitoring
android-logs-performance DURATION="60" LINES="20":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📊 Monitoring performance logs on Android device..."
    echo "📱 Device: {{ANDROID_DEVICE_ID}}"
    echo "⏱️  Duration: {{DURATION}} seconds"
    echo ""
    
    # Monitor performance patterns with focused filtering
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat \
        --pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} || echo "0") \
        -v time "*:I" \
        | grep -iE "(duration_ms|execution_time|performance|fps|memory_mb|lag|slow|benchmark)" \
        | head -{{LINES}} \
        || echo "📊 Performance monitoring completed"

# Quick Android device status and recent logs
android-logs-recent LINES="50":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Recent Android device logs (last {{LINES}} lines)..."
    echo "📱 Device: {{ANDROID_DEVICE_ID}}"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    echo ""
    
    # Check if device is connected
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "connected" >/dev/null 2>&1; then
        echo "❌ Device {{ANDROID_DEVICE_ID}} not connected"
        echo "💡 Run 'adb devices' to check connected devices"
        exit 1
    fi
    
    # Check if app is running
    app_pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
    if [[ -z "$app_pid" ]]; then
        echo "⚠️  App {{ANDROID_PACKAGE_NAME}} not currently running"
        echo "💡 Showing recent system logs for the package..."
        adb -s {{ANDROID_DEVICE_ID}} logcat -t {{LINES}} | grep "{{ANDROID_PACKAGE_NAME}}" || echo "No recent logs found"
    else
        echo "✅ App running with PID: $app_pid"
        echo "📋 Recent logs (filtered for relevance):"
        adb -s {{ANDROID_DEVICE_ID}} logcat --pid=$app_pid -t {{LINES}} \
            | grep -E "(firebase|debug|error|test|startup|completed)" \
            | grep -v -E "(OpenGL|GL_|font|Buffer|VSYNC)" \
            | head -{{LINES}}
    fi

# Clear Android device logs with robust error handling
# Background monitoring that captures logs from app launch until stopped
android-logs-monitor-background TEST_ID LOG_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    LOG_FILE="{{LOG_FILE}}"
    
    echo "🔍 Starting background Android log monitoring for test: $TEST_ID"
    echo "📄 Logs will be saved to: $LOG_FILE"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Clear the log file to start fresh
    > "$LOG_FILE"
    
    # Create control files for start/stop signaling
    MONITOR_CONTROL="/tmp/android_monitor_${TEST_ID}"
    echo "monitoring" > "$MONITOR_CONTROL"
    
    # Background monitoring loop (redirect all output to prevent terminal spill)
    {
        while [[ -f "$MONITOR_CONTROL" && "$(cat "$MONITOR_CONTROL" 2>/dev/null)" == "monitoring" ]]; do
            # Check if app is running
            APP_PID=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "0")
            
            if [[ "$APP_PID" != "0" ]]; then
                echo "📱 App detected with PID: $APP_PID - capturing logs..." >> "$LOG_FILE"
                
                # Capture logs while app is running
                timeout 120 adb -s {{ANDROID_DEVICE_ID}} logcat \
                    --pid="$APP_PID" \
                    -b all \
                    -v time "*:I" \
                    | grep -E "({{ANDROID_PACKAGE_NAME}}|E/godot|SCRIPT ERROR|ERROR:|FAILED|DEBUG_TEST_FAILURE|TEST_COMPLETE|SEMANTIC_ACTION|$TEST_ID)" \
                    | grep -v -E "(OpenGL|GL_|font|Buffer|VSYNC|Touch|Input)" \
                    >> "$LOG_FILE" || echo "📱 App monitoring ended" >> "$LOG_FILE"
            else
                # Wait for app to start
                sleep 0.5
            fi
        done
        
        echo "🔍 Background monitoring stopped for test: $TEST_ID" >> "$LOG_FILE"
    } >/dev/null 2>&1 &
    
    # Store the background process PID for later cleanup
    MONITOR_PID=$!
    echo "$MONITOR_PID" > "${MONITOR_CONTROL}_pid"
    echo "🔍 Background monitoring started with PID: $MONITOR_PID"

# Stop background monitoring
android-logs-monitor-stop TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    MONITOR_CONTROL="/tmp/android_monitor_${TEST_ID}"
    MONITOR_PID_FILE="${MONITOR_CONTROL}_pid"
    
    # Signal monitoring to stop
    if [[ -f "$MONITOR_CONTROL" ]]; then
        echo "stopping" > "$MONITOR_CONTROL"
        echo "🔍 Signaled background monitoring to stop for test: $TEST_ID"
    fi
    
    # Kill the background process if it exists
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        MONITOR_PID=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            kill "$MONITOR_PID" 2>/dev/null || true
            echo "🔍 Stopped background monitoring process: $MONITOR_PID"
        fi
        rm -f "$MONITOR_PID_FILE"
    fi
    
    # Cleanup control file
    rm -f "$MONITOR_CONTROL"

android-logs-clear:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧹 Clearing Android device logs..."
    
    # Check if device is available
    if ! adb -s {{ANDROID_DEVICE_ID}} get-state >/dev/null 2>&1; then
        echo "❌ Android device {{ANDROID_DEVICE_ID}} not available"
        echo "💡 Check device connection: adb devices"
        exit 1
    fi
    
    # Kill any existing adb server connections that might block clearing
    echo "🔄 Restarting ADB server to ensure clean logcat access..."
    adb kill-server 2>/dev/null || true
    adb start-server 2>/dev/null || true
    sleep 1
    
    # Attempt multiple clearing methods with retries
    RETRY_COUNT=0
    MAX_RETRIES=3
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Method 1: Clear all buffers explicitly (main, events, radio)
        echo "🧹 Clearing all log buffers (main, events, radio)..."
        adb -s {{ANDROID_DEVICE_ID}} logcat -b all -c 2>/dev/null || true
        
        # Method 2: Clear individual buffers as fallback
        adb -s {{ANDROID_DEVICE_ID}} logcat -b main -c 2>/dev/null || true
        adb -s {{ANDROID_DEVICE_ID}} logcat -b events -c 2>/dev/null || true
        adb -s {{ANDROID_DEVICE_ID}} logcat -b radio -c 2>/dev/null || true
        
        # Method 3: Alternative shell command approach
        adb -s {{ANDROID_DEVICE_ID}} shell "logcat -b all -c" 2>/dev/null || true
        
        # Brief pause to let clearing take effect
        sleep 1
        
        # Verify clearing worked by checking all buffers
        MAIN_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b main -d 2>/dev/null | wc -l || echo "999")
        EVENTS_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b events -d 2>/dev/null | wc -l || echo "999")
        RADIO_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b radio -d 2>/dev/null | wc -l || echo "999")
        TOTAL_COUNT=$((MAIN_COUNT + EVENTS_COUNT + RADIO_COUNT))
        
        if [ "$TOTAL_COUNT" -le 10 ]; then  # Allow for a few system messages across all buffers
            echo "✅ All logcat buffers cleared successfully"
            echo "   📊 main: $MAIN_COUNT, events: $EVENTS_COUNT, radio: $RADIO_COUNT (total: $TOTAL_COUNT)"
            exit 0
        else
            echo "⚠️  Logcat buffers still contain entries after clearing attempt $((RETRY_COUNT + 1))"
            echo "   📊 main: $MAIN_COUNT, events: $EVENTS_COUNT, radio: $RADIO_COUNT (total: $TOTAL_COUNT)"
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "🔄 Retrying logcat clear in 2 seconds..."
            sleep 2
        fi
    done
    
    # If we still have many logs, warn but don't fail the test
    FINAL_LOG_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -d 2>/dev/null | wc -l || echo "999")
    if [ "$FINAL_LOG_COUNT" -gt 20 ]; then
        echo "⚠️  Warning: Logcat buffer still contains $FINAL_LOG_COUNT lines"
        echo "💡 This may cause old error logs to appear in current test results"
        echo "💡 Consider manually clearing or restarting the Android device"
    else
        echo "✅ Logcat buffer acceptably clear ($FINAL_LOG_COUNT lines)"
    fi
    
    # Don't fail the test - just warn about potential pollution
    exit 0

# Lightweight logcat clearing optimized for PID-based filtering
android-logs-clear-lightweight:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧹 Performing lightweight logcat clear (optimized for PID filtering)..."
    
    # Check if device is available
    if ! adb -s {{ANDROID_DEVICE_ID}} get-state >/dev/null 2>&1; then
        echo "❌ Android device {{ANDROID_DEVICE_ID}} not available"
        echo "💡 Check device connection: adb devices"
        exit 1
    fi
    
    # Simple clear - since we use PID-specific filtering, we don't need aggressive clearing
    adb -s {{ANDROID_DEVICE_ID}} logcat -c 2>/dev/null || true
    
    echo "✅ Logcat cleared (test isolation provided by PID-based filtering)"

# Android device log monitoring with auto-restart detection
android-logs-monitor-restart DURATION="120" LINES="20":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Monitoring Android app restarts and startup logs..."
    echo "📱 Device: {{ANDROID_DEVICE_ID}}"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    echo "⏱️  Duration: {{DURATION}} seconds"
    echo ""
    
    # Monitor for app lifecycle events with focused output
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat \
        -v time "*:I" \
        | grep -E "(ActivityManager.*{{ANDROID_PACKAGE_NAME}}|START.*{{ANDROID_PACKAGE_NAME}}|KILL.*{{ANDROID_PACKAGE_NAME}}|godot.*ready|debug.*start)" \
        | head -{{LINES}} \
        || echo "🔄 Restart monitoring completed"

# Check Android device and app status
android-logs-status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Android Device & App Status"
    echo "============================="
    echo ""
    
    # Device connectivity
    echo "🔌 Device Connectivity:"
    if adb -s {{ANDROID_DEVICE_ID}} shell echo "connected" >/dev/null 2>&1; then
        echo "  ✅ Device {{ANDROID_DEVICE_ID}} connected"
        
        # Device info
        device_model=$(adb -s {{ANDROID_DEVICE_ID}} shell getprop ro.product.model)
        android_version=$(adb -s {{ANDROID_DEVICE_ID}} shell getprop ro.build.version.release)
        echo "  📱 Model: $device_model"
        echo "  🤖 Android: $android_version"
    else
        echo "  ❌ Device {{ANDROID_DEVICE_ID}} not connected"
        echo "  💡 Available devices:"
        adb devices
        exit 1
    fi
    
    echo ""
    echo "📦 App Status:"
    
    # App process info
    app_pid=$(adb -s {{ANDROID_DEVICE_ID}} shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
    if [[ -n "$app_pid" ]]; then
        echo "  ✅ App {{ANDROID_PACKAGE_NAME}} running (PID: $app_pid)"
        
        # Memory usage
        memory_info=$(adb -s {{ANDROID_DEVICE_ID}} shell dumpsys meminfo $app_pid | head -3 | tail -1)
        echo "  💾 $memory_info"
    else
        echo "  ⚠️  App {{ANDROID_PACKAGE_NAME}} not running"
    fi
    
    # Check if app is installed
    if adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "  ✅ App installed"
        app_version=$(adb -s {{ANDROID_DEVICE_ID}} shell dumpsys package {{ANDROID_PACKAGE_NAME}} | grep "versionName" | head -1)
        echo "  📋 $app_version"
    else
        echo "  ❌ App not installed"
    fi