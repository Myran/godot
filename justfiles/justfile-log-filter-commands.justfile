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