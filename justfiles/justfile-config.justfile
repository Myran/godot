# ================================
# DEBUG CONFIG MANAGEMENT
# ================================

# Create debug config directory and sample configs
config-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📋 Setting up debug configuration files..."
    
    # Create debug configs directory
    mkdir -p project/debug_configs
    
    # Create sample configuration files
    
    # 1. System testing config
    echo '{"actions": ["Show Registry Stats", "Print Debug Info", "Log System Info"]}' > project/debug_configs/system-testing.json
    
    # 2. Database testing config  
    echo '{"actions": ["RTDB Status", "RTDB Get Simple Value", "RTDB List Children"]}' > project/debug_configs/database-testing.json
    
    # 3. Gameplay testing config
    echo '{"actions": ["Reset Match Level", "Load Match Level 1", "Draw Hand"]}' > project/debug_configs/gameplay-testing.json
    
    # 4. Performance testing config
    echo '{"actions": ["Show Registry Stats", "RTDB Concurrent Operations", "RTDB Large Data Test"]}' > project/debug_configs/performance-testing.json
    
    # 5. Minimal testing config
    echo '{"actions": ["Print Debug Info"]}' > project/debug_configs/minimal-testing.json
    
    # 6. Empty config (no actions)
    echo '{"actions": []}' > project/debug_configs/no-actions.json
    
    echo "✅ Debug configs created:"
    echo "  📁 project/debug_configs/"
    ls -la project/debug_configs/
    echo ""
    echo "💡 Use 'just config-set <name>' to switch configs"
    echo "   Example: just config-set system-testing"


# Set a specific debug configuration (updates embedded config)
config-set CONFIG_NAME: (_validate-config-exists CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE=$(just _get-safe-config-file "{{CONFIG_NAME}}")
    TARGET_FILE="project/debug_startup_actions.json"
    
    echo "📝 Setting debug config to: {{CONFIG_NAME}}"
    echo "📄 Config content:"
    cat "$CONFIG_FILE" | jq .
    
    # Copy config to main debug startup file
    cp "$CONFIG_FILE" "$TARGET_FILE"
    
    echo "✅ Debug config updated!"
    echo "💡 Next steps:"
    echo "   1. For development: just config-restart-android {{CONFIG_NAME}}"
    echo "   2. For full rebuild: just save-android-project && just install-android-app"
    
    # Clean up temporary config if it was auto-generated
    just _cleanup-temp-config "{{CONFIG_NAME}}"


# Remove external debug config from Android device (fall back to embedded config)
# REMOVED: config-clear-android
_removed_config_clear_android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    echo "🗑️  Removing external debug config..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f $REMOTE_CONFIG" 2>/dev/null || true
    echo "✅ External config removed - app will use embedded config"
    echo "💡 Run 'just restart-android-app' to apply changes"

# ================================
# LOGGER CONFIG MANAGEMENT
# ================================

# Quick tag filtering for focused debugging sessions
# REMOVED: config-android-tags
_removed_config_android_tags ACTIVE_TAGS IGNORED_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Updating Android logger tags..."
    echo "   Active tags: {{ACTIVE_TAGS}}"
    echo "   Ignored tags: {{IGNORED_TAGS}}"
    
    # Parse comma-separated tags
    IFS=',' read -ra ACTIVE_ARRAY <<< "{{ACTIVE_TAGS}}"
    IFS=',' read -ra IGNORED_ARRAY <<< "{{IGNORED_TAGS}}"
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Build active tags array string
    ACTIVE_FORMATTED=""
    for tag in "${ACTIVE_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$ACTIVE_FORMATTED" ]; then
                ACTIVE_FORMATTED="$ACTIVE_FORMATTED, "
            fi
            ACTIVE_FORMATTED="$ACTIVE_FORMATTED\"$tag\""
        fi
    done
    
    # Build ignored tags array string
    IGNORED_FORMATTED=""
    for tag in "${IGNORED_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$IGNORED_FORMATTED" ]; then
                IGNORED_FORMATTED="$IGNORED_FORMATTED, "
            fi
            IGNORED_FORMATTED="$IGNORED_FORMATTED\"$tag\""
        fi
    done
    
    # Update active tags in config
    sed -i '' "s/active_tags=Array\[String\](\[.*\])/active_tags=Array[String]([$ACTIVE_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Update ignored tags in config
    sed -i '' "s/ignored_tags=Array\[String\](\[.*\])/ignored_tags=Array[String]([$IGNORED_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Push to device
    echo "📱 Pushing logger config to Android device..."
    adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Logger tags updated!"
    echo "💡 Restart app to apply: just restart-android-app"

# Set Android logger level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
# REMOVED: config-android-level
_removed_config_android_level LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Convert level name to number
    case "{{LEVEL}}" in
        DEBUG|debug)
            LEVEL_NUM=0
            LEVEL_NAME="DEBUG"
            ;;
        INFO|info)
            LEVEL_NUM=1
            LEVEL_NAME="INFO"
            ;;
        WARNING|warning|WARN|warn)
            LEVEL_NUM=2
            LEVEL_NAME="WARNING"
            ;;
        ERROR|error)
            LEVEL_NUM=3
            LEVEL_NAME="ERROR"
            ;;
        CRITICAL|critical)
            LEVEL_NUM=4
            LEVEL_NAME="CRITICAL"
            ;;
        *)
            echo "❌ Invalid log level: {{LEVEL}}"
            echo "💡 Valid levels: DEBUG, INFO, WARNING, ERROR, CRITICAL"
            exit 1
            ;;
    esac
    
    echo "📊 Setting Android logger level to $LEVEL_NAME ($LEVEL_NUM)..."
    
    # Create temporary config file with current settings
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Update log level in config
    sed -i '' "s/log_level=[0-9]/log_level=$LEVEL_NUM/g" "$TEMP_CONFIG"
    
    # Push to device
    echo "📱 Pushing logger config to Android device..."
    adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Logger level set to $LEVEL_NAME!"
    echo "💡 Restart app to apply: just restart-android-app"

# Reset Android logger config to project defaults
# REMOVED: config-android-reset
_removed_config_android_reset:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Resetting Android logger config to project defaults..."
    
    # Remove custom logger config from device
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg" 2>/dev/null || true
    
    echo "✅ Logger config reset!"
    echo "💡 App will use project defaults (DEBUG level) on next start"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log control (advanced_logger) - Filter what gets written during app execution
runtime-filter-tags ACTIVE_TAGS IGNORED_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Updating advanced_logger runtime tag filtering..."
    echo "   Active tags: {{ACTIVE_TAGS}}"
    echo "   Ignored tags: {{IGNORED_TAGS}}"
    
    # Parse comma-separated tags
    IFS=',' read -ra ACTIVE_ARRAY <<< "{{ACTIVE_TAGS}}"
    IFS=',' read -ra IGNORED_ARRAY <<< "{{IGNORED_TAGS}}"
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Build active tags array string
    ACTIVE_FORMATTED=""
    for tag in "${ACTIVE_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$ACTIVE_FORMATTED" ]; then
                ACTIVE_FORMATTED="$ACTIVE_FORMATTED, "
            fi
            ACTIVE_FORMATTED="$ACTIVE_FORMATTED\"$tag\""
        fi
    done
    
    # Build ignored tags array string
    IGNORED_FORMATTED=""
    for tag in "${IGNORED_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$IGNORED_FORMATTED" ]; then
                IGNORED_FORMATTED="$IGNORED_FORMATTED, "
            fi
            IGNORED_FORMATTED="$IGNORED_FORMATTED\"$tag\""
        fi
    done
    
    # Update active tags in config
    sed -i '' "s/active_tags=Array\[String\](\[.*\])/active_tags=Array[String]([$ACTIVE_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Update ignored tags in config
    sed -i '' "s/ignored_tags=Array\[String\](\[.*\])/ignored_tags=Array[String]([$IGNORED_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime tag filtering updated!"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log level control (advanced_logger) - Set log level during app execution
runtime-filter-level LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Convert level name to number
    case "{{LEVEL}}" in
        DEBUG|debug)
            LEVEL_NUM=0
            LEVEL_NAME="DEBUG"
            ;;
        INFO|info)
            LEVEL_NUM=1
            LEVEL_NAME="INFO"
            ;;
        WARNING|warning|WARN|warn)
            LEVEL_NUM=2
            LEVEL_NAME="WARNING"
            ;;
        ERROR|error)
            LEVEL_NUM=3
            LEVEL_NAME="ERROR"
            ;;
        CRITICAL|critical)
            LEVEL_NUM=4
            LEVEL_NAME="CRITICAL"
            ;;
        *)
            echo "❌ Invalid log level: {{LEVEL}}"
            echo "💡 Valid levels: DEBUG, INFO, WARNING, ERROR, CRITICAL"
            exit 1
            ;;
    esac
    
    echo "📊 Setting advanced_logger runtime level to $LEVEL_NAME ($LEVEL_NUM)..."
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Update log level in config
    sed -i '' "s/log_level=[0-9]/log_level=$LEVEL_NUM/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime level set to $LEVEL_NAME!"
    echo "💡 Restart app to apply: just restart-android-app"

# Quick tag filtering for focused debugging sessions
config-android-tags ACTIVE_TAGS IGNORED_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Updating Android logger tags..."
    echo "   Active tags: {{ACTIVE_TAGS}}"
    echo "   Ignored tags: {{IGNORED_TAGS}}"
    
    # Parse comma-separated tags
    IFS=',' read -ra ACTIVE_ARRAY <<< "{{ACTIVE_TAGS}}"
    IFS=',' read -ra IGNORED_ARRAY <<< "{{IGNORED_TAGS}}"
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Build active tags array string
    ACTIVE_FORMATTED=""
    for tag in "${ACTIVE_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$ACTIVE_FORMATTED" ]; then
                ACTIVE_FORMATTED="$ACTIVE_FORMATTED, "
            fi
            ACTIVE_FORMATTED="$ACTIVE_FORMATTED\"$tag\""
        fi
    done
    
    # Build ignored tags array string
    IGNORED_FORMATTED=""
    for tag in "${IGNORED_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$IGNORED_FORMATTED" ]; then
                IGNORED_FORMATTED="$IGNORED_FORMATTED, "
            fi
            IGNORED_FORMATTED="$IGNORED_FORMATTED\"$tag\""
        fi
    done
    
    # Update active tags in config
    sed -i '' "s/active_tags=Array\[String\](\[.*\])/active_tags=Array[String]([$ACTIVE_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Update ignored tags in config
    sed -i '' "s/ignored_tags=Array\[String\](\[.*\])/ignored_tags=Array[String]([$IGNORED_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime tag filtering updated!"
    echo "💡 Restart app to apply: just restart-android-app"

# Set Android logger level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
config-android-level LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LEVEL_NAME="{{LEVEL}}"
    echo "📊 Setting Android logger level to: $LEVEL_NAME"
    
    # Validate level
    case "$LEVEL_NAME" in
        DEBUG|INFO|WARNING|ERROR|CRITICAL)
            echo "✅ Valid log level: $LEVEL_NAME"
            ;;
        *)
            echo "❌ Invalid log level: $LEVEL_NAME"
            echo "Valid levels: DEBUG, INFO, WARNING, ERROR, CRITICAL"
            exit 1
            ;;
    esac
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Update log level in config
    sed -i '' "s/log_level=[0-9]*/log_level=$LEVEL_CODE/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime level set to $LEVEL_NAME!"
    echo "💡 Restart app to apply: just restart-android-app"

# Reset Android logger config to project defaults
config-android-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Resetting advanced_logger runtime filtering to project defaults..."
    
    # Auto-detect platform and remove custom config
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Removing custom advanced_logger config from Android device..."
        adb -s {{ANDROID_DEVICE_ID}} shell "rm -f /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg" 2>/dev/null || true
    else
        echo "📱 Android device not found, local config reset"
    fi
    
    echo "✅ Advanced_logger runtime filtering reset!"
    echo "💡 App will use project defaults (DEBUG level, all tags) on next start"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log reset (advanced_logger) - Reset to project defaults
