# ================================
# UNIVERSAL TAG-FILTERED LOG COMMANDS
# ================================

# Universal log display with optional tag filtering
logs TEST_ID *TAGS:
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
    
    echo "📋 Logs for Test: $TEST_ID"
    echo "📄 File: $LOG_FILE"
    
    if [ -n "$TAGS" ]; then
        echo "🏷️  Filtering by tags: $TAGS"
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
        
        # Filter logs by tags
        grep "$tag_pattern" "$LOG_FILE" | head -100
    else
        echo "📊 Full logs (first 50 lines):"
        echo ""
        head -50 "$LOG_FILE"
    fi

# Errors with optional tag filtering
logs-errors-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
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
    
    echo "🚨 Errors and Failures:"
    echo "======================="
    
    if [ -n "$TAGS" ]; then
        echo "🏷️  Filtered by tags: $TAGS"
        echo ""
        
        # Convert tags to pattern
        tag_pattern=""
        for tag in $TAGS; do
            if [ -z "$tag_pattern" ]; then
                tag_pattern="$tag"
            else
                tag_pattern="$tag_pattern\|$tag"
            fi
        done
        
        # Filter by tags first, then by errors
        grep "$tag_pattern" "$LOG_FILE" | grep -E "ERROR\|FAILURE\|error\|failure\|RESTART_NEEDED" || echo "✅ No errors in filtered logs"
    else
        echo "📊 All error types:"
        echo ""
        grep -E "ERROR\|FAILURE\|error\|failure\|RESTART_NEEDED" "$LOG_FILE" || echo "✅ No errors found"
    fi

# Performance with optional tag filtering  
logs-performance-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
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
    
    if [ -n "$TAGS" ]; then
        echo "🏷️  Filtered by tags: $TAGS"
        echo ""
        
        # Convert tags to pattern
        tag_pattern=""
        for tag in $TAGS; do
            if [ -z "$tag_pattern" ]; then
                tag_pattern="$tag"
            else
                tag_pattern="$tag_pattern\|$tag"
            fi
        done
        
        # Filter by tags first, then by performance data
        grep "$tag_pattern" "$LOG_FILE" | grep -E "duration_ms\|memory_mb\|performance" | head -20
    else
        echo "📊 All performance data:"
        echo ""
        grep -E "duration_ms\|memory_mb\|performance" "$LOG_FILE" | head -20
    fi

# Lifecycle with optional tag filtering
logs-lifecycle-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
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
    
    if [ -n "$TAGS" ]; then
        echo "🏷️  Filtered by tags: $TAGS"
        echo ""
        
        # Convert tags to pattern  
        tag_pattern=""
        for tag in $TAGS; do
            if [ -z "$tag_pattern" ]; then
                tag_pattern="$tag"
            else
                tag_pattern="$tag_pattern\|$tag"
            fi
        done
        
        # Filter by tags first, then by lifecycle events
        grep "$tag_pattern" "$LOG_FILE" | grep -E "DEBUG_TEST_START\|DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE\|DEBUG_TEST_COMPLETE\|DEBUG_TEST_RESTART" || echo "⚠️ No lifecycle events in filtered logs"
    else
        echo "📊 All lifecycle events:"
        echo ""
        grep -E "DEBUG_TEST_START\|DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE\|DEBUG_TEST_COMPLETE\|DEBUG_TEST_RESTART" "$LOG_FILE" || echo "⚠️ No lifecycle events found"
    fi