# Enhanced Testing with Comprehensive Log Error Detection
# Automatically enhances existing test commands to include error analysis
# Makes validation part of ordinary testing without new commands

# ================================
# UNIFIED METADATA INJECTION FUNCTIONS
# ================================

# Helper function to inject auto_quit metadata into config JSON
_inject-auto-quit-metadata source_config target_config auto_quit_value:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SOURCE_CONFIG="{{source_config}}"
    TARGET_CONFIG="{{target_config}}"
    AUTO_QUIT="{{auto_quit_value}}"
    
    # Read the original config
    if [ ! -f "$SOURCE_CONFIG" ]; then
        echo "❌ Source config not found: $SOURCE_CONFIG"
        exit 1
    fi
    
    # Use jq to inject/update the auto_quit metadata and test_id if TEST_ID is set
    if [ -n "${TEST_ID:-}" ]; then
        jq --arg auto_quit "$AUTO_QUIT" --arg test_id "$TEST_ID" '
            .metadata = (.metadata // {}) | 
            .metadata.auto_quit = ($auto_quit | test("true")) |
            .test_metadata = (.test_metadata // {}) |
            .test_metadata.test_id = $test_id
        ' "$SOURCE_CONFIG" > "$TARGET_CONFIG"
        echo "✅ Config updated with auto_quit: $AUTO_QUIT and test_id: $TEST_ID"
    else
        jq --arg auto_quit "$AUTO_QUIT" '
            .metadata = (.metadata // {}) | 
            .metadata.auto_quit = ($auto_quit | test("true"))
        ' "$SOURCE_CONFIG" > "$TARGET_CONFIG"
        echo "✅ Config updated with auto_quit: $AUTO_QUIT"
    fi
    
    echo "   Source: $SOURCE_CONFIG"
    echo "   Target: $TARGET_CONFIG"


# ================================
# SHARED CONFIGURATION FUNCTIONS  
# ================================

# Calculate dynamic timeout based on action count and platform

# Unified test ID generation for both platforms
_generate-test-id config_name platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    PLATFORM="{{platform}}"
    
    # Generate consistent test ID format
    TEST_ID="${CONFIG_NAME}_${PLATFORM}_$(date +%s)"
    echo "$TEST_ID"

# Unified configuration analysis for both platforms
_analyze-test-config config_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_PATH="{{config_path}}"
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi
    
    # Check if configuration has checksum validation
    HAS_CHECKSUM=false
    if jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        HAS_CHECKSUM=true
        
        # Get checksum configuration
        STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
        EXPECTED_CHECKSUMS=$(jq -r '.checksum_config.expected_checksums // []' "$CONFIG_PATH")
        EXPECTED_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
        
        echo "📸 Checksum Test Detected"
        echo "State Type: $STATE_TYPE"
        echo "Expected Checksums: $EXPECTED_CHECKSUMS_COUNT checksums"
        
        # Check if baseline is set
        if [[ "$EXPECTED_CHECKSUMS_COUNT" -eq 0 ]]; then
            echo ""
            echo "ℹ️  No baseline checksums set - this will be the first run"
            echo "   A baseline will be automatically created and saved"
            echo "   The test will automatically restart to validate the baseline"
        else
            echo ""
            echo "✅ Baseline checksums found - will validate against them"
        fi
        
        # Export checksum info for other functions
        export HAS_CHECKSUM
        export STATE_TYPE
        export EXPECTED_CHECKSUMS_COUNT
    else
        export HAS_CHECKSUM=false
        export EXPECTED_CHECKSUMS_COUNT=0
    fi
    
    # Detect test mode from config
    AUTO_QUIT=$(jq -r '.metadata.auto_quit // false' "$CONFIG_PATH")
    if [[ "$AUTO_QUIT" == "true" ]]; then
        echo "🤖 Test Mode: Automated (auto_quit: true)"
        export TEST_MODE="automated"
    else
        echo "👤 Test Mode: Manual (auto_quit: false)" 
        export TEST_MODE="manual"
    fi

# Unified config validation and preparation for both platforms
_validate-and-prepare-config config_name platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    PLATFORM="{{platform}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🔍 Validating and preparing config: $CONFIG_NAME"
    
    # Validate configuration exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    # Analyze config (exports HAS_CHECKSUM, TEST_MODE, etc.)
    just _analyze-test-config "$CONFIG_PATH"
    
    # Generate test ID and export it
    export TEST_ID=$(just _generate-test-id "$CONFIG_NAME" "$PLATFORM")
    echo "🔍 Test ID: $TEST_ID"
    
    # Create temporary config with auto_quit=true for automated mode
    TEMP_CONFIG_NAME="${CONFIG_NAME}_${PLATFORM}_automated"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    
    echo "📋 Creating temporary config with auto_quit=true for automated mode..."
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "true"
    
    # Return temp config path for platform-specific deployment
    echo "$TEMP_CONFIG_PATH"

# ================================
# CHECKSUM VALIDATION FUNCTIONS
# ================================

# Unified checksum extraction function for both desktop and Android logs
_extract-checksums-unified log_file test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="{{log_file}}"
    TEST_ID="{{test_id}}"
    
    # Handle different input types (file path vs logcat output)
    if [[ "$LOG_FILE" == "logcat" ]]; then
        # Android: Get logcat output
        LOG_CONTENT=$(adb logcat -d 2>/dev/null || echo "")
        if [[ -z "$LOG_CONTENT" ]]; then
            echo "No logcat output available" >&2
            return 0
        fi
    else
        # Desktop: Read from log file
        if [[ ! -f "$LOG_FILE" ]]; then
            echo "Log file not found: $LOG_FILE" >&2
            return 0
        fi
        LOG_CONTENT=$(cat "$LOG_FILE")
    fi
    
    # Unified extraction: Look for SEMANTIC_ACTION logs with pre_action_checksum
    # This works for both desktop ALogger format and Android logcat format
    # For Android: get the most recent session to avoid picking up old test checksums
    if [[ "$LOG_FILE" == "logcat" && -n "$TEST_ID" && "$TEST_ID" != "test_id" ]]; then
        # Extract timestamp from test ID (format: config_platform_timestamp)
        TIMESTAMP=$(echo "$TEST_ID" | grep -o '[0-9]\{10\}$' || echo "")
        if [[ -n "$TIMESTAMP" ]]; then
            # Get the most recent session ID that matches the test timing
            RECENT_SESSION=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | tail -1 | \
                           sed -n 's/.*"session_id": *"\([^"]*\)".*/\1/p' || echo "")
            if [[ -n "$RECENT_SESSION" ]]; then
                # Extract checksums from the most recent session only
                # Get all checksums and take the last N based on expected count
                ALL_CHECKSUMS=$(echo "$LOG_CONTENT" | grep "$RECENT_SESSION" | grep "SEMANTIC_ACTION" | \
                               sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                               grep -v "^$")
                # Take the last EXPECTED_CHECKSUMS_COUNT entries to avoid duplicates
                if [[ -n "${EXPECTED_CHECKSUMS_COUNT:-}" && "${EXPECTED_CHECKSUMS_COUNT}" -gt 0 ]]; then
                    CHECKSUMS=$(echo "$ALL_CHECKSUMS" | tail -${EXPECTED_CHECKSUMS_COUNT})
                else
                    # Fallback: take last 8 entries
                    CHECKSUMS=$(echo "$ALL_CHECKSUMS" | tail -8)
                fi
            else
                # Fallback to all recent SEMANTIC_ACTION logs
                CHECKSUMS=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | tail -20 | \
                           sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                           grep -v "^$")
            fi
        else
            # No timestamp in test ID - use most recent logs
            CHECKSUMS=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | tail -20 | \
                       sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                       grep -v "^$")
        fi
    else
        # Desktop logs or fallback: get all SEMANTIC_ACTION checksums
        CHECKSUMS=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | \
                   sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                   grep -v "^$")
    fi
    
    echo "$CHECKSUMS"

# Extract checksums from Android logcat output - DEPRECATED: Use _extract-checksums-unified instead
_extract-checksums-from-logcat test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    
    # Get the full logcat output
    LOGCAT_OUTPUT=$(adb logcat -d 2>/dev/null || echo "")
    
    if [[ -z "$LOGCAT_OUTPUT" ]]; then
        echo "No logcat output available" >&2
        return 0
    fi
    
    # Extract checksums from the actual log format
    # Look for Generated checksum logs from SessionManager
    CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "Generated checksum.*checksum.*:" | \
               sed -n 's/.*"checksum": *"\([^"]*\)".*/\1/p' | \
               grep -v "^$" | sort | uniq || echo "")
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 1: look for SEMANTIC_ACTION checksums which contain pre_action_checksum
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "SEMANTIC_ACTION.*pre_action_checksum" | \
                   sed -n 's/.*"pre_action_checksum": *"\([^"]*\)".*/\1/p' | \
                   grep -v "^$" | sort | uniq || echo "")
    fi
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 2: look for final state checksums
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "FINAL_STATE_CAPTURED.*final_checksum" | \
                   sed -n 's/.*"final_checksum": *"\([^"]*\)".*/\1/p' | \
                   grep -v "^$" | sort | uniq || echo "")
    fi
    
    if [[ -z "$CHECKSUMS" ]]; then
        # Fallback 3: look for any checksum patterns in the logs
        CHECKSUMS=$(echo "$LOGCAT_OUTPUT" | grep -E "checksum.*[a-f0-9]{32,}" | \
                   sed -n 's/.*checksum[^a-f0-9]*\([a-f0-9]\{32,\}\).*/\1/p' | \
                   sort | uniq || echo "")
    fi
    
    # Debug: show what we found in the logs
    if [[ -z "$CHECKSUMS" ]]; then
        echo "🔍 Debug: Searching for checksum patterns in logs..." >&2
        CHECKSUM_LINES=$(echo "$LOGCAT_OUTPUT" | grep -i checksum | head -5 || echo "")
        if [[ -n "$CHECKSUM_LINES" ]]; then
            echo "Found checksum-related lines:" >&2
            echo "$CHECKSUM_LINES" | sed 's/^/  /' >&2
        else
            echo "No checksum-related lines found in logcat output" >&2
        fi
    fi
    
    echo "$CHECKSUMS"

# Save checksums to configuration file
_save-checksums-to-config config_path checksums:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_PATH="{{config_path}}"
    CHECKSUMS="{{checksums}}"
    
    # Create backup
    cp "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%s)"
    
    # Convert checksums to JSON array
    CHECKSUMS_JSON=$(echo "$CHECKSUMS" | jq -R -s 'split("\n") | map(select(length > 0))')
    
    # Update the config file
    jq --argjson checksums "$CHECKSUMS_JSON" \
       '.checksum_config.expected_checksums = $checksums' \
       "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"
    
    # Validate the JSON and replace original
    if jq -e . "${CONFIG_PATH}.tmp" >/dev/null 2>&1; then
        mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
        echo "✅ Checksums saved to $CONFIG_PATH"
    else
        echo "❌ Failed to update JSON file"
        rm -f "${CONFIG_PATH}.tmp"
        exit 1
    fi

# Compare extracted checksums with expected ones
_compare-checksums extracted_checksums expected_checksums:
    #!/usr/bin/env bash
    set -euo pipefail
    
    EXTRACTED="{{extracted_checksums}}"
    EXPECTED="{{expected_checksums}}"
    
    # Sort both sets for comparison
    EXTRACTED_SORTED=$(echo "$EXTRACTED" | sort)
    EXPECTED_SORTED=$(echo "$EXPECTED" | sort)
    
    if [[ "$EXTRACTED_SORTED" == "$EXPECTED_SORTED" ]]; then
        echo "MATCH"
    else
        echo "MISMATCH"
        echo "Expected:"
        echo "$EXPECTED_SORTED" | sed 's/^/  /'
        echo "Actual:"
        echo "$EXTRACTED_SORTED" | sed 's/^/  /'
        echo "Differences:"
        diff <(echo "$EXPECTED_SORTED") <(echo "$EXTRACTED_SORTED") | sed 's/^/  /' || true
    fi

# Unified checksum validation workflow for both platforms
_handle-checksum-validation config_path platform test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_PATH="{{config_path}}"
    PLATFORM="{{platform}}"
    TEST_ID="{{test_id}}"
    
    # Only proceed if config has checksum validation
    if [[ "${HAS_CHECKSUM:-false}" != "true" ]]; then
        exit 0
    fi
    
    echo ""
    echo "📸 Checksum Validation:"
    echo "======================"
    
    # Platform-specific log extraction
    EXTRACTED_CHECKSUMS=""
    case "$PLATFORM" in
        "android")
            # First try to use saved Android log file
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            ANDROID_LOG_FILE="$USER_DATA_DIR/logs/android_${TEST_ID}.log"
            
            if [[ -f "$ANDROID_LOG_FILE" ]]; then
                # Use saved log file for checksum extraction
                if just _extract-checksums-unified "$ANDROID_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from saved file:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                # Fallback to live logcat
                if just _extract-checksums-unified "logcat" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            fi
            ;;
        "desktop")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
            if [[ -n "$LATEST_LOG" ]]; then
                if just _extract-checksums-unified "$LATEST_LOG" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  No desktop log files available"
            fi
            ;;
        *)
            echo "❌ Unknown platform for checksum validation: $PLATFORM"
            exit 1
            ;;
    esac
    
    if [[ -z "$EXTRACTED_CHECKSUMS" ]]; then
        echo "⚠️  No checksums found in test logs"
        echo "This could indicate:"
        echo "  • Test completed too quickly for checksum capture"
        echo "  • SessionManager not logging checksums properly"
        echo "  • Debug actions not being executed"
        echo ""
        echo "💡 Try running the test manually to debug:"
        if [[ "$PLATFORM" == "android" ]]; then
            echo "   just test-android $(basename "$CONFIG_PATH" .json)"
        else
            echo "   just test-desktop $(basename "$CONFIG_PATH" .json)"
        fi
        exit 0
    fi
    
    CHECKSUM_COUNT=$(echo "$EXTRACTED_CHECKSUMS" | wc -l | tr -d ' ')
    echo "📸 Extracted $CHECKSUM_COUNT checksums from logs"
    
    # Check if this is first run (no baseline)
    if [[ "${EXPECTED_CHECKSUMS_COUNT:-0}" -eq 0 ]]; then
        echo ""
        echo "📝 Creating baseline checksums..."
        just _save-checksums-to-config "$CONFIG_PATH" "$EXTRACTED_CHECKSUMS"
        echo "✅ Baseline checksums created and saved"
        echo ""
        echo "Next run will validate against this baseline"
    else
        # Compare with expected checksums - handle both formats (strings and objects)
        # First check if expected_checksums contains objects with .checksum field
        if jq -e '.checksum_config.expected_checksums[0] | has("checksum")' "$CONFIG_PATH" >/dev/null 2>&1; then
            # Old structured format: extract .checksum field
            EXPECTED_CHECKSUMS_LIST=$(jq -r '.checksum_config.expected_checksums[].checksum' "$CONFIG_PATH")
        else
            # New simple format: checksums are direct strings
            EXPECTED_CHECKSUMS_LIST=$(jq -r '.checksum_config.expected_checksums[]' "$CONFIG_PATH")
        fi
        
        # Create detailed action-to-checksum mapping for better debugging
        echo "📋 Checksum-to-Action Mapping:"
        echo "| Seq | Action | Expected | Actual | Status |"
        echo "|-----|--------|----------|--------|--------|"
        
        # Get expected checksums with metadata for comparison
        EXPECTED_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
        
        # Check format of expected checksums for action mapping display
        HAS_METADATA=false
        if jq -e '.checksum_config.expected_checksums[0] | has("checksum")' "$CONFIG_PATH" >/dev/null 2>&1; then
            HAS_METADATA=true
        fi
        
        MATCH_STATUS="PASS"
        INDEX=0
        while IFS= read -r ACTUAL_CHECKSUM && [[ $INDEX -lt $EXPECTED_COUNT ]]; do
            if [[ "$HAS_METADATA" == "true" ]]; then
                # Structured format with metadata
                EXPECTED_ENTRY=$(jq -r ".checksum_config.expected_checksums[$INDEX]" "$CONFIG_PATH")
                EXPECTED_SEQ=$(echo "$EXPECTED_ENTRY" | jq -r '.sequence')
                EXPECTED_ACTION=$(echo "$EXPECTED_ENTRY" | jq -r '.action')
                EXPECTED_CHECKSUM=$(echo "$EXPECTED_ENTRY" | jq -r '.checksum')
            else
                # Simple string format
                EXPECTED_CHECKSUM=$(jq -r ".checksum_config.expected_checksums[$INDEX]" "$CONFIG_PATH")
                EXPECTED_SEQ=$((INDEX + 1))
                EXPECTED_ACTION="checksum_validation"
            fi
            
            # Compare checksums
            if [[ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]]; then
                STATUS="✅"
            else
                STATUS="❌"
                MATCH_STATUS="FAIL"
            fi
            
            # Truncate checksums for display (first 12 chars)
            EXPECTED_SHORT="${EXPECTED_CHECKSUM:0:12}..."
            ACTUAL_SHORT="${ACTUAL_CHECKSUM:0:12}..."
            
            echo "| $EXPECTED_SEQ | $EXPECTED_ACTION | $EXPECTED_SHORT | $ACTUAL_SHORT | $STATUS |"
            INDEX=$((INDEX + 1))
        done <<< "$EXTRACTED_CHECKSUMS"
        
        # Handle case where actual has fewer checksums than expected
        while [[ $INDEX -lt $EXPECTED_COUNT ]]; do
            if [[ "$HAS_METADATA" == "true" ]]; then
                EXPECTED_ENTRY=$(jq -r ".checksum_config.expected_checksums[$INDEX]" "$CONFIG_PATH")
                EXPECTED_SEQ=$(echo "$EXPECTED_ENTRY" | jq -r '.sequence')
                EXPECTED_ACTION=$(echo "$EXPECTED_ENTRY" | jq -r '.action')
                EXPECTED_CHECKSUM=$(echo "$EXPECTED_ENTRY" | jq -r '.checksum')
            else
                EXPECTED_CHECKSUM=$(jq -r ".checksum_config.expected_checksums[$INDEX]" "$CONFIG_PATH")
                EXPECTED_SEQ=$((INDEX + 1))
                EXPECTED_ACTION="checksum_validation"
            fi
            
            EXPECTED_SHORT="${EXPECTED_CHECKSUM:0:12}..."
            echo "| $EXPECTED_SEQ | $EXPECTED_ACTION | $EXPECTED_SHORT | MISSING... | ❌ |"
            MATCH_STATUS="FAIL"
            INDEX=$((INDEX + 1))
        done
        echo ""
        
        COMPARISON_RESULT=$(just _compare-checksums "$EXTRACTED_CHECKSUMS" "$EXPECTED_CHECKSUMS_LIST")
        
        if [[ "$COMPARISON_RESULT" == "MATCH" ]]; then
            echo "✅ Checksum validation PASSED"
            echo "All checksums match expected baseline"
        else
            echo "❌ Checksum validation FAILED"
            echo ""
            echo "$COMPARISON_RESULT"
            echo ""
            echo "This could indicate:"
            echo "  • Legitimate changes requiring baseline update"
            echo "  • Regression in game state consistency"
            echo "  • Non-deterministic behavior in game logic"
            echo ""
            echo "Use 'just test-${PLATFORM}-update $(basename "$CONFIG_PATH" .json)' to update baseline if changes are legitimate"
            # Set flag to indicate checksum validation failure
            export CHECKSUM_VALIDATION_FAILED=1
            exit 1
        fi
    fi

# Platform-specific log extraction functions
_extract-logs-android test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    
    # Extract all Android logs for the test and save to expected location
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    ANDROID_LOG_FILE="$LOGS_DIR/android_${TEST_ID}.log"
    
    # Check if logs were captured during real-time monitoring
    echo "📱 Checking for logs captured during test execution..."
    
    # If real-time monitoring didn't capture logs, fall back to post-extraction
    if [[ ! -f "$ANDROID_LOG_FILE" || ! -s "$ANDROID_LOG_FILE" ]]; then
        echo "📱 No real-time logs found - attempting post-test extraction..."
        
        # Get app PID - if running, use PID filtering; if not, fall back to package name filtering
        APP_PID=$(adb shell pidof com.primaryhive.gametwo 2>/dev/null || echo "")
        
        if [[ -n "$APP_PID" && "$APP_PID" != "0" ]]; then
            echo "📱 App PID found: $APP_PID - using PID filtering with main buffer"
            adb logcat -b main -d --pid="$APP_PID" 2>/dev/null > "$ANDROID_LOG_FILE" || true
        else
            echo "📱 App not running - using TEST_ID and SEMANTIC_ACTION filtering for session isolation"
            adb logcat -b main -d 2>/dev/null | grep -E "($TEST_ID|SEMANTIC_ACTION)" > "$ANDROID_LOG_FILE" || true
        fi
    else
        echo "📱 Real-time logs found - using captured logs"
    fi
    
    if [[ -f "$ANDROID_LOG_FILE" ]]; then
        echo "📄 Android logs saved to: $ANDROID_LOG_FILE"
        wc -l "$ANDROID_LOG_FILE" | awk '{print "📊 Log lines captured:", $1}'
    else
        echo "⚠️  Failed to save Android logs"
    fi

_extract-logs-desktop test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    
    if [[ ! -d "$LOGS_DIR" ]]; then
        echo "⚠️  No desktop logs directory: $LOGS_DIR"
        exit 1
    fi
    
    LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
    if [[ -z "$LATEST_LOG" ]]; then
        echo "⚠️  No desktop log files available"
        exit 1
    fi
    
    cat "$LATEST_LOG"

# Desktop log filtering with error-safe suppression (Android-style clean output)
_filter-desktop-logs-safely temp_file_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEMP_FILE="{{temp_file_path}}"
    
    if [[ ! -f "$TEMP_FILE" ]]; then
        echo "❌ Temp file not found: $TEMP_FILE"
        return 1
    fi
    
    # CRITICAL ERROR DETECTION FIRST - Whitelist approach for maximum safety
    # Check for any critical error patterns BEFORE applying any filtering
    CRITICAL_PATTERNS="SCRIPT ERROR|Assertion failed|CRITICAL|FAILED|Exception.*Error|CRASH|ABORT|CHECKSUM_MISMATCH|Parse Error"
    
    # Check for critical errors, excluding known safe warnings
    if grep -i -E "$CRITICAL_PATTERNS" "$TEMP_FILE" >/dev/null 2>&1; then
        # Check specifically for known safe warnings that contain "WARNING" pattern
        SAFE_WARNINGS=$(grep -E "(ObjectDB instances leaked|WARNING.*ObjectDB|WARNING.*deprecated|WARNING.*Viewport)" "$TEMP_FILE" | wc -l)
        # Count only actual critical errors (excluding the WARNING pattern entirely for this check)
        REAL_CRITICAL_ERRORS=$(grep -i -E "(SCRIPT ERROR|Assertion failed|CRITICAL|FAILED|Exception.*Error|CRASH|ABORT|CHECKSUM_MISMATCH|Parse Error)" "$TEMP_FILE" | wc -l)
        
        if [[ $SAFE_WARNINGS -gt 0 ]] && [[ $REAL_CRITICAL_ERRORS -eq 0 ]]; then
            # Only safe warnings found - proceed with filtering
            echo "ℹ️  Only safe warnings detected (ObjectDB, etc.) - applying filtering"
        else
            # Real critical errors found
            echo "⚠️  CRITICAL ERRORS DETECTED - Preserving full output for debugging"
            echo "🔍 Error-safe mode: Showing unfiltered logs"
            echo ""
            cat "$TEMP_FILE"
            exit 0
        fi
    fi
    
    # NO CRITICAL ERRORS DETECTED - Safe to apply filtering for clean output
    echo "✅ No critical errors detected - Applying clean output filtering"
    echo ""
    
    # Create filtered version step by step
    TEMP_FILTERED=$(mktemp)
    
    # Apply aggressive filtering - only show ERROR level and above, plus essential test events
    grep -E "(ERROR|CRITICAL|FAILED|SCRIPT ERROR|TEST_COMPLETE|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|CHECKSUM|STATE_CAPTURED|SESSION_|SEMANTIC_ACTION)" "$TEMP_FILE" > "$TEMP_FILTERED" || true
    
    # If that results in too few lines, include WARNING level as well
    LINE_COUNT=$(wc -l < "$TEMP_FILTERED" 2>/dev/null || echo "0")
    if [[ $LINE_COUNT -lt 5 ]]; then
        grep -E "(ERROR|CRITICAL|FAILED|WARNING|SCRIPT ERROR|TEST_COMPLETE|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE|CHECKSUM|STATE_CAPTURED|SESSION_|SEMANTIC_ACTION)" "$TEMP_FILE" > "$TEMP_FILTERED" || true
    fi
    
    # Filter out ANSI color codes for clean terminal output
    sed 's/\x1b\[[0-9;]*m//g' "$TEMP_FILTERED" > "${TEMP_FILTERED}.2" && mv "${TEMP_FILTERED}.2" "$TEMP_FILTERED"
    
    # Remove font tags for cleaner output
    sed 's/\[font_size=[^]]*\]//g; s/\[\/font_size\]//g' "$TEMP_FILTERED" > "${TEMP_FILTERED}.3" && mv "${TEMP_FILTERED}.3" "$TEMP_FILTERED"
    
    # Generate Android-style structured summary
    echo "📊 Desktop Test Execution Summary"
    echo "================================="
    echo ""
    
    # Extract essential test info from filtered logs (exclude buffer replays)
    ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_FILTERED" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -d ' ' || echo "0")
    FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_FILTERED" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -d ' ' || echo "0")
    ERROR_COUNT=$(grep -c -E "(ERROR|CRITICAL|FAILED)" "$TEMP_FILTERED" 2>/dev/null || echo "0")
    
    # Extract session info for better reporting
    SESSION_INFO=$(grep "SESSION_END" "$TEMP_FILTERED" | head -1 | grep -o '"duration_ms":[0-9]*' | cut -d: -f2 2>/dev/null || echo "0")
    if [[ "$SESSION_INFO" != "0" ]]; then
        DURATION_SECONDS=$((SESSION_INFO / 1000))
        DURATION_DISPLAY="${DURATION_SECONDS}s"
    else
        DURATION_DISPLAY="unknown"
    fi
    
    echo "**Actions Executed**: $ACTION_COUNT"
    echo "**Actions Failed**: $FAILED_COUNT"
    echo "**Test Duration**: $DURATION_DISPLAY"
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo "**Status**: ❌ ERRORS DETECTED ($ERROR_COUNT)"
    else
        echo "**Status**: ✅ COMPLETED"
    fi
    echo ""
    
    # Show only the most essential events
    echo "📋 Key Test Events:"
    if [[ -s "$TEMP_FILTERED" ]]; then
        # Show filtered essential events only
        grep -E "(SESSION_START|SESSION_END|TEST_COMPLETE|CHECKSUM.*validation)" "$TEMP_FILTERED" | head -5 | sed 's/^/  /' 2>/dev/null || echo "  Test execution completed"
        
        # Show any errors/failures found
        if [[ $ERROR_COUNT -gt 0 ]] || [[ $FAILED_COUNT -gt 0 ]]; then
            echo ""
            echo "⚠️  Issues found:"
            grep -E "(ERROR|CRITICAL|FAILED|DEBUG_TEST_FAILURE)" "$TEMP_FILTERED" | head -3 | sed 's/^/  /' 2>/dev/null
        fi
    else
        echo "  Test executed with minimal logging - no issues detected"
    fi
    
    echo ""
    if [[ $ERROR_COUNT -eq 0 ]] && [[ $FAILED_COUNT -eq 0 ]]; then
        echo "🎯 Test completed successfully with clean output"
    else
        echo "⚠️  Test completed with $ERROR_COUNT errors and $FAILED_COUNT failures"
    fi
    
    # Cleanup
    rm -f "$TEMP_FILTERED"

# ================================
# SHARED ERROR ANALYSIS LOGIC
# ================================

# Unified error analysis that works for both Android and Desktop
_analyze-test-errors test_id platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    
    echo "🔍 Analyzing test errors for: $TEST_ID ($PLATFORM)"
    echo "================================================"
    
    # Get logs based on platform  
    case "$PLATFORM" in
        "android")
            if ! command -v adb >/dev/null 2>&1; then
                echo "⚠️  adb not available - skipping Android log analysis"
                exit 0
            fi
            
            # First try to read from saved Android log file
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            ANDROID_LOG_FILE="$USER_DATA_DIR/logs/android_${TEST_ID}.log"
            
            if [[ -f "$ANDROID_LOG_FILE" ]]; then
                echo "📄 Analyzing: android_${TEST_ID}.log"
                LOGS=$(cat "$ANDROID_LOG_FILE")
            else
                # Fallback to live logcat if no saved file
                LOGS=$(adb logcat -d 2>/dev/null | tail -1000)
            fi
            
            if [[ -z "$LOGS" ]]; then
                echo "⚠️  No Android logs available"
                exit 0
            fi
            ;;
            
        "desktop")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            
            if [[ ! -d "$LOGS_DIR" ]]; then
                echo "⚠️  No desktop logs directory: $LOGS_DIR"
                exit 0
            fi
            
            LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
            if [[ -z "$LATEST_LOG" ]]; then
                echo "⚠️  No desktop log files available"
                exit 0
            fi
            
            LOGS=$(cat "$LATEST_LOG")
            echo "📄 Analyzing: $(basename "$LATEST_LOG")"
            ;;
            
        *)
            echo "❌ Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    # WHITELIST APPROACH: Only look for test-relevant logs, ignore all system noise
    # Focus on our application logs with specific test ID or Godot tags
    if [[ -n "$TEST_ID" ]]; then
        # Filter to only logs related to this specific test or Godot app
        RELEVANT_LOGS=$(echo "$LOGS" | grep -E "($TEST_ID|godot.*ERROR|godot.*CRITICAL|godot.*SCRIPT ERROR|godot.*Assertion failed|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH)" || echo "")
    else
        # Fallback: only Godot application errors
        RELEVANT_LOGS=$(echo "$LOGS" | grep -E "(godot.*ERROR|godot.*CRITICAL|godot.*SCRIPT ERROR|godot.*Assertion failed|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH)" || echo "")
    fi
    
    # Count critical errors in relevant logs only
    CRITICAL_ERRORS=$(echo "$RELEVANT_LOGS" | grep -c -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH" 2>/dev/null || echo "0")
    CRITICAL_ERRORS=$(echo "$CRITICAL_ERRORS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    # Filter out intentional test errors (error handling validation actions)
    # These actions deliberately generate errors to test error handling
    ERROR_HANDLING_FILTERED_LOGS=$(echo "$RELEVANT_LOGS" | grep -v -E "(action.*\.firebase\.error_handling|action.*\.testing\.error_handling|ERROR.*Error: Invalid Path|ERROR.*Error: Timeout Test|ERROR.*Basic Operation Test|ERROR.*Unsupported backend method|Testing backend Error: Invalid Path|Testing backend Error: Timeout)" || echo "")
    
    # Count all errors in filtered relevant logs
    ALL_ERRORS=$(echo "$ERROR_HANDLING_FILTERED_LOGS" | grep -c -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error" 2>/dev/null || echo "0")
    ALL_ERRORS=$(echo "$ALL_ERRORS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    # Count warnings in relevant logs only
    WARNINGS=$(echo "$RELEVANT_LOGS" | grep -c -E "WARNING|WARN" 2>/dev/null || echo "0")
    WARNINGS=$(echo "$WARNINGS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    # Subtract errors from warnings to avoid double counting (with safe arithmetic)
    if [[ "$WARNINGS" =~ ^[0-9]+$ ]] && [[ "$ALL_ERRORS" =~ ^[0-9]+$ ]]; then
        WARNINGS=$((WARNINGS - ALL_ERRORS))
        if [[ $WARNINGS -lt 0 ]]; then
            WARNINGS=0
        fi
    else
        echo "⚠️  Warning: Error count parsing issue, setting warnings to 0" >&2
        WARNINGS=0
    fi
    
    echo ""
    echo "📊 Error Analysis Results:"
    echo "   Critical Errors: $CRITICAL_ERRORS"
    echo "   Total Errors: $ALL_ERRORS"
    echo "   Warnings: $WARNINGS"
    
    # Show sample errors if found (from relevant logs only)
    if [[ $CRITICAL_ERRORS -gt 0 ]]; then
        echo ""
        echo "🚨 Critical Errors Found:"
        echo "$RELEVANT_LOGS" | grep -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH" | head -3 | sed 's/^/   /'
    fi
    
    if [[ $ALL_ERRORS -gt $CRITICAL_ERRORS ]]; then
        echo ""
        echo "❌ Test-Related Errors Found:"
        echo "$ERROR_HANDLING_FILTERED_LOGS" | grep -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error" | grep -v -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" | head -3 | sed 's/^/   /'
    fi
    
    if [[ $WARNINGS -gt 0 ]] && [[ $WARNINGS -lt 10 ]]; then
        echo ""
        echo "⚠️  Warnings Found: $WARNINGS (non-critical)"
    fi
    
    # Determine result
    if [[ $ALL_ERRORS -gt 0 ]]; then
        echo ""
        echo "❌ ERROR ANALYSIS FAILED"
        echo "💡 Found $ALL_ERRORS errors in test logs"
        echo ""
        case "$PLATFORM" in
            "android")
                echo "🔧 Debug: just logs-android-errors $TEST_ID"
                ;;
            "desktop") 
                echo "🔧 Debug: just logs-desktop-errors $TEST_ID"
                ;;
        esac
        exit 1
    else
        echo ""
        echo "✅ ERROR ANALYSIS PASSED"
        echo "💡 No critical errors found in logs"
        exit 0
    fi

# ================================
# TEST COMMAND ENHANCEMENT HOOKS
# ================================

# Collect action execution results from logs and save to file
_collect-action-results test_id platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    
    # Extract and save logs for analysis (this persists them for later use)
    case "$PLATFORM" in
        "android")
            if ! command -v adb >/dev/null 2>&1; then
                return 0
            fi
            # Extract and save Android logs to file for later analysis
            just _extract-logs-android "$TEST_ID"
            # Then read from the saved file
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            ANDROID_LOG_FILE="$USER_DATA_DIR/logs/android_${TEST_ID}.log"
            if [[ -f "$ANDROID_LOG_FILE" ]]; then
                LOGS=$(cat "$ANDROID_LOG_FILE")
            else
                LOGS=""
            fi
            ;;
        "desktop")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            if [[ ! -d "$LOGS_DIR" ]]; then
                return 0
            fi
            LATEST_LOG=$(find "$LOGS_DIR" -name "*.log" -type f -exec ls -t {} + | head -1)
            if [[ -z "$LATEST_LOG" ]]; then
                return 0
            fi
            LOGS=$(cat "$LATEST_LOG")
            ;;
        *)
            return 0
            ;;
    esac
    
    if [[ -z "$LOGS" ]]; then
        return 0
    fi
    
    # Create results file
    RESULTS_FILE="/tmp/test_action_results_${TEST_ID}.json"
    echo "[]" > "$RESULTS_FILE"
    
    # Process successful actions - use process substitution to avoid subshell issues
    while IFS= read -r line; do
        # Extract JSON part - look for { and } to get the JSON object
        if [[ "$line" == *"DEBUG_TEST_SUCCESS"* && "$line" == *"{"* && "$line" == *"}"* ]]; then
            # Extract everything from first { to last } (inclusive)
            JSON_PART="${line#*\{}"
            JSON_PART="{"$JSON_PART
            JSON_PART="${JSON_PART%\}*}}"
            
            # Validate it's proper JSON and extract fields
            if echo "$JSON_PART" | jq -e . >/dev/null 2>&1; then
                ACTION=$(echo "$JSON_PART" | jq -r '.action // "unknown"' 2>/dev/null)
                CATEGORY=$(echo "$JSON_PART" | jq -r '.category // "unknown"' 2>/dev/null) 
                GROUP=$(echo "$JSON_PART" | jq -r '.group // ""' 2>/dev/null)
                DURATION=$(echo "$JSON_PART" | jq -r '.duration_ms // 0' 2>/dev/null)
                SEQUENCE=$(echo "$JSON_PART" | jq -r '.sequence // 0' 2>/dev/null)
                
                if [[ "$ACTION" != "unknown" && "$ACTION" != "null" && -n "$ACTION" ]]; then
                    # Create result entry using jq for proper JSON formatting
                    TEMP_FILE=$(mktemp)
                    if jq ". + [{\"action\":\"$ACTION\",\"category\":\"$CATEGORY\",\"group\":\"$GROUP\",\"success\":true,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\"\"}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                        mv "$TEMP_FILE" "$RESULTS_FILE"
                    else
                        rm -f "$TEMP_FILE"
                    fi
                fi
            fi
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_SUCCESS" | grep -v "\[BUFFER\]" || true)
    
    # Process failed actions - use process substitution to avoid subshell issues
    while IFS= read -r line; do
        # Extract JSON part - look for { and } to get the JSON object
        if [[ "$line" == *"DEBUG_TEST_FAILURE"* && "$line" == *"{"* && "$line" == *"}"* ]]; then
            # Extract everything from first { to last } (inclusive)
            JSON_PART="${line#*\{}"
            JSON_PART="{"$JSON_PART
            JSON_PART="${JSON_PART%\}*}}"
            
            # Validate it's proper JSON and extract fields
            if echo "$JSON_PART" | jq -e . >/dev/null 2>&1; then
                ACTION=$(echo "$JSON_PART" | jq -r '.action // "unknown"' 2>/dev/null)
                CATEGORY=$(echo "$JSON_PART" | jq -r '.category // "unknown"' 2>/dev/null)
                GROUP=$(echo "$JSON_PART" | jq -r '.group // ""' 2>/dev/null)
                DURATION=$(echo "$JSON_PART" | jq -r '.duration_ms // 0' 2>/dev/null)
                SEQUENCE=$(echo "$JSON_PART" | jq -r '.sequence // 0' 2>/dev/null)
                ERROR_MSG=$(echo "$JSON_PART" | jq -r '.error // ""' 2>/dev/null)
                
                if [[ "$ACTION" != "unknown" && "$ACTION" != "null" && -n "$ACTION" ]]; then
                    # Create result entry using jq for proper JSON formatting and escaping
                    TEMP_FILE=$(mktemp)
                    if jq --arg action "$ACTION" --arg category "$CATEGORY" --arg group "$GROUP" --arg error "$ERROR_MSG" ". + [{\"action\":\$action,\"category\":\$category,\"group\":\$group,\"success\":false,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\$error}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                        mv "$TEMP_FILE" "$RESULTS_FILE"
                    else
                        rm -f "$TEMP_FILE"
                    fi
                fi
            fi
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_FAILURE" | grep -v "\[BUFFER\]" || true)

# Generate detailed action summary from collected results file
_generate-action-summary-from-file test_id config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    CONFIG_NAME="{{config_name}}"
    RESULTS_FILE="/tmp/test_action_results_${TEST_ID}.json"
    
    echo ""
    echo "📊 Detailed Action Execution Summary"
    echo "====================================="
    echo ""
    echo "**Test Configuration**: \`$CONFIG_NAME\`"
    echo "**Test ID**: \`$TEST_ID\`"
    echo ""
    
    if [[ ! -f "$RESULTS_FILE" ]] || [[ ! -s "$RESULTS_FILE" ]]; then
        echo "⚠️  No action execution data collected"
        exit 0
    fi
    
    # Parse results and group by category
    TOTAL_ACTIONS=$(jq 'length' "$RESULTS_FILE")
    PASSED_ACTIONS=$(jq '[.[] | select(.success == true)] | length' "$RESULTS_FILE")
    FAILED_ACTIONS=$(jq '[.[] | select(.success == false)] | length' "$RESULTS_FILE")
    
    if [[ "$TOTAL_ACTIONS" == "0" ]]; then
        echo "⚠️  No actions found in results file"
        exit 0
    fi
    
    echo "## **📊 Action Execution Results**"
    echo ""
    
    # Get unique categories and their actions
    CATEGORIES=$(jq -r '[.[].category] | unique | .[]' "$RESULTS_FILE")
    
    while IFS= read -r category; do
        if [[ -z "$category" || "$category" == "null" ]]; then
            continue
        fi
        
        # Count actions in this category
        CATEGORY_COUNT=$(jq --arg cat "$category" '[.[] | select(.category == $cat)] | length' "$RESULTS_FILE")
        
        if [[ "$CATEGORY_COUNT" == "0" ]]; then
            continue
        fi
        
        # Determine category emoji and name
        case "$category" in
            "C++ Firebase")
                echo "### **🔥 C++ Firebase Layer** (\`cpp.firebase.*\` - $CATEGORY_COUNT actions)"
                ;;
            "Firebase Backend")
                echo "### **🚀 Firebase Backend Layer** (\`backend.firebase.*\` - $CATEGORY_COUNT actions)"
                ;;
            "RTDB")
                echo "### **🗄️ RTDB Database Layer** (\`rtdb.*\` - $CATEGORY_COUNT actions)"
                ;;
            "System")
                echo "### **🌐 System Network Layer** (\`system.*\` - $CATEGORY_COUNT actions)"
                ;;
            *)
                echo "### **⚙️ $category Layer** - $CATEGORY_COUNT actions"
                ;;
        esac
        
        echo "| Action | Category | End State | Duration |"
        echo "|--------|----------|-----------|----------|"
        
        # Show actions for this category, sorted by sequence
        jq -r --arg cat "$category" '
            [.[] | select(.category == $cat)] | 
            sort_by(.sequence) | 
            .[] | 
            "\(.action)|\(.category)|\(if .success then "✅ **PASSED**" else "❌ **FAILED**" end)|\(.duration_ms)ms"
        ' "$RESULTS_FILE" | while IFS='|' read -r action category status duration; do
            echo "| \`$action\` | $category | $status | $duration |"
        done
        
        echo ""
    done <<< "$CATEGORIES"
    
    echo "---"
    echo ""
    echo "**✅ Total Actions Executed**: **$TOTAL_ACTIONS actions**"
    echo "**✅ Actions Passed**: **$PASSED_ACTIONS/$TOTAL_ACTIONS ($((PASSED_ACTIONS * 100 / TOTAL_ACTIONS))%)**"
    echo "**❌ Actions Failed**: **$FAILED_ACTIONS/$TOTAL_ACTIONS ($((FAILED_ACTIONS * 100 / TOTAL_ACTIONS))%)**"
    
    # Clean up results file
    rm -f "$RESULTS_FILE"

# Hook that can be called after any test execution to add error analysis
_post-test-validation test_id platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    
    # Collect action results from logs first
    just _collect-action-results "$TEST_ID" "$PLATFORM"
    
    # Generate detailed action summary
    just _generate-action-summary-from-file "$TEST_ID" "${CURRENT_CONFIG_NAME:-unknown}"
    
    echo ""
    echo "🔍 Running Post-Test Error Analysis..."
    echo "====================================="
    
    ERROR_ANALYSIS_RESULT=0
    just _analyze-test-errors "$TEST_ID" "$PLATFORM" || ERROR_ANALYSIS_RESULT=$?
    
    if [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
        echo ""
        echo "❌ TEST FAILED DUE TO ERRORS IN LOGS"
        echo "💡 Test execution may have succeeded, but logs contain failures"
        echo "💡 This indicates issues that need to be addressed"
        exit 1
    fi
    
    echo ""
    echo "✅ Test validation complete - no issues found"

# ================================
# SHARED TEST LIST EXECUTION
# ================================

# Generic test list executor that works for both Android and Desktop
_test-list-generic test_list platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST="{{test_list}}"
    PLATFORM="{{platform}}"
    TEST_LIST_DIR="./project/test-lists"
    TEST_LIST_PATH="$TEST_LIST_DIR/${TEST_LIST}.json"
    
    echo "🧪 Executing test list: $TEST_LIST ($PLATFORM)"
    echo "=============================================="
    
    # Validate test list exists
    if [[ ! -f "$TEST_LIST_PATH" ]]; then
        echo "❌ Test list not found: $TEST_LIST_PATH"
        exit 1
    fi
    
    # Validate JSON format
    if ! jq -e . "$TEST_LIST_PATH" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in test list: $TEST_LIST_PATH"
        exit 1
    fi
    
    # Extract configs
    if ! jq -e '.configs' "$TEST_LIST_PATH" >/dev/null 2>&1; then
        echo "❌ Test list missing required 'configs' field"
        exit 1
    fi
    
    # Check if test list contains @ references and expand accordingly
    HAS_AT_REFERENCES=$(jq -r '.configs[]?' "$TEST_LIST_PATH" 2>/dev/null | grep -c "^@" || echo "0")
    HAS_AT_REFERENCES=$(echo "$HAS_AT_REFERENCES" | tail -1)  # Get only the last line to avoid multi-line issues
    
    if [[ "${HAS_AT_REFERENCES:-0}" -gt 0 ]]; then
        echo "🔄 Expanding @ references..."
        CONFIGS=$(just _expand_at_references "$TEST_LIST")
    else
        CONFIGS=$(jq -r '.configs[]' "$TEST_LIST_PATH")
    fi
    
    if [[ -z "$CONFIGS" ]]; then
        echo "❌ No configurations found in test list"
        exit 1
    fi
    
    # Show test list info
    description=$(jq -r '.description // "No description provided"' "$TEST_LIST_PATH")
    echo "Description: $description"
    
    config_count=$(jq -r '.configs | length' "$TEST_LIST_PATH")
    echo "Configurations: $config_count"
    
    echo ""
    echo "📋 Configuration List:"
    echo "==================="
    echo "$CONFIGS" | nl -w2 -s'. '
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="
    
    # Execute each configuration using the unified analysis system
    TOTAL_CONFIGS=0
    PASSED_CONFIGS=0
    FAILED_CONFIGS=0
    
    while IFS= read -r config; do
        if [[ -z "$config" ]]; then
            continue
        fi
        
        TOTAL_CONFIGS=$((TOTAL_CONFIGS + 1))
        
        echo ""
        echo "🔍 Testing configuration $TOTAL_CONFIGS: $config"
        echo "================================================="
        
        # Execute configuration using the unified system
        if just _execute-test-with-analysis "$config" "$PLATFORM"; then
            echo "✅ Configuration passed: $config"
            PASSED_CONFIGS=$((PASSED_CONFIGS + 1))
        else
            echo "❌ Configuration failed: $config"
            FAILED_CONFIGS=$((FAILED_CONFIGS + 1))
        fi
        
        # Small delay between tests
        sleep 2
    done <<< "$CONFIGS"
    
    echo ""
    echo "📊 Test List Results Summary"
    echo "============================="
    echo "Test List: $TEST_LIST"
    echo "Platform: $PLATFORM"
    echo "Total Configurations: $TOTAL_CONFIGS"
    echo "Passed: $PASSED_CONFIGS"
    echo "Failed: $FAILED_CONFIGS"
    echo "Success Rate: $(( PASSED_CONFIGS * 100 / TOTAL_CONFIGS ))%"
    
    if [[ $FAILED_CONFIGS -gt 0 ]]; then
        echo ""
        echo "❌ Some configurations failed. Check individual test results above."
        exit 1
    else
        echo ""
        echo "✅ All configurations passed!"
    fi

# ================================
# UNIFIED TEST EXECUTION PATTERN
# ================================

# Universal test wrapper that works for both Android and Desktop
_execute-test-with-analysis config_name platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    PLATFORM="{{platform}}"
    
    echo "🎯 $PLATFORM Testing with Error Analysis: $CONFIG_NAME"
    echo "$(printf '=%.0s' {1..50})"
    echo ""
    
    # Phase 1: Auto-detect between test list and debug config
    TEST_LIST_PATH="./project/test-lists/${CONFIG_NAME}.json"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    # Check if it's a test list first
    if [[ -f "$TEST_LIST_PATH" ]]; then
        echo "📋 Detected test list: $CONFIG_NAME"
        just _test-list-generic "$CONFIG_NAME" "$PLATFORM"
        return
    fi
    
    # Check if it's a debug config, or try to create wildcard pattern config
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "🔍 Config not found, checking for wildcard pattern: $CONFIG_NAME"
        
        # Try to validate/create config (handles wildcards, single actions, etc.)
        if just _validate-config-exists "$CONFIG_NAME" >/dev/null 2>&1; then
            echo "✅ Wildcard pattern config created: $CONFIG_NAME"
            # Update CONFIG_PATH to point to the created temporary config
            CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
        else
            echo "❌ Neither test list nor config found:"
            echo "   Test list: $TEST_LIST_PATH"
            echo "   Config: $CONFIG_PATH"
            echo "💡 Available configs:"
            ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
            echo "💡 Available test lists:"
            ls project/test-lists/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No test lists found"
            exit 1
        fi
    fi
    
    # Generate test ID directly
    TEST_ID="${CONFIG_NAME}_${PLATFORM}_$(date +%s)"
    export TEST_ID
    export CURRENT_CONFIG_NAME="$CONFIG_NAME"
    
    # Check if configuration has checksum validation  
    HAS_CHECKSUM=false
    EXPECTED_CHECKSUMS_COUNT=0
    if jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        HAS_CHECKSUM=true
        EXPECTED_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
        echo "📸 Checksum Test Detected (${EXPECTED_CHECKSUMS_COUNT} expected checksums)"
    fi
    export HAS_CHECKSUM
    export EXPECTED_CHECKSUMS_COUNT
    
    # Set auto_quit value - this determines both behavior and display
    # -target commands use automated mode (auto_quit=true)
    # Other commands should pass their specific mode
    AUTO_QUIT_VALUE="true"  # Default to automated for -target commands
    
    # Create temporary config with auto_quit metadata
    TEMP_CONFIG_NAME="${CONFIG_NAME}_${PLATFORM}_automated"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "$AUTO_QUIT_VALUE"
    
    # Set display mode based on the auto_quit value we just injected
    if [[ "$AUTO_QUIT_VALUE" == "true" ]]; then
        TEST_MODE="automated"
    else
        TEST_MODE="manual"
    fi
    export TEST_MODE
    
    echo "🔍 Test ID: $TEST_ID"
    echo "📊 Test Mode: $TEST_MODE"
    echo ""
    
    echo "📋 Creating temporary config with auto_quit=${AUTO_QUIT_VALUE} for ${TEST_MODE} mode..."
    echo ""
    
    # Phase 2: Platform-specific deployment and execution  
    echo "🚀 Starting $PLATFORM test execution..."
    echo "$(printf '=%.0s' {1..35})"
    
    TEST_RESULT=0
    case "$PLATFORM" in
        "android")
            # Deploy and execute Android test
            just _deploy-config-android "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-android "$CONFIG_NAME" || TEST_RESULT=$?
            fi
            ;;
        "desktop")
            # Deploy and execute Desktop test  
            just _deploy-config-desktop "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-desktop "$CONFIG_NAME" || TEST_RESULT=$?
            fi
            ;;
        *)
            echo "❌ Unknown platform: $PLATFORM"
            TEST_RESULT=1
            ;;
    esac
    
    # Cleanup temp config
    rm -f "$TEMP_CONFIG_PATH"
    
    echo ""
    echo "📊 Test Execution: $(if [[ $TEST_RESULT -eq 0 ]]; then echo "✅ PASSED"; else echo "❌ FAILED"; fi)"
    
    # Phase 3: Unified post-test validation (shared logic)
    if [[ $TEST_RESULT -eq 0 ]]; then
        # Run error analysis
        just _post-test-validation "$TEST_ID" "$PLATFORM" || TEST_RESULT=$?
        
        # Run checksum validation if applicable
        if [[ $TEST_RESULT -eq 0 ]]; then
            HAS_CHECKSUM="$HAS_CHECKSUM" EXPECTED_CHECKSUMS_COUNT="$EXPECTED_CHECKSUMS_COUNT" just _handle-checksum-validation "$CONFIG_PATH" "$PLATFORM" "$TEST_ID" || TEST_RESULT=$?
        fi
    else
        echo ""
        echo "❌ OVERALL RESULT: FAILED"  
        echo "💡 Test execution failed - skipping validation"
        exit 1
    fi
    
    # Final result
    if [[ $TEST_RESULT -eq 0 ]]; then
        echo ""
        echo "🎉 $PLATFORM test execution complete!"
        echo "✅ All validations passed"
    else
        echo ""
        echo "❌ OVERALL RESULT: FAILED"
        exit 1
    fi

# Platform-specific app stopping functions
_stop-app-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🛑 Stopping Android app for clean state..."
    # Clear Android test cache (which includes stopping the app)
    just clear-android-test-cache
    echo "✅ Android app stopped"

_stop-app-desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🛑 Stopping desktop test instances (preserving editor)..."
    
    # Only kill test processes (--test-mode), preserve editor processes (--editor)
    # This prevents terminating the editor when running tests
    pkill -f "{{GODOT_EXECUTABLE}}.*{{PROJECT_PATH}}.*--test-mode" 2>/dev/null || true
    
    # Also kill any headless instances that might be running tests
    pkill -f "{{GODOT_EXECUTABLE}}.*{{PROJECT_PATH}}.*--headless" 2>/dev/null || true
    
    echo "✅ Desktop test instances stopped (editor preserved)"

# Platform-specific deployment functions
_deploy-config-android temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEMP_CONFIG_PATH="{{temp_config_path}}"
    TEMP_CONFIG_NAME=$(basename "$TEMP_CONFIG_PATH" .json)
    
    echo "📱 Deploying configuration to Android device..."
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        echo "Please connect a device and enable USB debugging"
        exit 1
    fi
    
    echo "📱 Device: $(adb devices | grep 'device$' | head -1 | cut -f1)"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
    # Stop app for clean state
    just _stop-app-android
    
    # Deploy config
    just config-push-android "$TEMP_CONFIG_NAME"
    echo "✅ Configuration deployed successfully - app stopped and ready for fresh launch"

_deploy-config-desktop temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEMP_CONFIG_PATH="{{temp_config_path}}"
    
    echo "🖥️  Deploying configuration to desktop..."
    
    # Stop any running desktop instances for consistent state
    just _stop-app-desktop
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup
    STARTUP_CONFIG="$USER_DATA_DIR/debug_startup_actions.json"
    
    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi
    
    echo "📋 Copying config for desktop startup..."
    cp "$TEMP_CONFIG_PATH" "$STARTUP_CONFIG"
    
    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ] || [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi
    
    echo "✅ Configuration deployed successfully - app stopped and ready for fresh launch ($(wc -c < "$STARTUP_CONFIG") bytes)"

# Platform-specific execution functions
_execute-test-android config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    echo "📱 Starting Android test monitoring..."
    
    # Prepare log file path for background monitoring
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    ANDROID_LOG_FILE="$LOGS_DIR/android_${TEST_ID}.log"
    
    # Clear logcat buffer for clean monitoring
    echo "🧹 Clearing Android logcat buffer for clean test monitoring..."
    just android-logs-clear-lightweight
    
    echo "🔍 App is running with fresh configuration - waiting for test completion..."
    
    # Simple monitoring - wait for app to quit
    echo "🔍 DEBUG: Starting app monitoring..."
    
    # Wait for test completion without timeout - single monitoring loop
    echo "🔍 Waiting for test completion..."
    
    echo "🔍 DEBUG: Starting monitoring loop (no timeout)"
    MONITOR_ITERATIONS=0
    while true; do
        MONITOR_ITERATIONS=$((MONITOR_ITERATIONS + 1))
        CURRENT_PID=$(adb shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
        
        # Debug output every 10 iterations
        if [[ $((MONITOR_ITERATIONS % 10)) -eq 0 ]]; then
            echo "🐛 DEBUG: Monitor iteration $MONITOR_ITERATIONS - APP_PID: $CURRENT_PID"
        fi
        
        if [[ -z "$CURRENT_PID" || "$CURRENT_PID" == "0" ]]; then
            echo ""
            echo "✅ App quit - test completed after $MONITOR_ITERATIONS iterations"
            echo "🐛 DEBUG: App quit detected, breaking monitoring loop"
            break
        fi
        
        sleep 2
    done
    
    echo "🐛 DEBUG: Monitoring loop ended - app quit detected"
    
    # Extract logs from Android device using proper log extraction
    echo "🔍 Extracting logs from Android device after test completion..."
    sleep 2  # Give device time to flush logs
    
    # Use the existing Android log extraction function
    just _extract-logs-android "$TEST_ID"
    
    if [[ -f "$ANDROID_LOG_FILE" && -s "$ANDROID_LOG_FILE" ]]; then
        LOG_LINES=$(wc -l < "$ANDROID_LOG_FILE")
        echo "✅ Android logs extracted: $LOG_LINES lines saved to $(basename "$ANDROID_LOG_FILE")"
    else
        echo "⚠️  Warning: No logs extracted or log file is empty"
    fi
    
    # Clean up temporary files
    rm -f /tmp/android_test_complete
    
    # Test completed successfully - app quit was detected
    echo "✅ Android test execution completed successfully"
    echo "💡 App quit detected - test finished"

_execute-test-desktop config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    echo "🖥️  Starting desktop test execution..."
    
    # Run desktop Godot with debug actions (automated mode with quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting desktop test in automated mode with --test-mode flag..."
    
    echo ""
    
    # Capture all output to a temporary file for filtering
    TEMP_OUTPUT=$(mktemp)
    
    # Execute test with reduced logging but preserve essential test information
    # Use --verbose to override quiet mode and get test logs, but filter output
    {
        ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode 2>&1
        TEST_EXIT_CODE=$?
    } > "$TEMP_OUTPUT" || TEST_EXIT_CODE=$?
    
    # Show minimal, clean output for desktop testing
    echo "📊 Desktop Test Execution Summary"
    echo "================================="
    echo ""
    
    # Check for any critical errors first (excluding ObjectDB warnings)
    CRITICAL_ERRORS=$(grep -E "(SCRIPT ERROR|CRITICAL|FAILED|Exception|Assertion failed)" "$TEMP_OUTPUT" | grep -v "ObjectDB instances leaked" || echo "")
    
    if [[ -n "$CRITICAL_ERRORS" ]]; then
        echo "⚠️  ERRORS DETECTED - Showing relevant output:"
        echo ""
        echo "$CRITICAL_ERRORS" | head -10
        TEST_EXIT_CODE=1
    else
        # Extract essential test info from output (preserve logs for checksum extraction, exclude buffer replays)
        ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -d ' ' || echo "0")
        FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -d ' ' || echo "0")
        
        # Extract session duration if available
        SESSION_INFO=$(grep "SESSION_END" "$TEMP_OUTPUT" | head -1 | grep -o '"duration_ms":[0-9]*' | cut -d: -f2 2>/dev/null || echo "0")
        if [[ "$SESSION_INFO" != "0" ]]; then
            DURATION_SECONDS=$((SESSION_INFO / 1000))
            DURATION_DISPLAY="${DURATION_SECONDS}s"
        else
            DURATION_DISPLAY="completed"
        fi
        
        echo "**Actions Executed**: $ACTION_COUNT"
        echo "**Actions Failed**: $FAILED_COUNT"  
        echo "**Status**: ✅ COMPLETED"
        echo "**Duration**: $DURATION_DISPLAY"
        echo ""
        
        # Show key test events in a concise format (no verbose startup logs, exclude buffer replays)
        echo "📋 Key Test Events:"
        grep -E "(SESSION_START|SESSION_END|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE)" "$TEMP_OUTPUT" | grep -v "\[BUFFER\]" | head -5 | sed 's/^/  /' 2>/dev/null || echo "  Test execution completed"
        
        echo ""
        echo "🎯 Test completed successfully with clean output"
    fi
    
    # Cleanup temp file
    rm -f "$TEMP_OUTPUT"
    
    # Handle exit codes
    if [[ ${TEST_EXIT_CODE:-0} -eq 124 ]]; then
        echo ""
        echo "❌ Desktop test timed out after ${MAX_TIMEOUT} seconds"
        exit 1
    elif [[ ${TEST_EXIT_CODE:-0} -ne 0 ]]; then
        echo ""
        echo "⚠️  Desktop test completed with exit code ${TEST_EXIT_CODE}"
        if [[ ${TEST_EXIT_CODE} -ne 0 ]]; then
            exit ${TEST_EXIT_CODE}
        fi
    fi
    
    echo ""
    echo "✅ Desktop test execution completed"

# ================================
# ENHANCED EXISTING COMMANDS
# ================================

# Enhanced version of test-android-target that includes automatic error analysis
test-android-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "android" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi
    
    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "android"

# Manual mode test commands that inject auto_quit: false
test-android-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Android Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "==========================================================="
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Create temporary config with auto_quit=false for manual mode
    echo "📱 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_manual"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"
    
    # Deploy config and start app using standard config-push-android
    echo "📱 Deploying configuration and starting app..."
    just config-push-android "$TEMP_CONFIG_NAME"
    rm -f "$TEMP_CONFIG_PATH"
    just restart-android-app
    
    echo "✅ Android test started in manual mode (app will stay open for verification)"

# Desktop manual mode test command
test-desktop-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Desktop Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "=========================================================="
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Create temporary config with auto_quit=false for manual mode
    echo "🖥️  Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_desktop_manual"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"
    
    # Deploy config to desktop (this stops any running instances)
    echo "🖥️  Deploying configuration to desktop..."
    just _deploy-config-desktop "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"
    
    # Start desktop app in manual mode with --test-mode flag (reads debug config but doesn't quit due to auto_quit: false)
    echo "🚀 Starting desktop app in manual mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode &
    
    echo "✅ Desktop test started in manual mode (app will stay open for verification)"

# Enhanced version of test-desktop-target that includes automatic error analysis  
test-desktop-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "desktop" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi
    
    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "desktop"

# ================================
# ORIGINAL COMMAND PRESERVATION
# ================================

# Preserved original Android test command (renamed to avoid recursion)
_test-android-target-original config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🎯 Testing target: $CONFIG_NAME"
    echo "==============================="
    
    # Clear Android test cache first to prevent stale state contamination
    echo "🧹 Clearing Android test cache to ensure fresh state..."
    just clear-android-test-cache
    echo ""
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check device connectivity
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        echo "Please connect a device and enable USB debugging"
        exit 1
    fi
    
    # Check if configuration has checksum validation
    HAS_CHECKSUM=false
    if [[ -f "$CONFIG_PATH" ]] && jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        HAS_CHECKSUM=true
        
        # Get checksum configuration
        STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
        EXPECTED_CHECKSUMS=$(jq -r '.checksum_config.expected_checksums // []' "$CONFIG_PATH")
        EXPECTED_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
        
        echo "📸 Checksum Test Detected"
        echo "State Type: $STATE_TYPE"
        echo "Expected Checksums: $EXPECTED_CHECKSUMS_COUNT checksums"
        
        # Check if baseline is set
        if [[ "$EXPECTED_CHECKSUMS_COUNT" -eq 0 ]]; then
            echo ""
            echo "ℹ️  No baseline checksums set - this will be the first run"
            echo "   A baseline will be automatically created and saved"
            echo "   The test will automatically restart to validate the baseline"
        else
            echo ""
            echo "✅ Baseline checksums found - will validate against them"
        fi
    fi
    
    # Generate unique test ID
    TEST_ID="${CONFIG_NAME}_$(date +%s)"
    export TEST_ID
    
    echo ""
    echo "🔍 Test ID: $TEST_ID"
    echo "📱 Device: $(adb devices | grep 'device$' | head -1 | cut -f1)"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
    # Clear logcat buffer
    adb logcat -c
    
    # Get current app state
    APP_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    if [[ -n "$APP_PID" ]]; then
        echo "🔍 App running (PID: $APP_PID)"
    else
        echo "⚠️  App not running - will start"
    fi
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="
    
    # Create temporary config with auto_quit=true for automated mode
    echo "📱 Creating temporary config with auto_quit=true for automated mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_automated"
    TEMP_CONFIG_PATH="./project/debug_configs/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "true"
    
    # Deploy config and start app using standard config-push-android
    echo "📱 Deploying configuration and starting app..."
    just config-push-android "$TEMP_CONFIG_NAME"
    rm -f "$TEMP_CONFIG_PATH"
    just restart-android-app
    echo ""
    
    # Brief pause for app startup, then start monitoring immediately
    sleep 1
    
    # Monitor test execution
    echo ""
    echo "🔍 Monitoring test execution..."
    echo "==============================="
    
    # Skip background monitoring for now - it's causing the hang
    # The main detection loop below will handle completion detection
    echo "🔍 Background monitoring disabled - using polling detection"
    
    # Wait for test completion
    TIMEOUT=60   # Reasonable timeout for automated tests
    ELAPSED=0
    TEST_COMPLETED=false
    CHECKSUM_SAVED=false
    
    echo "🔍 Starting monitoring loop with timeout $TIMEOUT..."
    echo "🔍 Initial values: ELAPSED=$ELAPSED, TIMEOUT=$TIMEOUT, TEST_COMPLETED=$TEST_COMPLETED"
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        echo "🔍 Loop iteration: ELAPSED=$ELAPSED, checking for completion..."
        # Check for test completion (standard pattern) - safe grep
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE.*$TEST_ID" 2>/dev/null || false; then
            TEST_COMPLETED=true
            break
        fi
        
        # Check for test completion (fallback pattern for automated mode) - safe grep  
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE_${CONFIG_NAME}_" 2>/dev/null || false; then
            TEST_COMPLETED=true
            echo "✅ Test completed with automated mode fallback signal"
            break
        fi
        
        # Check for any TEST_COMPLETE signal with automated completion (broader fallback) - safe grep
        if adb logcat -d 2>/dev/null | grep -q "TEST_COMPLETE_.*automated_completion.*true" 2>/dev/null || false; then
            TEST_COMPLETED=true
            echo "✅ Test completed with generic automated mode signal"
            break
        fi
        
        # Check for any recent TEST_COMPLETE signal (even more flexible) - safe grep
        RECENT_COMPLETE=$(adb logcat -d 2>/dev/null | grep "TEST_COMPLETE" 2>/dev/null | tail -1 || echo "")
        if [[ -n "$RECENT_COMPLETE" ]] && [[ "$RECENT_COMPLETE" =~ automated_completion.*true ]]; then
            TEST_COMPLETED=true
            echo "✅ Test completed with recent automated signal"
            break
        fi
        
        # Debug: Check what we're actually seeing
        if [[ $((ELAPSED % 4)) -eq 0 ]]; then
            echo "🔍 Debug: Checking for completion... (${ELAPSED}s)"
            RECENT_TEST_LOG=$(adb logcat -d 2>/dev/null | grep "TEST_COMPLETE" 2>/dev/null | tail -1 || echo "")
            if [[ -n "$RECENT_TEST_LOG" ]]; then
                echo "🔍 Last TEST_COMPLETE: $RECENT_TEST_LOG"
                # Test the pattern right here
                if echo "$RECENT_TEST_LOG" | grep -q "automated_completion.*true" 2>/dev/null; then
                    echo "🔍 Pattern MATCHES - should have been detected!"
                else
                    echo "🔍 Pattern does NOT match"
                fi
            else
                echo "🔍 No TEST_COMPLETE logs found yet"
            fi
        fi
        
        # Check for checksum save event (first run scenario)
        if [[ $HAS_CHECKSUM == true ]] && adb logcat -d | grep -q "CHECKSUM_SAVED.*$TEST_ID"; then
            CHECKSUM_SAVED=true
            echo ""
            echo "📸 Checksum baseline saved - test will restart automatically"
        fi
        
        # Check for errors
        if adb logcat -d | grep -q "TEST_ERROR.*$TEST_ID"; then
            echo ""
            echo "❌ Test failed with error"
            break
        fi
        
        # Check app status - if app has quit, consider test complete
        CURRENT_PID=$(adb shell pidof "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
        if [[ -z "$CURRENT_PID" ]]; then
            echo ""
            echo "✅ App quit - test completed"
            TEST_COMPLETED=true
            break
        fi
        
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        
        # Progress indicator
        if [[ $((ELAPSED % 20)) -eq 0 ]]; then
            echo "⏳ Test running... (${ELAPSED}s / ${TIMEOUT}s)"
        fi
    done
    
    # No background monitoring to cleanup (disabled above)
    echo "✅ Monitoring completed"
    
    echo ""
    echo "📊 Test Results"
    echo "==============="
    echo "Test ID: $TEST_ID"
    echo "Configuration: $CONFIG_NAME"
    echo "Duration: ${ELAPSED}s"
    
    # Determine test result
    if [[ $TEST_COMPLETED == true ]]; then
        echo "Status: ✅ COMPLETED"
        
        # Check for checksum validation results
        if [[ $HAS_CHECKSUM == true ]]; then
            echo ""
            echo "📸 Checksum Validation:"
            echo "======================"
            
            # Extract actual checksums using unified parser
            EXTRACTED_CHECKSUMS=""
            # First try to use saved Android log file
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            ANDROID_LOG_FILE="$USER_DATA_DIR/logs/android_${TEST_ID}.log"
            
            if [[ -f "$ANDROID_LOG_FILE" ]]; then
                # Use saved log file for checksum extraction
                if just _extract-checksums-unified "$ANDROID_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from saved file:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                # Fallback to live logcat
                if just _extract-checksums-unified "logcat" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            fi
            
            if [[ -z "$EXTRACTED_CHECKSUMS" ]]; then
                echo "⚠️  No checksums found in test logs"
                echo "This could indicate:"
                echo "  • Test completed too quickly for checksum capture"
                echo "  • SessionManager not logging checksums properly"
                echo "  • Debug actions not being executed"
                echo ""
                echo "💡 Try running the test manually to debug:"
                echo "   just test-android $CONFIG_NAME"
            else
                echo "📸 Extracted $(echo "$EXTRACTED_CHECKSUMS" | wc -l) checksums from logs"
                
                # Check if this is first run (no baseline)
                if [[ "$EXPECTED_CHECKSUMS_COUNT" -eq 0 ]]; then
                    echo ""
                    echo "📝 Creating baseline checksums..."
                    just _save-checksums-to-config "$CONFIG_PATH" "$EXTRACTED_CHECKSUMS"
                    echo "✅ Baseline checksums created and saved"
                    echo ""
                    echo "Next run will validate against this baseline"
                else
                    # Compare with expected checksums
                    EXPECTED_CHECKSUMS_LIST=$(jq -r '.checksum_config.expected_checksums[]' "$CONFIG_PATH")
                    COMPARISON_RESULT=$(just _compare-checksums "$EXTRACTED_CHECKSUMS" "$EXPECTED_CHECKSUMS_LIST")
                    
                    if [[ "$COMPARISON_RESULT" == "MATCH" ]]; then
                        echo "✅ Checksum validation PASSED"
                        echo "All checksums match expected baseline"
                    else
                        echo "❌ Checksum validation FAILED"
                        echo ""
                        echo "$COMPARISON_RESULT"
                        echo ""
                        echo "This could indicate:"
                        echo "  • Legitimate changes requiring baseline update"
                        echo "  • Regression in game state consistency"
                        echo "  • Non-deterministic behavior in game logic"
                        echo ""
                        echo "Use 'just test-android-update $CONFIG_NAME' to update baseline if changes are legitimate"
                        # Set a flag to indicate checksum validation failure
                        export CHECKSUM_VALIDATION_FAILED=1
                    fi
                fi
            fi
        fi
    else
        echo "Status: ❌ FAILED/TIMEOUT"
        exit 1
    fi
    
    echo ""
    echo "✅ Test execution completed"
    
    # Check if checksum validation failed
    if [[ "${CHECKSUM_VALIDATION_FAILED:-0}" == "1" ]]; then
        exit 1
    fi


# Preserved original Desktop test command (renamed to avoid recursion)
_test-desktop-target-original config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{config_name}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running desktop test: {{config_name}} (automated mode - quits automatically)"
    echo "   Config: $CONFIG_FILE"
    echo ""
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup (user directory)
    USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/gametwo"
    mkdir -p "$USER_DIR"
    STARTUP_CONFIG="$USER_DIR/debug_startup_actions.json"
    
    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi
    
    echo "📋 Injecting auto_quit metadata and copying config for desktop startup: $STARTUP_CONFIG"
    just _inject-auto-quit-metadata "$CONFIG_FILE" "$STARTUP_CONFIG" "true"
    
    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi
    
    # Verify the file has content
    if [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Created config file is empty: $STARTUP_CONFIG"
        exit 1
    fi
    
    echo "✅ Config file created with auto_quit=true ($(wc -c < "$STARTUP_CONFIG") bytes)"
    
    # Run desktop Godot with debug actions (automated mode with quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting desktop test in automated mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
        && echo "✅ Desktop test completed successfully" \
        || echo "⚠️  Desktop test completed with exit code $?"
    
    echo ""
    
    # Check for checksum validation if config has checksum_config
    if jq -e '.checksum_config' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "🔍 Checksum validation enabled - validating replay..."
        if ! just _validate-checksums-from-logs "$CONFIG_FILE" "$LOGS_DIR/godot.log"; then
            echo "❌ Checksum validation failed!"
            echo "🚨 TEST FAILED - Checksum validation did not pass"
            exit 1
        fi
        echo "✅ Checksum validation passed!"
        echo ""
    fi
    
    echo "🎉 Desktop test execution complete!"
    echo "💡 Check logs with: just logs-desktop-last"

# ================================
# CHECKSUM BASELINE UPDATE COMMANDS
# ================================

# Shared function for updating checksum baselines across platforms
_update-checksum-baseline platform config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{platform}}"
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="./project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🔄 Updating checksum baseline for: $CONFIG_NAME ($PLATFORM)"
    echo "============================================================="
    
    # Validate configuration exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        echo "Add a checksum_config section to enable checksum testing"
        exit 1
    fi
    
    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CURRENT_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
    
    echo "📸 Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksums: $CURRENT_CHECKSUMS_COUNT checksums"
    
    # Clear expected checksums to force baseline creation
    echo ""
    echo "🔄 Clearing current baseline..."
    TEMP_CONFIG=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_CONFIG"
    mv "$TEMP_CONFIG" "$CONFIG_PATH"
    
    echo "✅ Baseline cleared - running test to generate new baseline..."
    
    # Run test to generate new baseline
    echo ""
    echo "🚀 Generating new baseline..."
    echo "============================="
    
    # Execute platform-specific test which will create new baseline
    if [[ "$PLATFORM" == "android" ]]; then
        just test-android-target "$CONFIG_NAME" || echo "Test execution completed (ignoring validation failure for update)"
    elif [[ "$PLATFORM" == "desktop" ]]; then
        just test-desktop-target "$CONFIG_NAME" || echo "Test execution completed (ignoring validation failure for update)"
    else
        echo "❌ Unknown platform: $PLATFORM"
        exit 1
    fi
    
    # Check if baseline was created
    UPDATED_CHECKSUMS_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")
    
    if [[ "$UPDATED_CHECKSUMS_COUNT" -gt 0 ]]; then
        echo ""
        echo "✅ Baseline update completed successfully!"
        echo "========================================"
        echo "Configuration: $CONFIG_NAME"
        echo "Platform: $PLATFORM"
        echo "State Type: $STATE_TYPE"
        echo "Previous Checksums: $CURRENT_CHECKSUMS_COUNT checksums"
        echo "New Checksums: $UPDATED_CHECKSUMS_COUNT checksums"
        echo ""
        echo "The new baseline has been saved and will be used for future validations."
    else
        echo ""
        echo "❌ Baseline update failed"
        echo "========================"
        echo "The test may have failed or the checksum was not properly generated."
        echo "Check the test logs for more details."
        exit 1
    fi

# Update checksum baseline for Android test configuration
test-android-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."
        
        # Find all checksum-enabled configs
        CONFIG_DIR="./project/debug_configs"
        CHECKSUM_CONFIGS=""
        
        if [[ -d "$CONFIG_DIR" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")
                    
                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE SET"
                    else
                        status="✅ BASELINE SET"
                    fi
                    
                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "$CONFIG_DIR" -name "*.json" -type f -print0)
        fi
        
        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            echo ""
            echo "To enable checksum testing, add a checksum_config section to your configuration."
            exit 1
        fi
        
        echo "📸 Available checksum configurations:"
        echo "===================================="
        
        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to update: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi
            
            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-android-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi
    
    # Call shared update function
    just _update-checksum-baseline "android" "$CONFIG_NAME"

# Update checksum baseline for Desktop test configuration
test-desktop-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."
        
        # Find all checksum-enabled configs
        CONFIG_DIR="./project/debug_configs"
        CHECKSUM_CONFIGS=""
        
        if [[ -d "$CONFIG_DIR" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")
                    
                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE SET"
                    else
                        status="✅ BASELINE SET"
                    fi
                    
                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "$CONFIG_DIR" -name "*.json" -type f -print0)
        fi
        
        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            echo ""
            echo "To enable checksum testing, add a checksum_config section to your configuration."
            exit 1
        fi
        
        echo "📸 Available checksum configurations:"
        echo "===================================="
        
        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to update: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi
            
            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-desktop-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi
    
    # Call shared update function
    just _update-checksum-baseline "desktop" "$CONFIG_NAME"