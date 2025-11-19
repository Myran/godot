# Core Configuration & Shared Utilities
# Shared variables, paths, and utility functions used across all modules
# This module is imported by all other modules and provides foundational infrastructure

# Note: This file contains no functions, only variables and configuration
# Functions use these variables via inheritance from main justfile

# ================================
# CORE PROJECT CONFIGURATION
# ================================
GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
PROJECT_PATH := justfile_directory() + "/project"
GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
GODOT_VERSION := "4.0"
GODOT_BUILD_VERSION := "4.3.rc"

# ================================
# DEVICE CONFIGURATION
# ================================
# iOS Devices - Both ID formats supported
# Hash format for idevicesyslog logging
IOS_IPHONE_DEVICE_ID := env_var_or_default("IOS_IPHONE_DEVICE_ID", "c9a2c197b5e75b8386c22d1edf2ceb48")
IOS_IPAD_DEVICE_ID := env_var_or_default("IOS_IPAD_DEVICE_ID", "7fb6c66bb671ed19676ad6ec794ab8a2d255180c")
# UDID format for xcrun devicectl deployment
IOS_IPHONE_UDID := env_var_or_default("IOS_IPHONE_UDID", "C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48")
IOS_IPAD_UDID := env_var_or_default("IOS_IPAD_UDID", "38A3A7F3-6C49-5C54-B86E-D84C81ABD10C")
# Default test device (uses hash format for logging)
IOS_TEST_DEVICE := env_var_or_default("IOS_TEST_DEVICE", IOS_IPAD_DEVICE_ID)
# Default deployment device (uses UDID format for xcrun devicectl)
IOS_DEPLOY_DEVICE := env_var_or_default("IOS_DEPLOY_DEVICE", IOS_IPAD_UDID)

# Android Devices  
ANDROID_DEVICE_ID := env_var_or_default("ANDROID_DEVICE_ID", "246d2c533a037ece")
ANDROID_DEVICE_IP := env_var_or_default("ANDROID_DEVICE_IP", "192.168.1.100")

# ================================
# PLATFORM IDENTIFIERS
# ================================
ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "com.primaryhive." + GAME_NAME)
IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.primaryhive." + GAME_NAME)

# ================================
# BUILD PATHS & TOOLS
# ================================
ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", env_var("HOME") + "/Library/Android/sdk")
ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
ANDROID_GRADLE_DIR := "project/android/build"
KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")

# ================================
# DEBUG SYSTEM PATHS
# ================================
DEBUG_CONFIG_DIR := "tests/debug_configs"
TEST_LIST_DIR := "tests/test-lists"

# ================================
# TEST CONFIGURATION
# ================================
# Inter-config delay for Firebase resource drainage (task-230)
# INTER_CONFIG_DELAY seconds provides optimal balance: improved reliability with reasonable speed
# Allows Google Play Services to drain Firebase resources between test configs
INTER_CONFIG_DELAY := env_var_or_default("INTER_CONFIG_DELAY", "5")

# ================================
# LOG PATHS
# ================================
# Desktop Godot logs (macOS)
DESKTOP_LOG_DIR := env_var("HOME") + "/Library/Application Support/Godot/app_userdata/" + GAME_NAME + "/logs"

# Additional log path variables (consolidated from semantic-replay-commands)
PROJECT_LOGS_DIR := "./logs"
USER_DATA_DIR := "$HOME/Library/Application Support/Godot/app_userdata/gametwo"
STANDARD_LOGS_DIR := USER_DATA_DIR + "/logs"
SAVED_STATES_DIR := "./project/debug/saved_states"

# Temporary files directory for test and build artifacts
TEMP_DIR := "/tmp"

# ================================
# SHARED UTILITY FUNCTIONS
# ================================

# Unified desktop log retrieval function
# Returns path to latest desktop log file, with fallback logic
_get-desktop-log-file:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Desktop log directory (macOS standard location)
    DESKTOP_LOG_DIR="{{DESKTOP_LOG_DIR}}"
    
    # Function to find latest desktop log in a directory
    find_latest_log() {
        local log_dir="$1"
        if [ -d "$log_dir" ]; then
            # Get the most recent file from both desktop_*.log and godot*.log
            local latest_log=""
            
            # Combine both types and sort by modification time
            if ls "$log_dir"/desktop_*.log "$log_dir"/godot*.log &>/dev/null; then
                latest_log=$(ls -t "$log_dir"/desktop_*.log "$log_dir"/godot*.log 2>/dev/null | head -1)
            elif ls "$log_dir"/desktop_*.log &>/dev/null; then
                latest_log=$(ls -t "$log_dir"/desktop_*.log 2>/dev/null | head -1)
            elif ls "$log_dir"/godot*.log &>/dev/null; then
                latest_log=$(ls -t "$log_dir"/godot*.log 2>/dev/null | head -1)
            fi
            
            echo "$latest_log"
        else
            echo ""
        fi
    }
    
    # Get latest log from primary location only
    LATEST_LOG=$(find_latest_log "$DESKTOP_LOG_DIR")
    
    # If no log found, provide helpful error
    if [ -z "$LATEST_LOG" ]; then
        echo "❌ No desktop log files found in:" >&2
        echo "   $DESKTOP_LOG_DIR" >&2
        echo "" >&2
        echo "💡 Try running a test first to generate logs:" >&2
        echo "   just test-desktop development-workflow" >&2
        exit 1
    fi
    
    # Return the log file path
    echo "$LATEST_LOG"

# Find desktop log file containing specific test ID
# Usage: _find-desktop-log-with-test-id TEST_ID
_find-desktop-log-with-test-id TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Desktop log directory
    DESKTOP_LOG_DIR="{{DESKTOP_LOG_DIR}}"
    
    # Function to search for test ID in log directory
    search_logs_for_test_id() {
        local log_dir="$1"
        if [ -d "$log_dir" ]; then
            # First, check if test ID is in any filename (for Android logs stored on desktop)
            local filename_match=$(find "$log_dir" -name "*${TEST_ID}*.log" -type f | head -1)
            if [ -n "$filename_match" ]; then
                echo "$filename_match"
                return 0
            fi
            
            # Fall back to searching file contents (for desktop logs)
            find "$log_dir" -name "*.log" -type f -exec grep -l "$TEST_ID" {} \; 2>/dev/null | head -1
        fi
    }
    
    # Search primary location only
    LOG_FILE=$(search_logs_for_test_id "$DESKTOP_LOG_DIR")
    
    # If not found, provide helpful error
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID" >&2
        echo "" >&2
        echo "🔍 Searched in:" >&2
        echo "   $DESKTOP_LOG_DIR" >&2
        echo "" >&2
        echo "💡 Available test IDs:" >&2
        # Try to show available test IDs from recent logs
        if [ -d "$DESKTOP_LOG_DIR" ]; then
            find "$DESKTOP_LOG_DIR" -name "*.log" -type f -exec grep -l "Test ID:" {} \; 2>/dev/null | head -3 | while read -r logfile; do
                echo "   $(basename "$logfile"): $(grep "Test ID:" "$logfile" 2>/dev/null | head -1 | sed 's/.*Test ID: //' || echo "No test ID found")"
            done
        fi
        exit 1
    fi
    
    # Return the log file path (replay generation needs the path, not content)
    echo "$LOG_FILE"


_find-desktop-log-with-session-id SESSION_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{SESSION_ID}}"
    
    # Desktop log directory
    DESKTOP_LOG_DIR="{{DESKTOP_LOG_DIR}}"
    
    # Function to search for session ID in log directory
    search_logs_for_session_id() {
        local log_dir="$1"
        if [ -d "$log_dir" ]; then
            # Find all .log files and search for session ID in SESSION_START entries
            find "$log_dir" -name "*.log" -type f -exec grep -l "SESSION_START.*\"session_id\": \"$SESSION_ID\"" {} \; 2>/dev/null | head -1
        fi
    }
    
    # Search primary location only
    LOG_FILE=$(search_logs_for_session_id "$DESKTOP_LOG_DIR")
    
    # If not found, provide helpful error
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing session ID: $SESSION_ID" >&2
        echo "" >&2
        echo "🔍 Searched in:" >&2
        echo "   $DESKTOP_LOG_DIR" >&2
        echo "" >&2
        echo "💡 Available session IDs:" >&2
        if [ -d "$DESKTOP_LOG_DIR" ]; then
            find "$DESKTOP_LOG_DIR" -name "*.log" -type f -exec grep -h "SESSION_START" {} \; 2>/dev/null | grep -o '"session_id": "[^"]*"' | sort -u | head -5 >&2 || echo "   (no sessions found)" >&2
        fi
        exit 1
    fi
    
    echo "$LOG_FILE"


_find-android-log-with-session-id SESSION_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{SESSION_ID}}"
    
    # For Android, we need to check if current logs contain the session
    # Use session-aware log retrieval
    ANDROID_LOGS=$(just _get-android-log-file 2>/dev/null || echo "")
    
    if [ -z "$ANDROID_LOGS" ]; then
        echo "❌ No Android logs available" >&2
        exit 1
    fi
    
    # Check if session exists in current logs
    SESSION_CHECK=$(echo "$ANDROID_LOGS" | grep "SESSION_START.*\"session_id\": \"$SESSION_ID\"" || echo "")
    
    if [ -z "$SESSION_CHECK" ]; then
        echo "❌ Session ID not found in current Android logs: $SESSION_ID" >&2
        echo "" >&2
        echo "💡 Available session IDs in current logs:" >&2
        echo "$ANDROID_LOGS" | grep "SESSION_START" | grep -o '"session_id": "[^"]*"' | sort -u | head -5 >&2 || echo "   (no sessions found)" >&2
        exit 1
    fi
    
    # Return success - session exists in current logs
    echo "android-logs-current"


_validate-session-logs SESSION_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{SESSION_ID}}"
    
    echo "🔍 Validating session logs for: $SESSION_ID"
    
    # Try to find session in desktop logs first
    if DESKTOP_LOG=$(just _find-desktop-log-with-session-id "$SESSION_ID" 2>/dev/null); then
        echo "✅ Found session in desktop logs: $DESKTOP_LOG"
        
        # Count semantic actions in this session
        SEMANTIC_COUNT=$(grep "SEMANTIC_ACTION.*\"session_id\": \"$SESSION_ID\"" "$DESKTOP_LOG" 2>/dev/null | wc -l | tr -d ' ')
        echo "📊 Semantic actions found: $SEMANTIC_COUNT"
        
        # Check for session start
        if grep -q "SESSION_START.*\"session_id\": \"$SESSION_ID\"" "$DESKTOP_LOG" 2>/dev/null; then
            echo "✅ Session has proper SESSION_START marker"
        else
            echo "⚠️  Warning: No SESSION_START marker found for session"
        fi
        
        return 0
    fi
    
    # Try Android logs if desktop not found
    if just _find-android-log-with-session-id "$SESSION_ID" >/dev/null 2>&1; then
        echo "✅ Found session in Android logs"
        
        # Get Android logs for counting
        ANDROID_LOGS=$(just _get-android-log-file 2>/dev/null || echo "")
        SEMANTIC_COUNT=$(echo "$ANDROID_LOGS" | grep "SEMANTIC_ACTION.*\"session_id\": \"$SESSION_ID\"" | wc -l | tr -d ' ')
        echo "📊 Semantic actions found: $SEMANTIC_COUNT"
        
        # Check for session start
        if echo "$ANDROID_LOGS" | grep -q "SESSION_START.*\"session_id\": \"$SESSION_ID\""; then
            echo "✅ Session has proper SESSION_START marker"
        else
            echo "⚠️  Warning: No SESSION_START marker found for session"
        fi
        
        return 0
    fi
    
    echo "❌ Session not found in any log source: $SESSION_ID"
    return 1


_get-logs-for-session SESSION_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{SESSION_ID}}"
    
    # Try desktop logs first
    if DESKTOP_LOG=$(just _find-desktop-log-with-session-id "$SESSION_ID" 2>/dev/null); then
        # Return the content of the specific log file
        cat "$DESKTOP_LOG"
        return 0
    fi
    
    # Try Android logs
    if just _find-android-log-with-session-id "$SESSION_ID" >/dev/null 2>&1; then
        # Return Android logs - session filtering handled by caller
        ANDROID_LOGS=$(just _get-android-log-file 2>/dev/null || echo "")
        echo "$ANDROID_LOGS"
        return 0
    fi
    
    echo "❌ No logs found for session: $SESSION_ID" >&2
    return 1

# ================================
# CREDENTIALS (Environment-based)
# ================================
# Only sensitive data remains as exports for security
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export ANDROID_KEYSTORE := env_var_or_default("ANDROID_KEYSTORE", "")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`

# ================================
# SHARED UTILITY FUNCTIONS
# ================================

# Clean up temporary config file if it was auto-generated
_cleanup-temp-config CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/{{CONFIG}}.json"
    
    # Check if this is a temporary config by looking for our specific description patterns
    if [ -f "$CONFIG_FILE" ] && (grep -q "Temporary config for single action:" "$CONFIG_FILE" 2>/dev/null || grep -q "Temporary.*config for.*pattern:" "$CONFIG_FILE" 2>/dev/null); then
        echo "🧹 Cleaning up temporary config: $CONFIG_FILE"
        rm "$CONFIG_FILE"
        echo "✅ Temporary config cleaned up"
    fi

# Handle JSON action with parameters by creating temporary config
_handle-json-action-params CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Extract action name from JSON (shell removes quotes)
    ACTION_NAME=$(echo '{{CONFIG}}' | grep -o 'action:[[:space:]]*[^,}]*' | sed 's/action:[[:space:]]*//')
    if [ -z "$ACTION_NAME" ]; then
        echo "❌ Could not extract action name from JSON: {{CONFIG}}"
        exit 1
    fi
    
    # Create safe filename based on action name
    SAFE_ACTION_NAME=$(echo "$ACTION_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
    if [[ "{{CONFIG}}" == *"params:"* ]]; then
        CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/temp_${SAFE_ACTION_NAME}_with_params.json"
        CONFIG_DESC="Temporary config for action with parameters: $ACTION_NAME"
        echo "🔧 Creating temporary config for action with params: $ACTION_NAME"
    else
        CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/temp_${SAFE_ACTION_NAME}_json_action.json"
        CONFIG_DESC="Temporary config for JSON action: $ACTION_NAME"
        echo "🔧 Creating temporary config for JSON action: $ACTION_NAME"
    fi
    
    # Create temporary config file with the JSON action structure
    # Convert shell-processed JSON back to proper JSON format
    PROPER_JSON=$(echo '{{CONFIG}}' | sed 's/\([a-zA-Z_][a-zA-Z0-9_]*\):/"\1":/g' | sed 's/: \([^",{}][^",{}]*\)/: "\1"/g')
    
    echo "{" > "$CONFIG_FILE"
    echo "  \"description\": \"$CONFIG_DESC\"," >> "$CONFIG_FILE"
    echo "  \"actions\": [" >> "$CONFIG_FILE"
    echo "    $PROPER_JSON" >> "$CONFIG_FILE"
    echo "  ]" >> "$CONFIG_FILE"
    echo "}" >> "$CONFIG_FILE"
    echo "✅ Temporary config created: $CONFIG_FILE"

# Validate config file exists or create temporary config for single action
_validate-config-exists CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if CONFIG is JSON with action field first (shell removes quotes)
    if [[ "{{CONFIG}}" == *"action:"* ]]; then
        if [[ "{{CONFIG}}" == *"params:"* ]]; then
            echo "🔍 Detected action with parameters JSON format"
        else
            echo "🔍 Detected action JSON format (no params)"
        fi
        just _handle-json-action-params "{{CONFIG}}"
        exit 0
    fi
    
    # Generate safe filename for config (replace unsafe characters)
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/${SAFE_CONFIG_NAME}.json"
    
    # Check if safe config file exists (including temporary ones)
    if [ -f "$CONFIG_FILE" ]; then
        exit 0
    fi
    
    # Also check if original unsafe filename exists (for backward compatibility)
    ORIGINAL_CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/{{CONFIG}}.json"
    if [ -f "$ORIGINAL_CONFIG_FILE" ]; then
        exit 0
    fi

    # NEW: Search recursively in subdirectories (for archive/generated-replays configs)
    RECURSIVE_FOUND=$(find "{{DEBUG_CONFIG_DIR}}" -name "{{CONFIG}}.json" -type f 2>/dev/null | head -1)
    if [ -f "$RECURSIVE_FOUND" ]; then
        exit 0
    fi
    
    # Config file doesn't exist - check if CONFIG is a config pattern or action name
    echo "🔍 Config file not found: $CONFIG_FILE"
    
    # Check if it's a wildcard pattern
    if [[ "{{CONFIG}}" == *'*'* ]]; then
        echo "🔍 Detected wildcard pattern: {{CONFIG}}"
        
        # First, try to match config file names (including subdirectories)
        echo "🔍 Checking for matching config files..."
        CONFIG_PATTERN="{{CONFIG}}"
        MATCHING_CONFIGS=$(find {{DEBUG_CONFIG_DIR}} -name "*.json" -type f 2>/dev/null | sed 's|{{DEBUG_CONFIG_DIR}}/||g' | sed 's|\.json||g' | grep -E "^$(echo "$CONFIG_PATTERN" | sed 's/\*/.*/')\$" | head -20 || true)
        
        if [ -n "$MATCHING_CONFIGS" ]; then
            echo "✅ Found matching config files:"
            echo "$MATCHING_CONFIGS" | sed 's/^/  /'
            echo "🔧 Creating temporary test list for config pattern: {{CONFIG}}"
            
            # Create temporary test list file 
            TEMP_LIST_FILE="{{TEST_LIST_DIR}}/temp_pattern_${SAFE_CONFIG_NAME}.json"
            CONFIG_LIST=$(echo "$MATCHING_CONFIGS" | sed 's/^/    "/' | sed 's/$/",/' | sed '$s/,$//')
            {
                echo '{'
                echo '  "name": "Config Pattern: '"$CONFIG_PATTERN"'",'
                echo '  "description": "Auto-generated test list for config pattern: '"$CONFIG_PATTERN"'",'
                echo '  "configs": ['
                echo "$CONFIG_LIST"
                echo '  ]'
                echo '}'
            } > "$TEMP_LIST_FILE"
            
            # Run the temporary test list 
            echo "✅ Temporary test list created: $TEMP_LIST_FILE"
            echo "🚀 Executing config pattern as test list..."
            
            # Execute via test list system and exit with its result
            exec just _test-list-android "temp_pattern_${SAFE_CONFIG_NAME}"
        fi
        
        echo "🔍 No matching config files, treating as action name pattern..."
        echo "🔧 Creating temporary config for wildcard pattern: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        PATTERN_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for wildcard pattern: '"$PATTERN_NAME"'","actions":["'"$PATTERN_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary wildcard config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Look for the action in existing config files to see if it's a valid action name
    if grep -r "\"{{CONFIG}}\"" {{DEBUG_CONFIG_DIR}}/*.json >/dev/null 2>&1; then
        echo "✅ Found '{{CONFIG}}' as an action name"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        ACTION_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Check if action would match any existing wildcard patterns
    ACTION_NAME="{{CONFIG}}"
    MATCHED_PATTERN=""
    while IFS= read -r pattern; do
        # Convert wildcard pattern to regex and test
        regex_pattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/[^.]*/g; s/\?/[^.]/g')
        if echo "$ACTION_NAME" | grep -qE "^${regex_pattern}$"; then
            MATCHED_PATTERN="$pattern"
            break
        fi
    done < <(grep -rh '"[^"]*\*[^"]*"' {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | sort -u)
    
    if [ -n "$MATCHED_PATTERN" ]; then
        echo "✅ Action '{{CONFIG}}' matches wildcard pattern: $MATCHED_PATTERN"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Neither config file nor action name found
    echo "❌ Neither config file nor action name found for: {{CONFIG}}"
    echo ""
    echo "💡 Available config files:"
    ls -1 {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | sed 's|{{DEBUG_CONFIG_DIR}}/||g' | sed 's|\.json||g' | sed 's/^/  /' || echo "  (no configs found)"
    echo ""
    echo "💡 Example action names (from existing configs):"
    grep -h "\"[A-Z].*Test\"" {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/  \1/' | sort -u | head -10 || echo "  (no action examples found)"
    exit 1

# Shared Android prerequisites check
_check-android-prerequisites:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use shared enhanced device check
    just _android-check-device-detailed >/dev/null

# Android log retrieval function
# Returns content of latest Android log file via adb
_get-android-log-file:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use shared Android log retrieval
    just _android-get-app-log "godot.log"

# Find Android log containing specific test ID
# Usage: _find-android-log-with-test-id TEST_ID
_find-android-log-with-test-id TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    just _check-android-prerequisites
    
    # Android log file path
    ANDROID_LOG_PATH="files/logs/godot.log"
    
    # Check if log file exists and contains test ID
    if adb shell "run-as {{ANDROID_PACKAGE_NAME}} ls $ANDROID_LOG_PATH" >/dev/null 2>&1; then
        if adb shell "run-as {{ANDROID_PACKAGE_NAME}} grep -q '$TEST_ID' $ANDROID_LOG_PATH" 2>/dev/null; then
            # Return the log content (since Android typically has one main log file)
            adb shell "run-as {{ANDROID_PACKAGE_NAME}} cat $ANDROID_LOG_PATH" 2>/dev/null
            exit 0
        fi
    fi
    
    # If test ID not found, provide helpful error
    echo "❌ No Android log found containing test ID: $TEST_ID" >&2
    echo "" >&2
    echo "🔍 Searched in: Android device $ANDROID_LOG_PATH" >&2
    echo "" >&2
    echo "💡 Available recent test IDs from Android:" >&2
    
    # Try to show recent test IDs from Android logs
    if adb shell "run-as {{ANDROID_PACKAGE_NAME}} ls $ANDROID_LOG_PATH" >/dev/null 2>&1; then
        adb shell "run-as {{ANDROID_PACKAGE_NAME}} grep 'test_id.*transition-test' $ANDROID_LOG_PATH | tail -3" 2>/dev/null | while read -r line; do
            echo "   $(echo "$line" | sed 's/.*test_id[\"]*: [\"]*\([^\"]*\).*/\1/' | head -1)"
        done || echo "   (No recent test IDs found in Android logs)"
    else
        echo "   (No Android log file found)"
    fi
    echo "" >&2
    exit 1


# Gruvbox Material colors
_gruvbox-colors:
    # Base colors
    @export BG_H="#1d2021"
    @export BG="#282828"
    @export BG_S="#32302f"
    @export FG="#d4be98"
    
    # Regular colors
    @export RED="#ea6962"
    @export GREEN="#a9b665"
    @export YELLOW="#d8a657"
    @export BLUE="#7daea3"
    @export PURPLE="#d3869b"
    @export AQUA="#89b482"
    @export ORANGE="#e78a4e"
    @export GRAY="#928374"