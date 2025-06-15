# ================================
# ENHANCED LOG ANALYSIS FUNCTIONS
# ================================

# Analyze phase-specific logs
logs-phase-analysis TEST_DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_DIR="{{TEST_DIR}}"
    
    echo "🔍 Phase-Specific Log Analysis"
    echo "=============================="
    
    if [ -f "$TEST_DIR/phase1_recording.log" ]; then
        echo ""
        echo "📊 PHASE 1 - RECORDING:"
        echo "   Lines: $(wc -l < "$TEST_DIR/phase1_recording.log")"
        echo "   PIDs: $(grep "I/godot" "$TEST_DIR/phase1_recording.log" | awk '{print $4}' | sort | uniq | tr '\n' ' ')"
        echo "   Recording mode: $(grep -c "RECORDING MODE" "$TEST_DIR/phase1_recording.log" 2>/dev/null || echo "0")"
        echo "   Hash saved: $(grep -c "Config updated with expectedHash" "$TEST_DIR/phase1_recording.log" 2>/dev/null || echo "0")"
        echo "   Restart signals: $(grep -c "DEBUG_TEST_RESTART_NEEDED" "$TEST_DIR/phase1_recording.log" 2>/dev/null || echo "0")"
    else
        echo "⚠️  Recording phase log not found"
    fi
    
    if [ -f "$TEST_DIR/phase2_validation.log" ]; then
        echo ""
        echo "📊 PHASE 2 - VALIDATION:"
        echo "   Lines: $(wc -l < "$TEST_DIR/phase2_validation.log")"
        echo "   PIDs: $(grep "I/godot" "$TEST_DIR/phase2_validation.log" | awk '{print $4}' | sort | uniq | tr '\n' ' ')"
        echo "   Validation mode: $(grep -c "VALIDATION MODE" "$TEST_DIR/phase2_validation.log" 2>/dev/null || echo "0")"
        echo "   Hash matches: $(grep -c "match.*true" "$TEST_DIR/phase2_validation.log" 2>/dev/null || echo "0")"
        echo "   Tests passed: $(grep -c "test PASSED" "$TEST_DIR/phase2_validation.log" 2>/dev/null || echo "0")"
    else
        echo "⚠️  Validation phase log not found"
    fi

# Analyze process IDs and restart behavior
logs-pid-analysis TEST_DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_DIR="{{TEST_DIR}}"
    LOG_FILE="$TEST_DIR/test_logs.log"
    
    echo "🔍 Process ID Analysis"
    echo "====================="
    
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "📊 Process Information:"
        unique_pids=$(grep "I/godot" "$LOG_FILE" | awk '{print $4}' | sort | uniq)
        echo "   Unique PIDs found: $(echo "$unique_pids" | wc -l)"
        
        for pid in $unique_pids; do
            echo ""
            echo "   📱 $pid:"
            line_count=$(grep "$pid" "$LOG_FILE" | wc -l)
            echo "      Log entries: $line_count"
            
            first_entry=$(grep "$pid" "$LOG_FILE" | head -1 | awk '{print $1, $2}')
            last_entry=$(grep "$pid" "$LOG_FILE" | tail -1 | awk '{print $1, $2}')
            echo "      First log: $first_entry"
            echo "      Last log: $last_entry"
            
            recording_count=$(grep "$pid" "$LOG_FILE" | grep -c "RECORDING MODE" 2>/dev/null || echo "0")
            validation_count=$(grep "$pid" "$LOG_FILE" | grep -c "VALIDATION MODE" 2>/dev/null || echo "0")
            echo "      Recording: $recording_count, Validation: $validation_count"
        done
        
        echo ""
        echo "📊 Phase Boundaries:"
        grep "PHASE.*====" "$LOG_FILE" 2>/dev/null || echo "   No phase markers found"
    else
        echo "❌ Log file not found: $LOG_FILE"
    fi

# Analyze restart sequence and timing
logs-restart-analysis TEST_DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_DIR="{{TEST_DIR}}"
    LOG_FILE="$TEST_DIR/test_logs.log"
    
    echo "🔍 Restart Sequence Analysis"
    echo "============================"
    
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "📊 Restart Events:"
        restart_signals=$(grep -c "DEBUG_TEST_RESTART_NEEDED" "$LOG_FILE" 2>/dev/null || echo "0")
        echo "   Restart signals: $restart_signals"
        
        if [ "$restart_signals" -gt 0 ]; then
            echo ""
            echo "📊 Restart Timeline:"
            grep -n "DEBUG_TEST_RESTART_NEEDED\|PHASE.*====\|Godot Engine" "$LOG_FILE" | head -10
        fi
        
        echo ""
        echo "📊 Config Analysis:"
        echo "   expectedHash found: $(grep -c "expectedHash.*d751" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "   Recording mode: $(grep -c "Set recording mode" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "   Validation mode: $(grep -c "Set validation mode" "$LOG_FILE" 2>/dev/null || echo "0")"
        
        echo ""
        echo "📊 Success Analysis:"
        echo "   Actions successful: $(grep -c "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null || echo "0")"
        echo "   Tests passed: $(grep -c "test PASSED" "$LOG_FILE" 2>/dev/null || echo "0")"
    else
        echo "❌ Log file not found: $LOG_FILE"
    fi