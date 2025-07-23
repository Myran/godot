# ================================
# UNIVERSAL TAG-FILTERED LOG COMMANDS
# ================================

# Universal log display with optional tag filtering
logs TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Use unified log retrieval function with auto-detection
    LOG_CONTENT=$(just _auto-detect-and-get-log "$TEST_ID")
    
    echo "📋 Logs for Test: $TEST_ID"
    echo "🔍 Platform auto-detected from test ID"
    
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
        echo "$LOG_CONTENT" | grep "$tag_pattern" | head -100
    else
        echo "📊 Full logs (first 50 lines):"
        echo ""
        echo "$LOG_CONTENT" | head -50
    fi

# Errors with optional tag filtering
logs-errors-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Use unified log retrieval function with auto-detection
    LOG_CONTENT=$(just _auto-detect-and-get-log "$TEST_ID")
    
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
        
        # Filter by tags first, then by errors (excludes test successes)
        echo "$LOG_CONTENT" | grep "$tag_pattern" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true" | head -20 || echo "✅ No errors in filtered logs"
    else
        echo "📊 All error types:"
        echo ""
        echo "$LOG_CONTENT" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true" | head -20 || echo "✅ No errors found"
    fi

# Performance with optional tag filtering  
logs-performance-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Use unified log retrieval function with auto-detection
    LOG_CONTENT=$(just _auto-detect-and-get-log "$TEST_ID")
    
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
        echo "$LOG_CONTENT" | grep "$tag_pattern" | grep -E "duration_ms|memory_mb|performance" | head -20 || echo "No performance data found with specified tags"
    else
        echo "📊 All performance data:"
        echo ""
        echo "$LOG_CONTENT" | grep -E "duration_ms|memory_mb|performance" | head -20 || echo "No performance data found"
    fi

# Lifecycle with optional tag filtering
logs-lifecycle-tagged TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    # Use unified log retrieval function with auto-detection
    LOG_CONTENT=$(just _auto-detect-and-get-log "$TEST_ID")
    
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
        
        # Filter by tags first, then by lifecycle events (searches both ERROR and INFO levels)
        echo "$LOG_CONTENT" | grep "$tag_pattern" | grep -E "DEBUG_TEST_START|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|DEBUG_TEST_COMPLETE|DEBUG_TEST_RESTART|Executing|Completed|started|initialized" | head -20 || echo "⚠️ No lifecycle events in filtered logs"
    else
        echo "📊 All lifecycle events:"
        echo ""
        echo "$LOG_CONTENT" | grep -E "DEBUG_TEST_START|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|DEBUG_TEST_COMPLETE|DEBUG_TEST_RESTART|Executing|Completed|started|initialized" | head -20 || echo "⚠️ No lifecycle events found"
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
    
    # Use unified log retrieval function
    LATEST_LOG=$(just _get-desktop-log-file)
    
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
    
    # Use unified log retrieval function
    LATEST_LOG=$(just _get-desktop-log-file)
    
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
    
    # Use unified log retrieval function
    LATEST_LOG=$(just _get-desktop-log-file)
    
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

