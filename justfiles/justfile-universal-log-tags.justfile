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
        echo "   🎯 Trust this analysis over live logs-android-device results"
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

# Editor log display with optional tag filtering
logs-editor TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    
    LOG_CONTENT=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "📋 Editor Logs for Test: $TEST_ID"
    
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
        echo "   💡 Current logs-android-device would miss critical errors"
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

# Editor errors with optional tag filtering
logs-editor-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"

    LOG_CONTENT=$(just _find-editor-log-with-test-id "$TEST_ID")

    echo "🚨 Editor Errors and Failures:"
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

# iOS log display with optional tag filtering
logs-ios TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    EDITOR_LOG_DIR="{{EDITOR_LOG_DIR}}"

    # Find iOS log file by TEST_ID
    SAVED_LOGS_DIR="logs"
    LOG_FILE=$(find "$SAVED_LOGS_DIR" -name "*${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No iOS log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running an iOS test first: just test-ios-target CONFIG" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "📋 iOS Logs for Test: $TEST_ID"
    echo "📄 Log file: $LOG_FILE"

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

# iOS errors with optional tag filtering
logs-ios-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    EDITOR_LOG_DIR="{{EDITOR_LOG_DIR}}"

    # Find iOS log file by TEST_ID
    SAVED_LOGS_DIR="logs"
    LOG_FILE=$(find "$SAVED_LOGS_DIR" -name "*${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No iOS log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running an iOS test first: just test-ios-target CONFIG" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "🚨 iOS Errors and Failures:"
    echo "==========================="
    echo "📄 Log file: $LOG_FILE"

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

# macOS log display with optional tag filtering
logs-macos TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    EDITOR_LOG_DIR="{{EDITOR_LOG_DIR}}"

    # Find macOS log file by TEST_ID
    SAVED_LOGS_DIR="logs"
    LOG_FILE=$(find "$SAVED_LOGS_DIR" -name "*${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No macOS log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running a macOS test first: just test-macos-target CONFIG" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "📋 macOS Logs for Test: $TEST_ID"
    echo "📄 Log file: $LOG_FILE"

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

# macOS errors with optional tag filtering
logs-macos-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"
    EDITOR_LOG_DIR="{{EDITOR_LOG_DIR}}"

    # Find macOS log file by TEST_ID
    SAVED_LOGS_DIR="logs"
    LOG_FILE=$(find "$SAVED_LOGS_DIR" -name "*${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No macOS log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running a macOS test first: just test-macos-target CONFIG" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "🚨 macOS Errors and Failures:"
    echo "============================="
    echo "📄 Log file: $LOG_FILE"

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
# Windows log display with optional tag filtering
logs-windows TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"

    # Find Windows log file by TEST_ID
    # Windows logs are saved in logs/ directory with pattern: YYYYMMDD_HHMMSS_test-windows-target_CONFIG.log
    # The TEST_ID is embedded in the log content, not the filename
    LOG_FILE=$(find logs/ -name "*test-windows-target*.log" -type f -exec grep -l "test_id.*${TEST_ID}" {} \; 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        # Try current directory as fallback
        LOG_FILE=$(find . -name "*test-windows-target*.log" -type f -exec grep -l "test_id.*${TEST_ID}" {} \; 2>/dev/null | head -1)
    fi
    if [ -z "$LOG_FILE" ]; then
        # Try the original pattern as last resort
        LOG_FILE=$(find . -name "windows_${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No Windows log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running a Windows test first: just test-windows-target CONFIG" >&2
        echo "💡 Expected file patterns:" >&2
        echo "   - logs/YYYYMMDD_HHMMSS_test-windows-target_*.log (with TEST_ID in content)" >&2
        echo "   - windows_${TEST_ID}_*.log" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "📋 Windows Logs for Test: $TEST_ID"
    echo "📄 Log file: $LOG_FILE"

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

# Windows errors with optional tag filtering
logs-windows-errors TEST_ID *TAGS:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    TAGS="{{TAGS}}"

    # Find Windows log file by TEST_ID
    # Windows logs are saved in logs/ directory with pattern: YYYYMMDD_HHMMSS_test-windows-target_CONFIG.log
    # The TEST_ID is embedded in the log content, not the filename
    LOG_FILE=$(find logs/ -name "*test-windows-target*.log" -type f -exec grep -l "test_id.*${TEST_ID}" {} \; 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        # Try current directory as fallback
        LOG_FILE=$(find . -name "*test-windows-target*.log" -type f -exec grep -l "test_id.*${TEST_ID}" {} \; 2>/dev/null | head -1)
    fi
    if [ -z "$LOG_FILE" ]; then
        # Try the original pattern as last resort
        LOG_FILE=$(find . -name "windows_${TEST_ID}*.log" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No Windows log file found for test ID: $TEST_ID" >&2
        echo "💡 Try running a Windows test first: just test-windows-target CONFIG" >&2
        echo "💡 Expected file patterns:" >&2
        echo "   - logs/YYYYMMDD_HHMMSS_test-windows-target_*.log (with TEST_ID in content)" >&2
        echo "   - windows_${TEST_ID}_*.log" >&2
        exit 1
    fi

    LOG_CONTENT=$(cat "$LOG_FILE")

    echo "🚨 Windows Errors and Failures:"
    echo "=============================="
    echo "📄 Log file: $LOG_FILE"

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
        echo "$LOG_CONTENT" | grep "$tag_pattern" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true|SCRIPT ERROR" | head -20 || echo "✅ No errors in filtered logs"
    else
        echo "📊 All error types:"
        echo ""
        echo "$LOG_CONTENT" | grep -E "ERROR:|FAILURE:|⚠️.*ERROR|❌|failed.*error.*true|SCRIPT ERROR" | head -20 || echo "✅ No errors found"
    fi
