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
logs-errors TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"

    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")

    # Extract and display test session information for Sentry correlation
    echo "🔍 Test Session Information for Sentry:"
    echo "======================================"
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
logs-last:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Platform detection and log retrieval
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
        echo "🤖 Getting latest Android logs..."

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
logs-last-android:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🤖 Getting latest Android logs (explicit)..."

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

logs-last-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🖥️  Getting latest Desktop logs (explicit)..."

    # Use unified log retrieval function
    LATEST_LOG=$(just _get-desktop-log-file)

    echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
    echo "📁 Location: $(dirname "$LATEST_LOG")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LATEST_LOG"

logs-last-ios:
    #!/usr/bin/env bash
    set -euo pipefail

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
logs-last-ios-iphone:
    #!/usr/bin/env bash
    set -euo pipefail

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
logs-last-ios-ipad:
    #!/usr/bin/env bash
    set -euo pipefail

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
    
    # Extract timing information
    grep -E "duration_ms\|memory_mb\|performance" "$LOG_FILE" | head -20

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
    
    # Show CHECKSUM_CONTENT_DETAIL entries
    grep "CHECKSUM_CONTENT_DETAIL" "$LOG_FILE"
    
    echo ""
    echo "=== Generated Checksums ==="
    grep "Generated checksum" "$LOG_FILE"




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
    
    # Extract key facts
    start_line=$(grep "DEBUG_TEST_START" "$LOG_FILE" | head -1)
    complete_line=$(grep "DEBUG_TEST_COMPLETE" "$LOG_FILE" | head -1)
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
        grep -E "ERROR\|error" "$LOG_FILE" | head -3
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
logs-text TEST_ID SEARCH_TERM:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    SEARCH_TERM="{{SEARCH_TERM}}"
    
    # Use existing infrastructure
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🔍 Searching logs for: $SEARCH_TERM"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Case-insensitive search with limit for token efficiency
    grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"