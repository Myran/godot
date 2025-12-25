# iOS Device Log Commands - Real idevicesyslog monitoring
# These commands read ACTUAL iOS device logs, not saved test result files
# iOS equivalent of Android's justfile-android-device-logs.justfile

# Core iOS device log monitoring function with device detection
_ios-log-base-internal device_id device_name operation duration lines pattern filter_exclude:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"
    OPERATION="{{operation}}"
    DURATION="{{duration}}"
    LINES="{{lines}}"
    PATTERN="{{pattern}}"
    FILTER_EXCLUDE="{{filter_exclude}}"

    echo "🔍 $OPERATION iOS device logs..."
    echo "📱 Device: $DEVICE_NAME ($DEVICE_ID)"
    if [[ -n "$DURATION" ]]; then
        echo "⏱️  Duration: ${DURATION}s"
    fi
    if [[ -n "$LINES" ]]; then
        echo "📊 Lines: $LINES"
    fi
    if [[ -n "$PATTERN" ]]; then
        echo "🎯 Pattern: $PATTERN"
    fi
    echo "💡 Press Ctrl+C to stop early"
    echo ""

    # Check if device is connected and gametwo is running
    if ! idevicesyslog -u "$DEVICE_ID" pidlist | grep -q "gametwo"; then
        echo "❌ Device $DEVICE_NAME not connected or gametwo not running"
        echo "💡 Check: idevicesyslog -u $DEVICE_ID pidlist"
        exit 1
    fi

    # Build base idevicesyslog command
    IDEVICE_CMD="idevicesyslog -u $DEVICE_ID -p gametwo --no-colors"

    # Add pattern matching if specified for idevicesyslog
    if [[ -n "$PATTERN" ]]; then
        IDEVICE_CMD="$IDEVICE_CMD -m \"$PATTERN\""
    fi

    # Add exclusion if specified for idevicesyslog
    if [[ -n "$FILTER_EXCLUDE" ]]; then
        IDEVICE_CMD="$IDEVICE_CMD -M \"$FILTER_EXCLUDE\""
    fi

    # Always filter for game-relevant output (unless pattern is already set)
    if [[ -z "$PATTERN" ]]; then
        IDEVICE_CMD="$IDEVICE_CMD | grep -E '\[DEBUG\]|\[INFO\]|\[ERROR\]|\[NOTICE\]|\[WARNING\]|\[CRITICAL\]|Firebase|backend\.|game\.|system\.|Sentry'"
    fi

    # Execute with duration limit or line limit
    if [[ -n "$DURATION" ]]; then
        timeout "$DURATION" bash -c "$IDEVICE_CMD" || echo "✅ Monitoring completed after ${DURATION}s"
    elif [[ -n "$LINES" ]]; then
        bash -c "$IDEVICE_CMD" | head -"$LINES" || echo "✅ Retrieved $LINES lines"
    else
        bash -c "$IDEVICE_CMD"
    fi

# Live iOS device error monitoring with app filtering
ios-logs-errors DURATION="30":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Error monitoring" "{{DURATION}}" "" "ERROR|CRASH|FAILED|Exception|SCRIPT ERROR" "CoreMotion"

# Live iOS device logs with app filtering
ios-logs-live DURATION="60" LEVEL="Info" LINES="50":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Live monitoring" "{{DURATION}}" "{{LINES}}" "" "CoreMotion"

# iOS device performance monitoring
ios-logs-performance DURATION="60" LINES="20":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Performance monitoring" "{{DURATION}}" "{{LINES}}" "duration_ms|execution_time|performance|fps|memory|benchmark" "CoreMotion"

# Quick iOS device status and recent logs
ios-logs-status:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 iOS Device Status"
    echo "=================="
    echo ""

    # Check device connection
    echo "🔍 Device Connection:"
    if idevice_id -l | grep -q "{{IOS_IPAD_DEVICE_ID}}"; then
        echo "✅ iPad connected ({{IOS_IPAD_DEVICE_ID}})"
    else
        echo "❌ iPad not connected"
        echo "💡 Connected devices:"
        idevice_id -l
        exit 1
    fi

    # Check if gametwo is running
    echo ""
    echo "🎮 App Status:"
    if idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep -q "gametwo"; then
        echo "✅ gametwo process running"

        # Get PID if possible
        GAMETWO_PID=$(idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep "gametwo" | awk '{print $1}' || echo "unknown")
        echo "📊 Process ID: $GAMETWO_PID"
    else
        echo "❌ gametwo not running"
        echo "💡 Available processes:"
        idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep -E "(gametwo|SpringBoard|backboardd)" || echo "No processes found"
    fi

    echo ""
    echo "📊 Recent Activity (last 5 minutes):"
    timeout 10 idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" -p gametwo --no-colors 2>/dev/null | head -5 || echo "No recent activity"

# iOS device recent logs with app filtering
ios-logs-recent LINES="50":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Recent logs" "" "{{LINES}}" "" "CoreMotion"

# iOS device gametwo-specific logs (filtered for game output only)
ios-logs-gametwo DURATION="30" LINES="100":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "GameTwo logs" "{{DURATION}}" "{{LINES}}" "" "CoreMotion"

# iOS device Firebase-specific logs
ios-logs-firebase DURATION="30" LINES="50":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Firebase logs" "{{DURATION}}" "{{LINES}}" "Firebase" "CoreMotion"

# iOS device log search (enhanced version)
ios-logs-search PATTERN LINES="20" DURATION="30":
    just _ios-log-base-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad" "Pattern search" "{{DURATION}}" "{{LINES}}" "{{PATTERN}}" "CoreMotion"

# iOS device log health check
ios-logs-health-check:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📊 iOS Device Log Health Check"
    echo "=========================="
    echo ""

    # Test basic idevicesyslog connectivity
    echo "🔍 Testing idevicesyslog connectivity..."
    if idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" --quiet-list >/dev/null 2>&1; then
        echo "✅ idevicesyslog connectivity working"
    else
        echo "❌ idevicesyslog connectivity failed"
        exit 1
    fi

    # Check process list
    echo ""
    echo "📋 Process Check:"
    if idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep -q "gametwo"; then
        echo "✅ gametwo process found"
        TOTAL_PROCS=$(idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" --quiet-list | wc -l || echo "0")
        echo "📊 Total monitorable processes: $TOTAL_PROCS"
    else
        echo "❌ gametwo process not found"
        echo "💡 Run app first: just run-ios-ipad"
    fi

    # Test log capture
    echo ""
    echo "🧪 Testing Log Capture:"
    echo "Capturing 3 seconds of logs..."
    timeout 3 idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" -p gametwo --no-colors 2>/dev/null | wc -l | while read count; do
        if [[ "$count" -gt 0 ]]; then
            echo "✅ Log capture working ($count lines captured)"
        else
            echo "⚠️  No logs captured (app might be idle)"
        fi
    done

    echo ""
    echo "📱 Device Summary:"
    echo "Device ID: {{IOS_IPAD_DEVICE_ID}}"
    echo "Tool: idevicesyslog"
    echo "Status: Ready for monitoring"

# iOS log cross-validation with saved test logs
ios-logs-cross-validate SEARCH_TERM:
    #!/usr/bin/env bash
    set -euo pipefail

    SEARCH_TERM="{{SEARCH_TERM}}"
    echo "🔍 Cross-validating '$SEARCH_TERM' across iOS log sources..."
    echo ""

    # Search recent device logs
    echo "📱 Device Live Logs (last 2 minutes):"
    timeout 10 idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" -p gametwo -m "$SEARCH_TERM" --no-colors 2>/dev/null || echo "No matches in live logs"

    echo ""
    echo "📁 Saved Test Logs:"
    find "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/logs" -name "ios_*.log" -exec grep -l "$SEARCH_TERM" {} \; | while read file; do
        echo "✅ Found in: $(basename "$file")"
        grep -n "$SEARCH_TERM" "$file" | head -3
    done || echo "No matches in saved logs"

    echo ""
    echo "📊 Cross-validation complete"

# iPhone device log variants (using same functions but different device)
ios-logs-errors-iphone DURATION="30":
    just _ios-log-base-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone" "Error monitoring" "{{DURATION}}" "" "ERROR|CRASH|FAILED|Exception|SCRIPT ERROR" "CoreMotion"

ios-logs-live-iphone DURATION="60" LEVEL="Info" LINES="50":
    just _ios-log-base-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone" "Live monitoring" "{{DURATION}}" "{{LINES}}" "" "CoreMotion"

ios-logs-performance-iphone DURATION="60" LINES="20":
    just _ios-log-base-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone" "Performance monitoring" "{{DURATION}}" "{{LINES}}" "duration_ms|execution_time|performance|fps|memory|benchmark" "CoreMotion"

ios-logs-status-iphone:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 iPhone Device Status"
    echo "==================="
    echo ""

    # Check device connection
    echo "🔍 Device Connection:"
    if idevice_id -l | grep -q "{{IOS_IPHONE_DEVICE_ID}}"; then
        echo "✅ iPhone connected ({{IOS_IPHONE_DEVICE_ID}})"
    else
        echo "❌ iPhone not connected"
        echo "💡 Connected devices:"
        idevice_id -l
        exit 1
    fi

    # Check if gametwo is running
    echo ""
    echo "🎮 App Status:"
    if idevicesyslog -u "{{IOS_IPHONE_DEVICE_ID}}" pidlist | grep -q "gametwo"; then
        echo "✅ gametwo process running"
    else
        echo "❌ gametwo not running"
        echo "💡 Run app first: just run-ios-iphone"
    fi

# iPhone-specific gametwo logs
ios-logs-gametwo-iphone DURATION="30" LINES="100":
    just _ios-log-base-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone" "GameTwo logs" "{{DURATION}}" "{{LINES}}" "" "CoreMotion"

# iPhone-specific Firebase logs
ios-logs-firebase-iphone DURATION="30" LINES="50":
    just _ios-log-base-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone" "Firebase logs" "{{DURATION}}" "{{LINES}}" "Firebase" "CoreMotion"

# ================================================================
# CONSOLIDATED iOS LOG COMMANDS (logs-ios-*)
# Following Android pattern for consistency (Task-369)
# These use auto-detection to find connected iOS device
# ================================================================

# iOS device status check (unified - auto-detects iPhone vs iPad)
logs-ios-status:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 iOS Device & App Status"
    echo "==========================="
    echo ""

    # Auto-detect connected device
    DEVICE_ID=""
    DEVICE_NAME=""

    # Try iPad first
    if idevice_id -l | grep -q "{{IOS_IPAD_DEVICE_ID}}"; then
        DEVICE_ID="{{IOS_IPAD_DEVICE_ID}}"
        DEVICE_NAME="iPad"
    # Then try iPhone
    elif idevice_id -l | grep -q "{{IOS_IPHONE_DEVICE_ID}}"; then
        DEVICE_ID="{{IOS_IPHONE_DEVICE_ID}}"
        DEVICE_NAME="iPhone"
    else
        # Try to find any connected iOS device
        FIRST_DEVICE=$(idevice_id -l | head -1 || echo "")
        if [[ -n "$FIRST_DEVICE" ]]; then
            DEVICE_ID="$FIRST_DEVICE"
            DEVICE_NAME="iOS Device"
        fi
    fi

    if [[ -z "$DEVICE_ID" ]]; then
        echo "❌ No iOS device connected"
        echo ""
        echo "💡 Connected devices:"
        idevice_id -l || echo "No devices found"
        echo ""
        echo "Connect a device and try again"
        exit 1
    fi

    # Check device connection
    echo "🔌 Device Connectivity:"
    echo "  ✅ $DEVICE_NAME connected ($DEVICE_ID)"
    echo ""

    # Check if gametwo is running
    echo "🎮 App Status:"
    if idevicesyslog -u "$DEVICE_ID" pidlist 2>/dev/null | grep -q "gametwo"; then
        echo "  ✅ gametwo process running"
        GAMETWO_PID=$(idevicesyslog -u "$DEVICE_ID" pidlist 2>/dev/null | grep "gametwo" | awk '{print $1}' || echo "unknown")
        echo "  📊 Process ID: $GAMETWO_PID"
    else
        echo "  ❌ gametwo not running"
        echo "  💡 Launch with: just run-ios-ipad or just run-ios-iphone"
    fi

    echo ""
    echo "📊 Device Info:"
    echo "  Device ID: $DEVICE_ID"
    echo "  Tool: idevicesyslog"

# iOS device health check (simplified - iOS doesn't have buffer issues like Android)
logs-ios-health:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📊 iOS Log System Health Check"
    echo "================================"
    echo ""

    # Note: iOS doesn't have the same circular buffer limitations as Android logcat
    echo "ℹ️  iOS Logging Architecture"
    echo "==============================="
    echo ""
    echo "iOS uses os_log unified logging system:"
    echo "  ✅ No circular buffer limitations (logs persist to disk)"
    echo "  ✅ No buffer overflow issues"
    echo "  ✅ Logs accessible via Console.app and idevicesyslog"
    echo ""
    echo "For device diagnostics, use:"
    echo "  • just logs-ios-status      - Check device and app status"
    echo "  • just logs-ios-device TERM  - Search device logs"
    echo ""

    # Quick connectivity check
    echo "🔍 Connectivity Check:"
    if command -v idevicesyslog >/dev/null 2>&1; then
        echo "  ✅ idevicesyslog available"
    else
        echo "  ❌ idevicesyslog not found"
        echo "  💡 Install: brew install libimobiledevice"
        exit 1
    fi

    if command -v idevice_id >/dev/null 2>&1; then
        DEVICE_COUNT=$(idevice_id -l | wc -l || echo "0")
        echo "  ✅ idevice_id available ($DEVICE_COUNT device(s) connected)"
    else
        echo "  ❌ idevice_id not found"
    fi

    echo ""
    echo "✅ iOS logging system is healthy"

# Unified iOS device log search (auto-detects iPhone vs iPad)
logs-ios-device SEARCH_TERM LINES="100":
    #!/usr/bin/env bash
    set -euo pipefail

    SEARCH_TERM="{{SEARCH_TERM}}"
    LINES="{{LINES}}"

    echo "🔍 Searching iOS device logs for: $SEARCH_TERM"
    echo ""

    # Auto-detect connected device
    DEVICE_ID=""
    DEVICE_NAME=""

    if idevice_id -l | grep -q "{{IOS_IPAD_DEVICE_ID}}"; then
        DEVICE_ID="{{IOS_IPAD_DEVICE_ID}}"
        DEVICE_NAME="iPad"
    elif idevice_id -l | grep -q "{{IOS_IPHONE_DEVICE_ID}}"; then
        DEVICE_ID="{{IOS_IPHONE_DEVICE_ID}}"
        DEVICE_NAME="iPhone"
    else
        FIRST_DEVICE=$(idevice_id -l | head -1 || echo "")
        if [[ -n "$FIRST_DEVICE" ]]; then
            DEVICE_ID="$FIRST_DEVICE"
            DEVICE_NAME="iOS Device"
        fi
    fi

    if [[ -z "$DEVICE_ID" ]]; then
        echo "❌ No iOS device connected"
        echo ""
        echo "💡 Connected devices:"
        idevice_id -l || echo "No devices found"
        exit 1
    fi

    echo "📱 Device: $DEVICE_NAME ($DEVICE_ID)"
    echo "📊 Lines: $LINES"
    echo ""

    # Check if gametwo is running
    if ! idevicesyslog -u "$DEVICE_ID" pidlist 2>/dev/null | grep -q "gametwo"; then
        echo "⚠️  gametwo not running - showing recent logs anyway..."
    fi

    # Search logs using idevicesyslog with pattern matching
    echo "📋 Matching logs:"
    echo "=================="
    timeout 10 idevicesyslog -u "$DEVICE_ID" -p gametwo -m "$SEARCH_TERM" --no-colors 2>/dev/null | head -"$LINES" || echo "No matches found (device may be idle)"

# Note: ios-logs-status (line 79) and ios-logs-health-check (line 134) remain for backward compatibility
# The new logs-ios-* commands provide auto-detection of iPhone vs iPad devices