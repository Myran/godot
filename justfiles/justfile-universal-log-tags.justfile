# ================================
# PLATFORM-SPECIFIC LOG COMMANDS
# ================================

# Android log display with optional tag filtering
logs-android TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"

    # 🚨 CRITICAL: Add buffer awareness for Android log analysis
    echo "🔍 Analyzing Android logs with buffer awareness..."
    echo "==============================================="

    # Check current buffer health to provide context
    BUFFER_HEALTH_OUTPUT=$(just logs-android-health 2>/dev/null || echo "Health check failed")

    if echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CRITICAL"; then
        echo "⚠️  🚨 CURRENT BUFFER IS CRITICAL - Live data unreliable!"
        echo "   💡 These saved logs are MORE RELIABLE than current live buffer"
        echo "   🎯 Trust this analysis over live android-logs-search results"
        echo ""
    elif echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CAUTION"; then
        echo "⚠️  Current buffer usage is high"
        echo "   💡 These saved logs provide reliable historical data"
        echo ""
    else
        echo "✅ Current buffer is healthy - live and saved data both reliable"
        echo ""
    fi

    LOG_CONTENT=$(just _find-android-log-with-test-id "$TEST_ID")

    echo "📋 Android Logs for Test: $TEST_ID"
    
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

# Desktop log display with optional tag filtering
logs-desktop TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    LOG_CONTENT=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "📋 Desktop Logs for Test: $TEST_ID"
    
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

# Android errors with optional tag filtering
logs-android-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"

    # 🚨 CRITICAL: Buffer-aware error analysis for Android
    echo "🚨 Android Error Analysis with Buffer Context"
    echo "============================================="

    # Check current buffer health to provide reliability context
    BUFFER_HEALTH_OUTPUT=$(just logs-android-health 2>/dev/null || echo "Health check failed")

    if echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CRITICAL"; then
        echo "⚠️  🚨 LIVE BUFFER CRITICAL - This saved log analysis is ESSENTIAL!"
        echo "   💡 Current android-logs-search would miss critical errors"
        echo "   🎯 Trust this analysis - it contains the complete error record"
        echo "   📁 These errors are reliably captured from test execution"
        echo ""
    elif echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CAUTION"; then
        echo "⚠️  Current buffer usage is high"
        echo "   💡 This saved log analysis is more reliable than live buffer"
        echo "   🎯 Cross-validation with live buffer recommended for critical issues"
        echo ""
    else
        echo "✅ Buffer is healthy - live and saved error analysis both reliable"
        echo ""
    fi

    LOG_CONTENT=$(just _find-android-log-with-test-id "$TEST_ID")

    echo "🚨 Android Errors and Failures:"
    echo "==============================="
    
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

# Desktop errors with optional tag filtering
logs-desktop-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    LOG_CONTENT=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    echo "🚨 Desktop Errors and Failures:"
    echo "==============================="
    
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