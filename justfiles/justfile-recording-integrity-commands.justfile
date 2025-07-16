#!/usr/bin/env just --justfile

# Recording System Integrity Commands
# Comprehensive integrity testing for recording/replay system components and workflows

# ================================
# CORE INTEGRITY TESTING
# ================================

# Run comprehensive recording system integrity validation
recording-integrity-test:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Starting comprehensive recording system integrity validation..."
    echo ""
    
    echo "1️⃣ Running recording system integrity tests..."
    just test-android-target comprehensive-recording-integrity
    
    echo ""
    echo "2️⃣ Checking for integrity issues..."
    TEST_ID=$(just logs-last | grep -E "test_[0-9]+" | head -1 | awk '{print $1}')
    
    # Check for integrity failures
    INTEGRITY_FAILURES=$(just logs-errors-tagged $TEST_ID integrity 2>/dev/null | wc -l | tr -d ' ')
    RECORDING_FAILURES=$(just logs-errors-tagged $TEST_ID recording 2>/dev/null | wc -l | tr -d ' ')
    REPLAY_FAILURES=$(just logs-errors-tagged $TEST_ID replay 2>/dev/null | wc -l | tr -d ' ')
    
    echo "📊 Integrity Test Results:"
    echo "   Integrity Failures: $INTEGRITY_FAILURES"
    echo "   Recording Failures: $RECORDING_FAILURES"
    echo "   Replay Failures: $REPLAY_FAILURES"
    echo ""
    
    # Determine overall result
    TOTAL_FAILURES=$((INTEGRITY_FAILURES + RECORDING_FAILURES + REPLAY_FAILURES))
    
    if [ "$TOTAL_FAILURES" -eq 0 ]; then
        echo "✅ Recording system integrity validation PASSED"
        echo "🎉 All components and workflows are functioning correctly"
    else
        echo "❌ Recording system integrity validation FAILED"
        echo "⚠️  $TOTAL_FAILURES integrity issues detected"
        echo ""
        echo "🔍 Quick error analysis:"
        just logs-errors-tagged $TEST_ID | head -5
        echo ""
        echo "💡 Run detailed analysis: just logs $TEST_ID integrity recording replay"
        exit 1
    fi

# Run recording system integrity test suite
recording-integrity-suite:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎯 Running recording system integrity test suite..."
    echo ""
    
    just test-android recording-system-integrity

# Quick recording system health check
recording-health-check:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏥 Recording system health check..."
    echo ""
    
    echo "1️⃣ Testing core recording components..."
    just config-restart-android 'system.recording.integrity_validation'
    
    echo ""
    echo "2️⃣ Testing replay capabilities..."  
    just config-restart-android 'system.replay.integrity_validation'
    
    echo ""
    echo "3️⃣ Checking recent test results..."
    TEST_ID=$(just logs-last | grep -E "test_[0-9]+" | head -1 | awk '{print $1}')
    
    # Check for any failures
    ERROR_COUNT=$(just logs-errors-tagged $TEST_ID 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo "✅ Recording system health check PASSED"
    else
        echo "⚠️  Recording system health check found $ERROR_COUNT issues"
        echo "🔍 Recent errors:"
        just logs-errors-tagged $TEST_ID | head -3
    fi

# ================================
# REGRESSION DETECTION
# ================================

# Detect recording system regressions
recording-regression-check:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Recording system regression detection..."
    echo ""
    
    echo "1️⃣ Checking for missing critical components..."
    
    # Check for critical recording system files
    CRITICAL_FILES=(
        "project/debug/utilities/semantic_action_mapper.gd"
        "project/debug/utilities/semantic_log_parser.gd"
        "project/debug/utilities/session_manager.gd"
        "project/debug/utilities/semantic_logger.gd"
        "project/debug/actions/system_recording_integrity_action.gd"
        "project/debug/actions/system_replay_integrity_action.gd"
    )
    
    MISSING_FILES=0
    for file in "${CRITICAL_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            echo "❌ Missing critical file: $file"
            MISSING_FILES=$((MISSING_FILES + 1))
        fi
    done
    
    if [ "$MISSING_FILES" -eq 0 ]; then
        echo "✅ All critical components present"
    else
        echo "⚠️  $MISSING_FILES critical files missing"
    fi
    
    echo ""
    echo "2️⃣ Testing core functionality..."
    just config-restart-android 'system.recording.integrity_validation'
    
    echo ""
    echo "3️⃣ Checking for functionality regressions..."
    TEST_ID=$(just logs-last | grep -E "test_[0-9]+" | head -1 | awk '{print $1}')
    
    # Look for regression indicators
    REGRESSION_INDICATORS=$(just logs $TEST_ID | grep -i "missing\|broken\|failed\|error" | wc -l | tr -d ' ')
    
    if [ "$REGRESSION_INDICATORS" -eq 0 ]; then
        echo "✅ No regressions detected"
        echo "🎉 Recording system integrity maintained"
    else
        echo "⚠️  Potential regressions detected ($REGRESSION_INDICATORS indicators)"
        echo "🔍 Regression analysis needed:"
        echo "   just logs $TEST_ID | grep -i 'missing\\|broken\\|failed'"
    fi

# ================================
# COMPONENT VALIDATION
# ================================

# Validate semantic action mapping system
validate-semantic-mapping:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🗺️  Validating semantic action mapping system..."
    echo ""
    
    # Test semantic action mapper through integrity validation
    just config-restart-android 'system.recording.integrity_validation'
    
    TEST_ID=$(just logs-last | grep -E "test_[0-9]+" | head -1 | awk '{print $1}')
    
    # Check mapping validation results
    MAPPING_RESULTS=$(just logs $TEST_ID | grep -i "mapping\|semantic.*action" | wc -l | tr -d ' ')
    
    if [ "$MAPPING_RESULTS" -gt 0 ]; then
        echo "✅ Semantic action mapping validation completed"
        echo "📊 Found $MAPPING_RESULTS mapping-related log entries"
        echo ""
        echo "🔍 Mapping validation summary:"
        just logs $TEST_ID | grep -i "mapping.*validation\|semantic.*action.*validation" | head -3
    else
        echo "⚠️  No mapping validation results found"
        echo "💡 Check: just logs $TEST_ID recording semantic"
    fi


# ================================
# PRE-COMMIT INTEGRATION
# ================================

# Recording system pre-commit validation
recording-pre-commit:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🚀 Recording system pre-commit validation..."
    echo ""
    
    echo "1️⃣ Quick health check..."
    just recording-health-check
    
    echo ""
    echo "2️⃣ Regression detection..."
    just recording-regression-check
    
    echo ""
    echo "3️⃣ Component validation..."
    echo "   Testing semantic mapping..."
    just validate-semantic-mapping >/dev/null 2>&1 || echo "⚠️  Semantic mapping issues detected"
    
    echo "   Testing replay generation..."
    echo "⚠️  Replay generation validation removed (legacy)"
    
    echo ""
    echo "✅ Recording system pre-commit validation complete"

# ================================
# ANALYSIS AND DEBUGGING
# ================================

# Analyze recording system performance
recording-performance-analysis TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    echo "📊 Recording system performance analysis for: $TEST_ID"
    echo ""
    
    echo "🔍 Performance metrics:"
    just logs-performance-tagged $TEST_ID recording
    
    echo ""
    echo "🔍 Integrity validation metrics:"
    just logs-performance-tagged $TEST_ID integrity
    
    echo ""
    echo "🔍 Component timing analysis:"
    just logs $TEST_ID | grep -i "semantic.*action\|mapping\|generation" | grep -i "ms\|time\|duration" | head -5


# ================================
# UTILITY COMMANDS
# ================================

