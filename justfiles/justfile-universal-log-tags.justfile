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
# DESKTOP LOG ANALYSIS COMMANDS - Direct Godot desktop log analysis
# ================================

# Desktop log analysis with tag filtering
logs-desktop *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TAGS="{{TAGS}}"
    
    echo "🖥️  Analyzing latest Desktop logs..."
    
    # Find the most recent log file from configured locations
    LATEST_LOG=""
    for log_dir in "{{DESKTOP_LOG_DIR}}" "{{DESKTOP_LOG_DIR_ALT}}"; do
        if [ -d "$log_dir" ]; then
            LATEST_LOG=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
            if [ -n "$LATEST_LOG" ]; then
                break
            fi
        fi
    done
    
    if [ -z "$LATEST_LOG" ]; then
        echo "❌ No desktop log files found"
        echo "📁 Checked:"
        echo "   {{DESKTOP_LOG_DIR}}"
        echo "   {{DESKTOP_LOG_DIR_ALT}}"
        echo "💡 Run desktop game first: just run-desktop"
        exit 1
    fi
    
    echo "📄 Desktop log: $(basename "$LATEST_LOG")"
    echo "📁 Location: $(dirname "$LATEST_LOG")"
    
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
        grep "$tag_pattern" "$LATEST_LOG" | head -100
    else
        echo "📊 Full logs (first 50 lines):"
        echo ""
        head -50 "$LATEST_LOG"
    fi

# Desktop log error analysis
logs-desktop-errors *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TAGS="{{TAGS}}"
    
    echo "🖥️  🚨 Desktop Log Errors:"
    echo "========================="
    
    # Find the most recent log file from configured locations
    LATEST_LOG=""
    for log_dir in "{{DESKTOP_LOG_DIR}}" "{{DESKTOP_LOG_DIR_ALT}}"; do
        if [ -d "$log_dir" ]; then
            LATEST_LOG=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
            if [ -n "$LATEST_LOG" ]; then
                break
            fi
        fi
    done
    
    if [ -z "$LATEST_LOG" ]; then
        echo "❌ No desktop log files found"
        echo "📁 Checked:"
        echo "   {{DESKTOP_LOG_DIR}}"
        echo "   {{DESKTOP_LOG_DIR_ALT}}"
        exit 1
    fi
    
    echo "📄 Analyzing: $(basename "$LATEST_LOG")"
    
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
        grep "$tag_pattern" "$LATEST_LOG" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌" | head -20 || echo "✅ No errors in filtered logs"
    else
        echo "📊 All error types:"
        echo ""
        grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌" "$LATEST_LOG" | head -20 || echo "✅ No errors found"
    fi

# Desktop log performance analysis
logs-desktop-performance *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TAGS="{{TAGS}}"
    
    echo "🖥️  ⚡ Desktop Log Performance:"
    echo "============================="
    
    # Find the most recent log file from configured locations
    LATEST_LOG=""
    for log_dir in "{{DESKTOP_LOG_DIR}}" "{{DESKTOP_LOG_DIR_ALT}}"; do
        if [ -d "$log_dir" ]; then
            LATEST_LOG=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
            if [ -n "$LATEST_LOG" ]; then
                break
            fi
        fi
    done
    
    if [ -z "$LATEST_LOG" ]; then
        echo "❌ No desktop log files found"
        echo "📁 Checked:"
        echo "   {{DESKTOP_LOG_DIR}}"
        echo "   {{DESKTOP_LOG_DIR_ALT}}"
        exit 1
    fi
    
    echo "📄 Analyzing: $(basename "$LATEST_LOG")"
    
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
        grep "$tag_pattern" "$LATEST_LOG" | grep -E "execution_time_ms|duration_ms|memory_mb|performance" | head -20 || echo "No performance data found with specified tags"
    else
        echo "📊 All performance data:"
        echo ""
        grep -E "execution_time_ms|duration_ms|memory_mb|performance" "$LATEST_LOG" | head -20 || echo "No performance data found"
    fi

