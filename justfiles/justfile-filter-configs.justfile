# Shared Filter Configurations for Cross-Platform Logging
# Eliminates hardcoded patterns and enables unified filtering

# Standard filter patterns (shared across platforms)
ERROR_FILTER := "ERROR|CRASH|FAILED|Exception|SCRIPT ERROR"
FIREBASE_FILTER := "Firebase|firebase"
PERFORMANCE_FILTER := "duration_ms|execution_time|performance|fps|memory|benchmark"
GAME_RELEVANT_FILTER := "\\[DEBUG\\]|\\[INFO\\]|\\[ERROR\\]|\\[NOTICE\\]|\\[WARNING\\]|\\[CRITICAL\\]|Firebase|backend\\.|game\\.|system\\.|Sentry"
SENSORS_FILTER := "duration_ms|execution_time|performance|fps|memory|benchmark"

# Platform-specific noise patterns
IOS_NOISE := "CoreMotion|CLSensorFusionService|CMDeviceMotion|backboardd|SpringBoard"
ANDROID_NOISE := "OpenGL|GL_|font|Buffer|VSYNC|Touch|Input|SurfaceFlinger"

# Cross-platform test result filtering (ACCOUNTS FOR VALID PLATFORM DIFFERENCES)
# Matches both Android (com.primaryhive.gametwo) and iOS (gametwo) process identifiers
# Handles different log level formats: Android (I/D/E/W/V) and iOS (<Debug>/<Info>/<Error>)
# EXCLUDES: Sentry logs (duplicates), system logs, noise - only counts actual game actions
# NOTE: This pattern will be combined with TEST_ID at runtime in the filtering commands
CROSS_PLATFORM_TEST_BASE := "(SEMANTIC_ACTION|gametwo|com.primaryhive|godot.*:)"

# Package and process identifiers
IOS_PACKAGE := "gametwo"
ANDROID_PACKAGE := "com.primaryhive.gametwo"

# Log normalization patterns for cross-platform parsing
# iOS privacy masking: <private> should be preserved as it's valid iOS behavior
# Different timestamp precisions and log level formats are handled by shared patterns
IOS_LOG_NORMALIZATION := "s/<private>/<private_data>/g"
ANDROID_LOG_NORMALIZATION := "s/\\x1b\\[[0-9;]*m//g"  # Remove ANSI color codes

# Default filter sets by platform
IOS_DEFAULT_FILTERS := "game_relevant"
ANDROID_DEFAULT_FILTERS := "package_and_debug"

# Common exclusion patterns for clean output
UNIVERSAL_EXCLUDE := "GooglePlayServices|android.hardware| dalvikvm|zygote"

# Log level patterns for severity filtering
CRITICAL_ONLY := "ERROR|CRASH|FATAL"
WARNING_AND_ABOVE := "ERROR|CRASH|WARNING|FATAL"
INFO_AND_ABOVE := "ERROR|CRASH|WARNING|INFO|FATAL"
DEBUG_AND_ABOVE := "ERROR|CRASH|WARNING|INFO|DEBUG|FATAL"

# Function: Get platform-specific filter command
_get-platform-filter platform filter_type:
    #!/bin/bash
    PLATFORM="{{platform}}"
    FILTER_TYPE="{{filter_type}}"

    case "$PLATFORM" in
        "ios")
            case "$FILTER_TYPE" in
                "error") echo "grep -E '$ERROR_FILTER'" ;;
                "firebase") echo "grep -E '$FIREBASE_FILTER'" ;;
                "performance") echo "grep -E '$PERFORMANCE_FILTER'" ;;
                "game_relevant") echo "grep -E '$GAME_RELEVANT_FILTER' | grep -v -E '$IOS_NOISE'" ;;
                "exclude_noise") echo "grep -v -E '$IOS_NOISE'" ;;
                *) echo "cat" ;;
            esac
            ;;
        "android")
            case "$FILTER_TYPE" in
                "error") echo "grep -E '($ANDROID_PACKAGE|$ERROR_FILTER)'" ;;
                "firebase") echo "grep -E '($ANDROID_PACKAGE|$FIREBASE_FILTER)'" ;;
                "performance") echo "grep -E '($ANDROID_PACKAGE|$PERFORMANCE_FILTER)'" ;;
                "package_only") echo "grep '$ANDROID_PACKAGE'" ;;
                "exclude_noise") echo "grep -v -E '$ANDROID_NOISE'" ;;
                *) echo "cat" ;;
            esac
            ;;
        *)
            echo "cat"  # Default: no filtering for unknown platforms
            ;;
    esac

# Function: Build platform-specific command with filters
_build-filtered-command platform base_cmd pattern custom_filter:
    #!/bin/bash
    PLATFORM="{{platform}}"
    BASE_CMD="{{base_cmd}}"
    PATTERN="{{pattern}}"
    CUSTOM_FILTER="{{custom_filter}}"

    # Start with base command
    RESULT_CMD="$BASE_CMD"

    # Add idevicesyslog pattern matching if specified (iOS only)
    if [[ -n "$PATTERN" && "$PLATFORM" == "ios" ]]; then
        RESULT_CMD="$RESULT_CMD -m \"$PATTERN\""
    fi

    # Add platform-specific filtering
    if [[ -z "$PATTERN" ]]; then  # Only add default filters if no specific pattern
        FILTER_CMD=$(_get-platform-filter "$PLATFORM" "game_relevant")
        RESULT_CMD="$RESULT_CMD | $FILTER_CMD"
    fi

    # Add custom exclusion filter if specified
    if [[ -n "$CUSTOM_FILTER" ]]; then
        RESULT_CMD="$RESULT_CMD | grep -v -E '$CUSTOM_FILTER'"
    fi

    echo "$RESULT_CMD"