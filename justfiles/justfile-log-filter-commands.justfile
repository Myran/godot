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
            PLATFORM="editor"
        elif [[ "$TEST_ID" == ios_* ]]; then
            PLATFORM="ios"
        elif [[ "$TEST_ID" == macos_* ]]; then
            PLATFORM="macos"
        else
            # Default to desktop for backwards compatibility
            PLATFORM="editor"
        fi
    fi

    # Find log file based on platform
    case "$PLATFORM" in
        android|ios|macos)
            # Use filename-based search for Android/iOS/macOS
            LOG_FILE=$(find "$DESKTOP_LOG_DIR" -name "*${TEST_ID}*.log" -type f | head -1)
            if [ -z "$LOG_FILE" ]; then
                echo "❌ No log file found for test ID: $TEST_ID" >&2
                exit 1
            fi
            ;;
        editor)
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

# Text search with optional platform parameter
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
            PLATFORM="editor"
        elif [[ "$TEST_ID" == ios_* ]]; then
            PLATFORM="ios"
        elif [[ "$TEST_ID" == macos_* ]]; then
            PLATFORM="macos"
        else
            # Default to desktop for backwards compatibility with logs-text
            PLATFORM="editor"
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
        
        editor)
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
                echo "💡 Try running an iOS test first:" >&2
                echo "   just test-ios-target CONFIG" >&2
                exit 1
            fi

            echo "📄 Log file: $LOG_FILE"
            echo ""

            # Case-insensitive search with limit for token efficiency
            grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
            ;;

        macos)
            # Use macOS log file search
            LOG_FILE=$(find "$DESKTOP_LOG_DIR" -name "*${TEST_ID}*.log" -type f | head -1)

            if [ -z "$LOG_FILE" ]; then
                echo "❌ No macOS log file found for test ID: $TEST_ID" >&2
                echo "" >&2
                echo "💡 Try running a macOS test first:" >&2
                echo "   just test-macos-target CONFIG" >&2
                exit 1
            fi

            echo "📄 Log file: $LOG_FILE"
            echo ""

            # Case-insensitive search with limit for token efficiency
            grep -i "$SEARCH_TERM" "$LOG_FILE" | head -50 || echo "❌ No matches found for: $SEARCH_TERM"
            ;;

        *)
            echo "❌ Invalid platform: $PLATFORM"
            echo "Valid options: auto, android, desktop, ios, macos"
            echo ""
            echo "Usage:"
            echo "  just logs-search TEST_ID \"term\"          # Auto-detect platform from TEST_ID"
            echo "  just logs-search TEST_ID \"term\" android  # Explicit Android"
            echo "  just logs-search TEST_ID \"term\" desktop  # Explicit Desktop"
            echo "  just logs-search TEST_ID \"term\" ios      # Explicit iOS"
            echo "  just logs-search TEST_ID \"term\" macos    # Explicit macOS"
            exit 1
            ;;
    esac
