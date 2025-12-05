# ================================
# TAG-BASED LOG FILTERING COMMANDS
# ================================

# Show only specific tags to save tokens
logs-tags TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🏷️  Filtering logs by tags: $TAGS"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Convert space-separated tags to grep pattern
    tag_pattern=""
    for tag in $TAGS; do
        if [ -z "$tag_pattern" ]; then
            tag_pattern="$tag"
        else
            tag_pattern="$tag_pattern\|$tag"
        fi
    done
    
    # Filter logs by tags and show only matching lines
    grep "$tag_pattern" "$LOG_FILE" | head -50


# Show only errors and failures
logs-errors TEST_ID PLATFORM="auto":
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    PLATFORM="{{PLATFORM}}"
    DESKTOP_LOG_DIR="{{DESKTOP_LOG_DIR}}"

    # Auto-detect platform from TEST_ID if platform is "auto"
    if [ "$PLATFORM" = "auto" ]; then
        if [[ "$TEST_ID" == android_* ]]; then
            PLATFORM="android"
        elif [[ "$TEST_ID" == desktop_* ]]; then
            PLATFORM="desktop"
        elif [[ "$TEST_ID" == ios_* ]]; then
            PLATFORM="ios"
        else
            # Default to desktop for backwards compatibility
            PLATFORM="desktop"
        fi
    fi

    # Find log file based on platform
    case "$PLATFORM" in
        android|ios)
            # Use filename-based search for Android/iOS
            LOG_FILE=$(find "$DESKTOP_LOG_DIR" -name "*${TEST_ID}*.log" -type f | head -1)
            if [ -z "$LOG_FILE" ]; then
                echo "❌ No log file found for test ID: $TEST_ID" >&2
                exit 1
            fi
            ;;
        desktop)
            # Use existing desktop infrastructure
            LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
            ;;
        *)
            echo "❌ Invalid platform: $PLATFORM" >&2
            exit 1
            ;;
    esac

    # Extract and display test session information for Sentry correlation
    echo "🔍 Test Session Information for Sentry:"
    echo "======================================"
    echo "🖥️  Platform: $PLATFORM ($([ "{{PLATFORM}}" = "auto" ] && echo "auto-detected" || echo "explicit"))"
    test_session_id=$(rg -o '"test_session_id": "[^"]*"' "$LOG_FILE" | cut -d'"' -f4 | head -1 || echo "Not found")

    # Use the provided TEST_ID for Sentry correlation
    echo "📋 Test ID: $TEST_ID"
    echo "🌐 Search in Sentry: test_session_id:$TEST_ID"

    if [ "$test_session_id" != "Not found" ] && [ "$test_session_id" != "$TEST_ID" ]; then
        echo "🏷️  Test Session ID: $test_session_id"
        echo "🌐 Alternative Sentry search: test_session_id:$test_session_id"
    fi
    echo ""

    echo "🚨 Errors and Failures Only:"
    echo "=============================="
    echo ""

    # Show errors, failures, warnings, and critical issues (exclude "error": false)
    grep -E "ERROR|FAILURE|WARNING.*⚠️|RESTART_NEEDED" "$LOG_FILE" | grep -v '"error": false' || echo "✅ No errors found"

# Show only test lifecycle events 
logs-lifecycle TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🔄 Test Lifecycle Events:"
    echo "========================="
    echo ""
    
    # Show key test events in order (searches both ERROR and INFO levels)
    grep -E "DEBUG_TEST_START\|DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE\|DEBUG_TEST_COMPLETE\|DEBUG_TEST_RESTART" "$LOG_FILE" || echo "⚠️ No lifecycle events found"

# Show logs from most recent test run only (platform-agnostic)
# ⚠️  DEPRECATED: Use 'logs-latest' instead - supports platform auto-detection and explicit override
logs-last:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last' is deprecated. Use 'logs-latest [PLATFORM]' instead"
    echo "   → New command supports: logs-latest (auto), logs-latest android, logs-latest desktop"
    echo ""

    # Android logs are stored in standard Godot logs directory
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"

    # Platform detection and log retrieval
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
        echo "🤖 Getting latest Android logs..."

        # Look for Android log files first (saved test results)
        if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null)" ]; then
            LATEST_ANDROID_LOG=$(ls -t "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null | head -1)
            echo "📄 Latest Android log: $(basename "$LATEST_ANDROID_LOG")"
            echo "📁 Location: $(dirname "$LATEST_ANDROID_LOG")"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$LATEST_ANDROID_LOG"
        else
            # Fallback to live device buffer if no saved logs exist
            echo "⚠️  No saved Android logs found, trying live device buffer..."
            echo ""
            # Get recent Android logs and extract test session information
            ANDROID_LOGS=$(adb logcat -d 2>/dev/null | tail -20000 || echo "")

            # Extract test session information from recent logs
            TEST_SESSION_ID=$(echo "$ANDROID_LOGS" | rg -o '"test_session_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
            LATEST_TEST_ID=$(echo "$ANDROID_LOGS" | rg '"test_id":' | rg -o '"test_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")

            echo ""
            if [ "$LATEST_TEST_ID" != "Not found" ]; then
                echo "🔍 Test Session Information:"
                echo "──────────────────────────"
                echo "📋 Test ID: $LATEST_TEST_ID"
                echo "🌐 Search in Sentry: test_session_id:$LATEST_TEST_ID"
            fi
            if [ "$TEST_SESSION_ID" != "Not found" ] && [ "$TEST_SESSION_ID" != "$LATEST_TEST_ID" ]; then
                echo "🏷️  Test Session ID: $TEST_SESSION_ID"
                echo "🌐 Alternative Sentry search: test_session_id:$TEST_SESSION_ID"
            fi
            if [ "$LATEST_TEST_ID" = "Not found" ] && [ "$TEST_SESSION_ID" = "Not found" ]; then
                echo "⚠️  No test context found in recent logs"
            fi
            echo ""

            echo "🤖 Latest Android logs:"
            echo "────────────────────"
            LAST_LINE=$(adb logcat -d | grep -n "ActivityManager.*Start proc.*gametwo" | tail -1 | cut -d: -f1)
            [ -n "$LAST_LINE" ] && adb logcat -d | tail -n +$LAST_LINE || echo "❌ No recent Android runs"
        fi
    else
        echo "🖥️  Getting latest Desktop logs..."

        # Use unified log retrieval function
        LATEST_LOG=$(just _get-desktop-log-file)

        echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
        echo "📁 Location: $(dirname "$LATEST_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_LOG"
    fi

# Platform-specific versions of logs-last for explicit targeting
# ⚠️  DEPRECATED: Use 'logs-latest android' instead
logs-last-android:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last-android' is deprecated. Use 'logs-latest android' instead"
    echo ""

    echo "🤖 Getting latest Android logs (explicit)..."

    # Android logs are stored in standard Godot logs directory
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"

    # Look for Android log files first (saved test results)
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null)" ]; then
        LATEST_ANDROID_LOG=$(ls -t "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null | head -1)
        echo "📄 Latest Android log: $(basename "$LATEST_ANDROID_LOG")"
        echo "📁 Location: $(dirname "$LATEST_ANDROID_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_ANDROID_LOG"
    else
        # Fallback to live device buffer if no saved logs exist
        echo "⚠️  No saved Android logs found, trying live device buffer..."
        echo ""

        # Get recent Android logs and extract test session information
        ANDROID_LOGS=$(adb logcat -d 2>/dev/null | tail -20000 || echo "")

        # Extract test session information from recent logs
        TEST_SESSION_ID=$(echo "$ANDROID_LOGS" | rg -o '"test_session_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
        LATEST_TEST_ID=$(echo "$ANDROID_LOGS" | rg '"test_id":' | rg -o '"test_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")

        echo ""
        if [ "$LATEST_TEST_ID" != "Not found" ]; then
            echo "🔍 Test Session Information:"
            echo "──────────────────────────"
            echo "📋 Test ID: $LATEST_TEST_ID"
            echo "🌐 Search in Sentry: test_session_id:$LATEST_TEST_ID"
        fi
        if [ "$TEST_SESSION_ID" != "Not found" ] && [ "$TEST_SESSION_ID" != "$LATEST_TEST_ID" ]; then
            echo "🏷️  Test Session ID: $TEST_SESSION_ID"
            echo "🌐 Alternative Sentry search: test_session_id:$TEST_SESSION_ID"
        fi
        if [ "$LATEST_TEST_ID" = "Not found" ] && [ "$TEST_SESSION_ID" = "Not found" ]; then
            echo "⚠️  No test context found in recent logs"
        fi
        echo ""

        echo "🤖 Latest Android logs:"
        echo "────────────────────"
        LAST_LINE=$(adb logcat -d | grep -n "ActivityManager.*Start proc.*gametwo" | tail -1 | cut -d: -f1)
        [ -n "$LAST_LINE" ] && adb logcat -d | tail -n +$LAST_LINE || echo "❌ No recent Android runs"
    fi

# ⚠️  DEPRECATED: Use 'logs-latest desktop' instead
logs-last-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last-desktop' is deprecated. Use 'logs-latest desktop' instead"
    echo ""

    echo "🖥️  Getting latest Desktop logs (explicit)..."

    # Use unified log retrieval function
    LATEST_LOG=$(just _get-desktop-log-file)

    echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
    echo "📁 Location: $(dirname "$LATEST_LOG")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LATEST_LOG"

# ⚠️  DEPRECATED: Use 'logs-latest ios' instead
logs-last-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last-ios' is deprecated. Use 'logs-latest ios' instead"
    echo ""

    echo "🍎 Getting latest iOS logs (explicit)..."

    # iOS logs are stored in standard Godot logs directory
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"

    # Look for iOS log files first
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IOS_LOG=$(ls -t "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iOS log: $(basename "$LATEST_IOS_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IOS_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IOS_LOG"
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IOS_LOG=$(ls -t "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iOS log: $(basename "$LATEST_IOS_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IOS_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IOS_LOG"
    else
        echo "❌ No iOS logs found"
        echo "💡 Try running an iOS test first, or check:"
        echo "   - $STANDARD_LOGS_DIR"
        echo "   - $PROJECT_LOGS_DIR"
        echo ""
        echo "🔍 Available iOS log commands:"
        echo "   - just ios-retrieve-logs-iphone"
        echo "   - just ios-retrieve-logs-ipad"
        echo "   - just ios-device-logs-iphone"
        echo "   - just ios-device-logs-ipad"
        echo "   - just logs-last-ios-iphone"
        echo "   - just logs-last-ios-ipad"
    fi

# iOS device-specific versions for logs-last-ios-iphone
# ⚠️  DEPRECATED: Use 'logs-latest ios' instead
logs-last-ios-iphone:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last-ios-iphone' is deprecated. Use 'logs-latest ios' instead"
    echo ""

    echo "🍎 Getting latest iPhone logs..."

    # iOS logs are stored in standard Godot logs directory
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"

    # Look for iPhone log files first
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IPHONE_LOG=$(ls -t "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iPhone log: $(basename "$LATEST_IPHONE_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IPHONE_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IPHONE_LOG"
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IPHONE_LOG=$(ls -t "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iPhone log: $(basename "$LATEST_IPHONE_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IPHONE_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IPHONE_LOG"
    else
        echo "❌ No iPhone logs found"
        echo "💡 Try running an iPhone test first, or check:"
        echo "   - $STANDARD_LOGS_DIR"
        echo "   - $PROJECT_LOGS_DIR"
        echo ""
        echo "🔍 Available iPhone log commands:"
        echo "   - just ios-retrieve-logs-iphone"
        echo "   - just ios-device-logs-iphone"
        echo "   - just ios-recent-logs-iphone"
        echo "   - just ios-search-logs-iphone \"pattern\""
        echo "   - just ios-sentry-logs-iphone"
        echo "   - just ios-config-logs-iphone"
    fi

# iOS device-specific versions for logs-last-ios-ipad
# ⚠️  DEPRECATED: Use 'logs-latest ios' instead
logs-last-ios-ipad:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-last-ios-ipad' is deprecated. Use 'logs-latest ios' instead"
    echo ""

    echo "🍎 Getting latest iPad logs..."

    # iOS logs are stored in standard Godot logs directory
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"

    # Look for iPad log files first
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IPAD_LOG=$(ls -t "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iPad log: $(basename "$LATEST_IPAD_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IPAD_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IPAD_LOG"
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
        LATEST_IPAD_LOG=$(ls -t "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
        echo "📄 Latest iPad log: $(basename "$LATEST_IPAD_LOG")"
        echo "📁 Location: $(dirname "$LATEST_IPAD_LOG")"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$LATEST_IPAD_LOG"
    else
        echo "❌ No iPad logs found"
        echo "💡 Try running an iPad test first, or check:"
        echo "   - $STANDARD_LOGS_DIR"
        echo "   - $PROJECT_LOGS_DIR"
        echo ""
        echo "🔍 Available iPad log commands:"
        echo "   - just ios-retrieve-logs-ipad"
        echo "   - just ios-device-logs-ipad"
        echo "   - just ios-recent-logs-ipad"
        echo "   - just ios-search-logs-ipad \"pattern\""
        echo "   - just ios-sentry-logs-ipad"
        echo "   - just ios-config-logs-ipad"
    fi

# Show only performance/timing info
logs-performance TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "⚡ Performance and Timing:"
    echo "========================="
    echo ""
    
    # Extract timing information (|| true prevents SIGPIPE from failing with pipefail)
    grep -E "duration_ms\|memory_mb\|performance" "$LOG_FILE" | head -20 || true

# Show detailed checksum content for state comparison debugging
logs-checksum-detail TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "=== Detailed Checksum Content for $TEST_ID ==="
    echo ""
    echo "Shows exact game state content that gets hashed for each checksum."
    echo "Critical for debugging checksum mismatches between recording and replay."
    echo ""
    
    # Show CHECKSUM_CONTENT_DETAIL entries (|| true prevents SIGPIPE from failing with pipefail)
    grep "CHECKSUM_CONTENT_DETAIL" "$LOG_FILE" || true

    echo ""
    echo "=== Generated Checksums ==="
    grep "Generated checksum" "$LOG_FILE" || true




# Smart summary - key facts only
logs-summary TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "📋 Quick Summary for $TEST_ID:"
    echo "============================="
    echo ""
    
    # Extract key facts (|| true prevents SIGPIPE from failing with pipefail)
    start_line=$(grep "DEBUG_TEST_START" "$LOG_FILE" | head -1 || true)
    complete_line=$(grep "DEBUG_TEST_COMPLETE" "$LOG_FILE" | head -1 || true)
    success_count=$(grep -c "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null || echo "0")
    failure_count=$(grep -c "DEBUG_TEST_FAILURE" "$LOG_FILE" 2>/dev/null || echo "0")
    restart_count=$(grep -c "RESTART" "$LOG_FILE" 2>/dev/null || echo "0")
    error_count=$(grep -c "ERROR\|error" "$LOG_FILE" 2>/dev/null || echo "0")
    
    if [ -n "$start_line" ]; then
        start_time=$(echo "$start_line" | grep -o '"timestamp": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "⏰ Started: $start_time"
    fi
    
    if [ -n "$complete_line" ]; then
        echo "✅ Completed: $complete_line"
    fi
    
    echo "📊 Results: $success_count successes, $failure_count failures"
    echo "🔄 Restarts: $restart_count"
    echo "🚨 Errors: $error_count"
    
    # Show any critical issues
    if [ "$error_count" -gt 0 ]; then
        echo ""
        echo "🚨 Critical Issues:"
        grep -E "ERROR\|error" "$LOG_FILE" | head -3 || true
    fi

# List available tags in a log file
logs-list-tags TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🏷️  Available tags in $TEST_ID:"
    echo "==============================="
    echo ""
    
    # Extract unique tags from log entries
    grep -o '\["[^"]*"[^]]*\]' "$LOG_FILE" | sort | uniq | head -20

# Simple free-text search in logs (case-insensitive)
# ⚠️  DEPRECATED: Use 'logs-search' instead - supports platform auto-detection
logs-text TEST_ID SEARCH_TERM:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  DEPRECATED: 'logs-text' is deprecated. Use 'logs-search TEST_ID \"SEARCH_TERM\"' instead"
    echo "   → New command supports platform auto-detection from TEST_ID"
    echo ""

    TEST_ID="{{TEST_ID}}"
    SEARCH_TERM="{{SEARCH_TERM}}"

    # Use existing infrastructure
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🔍 Searching logs for: $SEARCH_TERM"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Case-insensitive search with limit for token efficiency
    grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
# ================================
# NEW CONSOLIDATED COMMAND
# ================================
# Unified log retrieval with optional platform parameter
# Replaces: logs-last, logs-last-android, logs-last-desktop, logs-last-ios
logs-latest PLATFORM="auto":
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{PLATFORM}}"
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"
    
    case "$PLATFORM" in
        android)
            echo "🤖 Getting latest Android logs (explicit)..."
            
            # Look for Android log files first (saved test results)
            if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null)" ]; then
                LATEST_ANDROID_LOG=$(ls -t "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null | head -1)
                echo "📄 Latest Android log: $(basename "$LATEST_ANDROID_LOG")"
                echo "📁 Location: $(dirname "$LATEST_ANDROID_LOG")"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat "$LATEST_ANDROID_LOG"
            else
                # Fallback to live device buffer if no saved logs exist
                echo "⚠️  No saved Android logs found, trying live device buffer..."
                echo ""
                
                # Get recent Android logs and extract test session information
                ANDROID_LOGS=$(adb logcat -d 2>/dev/null | tail -20000 || echo "")
                
                # Extract test session information from recent logs
                TEST_SESSION_ID=$(echo "$ANDROID_LOGS" | rg -o '"test_session_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
                LATEST_TEST_ID=$(echo "$ANDROID_LOGS" | rg '"test_id":' | rg -o '"test_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
                
                echo ""
                if [ "$LATEST_TEST_ID" != "Not found" ]; then
                    echo "🔍 Test Session Information:"
                    echo "──────────────────────────"
                    echo "📋 Test ID: $LATEST_TEST_ID"
                    echo "🌐 Search in Sentry: test_session_id:$LATEST_TEST_ID"
                fi
                if [ "$TEST_SESSION_ID" != "Not found" ] && [ "$TEST_SESSION_ID" != "$LATEST_TEST_ID" ]; then
                    echo "🏷️  Test Session ID: $TEST_SESSION_ID"
                    echo "🌐 Alternative Sentry search: test_session_id:$TEST_SESSION_ID"
                fi
                if [ "$LATEST_TEST_ID" = "Not found" ] && [ "$TEST_SESSION_ID" = "Not found" ]; then
                    echo "⚠️  No test context found in recent logs"
                fi
                echo ""
                
                echo "🤖 Latest Android logs:"
                echo "────────────────────"
                LAST_LINE=$(adb logcat -d | grep -n "ActivityManager.*Start proc.*gametwo" | tail -1 | cut -d: -f1)
                [ -n "$LAST_LINE" ] && adb logcat -d | tail -n +$LAST_LINE || echo "❌ No recent Android runs"
            fi
            ;;
        
        desktop)
            echo "🖥️  Getting latest Desktop logs (explicit)..."
            
            # Use unified log retrieval function
            LATEST_LOG=$(just _get-desktop-log-file)
            
            echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
            echo "📁 Location: $(dirname "$LATEST_LOG")"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$LATEST_LOG"
            ;;
        
        ios)
            echo "🍎 Getting latest iOS logs (explicit)..."
            
            # Look for iOS log files first
            if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
                LATEST_IOS_LOG=$(ls -t "$STANDARD_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
                echo "📄 Latest iOS log: $(basename "$LATEST_IOS_LOG")"
                echo "📁 Location: $(dirname "$LATEST_IOS_LOG")"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat "$LATEST_IOS_LOG"
            elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null)" ]; then
                LATEST_IOS_LOG=$(ls -t "$PROJECT_LOGS_DIR"/ios_*.log 2>/dev/null | head -1)
                echo "📄 Latest iOS log: $(basename "$LATEST_IOS_LOG")"
                echo "📁 Location: $(dirname "$LATEST_IOS_LOG")"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat "$LATEST_IOS_LOG"
            else
                echo "❌ No iOS logs found"
                echo "💡 Try running an iOS test first, or check:"
                echo "   - $STANDARD_LOGS_DIR"
                echo "   - $PROJECT_LOGS_DIR"
            fi
            ;;
        
        auto)
            echo "🔍 Auto-detecting platform..."
            
            # Platform detection and log retrieval
            if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
                echo "🤖 Getting latest Android logs..."
                
                # Look for Android log files first (saved test results)
                if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null)" ]; then
                    LATEST_ANDROID_LOG=$(ls -t "$STANDARD_LOGS_DIR"/android_*.log 2>/dev/null | head -1)
                    echo "📄 Latest Android log: $(basename "$LATEST_ANDROID_LOG")"
                    echo "📁 Location: $(dirname "$LATEST_ANDROID_LOG")"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    cat "$LATEST_ANDROID_LOG"
                else
                    # Fallback to live device buffer if no saved logs exist
                    echo "⚠️  No saved Android logs found, trying live device buffer..."
                    echo ""
                    # Get recent Android logs and extract test session information
                    ANDROID_LOGS=$(adb logcat -d 2>/dev/null | tail -20000 || echo "")
                    
                    # Extract test session information from recent logs
                    TEST_SESSION_ID=$(echo "$ANDROID_LOGS" | rg -o '"test_session_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
                    LATEST_TEST_ID=$(echo "$ANDROID_LOGS" | rg '"test_id":' | rg -o '"test_id": "[^"]*"' | cut -d'"' -f4 | tail -1 || echo "Not found")
                    
                    echo ""
                    if [ "$LATEST_TEST_ID" != "Not found" ]; then
                        echo "🔍 Test Session Information:"
                        echo "──────────────────────────"
                        echo "📋 Test ID: $LATEST_TEST_ID"
                        echo "🌐 Search in Sentry: test_session_id:$LATEST_TEST_ID"
                    fi
                    if [ "$TEST_SESSION_ID" != "Not found" ] && [ "$TEST_SESSION_ID" != "$LATEST_TEST_ID" ]; then
                        echo "🏷️  Test Session ID: $TEST_SESSION_ID"
                        echo "🌐 Alternative Sentry search: test_session_id:$TEST_SESSION_ID"
                    fi
                    if [ "$LATEST_TEST_ID" = "Not found" ] && [ "$TEST_SESSION_ID" = "Not found" ]; then
                        echo "⚠️  No test context found in recent logs"
                    fi
                    echo ""
                    
                    echo "🤖 Latest Android logs:"
                    echo "────────────────────"
                    LAST_LINE=$(adb logcat -d | grep -n "ActivityManager.*Start proc.*gametwo" | tail -1 | cut -d: -f1)
                    [ -n "$LAST_LINE" ] && adb logcat -d | tail -n +$LAST_LINE || echo "❌ No recent Android runs"
                fi
            else
                echo "🖥️  Getting latest Desktop logs..."
                
                # Use unified log retrieval function
                LATEST_LOG=$(just _get-desktop-log-file)
                
                echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
                echo "📁 Location: $(dirname "$LATEST_LOG")"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat "$LATEST_LOG"
            fi
            ;;
        
        *)
            echo "❌ Invalid platform: $PLATFORM"
            echo "Valid options: auto, android, desktop, ios"
            echo ""
            echo "Usage:"
            echo "  just logs-latest          # Auto-detect platform"
            echo "  just logs-latest android  # Explicit Android"
            echo "  just logs-latest desktop  # Explicit Desktop"
            echo "  just logs-latest ios      # Explicit iOS"
            exit 1
            ;;
    esac

# Text search with optional platform parameter
# Replaces: logs-text
logs-search TEST_ID SEARCH_TERM PLATFORM="auto":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    SEARCH_TERM="{{SEARCH_TERM}}"
    PLATFORM="{{PLATFORM}}"
    DESKTOP_LOG_DIR="{{DESKTOP_LOG_DIR}}"
    
    # Auto-detect platform from TEST_ID if platform is "auto"
    if [ "$PLATFORM" = "auto" ]; then
        if [[ "$TEST_ID" == android_* ]]; then
            PLATFORM="android"
        elif [[ "$TEST_ID" == desktop_* ]]; then
            PLATFORM="desktop"
        elif [[ "$TEST_ID" == ios_* ]]; then
            PLATFORM="ios"
        else
            # Default to desktop for backwards compatibility with logs-text
            PLATFORM="desktop"
        fi
    fi
    
    echo "🔍 Searching for: $SEARCH_TERM"
    echo "📋 Test ID: $TEST_ID"
    echo "🖥️  Platform: $PLATFORM ($([ "{{PLATFORM}}" = "auto" ] && echo "auto-detected" || echo "explicit"))"
    echo ""
    
    case "$PLATFORM" in
        android)
            # Use Android log file search
            LOG_FILE=$(find "$DESKTOP_LOG_DIR" -name "*${TEST_ID}*.log" -type f | head -1)
            
            if [ -z "$LOG_FILE" ]; then
                echo "❌ No Android log file found for test ID: $TEST_ID" >&2
                echo "" >&2
                echo "💡 Try:" >&2
                echo "   just logs-latest android" >&2
                exit 1
            fi
            
            echo "📄 Log file: $LOG_FILE"
            echo ""
            
            # Case-insensitive search with limit for token efficiency
            grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
            ;;
        
        desktop)
            # Use existing desktop infrastructure
            LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
            
            echo "📄 Log file: $LOG_FILE"
            echo ""
            
            # Case-insensitive search with limit for token efficiency
            grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
            ;;
        
        ios)
            # Use iOS log file search
            LOG_FILE=$(find "$DESKTOP_LOG_DIR" -name "*${TEST_ID}*.log" -type f | head -1)
            
            if [ -z "$LOG_FILE" ]; then
                echo "❌ No iOS log file found for test ID: $TEST_ID" >&2
                echo "" >&2
                echo "💡 Try:" >&2
                echo "   just logs-latest ios" >&2
                exit 1
            fi
            
            echo "📄 Log file: $LOG_FILE"
            echo ""
            
            # Case-insensitive search with limit for token efficiency
            grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
            ;;
        
        *)
            echo "❌ Invalid platform: $PLATFORM"
            echo "Valid options: auto, android, desktop, ios"
            echo ""
            echo "Usage:"
            echo "  just logs-search TEST_ID \"term\"          # Auto-detect platform from TEST_ID"
            echo "  just logs-search TEST_ID \"term\" android  # Explicit Android"
            echo "  just logs-search TEST_ID \"term\" desktop  # Explicit Desktop"
            echo "  just logs-search TEST_ID \"term\" ios      # Explicit iOS"
            exit 1
            ;;
    esac
