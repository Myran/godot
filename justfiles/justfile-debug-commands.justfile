# ================================
# SIMPLE DEBUG COMMANDS
# ================================

# Quick overview of test execution flow
debug-quick TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        echo "🔍 Available recent test IDs:"
        # Use unified log retrieval to find recent test IDs
        LOG_FILE=$(just _get-desktop-log-file)
        if [ -n "$LOG_FILE" ]; then
            grep -o '"config_name": "[^"]*"' "$LOG_FILE" | head -3 | cut -d'"' -f4 | while read test_id; do
                echo "   📄 $test_id"
            done
        else
            echo "❌ No recent test logs found"
        fi
        # Legacy approach (fallback):
        find test_results -name "test_logs.log" -exec grep -l "DEBUG_TEST_START" {} \; 2>/dev/null | head -3 | while read f; do
            test_id=$(grep "DEBUG_TEST_START" "$f" | head -1 | grep -o '"test_id": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
            echo "   📄 $test_id (in $f)"
        done
        exit 1
    fi
    
    echo "🔍 Quick Debug Overview: $TEST_ID"
    echo "================================="
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Basic stats
    total_lines=$(wc -l < "$LOG_FILE")
    # For desktop logs, count unique process information differently
    if grep -q "I/godot" "$LOG_FILE"; then
        pids=$(grep "I/godot" "$LOG_FILE" | awk '{print $4}' | sort | uniq | wc -l)
    else
        pids=1  # Desktop logs typically have one process
    fi
    success_count=$(grep -c "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null || echo "0")
    restart_count=$(grep -c "DEBUG_TEST_RESTART_NEEDED" "$LOG_FILE" 2>/dev/null || echo "0")
    
    echo "📊 Stats: $total_lines lines, $pids PIDs, $success_count successes, $restart_count restarts"
    
    # Enhanced stats with sequence analysis  
    unique_successes=$(grep "DEBUG_TEST_SUCCESS" "$LOG_FILE" | grep -o '"sequence": [0-9]*' | sort -u | wc -l 2>/dev/null | tr -d '\n\r' || echo "0")
    if [ -n "$unique_successes" ] && [ "$unique_successes" -gt 0 ] && [ "$success_count" -gt "$unique_successes" ]; then
        echo "   📊 Actual unique successes: $unique_successes (duplicates detected)"
    fi
    
    # Memory usage analysis
    start_memory=$(grep "DEBUG_TEST_START" "$LOG_FILE" | head -1 | grep -o '"memory_mb": [0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    end_memory=$(grep "DEBUG_TEST_COMPLETE\|DEBUG_TEST_SUCCESS" "$LOG_FILE" | tail -1 | grep -o '"memory_mb": [0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    if [ "$start_memory" -gt 0 ] && [ "$end_memory" -gt 0 ]; then
        memory_diff=$((end_memory - start_memory))
        echo "   💾 Memory: ${start_memory}MB → ${end_memory}MB (${memory_diff:+${memory_diff}}MB)"
    fi
    
    # Show key markers
    echo ""
    echo "🔍 Key Events:"
    grep "RESTART.*===\|VALIDATION.*===\|COMPLETE.*===\|RECORDING MODE\|VALIDATION MODE" "$LOG_FILE" 2>/dev/null | head -5

# Show PIDs and their activity
debug-pids TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "📱 Process ID Analysis: $TEST_ID"
    echo "================================"
    
    if grep -q "I/godot" "$LOG_FILE"; then
        unique_pids=$(grep "I/godot" "$LOG_FILE" | awk '{print $4}' | sort | uniq)
    else
        unique_pids="desktop"  # Single desktop process
    fi
    
    # Handle different log formats (Android vs Desktop)
    if grep -q "I/godot" "$LOG_FILE"; then
        # Android log format
        for pid in $unique_pids; do
            line_count=$(grep "$pid" "$LOG_FILE" | wc -l)
            first_time=$(grep "$pid" "$LOG_FILE" | head -1 | awk '{print $1, $2}')
            last_time=$(grep "$pid" "$LOG_FILE" | tail -1 | awk '{print $1, $2}')
            
            echo ""
            echo "📱 $pid ($line_count lines)"
            echo "   ⏰ $first_time → $last_time"
            
            # Check for key events in this PID
            recording=$(grep "$pid" "$LOG_FILE" | grep -c "RECORDING MODE" 2>/dev/null || echo "0")
            validation=$(grep "$pid" "$LOG_FILE" | grep -c "VALIDATION MODE" 2>/dev/null || echo "0")
            success=$(grep "$pid" "$LOG_FILE" | grep -c "DEBUG_TEST_SUCCESS" 2>/dev/null || echo "0")
            
            echo "   🎯 Recording: $recording, Validation: $validation, Success: $success"
        done
    else
        # Desktop log format
        first_time=$(head -1 "$LOG_FILE" | awk '{print $1, $2}')
        last_time=$(tail -1 "$LOG_FILE" | awk '{print $1, $2}')
        
        echo ""
        echo "🖥️  Desktop Process ($total_lines lines)"
        echo "   ⏰ $first_time → $last_time"
        
        recording=$(grep -c "RECORDING MODE" "$LOG_FILE" 2>/dev/null || echo "0")
        validation=$(grep -c "VALIDATION MODE" "$LOG_FILE" 2>/dev/null || echo "0")
        success=$(grep -c "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null || echo "0")
        
        echo "   🎯 Recording: $recording, Validation: $validation, Success: $success"
    fi

# Show restart and phase transitions
debug-restarts TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "🔄 Restart Analysis: $TEST_ID"
    echo "============================="
    
    echo ""
    echo "🔍 Restart Events:"
    grep -n "DEBUG_TEST_RESTART_NEEDED\|RESTART.*===\|VALIDATION.*===\|Godot Engine" "$LOG_FILE" | head -10
    
    echo ""
    echo "📊 Determinism Flow:"
    grep -n "RECORDING MODE\|VALIDATION MODE\|expectedHash\|test PASSED\|test FAILED" "$LOG_FILE" | head -10

# Show complete test execution flow
debug-test-flow TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    # Use unified log retrieval function
    LOG_FILE=$(just _find-desktop-log-with-test-id "$TEST_ID")
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No log file found containing test ID: $TEST_ID"
        exit 1
    fi
    
    echo "🔍 Complete Test Flow: $TEST_ID"
    echo "==============================="
    
    echo ""
    echo "🎯 Test Lifecycle:"
    grep -n "DEBUG_TEST_START\|DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE\|DEBUG_TEST_COMPLETE" "$LOG_FILE" | head -20
    
    echo ""
    echo "🔄 App Lifecycle:"
    grep -n "Godot Engine\|RESTART.*===\|VALIDATION.*===" "$LOG_FILE"
    
    echo ""
    echo "⚙️ Determinism Flow:"
    grep -n "Config.*with.*Hash\|RECORDING\|VALIDATION\|expectedHash.*d751" "$LOG_FILE"

# Find logs by test ID pattern (fuzzy search)
debug-find-logs PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{PATTERN}}"
    
    echo "🔍 Finding logs matching: $PATTERN"
    echo "=================================="
    
    find test_results -name "test_logs.log" -path "*$PATTERN*" | while read log_file; do
        test_dir=$(dirname "$log_file")
        test_name=$(basename "$test_dir")
        echo "📄 $test_name"
        echo "   📁 $test_dir"
        echo "   📊 $(wc -l < "$log_file") lines"
        echo ""
    done

# Show recent test results
debug-recent:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📊 Recent Test Results"
    echo "====================="
    
    # Use unified log retrieval to find recent test results
    LOG_FILE=$(just _get-desktop-log-file)
    if [ -n "$LOG_FILE" ]; then
        echo "📄 Recent test from: $(basename "$LOG_FILE")"
        echo "📁 Location: $(dirname "$LOG_FILE")"
        echo ""
        # Extract test IDs from the log
        grep -o '"config_name": "[^"]*"' "$LOG_FILE" | head -10 | cut -d'"' -f4 | while read test_id; do
            echo "📄 $test_id"
            echo "   📊 just logs $test_id"
            echo "   📊 just logs-errors-tagged $test_id"
            echo ""
        done
    else
        echo "❌ No recent test logs found"
    fi
    # Legacy approach (fallback):
    if [ -d "test_results" ]; then
        find test_results -name "test_results.json" 2>/dev/null | head -10 | while read result_file; do
        test_dir=$(dirname "$result_file")
        test_name=$(basename "$test_dir")
        
        # Extract basic info from JSON if possible
        if [ -f "$result_file" ]; then
            echo "📄 $test_name"
            echo "   📁 $test_dir"
            
            # Try to get success/failure info
            if grep -q '"success": true' "$result_file" 2>/dev/null; then
                echo "   ✅ PASSED"
            elif grep -q '"success": false' "$result_file" 2>/dev/null; then
                echo "   ❌ FAILED"
            else
                echo "   ❓ UNKNOWN"
            fi
            echo ""
        fi
        done
    fi