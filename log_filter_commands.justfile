# ================================
# TAG-BASED LOG FILTERING COMMANDS
# ================================

# Show only specific tags to save tokens
logs-tags TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Find log file by searching for test_id within the log content
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
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
    
    # Find log file
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "🚨 Errors and Failures Only:"
    echo "=============================="
    echo ""
    
    # Show errors, failures, and critical issues
    grep -E "ERROR\|FAILURE\|error\|failure\|RESTART_NEEDED" "$LOG_FILE" || echo "✅ No errors found"

# Show only test lifecycle events 
logs-lifecycle TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Find log file
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "🔄 Test Lifecycle Events:"
    echo "========================="
    echo ""
    
    # Show key test events in order
    grep -E "DEBUG_TEST_START\|DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE\|DEBUG_TEST_COMPLETE\|DEBUG_TEST_RESTART" "$LOG_FILE" || echo "⚠️ No lifecycle events found"

# Show only performance/timing info
logs-performance TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Find log file
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "⚡ Performance and Timing:"
    echo "========================="
    echo ""
    
    # Extract timing information
    grep -E "duration_ms\|memory_mb\|performance" "$LOG_FILE" | head -20

# Show battle-specific logs  
logs-battle TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just logs-tags "{{TEST_ID}}" battle determinism

# Show firebase-specific logs
logs-firebase TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just logs-tags "{{TEST_ID}}" firebase rtdb backend

# Show system-level logs
logs-system TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    just logs-tags "{{TEST_ID}}" system startup initialization

# Smart summary - key facts only
logs-summary TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Find log file
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
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
    
    # Find log file
    LOG_FILE=""
    for log_file in $(find test_results -name "test_logs.log"); do
        if grep -q "$TEST_ID" "$log_file" 2>/dev/null; then
            LOG_FILE="$log_file"
            break
        fi
    done
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "🏷️  Available tags in $TEST_ID:"
    echo "==============================="
    echo ""
    
    # Extract unique tags from log entries
    grep -o '\["[^"]*"[^]]*\]' "$LOG_FILE" | sort | uniq | head -20