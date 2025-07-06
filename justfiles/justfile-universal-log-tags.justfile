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
        grep "$tag_pattern" "$LOG_FILE" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true" | head -20 || echo "✅ No errors in filtered logs"
    else
        echo "📊 All error types:"
        echo ""
        grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true" "$LOG_FILE" | head -20 || echo "✅ No errors found"
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
        grep "$tag_pattern" "$LOG_FILE" | grep -E "duration_ms|memory_mb|performance" | head -20 || echo "No performance data found with specified tags"
    else
        echo "📊 All performance data:"
        echo ""
        grep -E "duration_ms|memory_mb|performance" "$LOG_FILE" | head -20 || echo "No performance data found"
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
        grep "$tag_pattern" "$LOG_FILE" | grep -E "DEBUG_TEST_START|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|DEBUG_TEST_COMPLETE|DEBUG_TEST_RESTART|Executing|Completed|started|initialized" | head -20 || echo "⚠️ No lifecycle events in filtered logs"
    else
        echo "📊 All lifecycle events:"
        echo ""
        grep -E "DEBUG_TEST_START|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|DEBUG_TEST_COMPLETE|DEBUG_TEST_RESTART|Executing|Completed|started|initialized" "$LOG_FILE" | head -20 || echo "⚠️ No lifecycle events found"
    fi

# ================================
# TEST LOG ANALYSIS COMMANDS - Clear naming for saved test log analysis
# ================================

# Test log analysis - Universal filtering of saved test logs  
test-logs TEST_ID *TAGS: (logs TEST_ID TAGS)

# Test log error analysis - Error-focused analysis of saved test logs
test-logs-errors TEST_ID *TAGS: (logs-errors-tagged TEST_ID TAGS)

# Test log performance analysis - Performance analysis of saved test logs
test-logs-performance TEST_ID *TAGS: (logs-performance-tagged TEST_ID TAGS)

# Test log lifecycle analysis - Lifecycle analysis of saved test logs
test-logs-lifecycle TEST_ID *TAGS: (logs-lifecycle-tagged TEST_ID TAGS)