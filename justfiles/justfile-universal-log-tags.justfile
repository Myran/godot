# ================================
# PLATFORM-SPECIFIC LOG COMMANDS
# ================================

# Android log display with optional tag filtering
logs-android TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
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