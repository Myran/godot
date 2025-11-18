# iOS Platform Development Commands
# Complete iOS build, deploy, test, and device management workflow
# Handles iOS-specific development tasks and workflows

# Note: Variables and build functions inherited from imported modules

# iOS help information
help-ios:
    #!/usr/bin/env bash
    echo "🍎 iOS Development Commands"
    echo "=========================="
    echo ""
    echo "Build Commands:"
    echo "  just templates-ios               # Build iOS templates and executables"
    echo "  just build-ios-app              # Build iOS .app with Xcode"
    echo "  just export-pck-build-iphone     # Export PCK to iPhone .app"
    echo "  just export-pck-build-ipad       # Export PCK to iPad .app"
    echo "  just ios-deploy-config CONFIG   # Deploy test config to app bundle"
    echo "  just ios-test-file-access       # Test iOS file reading mechanism"
    echo "  just export-pck-ios              # Export iOS PCK file"
    echo "  just build-ios-all               # Full iOS build pipeline (templates + app + PCK)"
    echo "  just rebuild-all-ios            # Force rebuild all iOS components"
    echo ""
    echo "Testing Commands:"
    echo "  just test-ios CONFIG            # iOS testing with fzf selection (NEW!)"
    echo "  just test-ios-target CONFIG     # iOS automated testing (NEW!)"
    echo "  just test-ios-iphone CONFIG     # iOS testing on iPhone device (NEW!)"
    echo "  just test-ios-ipad CONFIG       # iOS testing on iPad device (NEW!)"
    echo "    • Default: iPad (configurable via IOS_TEST_DEVICE)"
    echo ""
    echo "Log Cleanup:"
    echo "  just clean-godot-logs            # Clean all Godot test logs (iOS, Android, Desktop)"
    echo "  just clean-godot-logs-by-age [days] # Clean Godot logs older than N days (default: 7)"
    echo "  just clean-all-logs [days]       # Clean all logs (Godot + main directory) older than N days (default: 7)"
    echo ""
    echo "Export & Deploy:"
    echo "  just export-pck-ios              # Export iOS PCK file"
    echo "  just ios-update-pck              # Update iOS PCK file"
    echo ""
    echo "Device Logging:"
    echo "  just ios-device-logs-iphone      # Monitor live logs from iPhone"
    echo "  just ios-device-logs-ipad        # Monitor live logs from iPad"
    echo "  just ios-recent-logs-iphone      # Recent logs from iPhone (10 min)"
    echo "  just ios-recent-logs-ipad        # Recent logs from iPad (10 min)"
    echo "  just ios-search-logs-iphone \"pattern\"  # Search logs on iPhone"
    echo "  just ios-search-logs-ipad \"pattern\"    # Search logs on iPad"
    echo "  just ios-sentry-logs-iphone      # Sentry-specific logs from iPhone"
    echo "  just ios-sentry-logs-ipad        # Sentry-specific logs from iPad"
    echo "  just ios-config-logs-iphone      # JSON config logs from iPhone"
    echo "  just ios-config-logs-ipad        # JSON config logs from iPad"
    echo ""
    echo "Quick Commands:"
    echo "  just quick-build-ios             # Quick iOS build"

# Export iOS PCK file
export-pck-ios: pre-build
    @echo "📦 Exporting iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-pack "ios" ../export/ios/{{GAME_NAME}}.pck --headless

# Build iOS app with Xcode (creates .app file)
build-ios-app: pre-build
    @echo "🔨 Building iOS app with Xcode..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace \
                                -scheme {{GAME_NAME}} \
                                -configuration Debug \
                                -destination "generic/platform=iOS" \
                                -allowProvisioningUpdates

# Export PCK file directly to iPhone app bundle
export-pck-build-iphone: pre-build
    @echo "💾 Exporting iOS PCK file to iPhone app bundle..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Export PCK file directly to iPad app bundle
export-pck-build-ipad: pre-build
    @echo "💾 Exporting iOS PCK file to iPad app bundle..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Deploy test config to iOS app bundle (overwrites file in app bundle)
ios-deploy-config config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Deploying test config to iOS app bundle..."
    CONFIG_FILE="tests/debug_configs/{{config_name}}.json"
    APP_BUNDLE_PATH="export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    TARGET_PATH="${APP_BUNDLE_PATH}/debug_startup_actions.json"

    # Validate config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls tests/debug_configs/*.json | xargs -n 1 basename | sed 's/.json$//'
        exit 1
    fi

    # Validate app bundle exists
    if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
        echo "❌ iOS app bundle not found: $APP_BUNDLE_PATH"
        echo "💡 Run 'just build-ios-app' first"
        exit 1
    fi

    echo "📄 Config: $CONFIG_FILE"
    echo "🎯 Target: $TARGET_PATH"

    # Deploy config to app bundle
    cp "$CONFIG_FILE" "$TARGET_PATH"

    echo "✅ Test config deployed to iOS app bundle"
    echo "💡 Next: 'just run-ios-iphone' or 'just run-ios-ipad'"

# Test iOS file access by building with placeholder config
ios-test-file-access:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧪 Testing iOS file access mechanism..."

    # Ensure placeholder config exists
    if [[ ! -f "export/ios/debug_startup_actions.json" ]]; then
        echo "❌ Placeholder config not found in export/ios/"
        exit 1
    fi

    echo "✅ Placeholder config found in export/ios/"
    echo "📄 Content preview:"
    cat export/ios/debug_startup_actions.json | jq '.description, .test_metadata.test_id'

    # Build iOS app
    echo "🔨 Building iOS app..."
    just build-ios-app

    # Copy placeholder config to app bundle (like we do for PCK files)
    echo "📝 Deploying placeholder config to app bundle..."
    APP_BUNDLE_PATH="export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    BUNDLE_CONFIG_PATH="${APP_BUNDLE_PATH}/debug_startup_actions.json"

    cp export/ios/debug_startup_actions.json "$BUNDLE_CONFIG_PATH"

    # Verify placeholder config is in app bundle
    if [[ -f "$BUNDLE_CONFIG_PATH" ]]; then
        echo "✅ Placeholder config deployed to app bundle at: $BUNDLE_CONFIG_PATH"
        echo "📄 Bundle content preview:"
        cat "$BUNDLE_CONFIG_PATH" | jq '.description, .test_metadata.test_id'
    else
        echo "❌ Placeholder config deployment failed"
        exit 1
    fi

    echo "✅ iOS file access test complete - placeholder ready for overwriting"
    echo "💡 Use 'just ios-deploy-config CONFIG' to overwrite with test configs"

# iOS build pipeline
# Duplicate removed - use export-pck-ios instead


# Update iOS PCK file
ios-update-pck: pre-build
    @echo "🔄 Updating iOS PCK file..."
    just export-pck-ios
    @echo "✅ iOS PCK updated"

# REMOVED: build-install-ios - duplicate of build-ios-all (incomplete, no .app build)
# REMOVED: build-all-ios - duplicate of build-ios-all (same functionality)
# Use: just build-ios-all for complete iOS build pipeline (templates + app + PCK)


# Force rebuild all iOS components (ignores existing builds)
rebuild-all-ios:
    @echo "🔥 Force rebuilding all iOS components..."
    just build-ios-all force=yes
    @echo "✅ All iOS rebuilds complete"

# Complete iOS pipeline - from source to device deployment
build-ios-all force="no":
    @echo "🤖 FULL BUILD - iOS ONLY"
    @echo "======================"
    @if [ "{{force}}" = "yes" ]; then \
        echo "⏱️  Estimated time: 30-40 minutes (FORCE REBUILD)"; \
        echo "🔥 Force rebuild enabled - will rebuild everything from scratch"; \
    else \
        echo "⏱️  Estimated time: 5-15 minutes (smart rebuild)"; \
        echo "💡 Use 'just build-ios-all force=yes' to force rebuild everything"; \
    fi
    @echo ""

    just templates-ios {{force}}
    just build-ios-app
    just export-pck-ios
    @echo "✅ iOS full build complete - ready for device deployment"
    @echo "💡 Use 'just run-ios-iphone' to deploy to iPhone"
    @echo "💡 Use 'just run-ios-ipad' to deploy to iPad"


# ================================
# iOS DEVICE LOGGING
# ================================

# Core device logging function - takes device ID as argument
_ios-device-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Streaming live logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Monitoring process: gametwo"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use log stream --debug for device console access
    log stream --debug --predicate 'processImagePath contains "gametwo"' --style compact

# Stream live logs from iPhone device
ios-device-logs-iphone:
    just _ios-device-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Stream live logs from iPad device
ios-device-logs-ipad:
    just _ios-device-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core recent logs function - takes device ID as argument
_ios-recent-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Searching recent logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "📊 Time range: Last 10 minutes"
    echo "🎯 Monitoring process: gametwo"
    echo ""

    # Use log show for recent device logs
    log show --predicate 'processImagePath contains "gametwo"' --last 10m --style compact

# Search recent logs from iPhone device (last 10 minutes)
ios-recent-logs-iphone:
    just _ios-recent-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search recent logs from iPad device (last 10 minutes)
ios-recent-logs-ipad:
    just _ios-recent-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core pattern search function - takes device ID as argument
_ios-search-logs-internal pattern device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    PATTERN="{{pattern}}"
    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Searching for pattern: ${PATTERN}"
    echo "📱 Device ID: $DEVICE_ID"
    echo "📊 Time range: Last 15 minutes"
    echo ""

    # Use log show for pattern search in device logs
    log show --predicate "processImagePath contains \"gametwo\" and (category contains \"${PATTERN}\" or message contains \"${PATTERN}\")" --last 15m --style compact

# Search for specific patterns in iPhone device logs
ios-search-logs-iphone pattern:
    just _ios-search-logs-internal "{{pattern}}" "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search for specific patterns in iPad device logs
ios-search-logs-ipad pattern:
    just _ios-search-logs-internal "{{pattern}}" "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core Sentry monitoring function - takes device ID as argument
_ios-sentry-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Monitoring Sentry SDK logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Looking for: Sentry initialization, debug messages, crash reports"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use log stream for Sentry-specific monitoring
    log stream --debug --predicate 'processImagePath contains "gametwo" and (message contains "Sentry" or message contains "sentry" or message contains "debug_startup")' --style compact

# Monitor Sentry-related logs specifically from iPhone
ios-sentry-logs-iphone:
    just _ios-sentry-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor Sentry-related logs specifically from iPad
ios-sentry-logs-ipad:
    just _ios-sentry-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core JSON config monitoring function - takes device ID as argument
_ios-config-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Monitoring JSON config reading logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Looking for: debug_startup_actions.json, config reader, debug coordinator"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use log stream for JSON config monitoring
    log stream --debug --predicate 'processImagePath contains "gametwo" and (message contains "debug_startup_actions" or message contains "config_reader" or message contains "DebugConfigReader" or message contains "DebugStartupCoordinator")' --style compact

# Monitor JSON config reading specifically from iPhone
ios-config-logs-iphone:
    just _ios-config-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor JSON config reading specifically from iPad
ios-config-logs-ipad:
    just _ios-config-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# iOS testing interface - manual mode with fzf selection
test-ios target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If arguments provided, delegate to test-ios-target (automated mode)
    if [ -n "{{target}}" ]; then
        echo "🎯 Automated mode execution: {{target}}"

        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        just test-ios-target "{{target}}"
        exit $?
    fi

    # Use shared fzf selection for all configs (automatic mode)
    selected=$(just _fzf-select-config "ios" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        echo "Running automatic mode: just test-ios-target '$selected'"
        just test-ios-target "$selected"
    else
        echo "❌ No selection made"
        exit 1
    fi

# iOS equivalent of test-android-target - complete test workflow with device logging
test-ios-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If no config provided, show fzf selection
    if [ -z "{{ config_name }}" ]; then
        selected=$(just _fzf-select-config "ios" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{ config_name }}"
    fi

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the unified execution pattern - same as Android!
    just _execute-test-with-analysis "$CONFIG_NAME" "ios" "$TEST_SESSION"

# iOS testing wrapper for iPhone device
test-ios-iphone target="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPhone: {{IOS_IPHONE_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPHONE_DEVICE_ID}}"

    if [ -n "{{target}}" ]; then
        just test-ios "{{target}}"
    else
        just test-ios
    fi

# iOS testing wrapper for iPad device
test-ios-ipad target="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPad: {{IOS_IPAD_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPAD_DEVICE_ID}}"

    if [ -n "{{target}}" ]; then
        just test-ios "{{target}}"
    else
        just test-ios
    fi

# iOS deployment function - integrates with existing ios-deploy-config recipe
_deploy-config-ios config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"
    echo "📱 Deploying iOS config: $(basename "$CONFIG_PATH")"

    # Validate config exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config file not found: $CONFIG_PATH"
        exit 1
    fi

    # Extract config name for deployment
    CONFIG_NAME=$(basename "$CONFIG_PATH" .json)

    # Use existing ios-deploy-config recipe (handles file copying to app bundle)
    if ! just ios-deploy-config "$CONFIG_NAME"; then
        echo "❌ Failed to deploy iOS config"
        exit 1
    fi

    echo "✅ iOS config deployed successfully"

# Clean up old iOS test logs by age
clean-ios-logs-by-age days="7":
    #!/usr/bin/env/bash
    set -euo pipefail

    DAYS="{{days}}"

    echo "🧹 Cleaning iOS test logs older than $DAYS days..."

    # Clean iOS device logs
    IOS_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    if [[ -d "$IOS_LOG_DIR" ]]; then
        echo "📱 Cleaning iOS device logs..."
        find "$IOS_LOG_DIR" -name "ios_*.log" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old iOS device logs to clean"

        echo "📊 Cleaning iOS action results..."
        find "$IOS_LOG_DIR" -name "test_action_results_*.json" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old iOS action results to clean"
    else
        echo "ℹ️  iOS log directory not found: $IOS_LOG_DIR"
    fi

    echo "✅ iOS log cleanup completed"

# Clean up all iOS test logs (default behavior)
clean-ios-logs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧹 Cleaning all iOS test logs..."

    FILES_DELETED=0

    # Clean all iOS logs from app userdata directory
    IOS_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    if [[ -d "$IOS_LOG_DIR" ]]; then
        echo "📱 Removing all iOS logs from $IOS_LOG_DIR..."

        IOS_FILES_DELETED=$(find "$IOS_LOG_DIR" -name "ios_*.log" -print -delete 2>/dev/null | wc -l)
        ACTION_FILES_DELETED=$(find "$IOS_LOG_DIR" -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
        TOTAL_IOS=$((IOS_FILES_DELETED + ACTION_FILES_DELETED))
        FILES_DELETED=$((FILES_DELETED + TOTAL_IOS))

        if [[ $TOTAL_IOS -gt 0 ]]; then
            echo "  🗑️  Deleted $TOTAL_IOS iOS log files from app directory"
        else
            echo "  ℹ️  No iOS files found in app directory"
        fi
    else
        echo "ℹ️  iOS log directory not found: $IOS_LOG_DIR"
    fi

    # Clean all temporary iOS logs
    echo "🗂️  Removing all temporary iOS logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*ios*.json" -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary iOS files"
    else
        echo "  ℹ️  No temporary iOS files found"
    fi

    echo "✅ iOS log cleanup completed - $FILES_DELETED files deleted"

# Clean up old Godot test logs by age
clean-godot-logs-by-age days="7":
    #!/usr/bin/env bash
    set -euo pipefail

    DAYS="{{days}}"
    echo "🧹 Cleaning Godot test logs older than $DAYS days..."

    FILES_DELETED=0

    # Clean all platform logs from app userdata directory
    GODOT_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    if [[ -d "$GODOT_LOG_DIR" ]]; then
        echo "📱 Cleaning iOS logs..."
        IOS_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "ios_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + IOS_FILES_DELETED))

        if [[ $IOS_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $IOS_FILES_DELETED iOS log files"
        else
            echo "  ℹ️  No old iOS logs to clean"
        fi

        echo "🤖 Cleaning Android logs..."
        ANDROID_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "android_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ANDROID_FILES_DELETED))

        if [[ $ANDROID_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $ANDROID_FILES_DELETED Android log files"
        else
            echo "  ℹ️  No old Android logs to clean"
        fi

        echo "🖥️  Cleaning Desktop logs..."
        DESKTOP_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "desktop_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + DESKTOP_FILES_DELETED))

        if [[ $DESKTOP_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $DESKTOP_FILES_DELETED Desktop log files"
        else
            echo "  ℹ️  No old Desktop logs to clean"
        fi

        echo "📊 Cleaning test action results..."
        ACTION_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "test_action_results_*.json" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ACTION_FILES_DELETED))

        if [[ $ACTION_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $ACTION_FILES_DELETED test action result files"
        else
            echo "  ℹ️  No old test action results to clean"
        fi
    else
        echo "ℹ️  Godot log directory not found: $GODOT_LOG_DIR"
    fi

    # Clean temporary Godot logs from /tmp
    echo "🗂️  Cleaning temporary Godot logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -o -name "*android*.log" -o -name "*desktop*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*.json" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary Godot files"
    else
        echo "  ℹ️  No old temporary Godot files to clean"
    fi

    echo "✅ Godot log cleanup completed - $FILES_DELETED files deleted"

# Clean up all Godot test logs (default behavior)
clean-godot-logs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧹 Cleaning all Godot test logs..."

    FILES_DELETED=0

    # Clean all platform logs from app userdata directory
    GODOT_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    if [[ -d "$GODOT_LOG_DIR" ]]; then
        echo "📱 Removing all iOS logs..."
        IOS_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "ios_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + IOS_FILES_DELETED))

        echo "🤖 Removing all Android logs..."
        ANDROID_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "android_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ANDROID_FILES_DELETED))

        echo "🖥️  Removing all Desktop logs..."
        DESKTOP_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "desktop_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + DESKTOP_FILES_DELETED))

        echo "📊 Removing all test action results..."
        ACTION_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ACTION_FILES_DELETED))

        PLATFORM_TOTAL=$((IOS_FILES_DELETED + ANDROID_FILES_DELETED + DESKTOP_FILES_DELETED + ACTION_FILES_DELETED))
        echo "  🗑️  Deleted $PLATFORM_TOTAL Godot log files from app directory"
    else
        echo "ℹ️  Godot log directory not found: $GODOT_LOG_DIR"
    fi

    # Clean all temporary Godot logs
    echo "🗂️  Removing all temporary Godot logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -o -name "*android*.log" -o -name "*desktop*.log" -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary Godot files"
    else
        echo "  ℹ️  No temporary Godot files found"
    fi

    echo "✅ Godot log cleanup completed - $FILES_DELETED files deleted"

# Clean all logs (Godot + main logs directory)
clean-all-logs days="7":
    #!/usr/bin/env bash
    set -euo pipefail

    DAYS="{{days}}"
    echo "🧹 Cleaning all logs older than $DAYS days..."

    # Clean all Godot platform logs
    echo "🎮 Cleaning all Godot platform logs..."
    just clean-godot-logs-by-age {{days}}

    # Clean main logs directory
    echo "📁 Cleaning main logs directory..."
    if [[ -d "logs" ]]; then
        find logs -name "*.log" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old main logs to clean"
    fi

    echo "✅ All log cleanup completed"

# iOS test execution function - uses configured device identifier from IOS_TEST_DEVICE variable
_execute-test-ios config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    IOS_DEVICE_ID="{{IOS_TEST_DEVICE}}"

    # Determine device type based on device ID
    if [[ "$IOS_DEVICE_ID" == "{{IOS_IPHONE_DEVICE_ID}}" ]]; then
        IOS_DEVICE_TYPE="iphone"
        DEVICE_NAME="iPhone"
    elif [[ "$IOS_DEVICE_ID" == "{{IOS_IPAD_DEVICE_ID}}" ]]; then
        IOS_DEVICE_TYPE="ipad"
        DEVICE_NAME="iPad"
    else
        echo "❌ Invalid IOS_TEST_DEVICE identifier: $IOS_DEVICE_ID"
        echo "💡 Valid options:"
        echo "   • iPhone: {{IOS_IPHONE_DEVICE_ID}}"
        echo "   • iPad: {{IOS_IPAD_DEVICE_ID}}"
        echo "💡 Configure in core config or environment"
        exit 1
    fi

    echo "🍎 Executing iOS test: $CONFIG_NAME on $DEVICE_NAME ($IOS_DEVICE_ID)"

    # Use appropriate hotreload recipe based on device type
    if [[ "$IOS_DEVICE_TYPE" == "iphone" ]]; then
        if ! just hotreload-ios-iphone; then
            echo "❌ Failed to execute iOS test on iPhone"
            exit 1
        fi
    else
        if ! just hotreload-ios-ipad; then
            echo "❌ Failed to execute iOS test on iPad"
            exit 1
        fi
    fi

    echo "✅ iOS test execution completed on $DEVICE_NAME"