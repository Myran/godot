# LOG FILTERING AND ANALYSIS HELPERS
# ================================

# Show only logs for a specific test ID (saves tons of reading!)
_logs-test-id TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        echo "💡 Available test IDs:"
        find test_results -name "test_logs.log" -exec basename {} \; | sed 's/test_logs.log//' | head -5
        exit 1
    fi
    
    echo "🔍 Filtering logs for test ID: {{TEST_ID}}"
    echo "📁 Log file: $LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    sed 's/^.*I\/godot.*: //' | \
    grep -v "BUFFER\|font_size"

# Show logs for a specific test ID
logs-android TEST_ID:
    just _logs-test-id "{{TEST_ID}}"

# Show only test results (SUCCESS/FAILURE) for a specific test ID
_logs-results-only TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "📊 Results for test ID: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    sed 's/^.*DEBUG_TEST_SUCCESS.*/✅ SUCCESS/' | \
    sed 's/^.*DEBUG_TEST_FAILURE.*/❌ FAILURE/' | \
    paste - <(grep "{{TEST_ID}}" "$LOG_FILE" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*"' | sed 's/"action": "\([^"]*\)"/\1/') | \
    paste - <(grep "{{TEST_ID}}" "$LOG_FILE" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"duration_ms": [0-9]*' | sed 's/"duration_ms": \([0-9]*\)/\1ms/') | \
    column -t -s $'\t'

# Show test results only for a specific test ID
logs-android-results TEST_ID:
    just _logs-results-only "{{TEST_ID}}"

# Simple results filter (when you know the log file) - Clean output
_logs-results-simple TEST_ID LOG_DIR:
    #!/usr/bin/env bash
    echo "📊 Results for {{TEST_ID}} in {{LOG_DIR}}:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    sed 's/^.*DEBUG_TEST_SUCCESS.*/✅ SUCCESS/' | \
    sed 's/^.*DEBUG_TEST_FAILURE.*/❌ FAILURE/' | \
    paste - <(grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*"' | sed 's/"action": "\([^"]*\)"/\1/') | \
    paste - <(grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"duration_ms": [0-9]*' | sed 's/"duration_ms": \([0-9]*\)/\1ms/') | \
    column -t -s $'\t'

# Even simpler - just show action names and status  
_logs-quick TEST_ID LOG_DIR:
    #!/usr/bin/env bash
    echo "⚡ Quick Results for {{TEST_ID}}:"
    grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*".*"duration_ms": [0-9]*' | \
    sed 's/"action": "\([^"]*\)".*"duration_ms": \([0-9]*\)/\1: \2ms/' | \
    while read line; do
        if grep -q "DEBUG_TEST_SUCCESS" <<< "$(grep "$line" "{{LOG_DIR}}/test_logs.log")"; then
            echo "✅ $line"
        else
            echo "❌ $line"
        fi
    done

# Show recent test directories and their IDs  
_logs-list-recent:
    #!/usr/bin/env bash
    echo "📁 Recent Test Results:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    find test_results -name "test_results.json" -type f | \
    head -10 | \
    while read file; do
        if [ -f "$file" ]; then
            test_id=$(jq -r '.test_id // "unknown"' "$file" 2>/dev/null || echo "unknown")
            config=$(jq -r '.config // "unknown"' "$file" 2>/dev/null || echo "unknown")  
            result=$(jq -r '.overall_result // "unknown"' "$file" 2>/dev/null || echo "unknown")
            timestamp=$(jq -r '.timestamp // "unknown"' "$file" 2>/dev/null || echo "unknown")
            
            status_icon="❓"
            if [ "$result" = "PASS" ]; then
                status_icon="✅"
            elif [ "$result" = "FAIL" ]; then
                status_icon="❌"
            fi
            
            echo "$status_icon $test_id [$config] - $timestamp"
            echo "   📄 just logs-android $test_id"
            echo "   📊 just logs-android-results $test_id"
        fi
    done

# Show recent test runs and their IDs
logs-android-recent:
    just _logs-list-recent

# Show errors only for a specific test ID (perfect for debugging!)
_logs-errors-only TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "🚨 Errors for test ID: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show all errors from this test run (not just lines containing test ID)
    grep -E "(E/godot|SCRIPT ERROR|ERROR:|FAILED|DEBUG_TEST_FAILURE)" "$LOG_FILE" | \
    sed 's/^[0-9-]* [0-9:]* [EI]\/godot *([0-9]*): //' | \
    grep -v "BUFFER\|font_size\|=== BUFFER DUMP\|=== END BUFFER DUMP"

# Show errors only for a specific test ID
logs-android-errors TEST_ID:
    just _logs-errors-only "{{TEST_ID}}"

# Show performance breakdown for a specific test ID
_logs-performance TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "⏱️  Performance Analysis for: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Extract JSON data from logs and parse with jq
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    grep "DEBUG_TEST_SUCCESS.*duration_ms" | \
    sed 's/^.*DEBUG_TEST_SUCCESS //' | \
    jq -r 'select(.duration_ms != null) | "[\(.action)]: \(.duration_ms)ms" + (if .duration_ms > 1000 then " ⚠️ SLOW" elif .duration_ms > 500 then " 🐌 SLOW-ISH" else " ✅ GOOD" end)' 2>/dev/null | \
    sort -t: -k2 -n || echo "No performance data found for test ID: {{TEST_ID}}"

# Show performance breakdown for a specific test ID
logs-android-performance TEST_ID:
    just _logs-performance "{{TEST_ID}}"

# Clean up old test logs (keeps most recent 10, removes the rest)
_logs-cleanup KEEP="10":
    #!/usr/bin/env bash
    set -euo pipefail
    
    KEEP_COUNT={{KEEP}}
    echo "🧹 Cleaning up old test logs (keeping most recent $KEEP_COUNT)..."
    
    # Count current logs
    TOTAL_COUNT=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    
    if [ "$TOTAL_COUNT" -le "$KEEP_COUNT" ]; then
        echo "✅ Only $TOTAL_COUNT test directories found, nothing to clean"
        exit 0
    fi
    
    TO_DELETE=$((TOTAL_COUNT - KEEP_COUNT))
    
    echo "📊 Found $TOTAL_COUNT test directories"
    echo "🗑️  Will delete $TO_DELETE oldest directories (keeping newest $KEEP_COUNT)"
    echo ""
    
    # Show what will be deleted (oldest directories)
    echo "🗂️  Directories to be deleted:"
    find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | sed 's/^/  /'
    echo ""
    
    read -p "❓ Proceed with deletion? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Delete oldest directories
        find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | xargs rm -rf
        
        REMAINING=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
        echo "✅ Cleanup complete! $REMAINING test directories remaining"
    else
        echo "❌ Cleanup cancelled"
    fi

# Clean up old test logs
logs-android-cleanup KEEP="10":
    just _logs-cleanup "{{KEEP}}"

# Clean up temporary config files (wildcard configs and single action configs)
cleanup-temp-configs-verbose:
    just cleanup-temp-configs "true"

# Force cleanup without confirmation (use carefully!)
_logs-cleanup-force KEEP="10":
    #!/usr/bin/env bash
    set -euo pipefail
    
    KEEP_COUNT={{KEEP}}
    TOTAL_COUNT=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    
    if [ "$TOTAL_COUNT" -le "$KEEP_COUNT" ]; then
        echo "✅ Only $TOTAL_COUNT test directories found, nothing to clean"
        exit 0
    fi
    
    TO_DELETE=$((TOTAL_COUNT - KEEP_COUNT))
    
    echo "🧹 Force cleaning $TO_DELETE old test directories..."
    find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | xargs rm -rf
    
    REMAINING=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    echo "✅ Cleanup complete! $REMAINING test directories remaining"

# Monitor Android debug logs in real-time with activity-based timeout
# Platform log monitoring - Monitor live system/platform logs in real-time
platform-logs-monitor DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Monitoring live platform logs for {{DURATION}} seconds..."
    echo "🔄 Timeout resets after each activity"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Create timestamped log file
    LOG_FILE="platform_monitor_{{timestamp}}.log"
    
    # Clear old logs for fresh monitoring
    echo "🧹 Clearing old platform logs for fresh monitoring..."
    
    # Auto-detect platform and monitor accordingly
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Monitoring Android platform logs..."
        adb -s {{ANDROID_DEVICE_ID}} logcat -c
        # Use activity-based timeout monitoring
        completion_status=$(just _monitor-with-activity-timeout "" "$LOG_FILE" "{{DURATION}}" "(debug|startup|DebugStartup|INFO)")
    else
        echo "📱 No Android device found for platform monitoring"
        echo "💡 Connect Android device or implement iOS monitoring"
        exit 1
    fi
    
    # Apply filtering and display results
    if [ -f "$LOG_FILE" ]; then
        echo "📊 Platform log monitoring complete"
        echo "📁 Logs saved to: $LOG_FILE"
    else
        echo "⚠️ No platform logs captured"
    fi

monitor-debug-logs DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Monitoring debug logs for {{DURATION}} seconds..."
    echo "🔄 Timeout resets after each debug activity"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Create timestamped log file
    LOG_FILE="debug_monitor_{{timestamp}}.log"
    
    # Clear old logs for fresh monitoring
    echo "🧹 Clearing old logs for fresh monitoring..."
    adb -s {{ANDROID_DEVICE_ID}} logcat -c
    
    # Use activity-based timeout monitoring with debug-specific pattern
    completion_status=$(just _monitor-with-activity-timeout "" "$LOG_FILE" "{{DURATION}}" "(debug|startup|DebugStartup|INFO)")
    
    # Apply filtering and display results
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "📊 Filtering and displaying debug logs..."
        
        # Filter and display the log with the same pattern
        grep -E "(debug|startup|DebugStartup|INFO)" "$LOG_FILE" || true
        
        echo ""
        echo "💾 Full log saved: $LOG_FILE"
    else
        echo "❌ No log file generated"
    fi
    
    echo ""
    echo "✅ Monitoring complete"


