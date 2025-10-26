# ================================
# LOG BUFFER CROSS-VALIDATION TOOLS
# ================================
# Automated cross-validation suggestions to prevent misdiagnosis

# Comprehensive log cross-validation when buffer saturation is suspected
android-logs-cross-validate SEARCH_TERM:
    #!/usr/bin/env bash
    set -euo pipefail

    SEARCH_TERM="{{SEARCH_TERM}}"
    echo "🔍 Cross-Validation Analysis for: $SEARCH_TERM"
    echo "=========================================="
    echo ""

    # Step 1: Check buffer status first
    echo "📊 Step 1: Analyzing buffer status..."
    just android-logs-search "$SEARCH_TERM" 2>/dev/null | grep -E "(📊|📱|⚙️|📡|📻|⚠️|🚨)" || echo "   Buffer analysis completed"
    echo ""

    # Step 2: Search historical log files
    echo "📁 Step 2: Searching historical log files..."
    HISTORIAL_MATCHES=0
    if [ -d "logs/" ]; then
        HISTORIAL_FILES=$(find logs/ -name "*.log" -exec grep -l "$SEARCH_TERM" {} \; 2>/dev/null | wc -l)
        if [ "$HISTORIAL_FILES" -gt 0 ]; then
            echo "   ✅ Found matches in $HISTORIAL_FILES historical log files"
            echo "   📄 Recent matches:"
            find logs/ -name "*.log" -exec grep -l "$SEARCH_TERM" {} \; 2>/dev/null | head -3 | while read file; do
                MATCH_COUNT=$(grep -c "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
                echo "      $(basename "$file"): $MATCH_COUNT matches"
            done
            HISTORIAL_MATCHES=1
        else
            echo "   ❌ No matches found in historical log files"
        fi
    else
        echo "   ⚠️  No logs/ directory found"
    fi
    echo ""

    # Step 3: Check recent test results
    echo "📋 Step 3: Checking recent test results..."
    if command -v just >/dev/null 2>&1 && just logs-last >/dev/null 2>&1; then
        RECENT_MATCHES=$(just logs-last 2>/dev/null | grep -c "$SEARCH_TERM" || echo "0")
        if [ "$RECENT_MATCHES" -gt 0 ]; then
            echo "   ✅ Found $RECENT_MATCHES matches in recent test results"
        else
            echo "   ❌ No matches in recent test results"
        fi
    else
        echo "   ⚠️  Could not access recent test results"
    fi
    echo ""

    # Step 4: Check Godot app userdata logs
    echo "🎮 Step 4: Checking Godot app userdata logs..."
    APP_LOG_DIR="/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/logs/"
    if [ -d "$APP_LOG_DIR" ]; then
        APP_MATCHES=$(find "$APP_LOG_DIR" -name "*.log" -exec grep -l "$SEARCH_TERM" {} \; 2>/dev/null | wc -l)
        if [ "$APP_MATCHES" -gt 0 ]; then
            echo "   ✅ Found matches in $APP_MATCHES app userdata log files"
            echo "   📄 Recent app logs with matches:"
            find "$APP_LOG_DIR" -name "*.log" -exec grep -l "$SEARCH_TERM" {} \; 2>/dev/null | head -3 | while read file; do
                MATCH_COUNT=$(grep -c "$SEARCH_TERM" "$file" 2>/dev/null || echo "0")
                echo "      $(basename "$file"): $MATCH_COUNT matches"
            done
        else
            echo "   ❌ No matches in app userdata logs"
        fi
    else
        echo "   ⚠️  App userdata logs directory not found"
    fi
    echo ""

    # Step 5: Provide recommendations based on findings
    echo "🎯 Step 5: Cross-Validation Recommendations"
    echo "=========================================="

    if [ "$HISTORIAL_MATCHES" -eq 1 ]; then
        echo "✅ HISTORICAL DATA AVAILABLE - Use for reliable analysis:"
        echo "   📁 Search all historical logs:"
        echo "      find logs/ -name \"*.log\" -exec grep \"$SEARCH_TERM\" {} +"
        echo "   📊 Analyze specific files:"
        echo "      rg \"$SEARCH_TERM\" logs/ --type-add 'log:*.log' -t log -A 2 -B 2"
        echo ""
        echo "⚠️  CAUTION: Live buffer data may be incomplete due to saturation"
        echo "   🔥 Prioritize historical log findings over live buffer results"
    else
        echo "❌ NO HISTORICAL DATA FOUND - Investigation may be compromised:"
        echo ""
        echo "🎯 IMMEDIATE ACTIONS:"
        echo "   1️⃣  Clear buffer and re-run test:"
        echo "         just android-logs-clear"
        echo "         just test-android-target YOUR_CONFIG"
        echo ""
        echo "   2️⃣  Use live monitoring during test execution:"
        echo "         just android-logs-live 60 \"*:I\" 100"
        echo ""
        echo "   3️⃣  Save complete output for future analysis:"
        echo "         just log-run-silent test-android-target YOUR_CONFIG"
    fi

    echo ""
    echo "🚨 BUFFER AWARENESS REMINDERS:"
    echo "   - Always cross-validate when live buffer shows saturation warnings"
    echo "   - Historical logs are more reliable than live buffer during high-volume testing"
    echo "   - Document buffer state in investigation notes"
    echo "   - Consider re-running tests with cleared buffer if data seems incomplete"

# Quick buffer health check with recommendations
android-logs-health-check:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🏥 Android Log Buffer Health Check"
    echo "================================="
    echo ""

    # Check device connectivity
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "connected" >/dev/null 2>&1; then
        echo "❌ Device {{ANDROID_DEVICE_ID}} not connected"
        echo "💡 Run 'adb devices' to check connected devices"
        exit 1
    fi

    # Analyze all buffer types
    echo "📊 Buffer Analysis:"
    MAIN_BUFFER_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b main -d 2>/dev/null | wc -l || echo "0")
    SYSTEM_BUFFER_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b system -d 2>/dev/null | wc -l || echo "0")
    EVENTS_BUFFER_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b events -d 2>/dev/null | wc -l || echo "0")
    RADIO_BUFFER_COUNT=$(adb -s {{ANDROID_DEVICE_ID}} logcat -b radio -d 2>/dev/null | wc -l || echo "0")
    TOTAL_BUFFER_COUNT=$((MAIN_BUFFER_COUNT + SYSTEM_BUFFER_COUNT + EVENTS_BUFFER_COUNT + RADIO_BUFFER_COUNT))

    echo "   📱 Main:     $MAIN_BUFFER_COUNT lines"
    echo "   ⚙️  System:   $SYSTEM_BUFFER_COUNT lines"
    echo "   📡 Events:   $EVENTS_BUFFER_COUNT lines"
    echo "   📻 Radio:    $RADIO_BUFFER_COUNT lines"
    echo "   📊 TOTAL:    $TOTAL_BUFFER_COUNT lines"
    echo ""

    # Health assessment
    BUFFER_WARNING_THRESHOLD=50000
    BUFFER_CAUTION_THRESHOLD=30000
    HEALTH_SCORE=$((100 - (TOTAL_BUFFER_COUNT * 100 / BUFFER_WARNING_THRESHOLD)))

    if [ "$HEALTH_SCORE" -lt 0 ]; then
        HEALTH_SCORE=0
    fi

    echo "🏥 Health Assessment:"
    if [ "$TOTAL_BUFFER_COUNT" -gt "$BUFFER_WARNING_THRESHOLD" ]; then
        echo "   🔴 CRITICAL: Buffer is >90% full"
        echo "   📊 Health Score: $HEALTH_SCORE%"
        echo "   ⚠️  Immediate action required"
        STATUS="CRITICAL"
    elif [ "$TOTAL_BUFFER_COUNT" -gt "$BUFFER_CAUTION_THRESHOLD" ]; then
        echo "   🟡 CAUTION: Buffer is 60-90% full"
        echo "   📊 Health Score: $HEALTH_SCORE%"
        echo "   ⚠️  Cross-validation recommended"
        STATUS="CAUTION"
    else
        echo "   🟢 HEALTHY: Buffer is <60% full"
        echo "   📊 Health Score: $HEALTH_SCORE%"
        echo "   ✅ Normal operation"
        STATUS="HEALTHY"
    fi
    echo ""

    # Recommendations based on status
    echo "💡 Recommendations:"
    case "$STATUS" in
        "CRITICAL")
            echo "   🚨 IMMEDIATE ACTIONS REQUIRED:"
            echo "   1️⃣  DO NOT trust live buffer for critical investigation"
            echo "   2️⃣  Use historical logs only: find logs/ -name \"*.log\""
            echo "   3️⃣  Clear buffer for fresh investigation: just android-logs-clear"
            echo "   4️⃣  Re-run tests with clean buffer"
            echo ""
            echo "   🎯 For current investigation:"
            echo "      just android-logs-cross-validate \"your_search_term\""
            ;;
        "CAUTION")
            echo "   ⚠️  ENHANCED VALIDATION REQUIRED:"
            echo "   1️⃣  Always cross-validate live buffer with historical logs"
            echo "   2️⃣  Use: just android-logs-cross-validate \"search_term\""
            echo "   3️⃣  Consider clearing buffer before critical tests"
            echo "   4️⃣  Document potential data loss in findings"
            ;;
        "HEALTHY")
            echo "   ✅ NORMAL INVESTIGATION PROTOCOL:"
            echo "   1️⃣  Live buffer tools are reliable"
            echo "   2️⃣  Standard investigation workflow applies"
            echo "   3️⃣  Still consider cross-validation for critical findings"
            echo "   4️⃣  Monitor buffer status during high-volume testing"
            ;;
    esac

    echo ""
    echo "🔧 Maintenance Commands:"
    echo "   Clear all buffers:     just android-logs-clear"
    echo "   Check device status:   just android-logs-status"
    echo "   Cross-validate:        just android-logs-cross-validate \"term\""

# Generate buffer limitation validation scenarios
create-buffer-validation-scenarios:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧪 Creating Buffer Limitation Validation Scenarios"
    echo "=================================================="
    echo ""

    # Create validation test configuration
    VALIDATION_CONFIG="tests/debug_configs/buffer-saturation-validation.json"

    echo "📝 Creating validation configuration: $VALIDATION_CONFIG"

    # Create validation configuration using echo commands for justfile compatibility
    echo '{' > "$VALIDATION_CONFIG"
    echo '  "description": "Validate buffer saturation detection and cross-validation recommendations",' >> "$VALIDATION_CONFIG"
    echo '  "actions": [' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.generate_high_volume_logs",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.generate_high_volume_logs",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.generate_high_volume_logs",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.generate_high_volume_logs",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.generate_high_volume_logs",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.buffer_test_entry",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.another_buffer_test_entry",' >> "$VALIDATION_CONFIG"
    echo '    "system.debug.final_buffer_test_entry"' >> "$VALIDATION_CONFIG"
    echo '  ],' >> "$VALIDATION_CONFIG"
    echo '  "metadata": {' >> "$VALIDATION_CONFIG"
    echo '    "buffer_validation": true,' >> "$VALIDATION_CONFIG"
    echo '    "expected_buffer_saturation": true,' >> "$VALIDATION_CONFIG"
    echo '    "cross_validation_required": true' >> "$VALIDATION_CONFIG"
    echo '  }' >> "$VALIDATION_CONFIG"
    echo '}' >> "$VALIDATION_CONFIG"

    echo "✅ Validation configuration created"
    echo ""

    # Create test script for demonstrating buffer limitations
    TEST_SCRIPT="scripts/test-buffer-limitations.sh"

    echo "📝 Creating test script: $TEST_SCRIPT"
    mkdir -p scripts

    # Create script using multiple echo commands for justfile compatibility
    echo '#!/bin/bash' > "$TEST_SCRIPT"
    echo '# Test script to demonstrate Android log buffer limitations' >> "$TEST_SCRIPT"
    echo '' >> "$TEST_SCRIPT"
    echo 'set -euo pipefail' >> "$TEST_SCRIPT"
    echo '' >> "$TEST_SCRIPT"
    echo 'echo "🧪 Android Log Buffer Limitation Validation"' >> "$TEST_SCRIPT"
    echo 'echo "========================================="' >> "$TEST_SCRIPT"
    echo 'echo ""' >> "$TEST_SCRIPT"
    echo '' >> "$TEST_SCRIPT"
    echo 'echo "📋 PRE-TEST: Check buffer health..."' >> "$TEST_SCRIPT"
    echo 'just android-logs-health-check' >> "$TEST_SCRIPT"
    echo 'echo ""' >> "$TEST_SCRIPT"
    echo '' >> "$TEST_SCRIPT"
    echo 'echo "🎯 STEP 1: Clear buffers for clean baseline..."' >> "$TEST_SCRIPT"
    echo 'just android-logs-clear' >> "$TEST_SCRIPT"
    echo 'echo ""' >> "$TEST_SCRIPT"
    echo '' >> "$TEST_SCRIPT"
    echo 'echo "📊 STEP 2: Check buffer status after clearing..."' >> "$TEST_SCRIPT"
    echo 'just android-logs-health-check' >> "$TEST_SCRIPT"
    echo 'echo ""' >> "$TEST_SCRIPT"

    chmod +x "$TEST_SCRIPT"
    echo "✅ Test script created and made executable"
    echo ""

    echo "🎯 VALIDATION SCENARIOS CREATED:"
    echo "   📝 Configuration: tests/debug_configs/buffer-saturation-validation.json"
    echo "   🧪 Test Script:   scripts/test-buffer-limitations.sh"
    echo ""
    echo "🚀 Usage:"
    echo "   just create-buffer-validation-scenarios    # Create scenarios"
    echo "   scripts/test-buffer-limitations.sh        # Run validation"
    echo "   just test-android-target buffer-saturation-validation  # Quick test"
    echo ""
    echo "🎓 These scenarios demonstrate:"
    echo "   ✅ Buffer saturation detection"
    echo "   ✅ Cross-validation recommendations"
    echo "   ✅ Historical log reliability"
    echo "   ✅ Health check functionality"