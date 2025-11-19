# Unified Device Logging Core Interface
# Cross-platform abstraction for iOS and Android device logging

# Import shared filter configurations
import "justfile-filter-configs.justfile"

# Main unified device logging function
_device-log-base-unified platform device_id device_name operation duration lines pattern filter_exclude additional_args:
    #!/usr/bin/env bash
    set -euo pipefail

    PLATFORM="{{platform}}"
    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"
    OPERATION="{{operation}}"
    DURATION="{{duration}}"
    LINES="{{lines}}"
    PATTERN="{{pattern}}"
    FILTER_EXCLUDE="{{filter_exclude}}"
    ADDITIONAL_ARGS="{{additional_args}}"

    echo "🔍 $OPERATION $PLATFORM device logs..."
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

    # Check device health and app status
    if ! _check-device-health "$PLATFORM" "$DEVICE_ID"; then
    exit 1
    fi

    # Build platform-specific command
    BASE_CMD=$(_build-base-command "$PLATFORM" "$DEVICE_ID" "$ADDITIONAL_ARGS")

    # Apply unified filtering
    FINAL_CMD=$(_build-filtered-command "$PLATFORM" "$BASE_CMD" "$PATTERN" "$FILTER_EXCLUDE")

    # Execute with timeout or line limit
    if [[ -n "$DURATION" ]]; then
    timeout "$DURATION" bash -c "$FINAL_CMD" || echo "✅ Monitoring completed after ${DURATION}s"
    elif [[ -n "$LINES" ]]; then
    bash -c "$FINAL_CMD" | head -"$LINES" || echo "✅ Retrieved $LINES lines"
    else
    bash -c "$FINAL_CMD"
    fi

# Platform-specific device health check
_check-device-health platform device_id:
    #!/bin/bash
    PLATFORM="{{platform}}"
    DEVICE_ID="{{device_id}}"

    case "$PLATFORM" in
    "ios")
        # Check device connection
        if ! idevice_id -l | grep -q "$DEVICE_ID"; then
            echo "❌ iOS device not connected: $DEVICE_ID"
            echo "💡 Available devices:"
            idevice_id -l
            return 1
        fi

        # Check if gametwo is running
        if ! idevicesyslog -u "$DEVICE_ID" pidlist | grep -q "gametwo"; then
            echo "⚠️  gametwo not running on device"
            echo "💡 Launch app first: just run-ios-device"
            return 1
        fi

        echo "✅ iOS device health check passed"
        ;;

    "android")
        # Check device connection
        if ! adb devices | grep -q "$DEVICE_ID"; then
            echo "❌ Android device not connected: $DEVICE_ID"
            echo "💡 Available devices:"
            adb devices
            return 1
        fi

        # Check if gametwo is installed and running
        if ! adb -s "$DEVICE_ID" shell pm list packages | grep -q "$ANDROID_PACKAGE"; then
            echo "❌ $ANDROID_PACKAGE not installed on device"
            return 1
        fi

        echo "✅ Android device health check passed"
        ;;

    *)
        echo "❌ Unknown platform: $PLATFORM"
        return 1
        ;;
    esac

# Build platform-specific base command
_build-base-command platform device_id additional_args:
    #!/bin/bash
    PLATFORM="{{platform}}"
    DEVICE_ID="{{device_id}}"
    ADDITIONAL_ARGS="{{additional_args}}"

    case "$PLATFORM" in
    "ios")
        echo "idevicesyslog -u $DEVICE_ID -p gametwo --no-colors"
        ;;
    "android")
        echo "adb -s $DEVICE_ID logcat -d | grep -E '($ANDROID_PACKAGE|godot)'"
        ;;
    *)
        echo "echo '❌ Unsupported platform: $PLATFORM'"
        ;;
    esac

# Get device configuration by platform and type
_get-device-config platform device_type:
    #!/bin/bash
    PLATFORM="{{platform}}"
    DEVICE_TYPE="{{device_type}}"

    case "${PLATFORM}_${DEVICE_TYPE}" in
    "ios_ipad")
        echo "{{IOS_IPAD_DEVICE_ID}} iPad"
        ;;
    "ios_iphone")
        echo "{{IOS_IPHONE_DEVICE_ID}} iPhone"
        ;;
    "android_default")
        echo "{{ANDROID_DEVICE_ID}} Android"
        ;;
    *)
        echo "UNKNOWN_DEVICE UNKNOWN"
        ;;
    esac

# High-level unified logging commands (platform-agnostic)
device-logs-errors platform="ios" device_type="ipad" duration="30":
    DEVICE_CONFIG=$(_get-device-config "{{platform}}" "{{device_type}}")
    DEVICE_ID=$(echo "$DEVICE_CONFIG" | cut -d' ' -f1)
    DEVICE_NAME=$(echo "$DEVICE_CONFIG" | cut -d' ' -f2)

    just _device-log-base-unified "{{platform}}" "$DEVICE_ID" "$DEVICE_NAME" "Error monitoring" "{{duration}}" "" "" "" ""

device-logs-live platform="ios" device_type="ipad" duration="60" lines="50":
    DEVICE_CONFIG=$(_get-device-config "{{platform}}" "{{device_type}}")
    DEVICE_ID=$(echo "$DEVICE_CONFIG" | cut -d' ' -f1)
    DEVICE_NAME=$(echo "$DEVICE_CONFIG" | cut -d' ' -f2)

    just _device-log-base-unified "{{platform}}" "$DEVICE_ID" "$DEVICE_NAME" "Live monitoring" "{{duration}}" "{{lines}}" "" "" ""

device-logs-firebase platform="ios" device_type="ipad" duration="30" lines="50":
    DEVICE_CONFIG=$(_get-device-config "{{platform}}" "{{device_type}}")
    DEVICE_ID=$(echo "$DEVICE_CONFIG" | cut -d' ' -f1)
    DEVICE_NAME=$(echo "$DEVICE_CONFIG" | cut -d' ' -f2)

    just _device-log-base-unified "{{platform}}" "$DEVICE_ID" "$DEVICE_NAME" "Firebase monitoring" "{{duration}}" "{{lines}}" "Firebase" ""

device-logs-search platform="ios" device_type="ipad" pattern="" lines="20" duration="30":
    DEVICE_CONFIG=$(_get-device-config "{{platform}}" "{{device_type}}")
    DEVICE_ID=$(echo "$DEVICE_CONFIG" | cut -d' ' -f1)
    DEVICE_NAME=$(echo "$DEVICE_CONFIG" | cut -d' ' -f2)

    just _device-log-base-unified "{{platform}}" "$DEVICE_ID" "$DEVICE_NAME" "Pattern search" "{{duration}}" "{{lines}}" "{{pattern}}" ""

# Device status and health check
device-logs-status platform="ios" device_type="ipad":
    DEVICE_CONFIG=$(_get-device-config "{{platform}}" "{{device_type}}")
    DEVICE_ID=$(echo "$DEVICE_CONFIG" | cut -d' ' -f1)
    DEVICE_NAME=$(echo "$DEVICE_CONFIG" | cut -d' ' -f2)

    echo "📱 $DEVICE_NAME Device Status"
    echo "==================="
    echo ""

    if _check-device-health "{{platform}}" "$DEVICE_ID"; then
    echo "✅ Device is ready for logging"
    # Get recent activity sample
    echo ""
    echo "📊 Recent Activity (last 5 lines):"
    BASE_CMD=$(_build-base-command "{{platform}}" "$DEVICE_ID" "")
    timeout 5 bash -c "$BASE_CMD | head -5" 2>/dev/null || echo "No recent activity"
    else
    echo "❌ Device health check failed"
    exit 1
    fi