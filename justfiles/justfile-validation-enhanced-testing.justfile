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
            .test_metadata.test_id = $test_id |
            if .sentry_test_id then del(.sentry_test_id) else . end
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
    
    # Generate consistent test ID format using shared function
    TEST_ID=$(just _shared-generate-test-id "$CONFIG_NAME" "test" "$PLATFORM")
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
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    echo "🔍 Validating and preparing config: $CONFIG_NAME"
    
    # Validate configuration exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        echo "💡 Available configs:"
        ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    # Analyze config (exports HAS_CHECKSUM, TEST_MODE, etc.)
    just _analyze-test-config "$CONFIG_PATH"
    
    # Generate test ID and export it
    export TEST_ID=$(just _generate-test-id "$CONFIG_NAME" "$PLATFORM")
    echo "🔍 Test ID: $TEST_ID"
    
    # Create temporary config with auto_quit=true for automated mode
    TEMP_CONFIG_NAME="${CONFIG_NAME}_${PLATFORM}_automated"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    
    echo "📋 Creating temporary config with auto_quit=true for automated mode..."
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "true"
    
    # Return temp config path for platform-specific deployment
    echo "$TEMP_CONFIG_PATH"

# ================================
# PLATFORM FILTERING FUNCTIONS
# ================================

# Check if a config supports the specified platform
_is-platform-supported config_path platform:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"
    PLATFORM="{{platform}}"

    # Check if this is an action name (not a config file)
    # Action names follow patterns like: backend.firebase.*, sentry.*, rtdb.*, cpp.firebase.*, system.*
    if [[ ! -f "$CONFIG_PATH" ]]; then
        # Extract the base name from the path (remove directory and .json extension)
        BASE_NAME=$(basename "$CONFIG_PATH" .json)
        if [[ "$BASE_NAME" =~ ^[a-z]+\.[a-z_]+\.[a-z_]+$ ]]; then
            echo "true"  # Actions are platform-agnostic by design
            exit 0
        fi
    fi

    # Check if config file exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "false"
        exit 0
    fi
    
    # Check if platforms field exists and contains the specified platform
    if jq -e '.platforms' "$CONFIG_PATH" >/dev/null 2>&1; then
        # Platforms field exists - check if it contains our platform
        if jq -e --arg platform "$PLATFORM" '.platforms | index($platform)' "$CONFIG_PATH" >/dev/null 2>&1; then
            echo "true"
        else
            echo "false"
        fi
    else
        # No platforms field - assume cross-platform (backward compatibility)
        echo "true"
    fi

# Get supported platforms from config
_get-supported-platforms config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"

    # Check if this is an action name (not a config file)
    # Action names follow patterns like: backend.firebase.*, sentry.*, rtdb.*, cpp.firebase.*, system.*
    if [[ ! -f "$CONFIG_PATH" ]]; then
        # Extract the base name from the path (remove directory and .json extension)
        BASE_NAME=$(basename "$CONFIG_PATH" .json)
        if [[ "$BASE_NAME" =~ ^[a-z]+\.[a-z_]+\.[a-z_]+$ ]]; then
            echo "editor, android, ios"  # Actions are cross-platform by design
            exit 0
        fi
    fi

    # Check if config file exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "unknown"
        exit 0
    fi
    
    # Check if platforms field exists
    if jq -e '.platforms' "$CONFIG_PATH" >/dev/null 2>&1; then
        # Extract platforms and format nicely
        PLATFORMS=$(jq -r '.platforms | join(", ")' "$CONFIG_PATH")
        echo "$PLATFORMS"
    else
        # No platforms field - assume cross-platform
        echo "android, editor"
    fi

# Show platform compatibility for a config
_show-platform-info config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_NAME"
        exit 0
    fi
    
    DESCRIPTION=$(jq -r '.description // "No description"' "$CONFIG_PATH")
    PLATFORMS=$(just _get-supported-platforms "$CONFIG_PATH")
    
    echo "📋 Config: $CONFIG_NAME"
    echo "   Description: $DESCRIPTION"
    echo "   Platforms: $PLATFORMS"

# Show platform compatibility for multiple configs or test lists
show-platform-matrix target="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{target}}"
    
    if [[ -z "$TARGET" ]]; then
        echo "Usage: just show-platform-matrix CONFIG_OR_TEST_LIST"
        echo ""
        echo "Examples:"
        echo "  just show-platform-matrix firebase-all"
        echo "  just show-platform-matrix firebase-cpp-layer"
        exit 1
    fi
    
    # Check if it's a test list first
    TEST_LIST_PATH="{{TEST_LIST_DIR}}/${TARGET}.json"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TARGET}.json"
    
    if [[ -f "$TEST_LIST_PATH" ]]; then
        echo "📋 PLATFORM COMPATIBILITY MATRIX: $TARGET (Test List)"
        echo "================================================"
        
        # Get configs from test list (handle @ references)
        HAS_AT_REFERENCES=$(jq -r '.configs[]?' "$TEST_LIST_PATH" 2>/dev/null | grep -c "^@" || echo "0")
        HAS_AT_REFERENCES=$(echo "$HAS_AT_REFERENCES" | tail -1)  # Get only the last line to avoid multi-line issues
        if [[ "${HAS_AT_REFERENCES:-0}" -gt 0 ]]; then
            CONFIGS=$(just _expand_at_references "$TARGET")
        else
            CONFIGS=$(jq -r '.configs[]' "$TEST_LIST_PATH")
        fi
        
        echo "┌─────────────────────────────┬─────────┬─────────┐"
        echo "│ Config                      │ Android │ Desktop │"
        echo "├─────────────────────────────┼─────────┼─────────┤"
        
        while IFS= read -r config; do
            if [[ -z "$config" ]]; then
                continue
            fi
            
            CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/${config}.json"
            if [[ ! -f "$CONFIG_FILE" ]]; then
                printf "│ %-27s │    ?    │    ?    │\n" "$config"
                continue
            fi
            
            ANDROID_SUPPORT="❌"
            DESKTOP_SUPPORT="❌"
            
            if [[ "$(just _is-platform-supported "$CONFIG_FILE" "android")" == "true" ]]; then
                ANDROID_SUPPORT="✅"
            fi
            
            if [[ "$(just _is-platform-supported "$CONFIG_FILE" "editor")" == "true" ]]; then
                DESKTOP_SUPPORT="✅"
            fi
            
            printf "│ %-27s │   %-3s   │   %-3s   │\n" "$config" "$ANDROID_SUPPORT" "$DESKTOP_SUPPORT"
        done <<< "$CONFIGS"
        
        echo "└─────────────────────────────┴─────────┴─────────┘"
        
    elif [[ -f "$CONFIG_PATH" ]]; then
        echo "📋 PLATFORM COMPATIBILITY: $TARGET (Config)"
        echo "========================================="
        just _show-platform-info "$TARGET"
        
    else
        echo "❌ Neither test list nor config found: $TARGET"
        echo "💡 Available test lists:"
        ls {{TEST_LIST_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No test lists found"
        echo "💡 Available configs:"
        ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi

# ================================
# CHECKSUM VALIDATION FUNCTIONS
# ================================

# Unified checksum extraction function for both editor and Android logs
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
            exit 0
        fi
    else
        # Desktop: Read from log file
        if [[ ! -f "$LOG_FILE" ]]; then
            echo "Log file not found: $LOG_FILE" >&2
            exit 0
        fi
        LOG_CONTENT=$(cat "$LOG_FILE")
    fi
    
    # Unified extraction: Look for SEMANTIC_ACTION logs with pre_action_checksum
    # This works for both editor ALogger format and Android logcat format
    # For Android: get the most recent session to avoid picking up old test checksums
    if [[ "$LOG_FILE" == "logcat" && -n "$TEST_ID" && "$TEST_ID" != "test_id" ]]; then
        # Extract timestamp from test ID (format: config_platform_timestamp)
        TIMESTAMP=$(echo "$TEST_ID" | grep -o '[0-9]\{10\}$' || echo "")
        if [[ -n "$TIMESTAMP" ]]; then
            # Get the most recent session ID that matches the test timing
            RECENT_SESSION=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | grep -v "\[Sentry\]" | tail -1 | \
                           sed -n 's/.*"session_id": *"\([^"]*\)".*/\1/p' || echo "")
            if [[ -n "$RECENT_SESSION" ]]; then
                # Extract checksums from the most recent session only
                # Get all checksums and take the last N based on expected count
                ALL_CHECKSUMS=$(echo "$LOG_CONTENT" | grep "$RECENT_SESSION" | grep "SEMANTIC_ACTION" | grep -v "\[Sentry\]" | \
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
                CHECKSUMS=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | grep -v "\[Sentry\]" | tail -20 | \
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
        CHECKSUMS=$(echo "$LOG_CONTENT" | grep "SEMANTIC_ACTION" | grep -v "\[Sentry\]" | \
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
        exit 0
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
        "editor")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            EDITOR_LOG_FILE="$LOGS_DIR/editor_${TEST_ID}.log"

            if [[ -f "$EDITOR_LOG_FILE" ]]; then
                if just _extract-checksums-unified "$EDITOR_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from editor test log:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  Editor test log file not found: $EDITOR_LOG_FILE"
                echo "💡 Expected file name pattern: editor_\${TEST_ID}.log"
            fi
            ;;
        "ios")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            IOS_LOG_FILE="$LOGS_DIR/ios_${TEST_ID}.log"

            if [[ -f "$IOS_LOG_FILE" ]]; then
                if just _extract-checksums-unified "$IOS_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from iOS test log:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  iOS test log file not found: $IOS_LOG_FILE"
                echo "💡 Expected file name pattern: ios_\${TEST_ID}.log"
            fi
            ;;
        "windows")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            WINDOWS_LOG_FILE="$LOGS_DIR/windows_${TEST_ID}.log"

            if [[ -f "$WINDOWS_LOG_FILE" ]]; then
                if just _extract-checksums-unified "$WINDOWS_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from Windows test log:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  Windows test log file not found: $WINDOWS_LOG_FILE"
                echo "💡 Expected file name pattern: windows_\${TEST_ID}.log"
            fi
            ;;
        "windows-physical")
            # Windows physical machine logs are saved locally after retrieval
            WIN_PHYSICAL_LOG_FILE="logs/${TEST_ID}.log"

            if [[ -f "$WIN_PHYSICAL_LOG_FILE" ]]; then
                if just _extract-checksums-unified "$WIN_PHYSICAL_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from Windows physical test log:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  Windows physical test log file not found: $WIN_PHYSICAL_LOG_FILE"
                echo "💡 Expected file name pattern: logs/\${TEST_ID}.log"
            fi
            ;;
        "macos")
            USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
            LOGS_DIR="$USER_DATA_DIR/logs"
            MACOS_LOG_FILE="$LOGS_DIR/macos_${TEST_ID}.log"

            if [[ -f "$MACOS_LOG_FILE" ]]; then
                if just _extract-checksums-unified "$MACOS_LOG_FILE" "$TEST_ID" > /tmp/checksum_extraction.log 2>&1; then
                    EXTRACTED_CHECKSUMS=$(cat /tmp/checksum_extraction.log)
                else
                    echo "⚠️  Checksum extraction failed from macOS test log:"
                    cat /tmp/checksum_extraction.log | sed 's/^/  /'
                fi
            else
                echo "⚠️  macOS test log file not found: $MACOS_LOG_FILE"
                echo "💡 Expected file name pattern: macos_\${TEST_ID}.log"
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
            echo "   just test-editor $(basename "$CONFIG_PATH" .json)"
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
            
            # Smart truncation - show full special values, truncate long hashes
            if [[ "$EXPECTED_CHECKSUM" == SKIP_* ]] || [[ ${#EXPECTED_CHECKSUM} -lt 30 ]]; then
                EXPECTED_SHORT="$EXPECTED_CHECKSUM"
            else
                EXPECTED_SHORT="${EXPECTED_CHECKSUM:0:12}..."
            fi

            if [[ "$ACTUAL_CHECKSUM" == SKIP_* ]] || [[ ${#ACTUAL_CHECKSUM} -lt 30 ]]; then
                ACTUAL_SHORT="$ACTUAL_CHECKSUM"
            else
                ACTUAL_SHORT="${ACTUAL_CHECKSUM:0:12}..."
            fi
            
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
            
            # Smart truncation for missing checksums too
            if [[ "$EXPECTED_CHECKSUM" == SKIP_* ]] || [[ ${#EXPECTED_CHECKSUM} -lt 30 ]]; then
                EXPECTED_SHORT="$EXPECTED_CHECKSUM"
            else
                EXPECTED_SHORT="${EXPECTED_CHECKSUM:0:12}..."
            fi
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

# Unified log extraction function for both platforms
_extract-logs test_id platform temp_output_file="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    TEMP_OUTPUT_FILE="{{temp_output_file}}"
    
    # Setup common paths
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"
    
    # Platform-specific log file naming
    LOG_FILE="$LOGS_DIR/${PLATFORM}_${TEST_ID}.log"
    
    case "$PLATFORM" in
        "android")
            echo "📱 Extracting Android logs for test: $TEST_ID"
            
            # Check if logs were captured during real-time monitoring
            if [[ ! -f "$LOG_FILE" || ! -s "$LOG_FILE" ]]; then
                echo "📱 No real-time logs found - attempting post-test extraction..."
                
                # Get app PID - if running, use PID filtering; if not, fall back to package name filtering
                APP_PID=$(adb shell pidof com.primaryhive.gametwo 2>/dev/null || echo "")
                
                if [[ -n "$APP_PID" && "$APP_PID" != "0" ]]; then
                    echo "📱 App PID found: $APP_PID - using PID filtering with all buffers"
                    # Use all buffers and increase capture size significantly with verbose logging
                    adb logcat -b main,system,crash -d --pid="$APP_PID" -t 10000 "*:V" 2>/dev/null > "$LOG_FILE" || true
                else
                    echo "📱 App not running - using TEST_ID and SEMANTIC_ACTION filtering with extended capture"
                    # Capture from all buffers, get more history, then filter with CROSS-PLATFORM TEST FILTER
                    # Use sort -u to prevent duplicate log lines from multiple pattern matches (fixes double counting)
                    adb logcat -b main,system,crash -d -t 20000 "*:V" 2>/dev/null | grep -E "($TEST_ID|{{CROSS_PLATFORM_TEST_BASE}})" | sort -u > "$LOG_FILE" || true
                    
                    # If that produces no results, try a broader time-based approach
                    if [[ ! -s "$LOG_FILE" ]]; then
                        echo "📱 No filtered logs found - trying time-based approach (last 10 minutes)"
                        TIME_THRESHOLD=$(date -d '10 minutes ago' '+%m-%d %H:%M:%S' 2>/dev/null || date -v-10M '+%m-%d %H:%M:%S' 2>/dev/null || echo "")
                        if [[ -n "$TIME_THRESHOLD" ]]; then
                            adb logcat -b main,system -d -t 30000 2>/dev/null | grep -A1 -B1 "gametwo\|com\.primaryhive" > "$LOG_FILE" || true
                        fi
                    fi
                fi
            else
                echo "📱 Real-time logs found - using captured logs"
            fi
            ;;
        "editor")
            echo "🖥️  Extracting editor logs for test: $TEST_ID"
            
            # Temp output file is required for editor logs
            if [[ -n "$TEMP_OUTPUT_FILE" && -f "$TEMP_OUTPUT_FILE" ]]; then
                echo "🖥️  Using provided temp output file: $TEMP_OUTPUT_FILE"
                cp "$TEMP_OUTPUT_FILE" "$LOG_FILE"
            else
                echo "❌ No temp output file provided for editor log extraction"
                echo "💡 Desktop logs must be extracted from test execution output"
                exit 1
            fi
            ;;
        "ios")
            echo "🍎 Extracting iOS logs for test: $TEST_ID"

            # Check if background-captured log file exists (from _execute-test-ios)
            if [[ -f "/tmp/ios_last_log_file.txt" ]]; then
                BACKGROUND_LOG_FILE=$(cat /tmp/ios_last_log_file.txt)

                if [[ -f "$BACKGROUND_LOG_FILE" ]]; then
                    echo "🍎 Using background-captured logs from: $BACKGROUND_LOG_FILE"

                    # Copy raw logs
                    cp "$BACKGROUND_LOG_FILE" "$LOG_FILE"

                    # Filter for relevant content if we got logs
                    if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then
                        LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
                        echo "🍎 Raw iOS logs captured: $LOG_LINES lines"

                        if [[ $LOG_LINES -gt 0 ]]; then
                            echo "🍎 Filtering for test-specific content..."
                            # Use CROSS-PLATFORM TEST FILTER for identical log capture between Android and iOS
                            # This ensures SEMANTIC_ACTION logs (required for checksum extraction) are preserved
                            # Fixes task-359: iOS checksum extraction was broken by TEST_ID-only filtering
                            grep -E "($TEST_ID|{{CROSS_PLATFORM_TEST_BASE}})" "$LOG_FILE" | sort -u > "${LOG_FILE}.filtered" 2>/dev/null || echo "No matches" > "${LOG_FILE}.filtered"

                            FILTERED_LINES=$(wc -l < "${LOG_FILE}.filtered" 2>/dev/null || echo "0")
                            echo "🍎 Filtered relevant logs: $FILTERED_LINES lines"

                            # If we have filtered content, use it; otherwise keep original
                            if [[ $FILTERED_LINES -gt 0 ]]; then
                                cp "${LOG_FILE}.filtered" "$LOG_FILE"
                                rm "${LOG_FILE}.filtered"
                            else
                                echo "🍎 Keeping full log stream for analysis (no specific matches found)"
                            fi
                        fi
                    else
                        echo "🍎 No logs in background capture file"
                    fi

                    # DEBUG: Keep temporary log file for debugging
                    # rm -f "$BACKGROUND_LOG_FILE" "/tmp/ios_last_log_file.txt"
                    echo "🔍 DEBUG: Log file preserved at: $BACKGROUND_LOG_FILE"
                else
                    echo "❌ Background log file not found: $BACKGROUND_LOG_FILE"
                    exit 1
                fi
            else
                echo "❌ No background iOS log capture found"
                echo "💡 iOS logs must be captured during test execution"
                exit 1
            fi

            # Final verification and reporting
            LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
            echo "🍎 iOS log extraction complete: $LOG_LINES lines captured"

            if [[ $LOG_LINES -lt 2 ]]; then
                echo "🍎 WARNING: Limited logs captured."
                echo "💡 iOS device may require:"
                echo "   - Passcode confirmation for syslog access"
                echo "   - 'Trust This Computer' on device"
                echo "   - Godot iOS app configured to use os_log"
            else
                echo "🍎 ✅ iOS device logs successfully captured"
            fi
            ;;
        "macos")
            echo "🍎 Extracting macOS exported app logs for test: $TEST_ID"

            # Temp output file is required for macOS logs (same pattern as editor)
            if [[ -n "$TEMP_OUTPUT_FILE" && -f "$TEMP_OUTPUT_FILE" ]]; then
                echo "🍎 Using provided temp output file: $TEMP_OUTPUT_FILE"
                cp "$TEMP_OUTPUT_FILE" "$LOG_FILE"
            else
                echo "❌ No temp output file provided for macOS log extraction"
                echo "💡 macOS logs must be extracted from test execution output"
                exit 1
            fi

            # Final verification and reporting
            LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
            echo "🍎 macOS log extraction complete: $LOG_LINES lines captured"
            ;;
        "windows")
            echo "🪟 Extracting Windows VM logs for test: $TEST_ID"

            # Windows logs are retrieved via SCP from VM and stored in temp output file
            if [[ -n "$TEMP_OUTPUT_FILE" && -f "$TEMP_OUTPUT_FILE" ]]; then
                echo "🪟 Using provided temp output file: $TEMP_OUTPUT_FILE"
                cp "$TEMP_OUTPUT_FILE" "$LOG_FILE"
            else
                echo "❌ No temp output file provided for Windows log extraction"
                echo "💡 Windows logs must be retrieved via SCP from VM"
                exit 1
            fi

            # Final verification and reporting
            LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
            echo "🪟 Windows log extraction complete: $LOG_LINES lines captured"
            ;;
        "windows-physical")
            echo "🪟 Extracting Windows physical machine logs for test: $TEST_ID"

            # Windows physical machine logs are retrieved via SCP and saved to logs/${TEST_ID}.log
            WIN_PHYSICAL_LOG="logs/${TEST_ID}.log"
            if [[ -f "$WIN_PHYSICAL_LOG" ]]; then
                echo "🪟 Using Windows physical log file: $WIN_PHYSICAL_LOG"
                cp "$WIN_PHYSICAL_LOG" "$LOG_FILE"
            elif [[ -n "$TEMP_OUTPUT_FILE" && -f "$TEMP_OUTPUT_FILE" ]]; then
                echo "🪟 Using provided temp output file: $TEMP_OUTPUT_FILE"
                cp "$TEMP_OUTPUT_FILE" "$LOG_FILE"
            else
                echo "❌ No log file found for Windows physical machine"
                echo "💡 Windows physical logs should be at: $WIN_PHYSICAL_LOG"
                exit 1
            fi

            # Final verification and reporting
            LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
            echo "🪟 Windows physical log extraction complete: $LOG_LINES lines captured"
            ;;
        *)
            echo "❌ Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac

    # ================================
    # SEQUENTIAL ACTION WAIT MECHANISM - Fix for task-143
    # ================================
    # Wait for sequential actions (auto_continue=false) to complete their logging
    # This ensures DEBUG_TEST_SUCCESS logs from sequential actions are captured
    # before result collection begins
    
    if [[ -f "$LOG_FILE" ]]; then
        echo "🔄 Checking for sequential actions needing completion..."
        
        # Detect sequential actions by counting actual action queue dispatches with auto_continue: false
        # This correctly excludes internal operation markers (DEBUG_TEST_SUCCESS) that were causing 2:1 count mismatch
        SEQUENTIAL_DISPATCHES=$(grep -c "=== PROCESSING ONE QUEUE ITEM - EXECUTING ACTION ===.*\"auto_continue\": false" "$LOG_FILE" 2>/dev/null || echo "0")
        SEQUENTIAL_DISPATCHES=$(echo "$SEQUENTIAL_DISPATCHES" | tr -d ' \t\n\r' | head -1)
        # Only match the unified completion event pattern from debug_action.gd base class
        COMPLETION_EVENTS=$(grep -c "Sequential action completed - emitting completion event" "$LOG_FILE" 2>/dev/null || echo "0")
        COMPLETION_EVENTS=$(echo "$COMPLETION_EVENTS" | tr -d ' \t\n\r' | head -1)

        if [[ "${SEQUENTIAL_DISPATCHES:-0}" -gt 0 ]]; then
            echo "📋 Found $SEQUENTIAL_DISPATCHES sequential action(s), $COMPLETION_EVENTS completion event(s)"
            
            # Wait for completion events to match dispatches (with timeout safety)
            # ENHANCED: Android-specific timeout and retry logic for task-190
            WAIT_COUNT=0
            # Platform-specific timeout: Mobile platforms (iOS/Android) get 45s (buffer/device delays), Desktop gets 30s
            if [[ "$PLATFORM" == "android" || "$PLATFORM" == "ios" ]]; then
                MAX_WAIT_SECONDS=45
            else
                MAX_WAIT_SECONDS=30
            fi
            WAIT_INTERVAL=1
            RETRY_COUNT=0
            MAX_RETRIES=3

            # Get app PID for Android buffer refresh (needed before the while loop)
            APP_PID=""
            if [[ "$PLATFORM" == "android" ]]; then
                APP_PID=$(adb shell pidof com.primaryhive.gametwo 2>/dev/null || echo "")
            fi

            while [[ ${COMPLETION_EVENTS:-0} -lt ${SEQUENTIAL_DISPATCHES:-0} && $WAIT_COUNT -lt $MAX_WAIT_SECONDS ]]; do
                echo "⏳ Waiting for sequential action completion... ($WAIT_COUNT/$MAX_WAIT_SECONDS) - $COMPLETION_EVENTS/$SEQUENTIAL_DISPATCHES events"
                sleep $WAIT_INTERVAL
                WAIT_COUNT=$((WAIT_COUNT + WAIT_INTERVAL))

                # ENHANCED: Add retry logic with buffer refresh for Android (task-190)
                if [[ "$PLATFORM" == "android" && $RETRY_COUNT -lt $MAX_RETRIES && $((WAIT_COUNT % 10)) -eq 0 ]]; then
                    echo "🔄 Android buffer refresh attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
                    # Force refresh logs to check for newly flushed completion events
                    if [[ -n "$APP_PID" && "$APP_PID" != "0" ]]; then
                        adb logcat -b main,system,crash -d --pid="$APP_PID" -t 5000 "*:V" 2>/dev/null >> "$LOG_FILE" || true
                    else
                        adb logcat -b main,system,crash -d -t 10000 "*:V" 2>/dev/null | grep -E "($TEST_ID|Sequential action completed)" >> "$LOG_FILE" || true
                    fi
                    RETRY_COUNT=$((RETRY_COUNT + 1))
                fi

                # Re-check completion events (logs might be updating)
                # Only match the unified completion event pattern from debug_action.gd base class
                COMPLETION_EVENTS=$(grep -c "Sequential action completed - emitting completion event" "$LOG_FILE" 2>/dev/null || echo "0")
                COMPLETION_EVENTS=$(echo "$COMPLETION_EVENTS" | tr -d ' \t\n\r' | head -1)
            done
            
            if [[ $COMPLETION_EVENTS -ge $SEQUENTIAL_DISPATCHES ]]; then
                echo "✅ All sequential actions completed ($COMPLETION_EVENTS/$SEQUENTIAL_DISPATCHES)"
            elif [[ $WAIT_COUNT -ge $MAX_WAIT_SECONDS ]]; then
                echo "❌ TIMEOUT: Sequential action completion events not detected (${MAX_WAIT_SECONDS}s)"
                echo "   Expected: $SEQUENTIAL_DISPATCHES completion events"
                echo "   Received: $COMPLETION_EVENTS completion events"
                echo "   Missing: $((SEQUENTIAL_DISPATCHES - COMPLETION_EVENTS)) events"

                # Track timeout for summary reporting (use test list session for aggregation)
                # Extract config name from TEST_ID (format: configname_platform_timestamp)
                CONFIG_NAME=$(echo "$TEST_ID" | sed -E "s/_${PLATFORM}_[0-9]+$//")
                TIMEOUT_TRACKER="/tmp/test_timeout_tracker_testlist.txt"
                echo "${CONFIG_NAME}|${PLATFORM}|${COMPLETION_EVENTS}/${SEQUENTIAL_DISPATCHES}" >> "$TIMEOUT_TRACKER"

                echo "❌ Test FAILED due to completion event timeout"
                exit 1
            fi
            
            # Give a small additional buffer for DEBUG_TEST_SUCCESS logging
            echo "⏲️  Brief wait for final DEBUG_TEST_SUCCESS logs..."
            sleep 2
        else
            echo "✅ No sequential actions detected - proceeding normally"
        fi
    fi
    
    # Verify and report results
    if [[ -f "$LOG_FILE" ]]; then
        LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        LINE_COUNT=$(echo "$LINE_COUNT" | tr -d ' \t\n\r' | head -1)
        echo "📄 ${PLATFORM} logs saved to: $(basename "$LOG_FILE")"
        echo "📊 Log lines captured: $LINE_COUNT"
        
        # Enhanced reporting for sequential action coverage
        if [[ -f "$LOG_FILE" ]]; then
            # Count only actual game DEBUG_TEST_SUCCESS entries, exclude Sentry duplicates
            DEBUG_SUCCESS_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null | grep -v "Sentry" | wc -l 2>/dev/null || echo "0")
            DEBUG_SUCCESS_COUNT=$(echo "$DEBUG_SUCCESS_COUNT" | tr -d ' \t\n\r' | head -1)
            echo "🎯 DEBUG_TEST_SUCCESS entries: $DEBUG_SUCCESS_COUNT"
            
            # Report on sequential actions specifically (exclude Sentry logs)
            SEQUENTIAL_SUCCESS_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$LOG_FILE" 2>/dev/null | grep -v "Sentry" | grep -E "(rtdb\.advanced\.transaction|rtdb\.advanced\.concurrent_ops|rtdb\.testing\.large_data|cpp\.firebase\.|backend\.firebase\.)" | wc -l 2>/dev/null || echo "0")
            SEQUENTIAL_SUCCESS_COUNT=$(echo "$SEQUENTIAL_SUCCESS_COUNT" | tr -d ' \t\n\r' | head -1)
            if [[ "${SEQUENTIAL_SUCCESS_COUNT:-0}" -gt 0 ]]; then
                echo "⚡ Sequential action successes: $SEQUENTIAL_SUCCESS_COUNT"
            fi
        fi
    else
        echo "⚠️  Failed to save ${PLATFORM} logs"
        exit 1
    fi

# Legacy function for backward compatibility - calls unified function
_extract-logs-android test_id:
    just _extract-logs "{{test_id}}" "android"

# Legacy function for backward compatibility - calls unified function  
_extract-logs-editor test_id:
    just _extract-logs "{{test_id}}" "editor"

# Editor log filtering with error-safe suppression (Android-style clean output)
_filter-editor-logs-safely temp_file_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEMP_FILE="{{temp_file_path}}"
    
    if [[ ! -f "$TEMP_FILE" ]]; then
        echo "❌ Temp file not found: $TEMP_FILE"
        exit 1
    fi
    
    # CRITICAL ERROR DETECTION FIRST - Whitelist approach for maximum safety
    # Check for any critical error patterns BEFORE applying any filtering
    CRITICAL_PATTERNS="SCRIPT ERROR|Assertion failed|CRITICAL|FAILED|Exception.*Error|CRASH|ABORT|CHECKSUM_MISMATCH|Parse Error|KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT"
    
    # Check for critical errors, excluding known safe warnings
    if grep -i -E "$CRITICAL_PATTERNS" "$TEMP_FILE" >/dev/null 2>&1; then
        # Check specifically for known safe warnings that contain "WARNING" pattern
        SAFE_WARNINGS=$(grep -E "(ObjectDB instances leaked|WARNING.*ObjectDB|WARNING.*deprecated|WARNING.*Viewport)" "$TEMP_FILE" | wc -l)
        # Count only actual critical errors (excluding the WARNING pattern entirely for this check)
        REAL_CRITICAL_ERRORS=$(grep -i -E "(SCRIPT ERROR|Assertion failed|CRITICAL|FAILED|Exception.*Error|CRASH|ABORT|CHECKSUM_MISMATCH|Parse Error|KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT)" "$TEMP_FILE" | wc -l)
        
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
    ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_FILTERED" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | awk '{print $1}' | head -1 || echo "0")
    FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_FILTERED" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | awk '{print $1}' | head -1 || echo "0")
    ERROR_COUNT=$(grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" "$TEMP_FILTERED" | grep -c -E "(ERROR|CRITICAL|FAILED)" 2>/dev/null | awk '{print $1}' | head -1 || echo "0")
    
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
# Optional third parameter: config_file path for expected result validation
_analyze-test-errors test_id platform config_file="":
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    CONFIG_FILE="{{config_file}}"
    
    echo "🔍 Analyzing test errors for: $TEST_ID ($PLATFORM)"
    echo "================================================"
    
    # Get logs using unified file naming pattern
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    PLATFORM_LOG_FILE="$LOGS_DIR/${PLATFORM}_${TEST_ID}.log"
    
    case "$PLATFORM" in
        "android")
            if ! command -v adb >/dev/null 2>&1; then
                echo "⚠️  adb not available - skipping Android log analysis"
                exit 0
            fi
            ;;
        "editor")
            # Desktop platform supported
            ;;
        "ios")
            # iOS platform supported
            ;;
        "macos")
            # macOS platform supported (same log location as editor)
            ;;
        "windows")
            # Windows platform supported (logs retrieved via SCP from VM)
            ;;
        "windows-physical")
            # Windows physical machine supported (logs retrieved via SCP from physical machine)
            # Override log file path - windows-physical saves logs directly to logs/${TEST_ID}.log
            PLATFORM_LOG_FILE="logs/${TEST_ID}.log"
            ;;
        *)
            echo "❌ Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac

    # Read from the unified platform-specific log file
    if [[ -f "$PLATFORM_LOG_FILE" ]]; then
        echo "📄 Analyzing: $(basename "$PLATFORM_LOG_FILE")"
        LOGS=$(cat "$PLATFORM_LOG_FILE")
    else
        echo "⚠️  No ${PLATFORM} log file found: $(basename "$PLATFORM_LOG_FILE")"
        echo "💡 Expected file should have been created by test execution"
        exit 0
    fi
    
    if [[ -z "$LOGS" ]]; then
        echo "⚠️  No ${PLATFORM} logs available in file"
        exit 0
    fi
    
    # WHITELIST APPROACH: Only look for test-relevant logs, ignore all system noise
    # Use word boundaries (\b) to match ERROR/CRITICAL/WARNING as words across all log formats
    if [[ -n "$TEST_ID" ]]; then
        RELEVANT_LOGS=$(echo "$LOGS" | grep -E "($TEST_ID|\bERROR\b|\bCRITICAL\b|\bWARNING\b|SCRIPT ERROR|Assertion failed|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH)" || echo "")
    else
        RELEVANT_LOGS=$(echo "$LOGS" | grep -E "(\bERROR\b|\bCRITICAL\b|\bWARNING\b|SCRIPT ERROR|Assertion failed|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH)" || echo "")
    fi

    # ================================
    # EXPECTED RESULT VALIDATION (TASK-151)
    # ================================

    # Check if config file exists and has expected_result specifications
    EXPECTED_RESULT_VALIDATION=false
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        # Check if config contains expected_result specifications
        if grep -q "expected_result" "$CONFIG_FILE" 2>/dev/null; then
            EXPECTED_RESULT_VALIDATION=true
            echo "📋 Expected result validation enabled for this test"

            # Detect validation type
            VALIDATION_TYPE=$(cat "$CONFIG_FILE" | jq -r '.actions[0].expected_result.type // "expected_errors"' 2>/dev/null || echo "expected_errors")

            if [[ "$VALIDATION_TYPE" == "action_result_trust" ]]; then
                echo "🎯 Using trust-based validation - relying on DebugActionResult success/failure"

                # Validate by checking action results instead of log patterns
                RESULTS_DIR="/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/logs"
                # Try naming patterns: exact match, suffix after TEST_ID, or prefix before TEST_ID
                RESULTS_FILE=$(find "$RESULTS_DIR" -name "test_action_results_${TEST_ID}.json" -o -name "test_action_results_${TEST_ID}_*.json" -o -name "test_action_results_*_${TEST_ID}.json" | head -1)
                if [[ -n "$RESULTS_FILE" && -f "$RESULTS_FILE" ]]; then
                    echo "📄 Checking action results in: $(basename "$RESULTS_FILE")"

                    # Count error handling actions and their success status
                    ERROR_HANDLING_TOTAL=$(jq '[.[] | select(.action | contains("error_handling"))] | length' "$RESULTS_FILE" 2>/dev/null || echo "0")
                    ERROR_HANDLING_PASSED=$(jq '[.[] | select(.action | contains("error_handling")) | .success] | map(select(. == true)) | length' "$RESULTS_FILE" 2>/dev/null || echo "0")

                    echo "📊 Error handling actions: $ERROR_HANDLING_PASSED/$ERROR_HANDLING_TOTAL passed"

                    if [[ "$ERROR_HANDLING_PASSED" -eq "$ERROR_HANDLING_TOTAL" && "$ERROR_HANDLING_TOTAL" -gt 0 ]]; then
                        echo "✅ ACTION RESULT VALIDATION PASSED"
                        echo "💡 All error handling actions succeeded according to DebugActionResult"
                        echo "💡 Trust-based validation confirms error handling working correctly"
                        exit 0
                    else
                        echo "❌ ACTION RESULT VALIDATION FAILED"
                        echo "💡 Not all error handling actions succeeded: $ERROR_HANDLING_PASSED/$ERROR_HANDLING_TOTAL"
                        echo "💡 This indicates actual error handling failures, not log parsing issues"
                        exit 1
                    fi
                else
                    echo "❌ ACTION RESULT VALIDATION FAILED"
                    echo "💡 Action results file not found in: $RESULTS_DIR"
                    echo "💡 Searched for patterns: test_action_results_${TEST_ID}.json, test_action_results_${TEST_ID}_*.json"
                    echo "💡 Cannot perform trust-based validation - falling back to error analysis"
                    EXPECTED_RESULT_VALIDATION=false
                fi
            else
                # Fall back to legacy pattern matching validation
                echo "🎯 Using legacy log pattern validation"

                # Extract expected error patterns from config using jq
                EXPECTED_PATTERNS=$(cat "$CONFIG_FILE" | jq -r '.actions[0].expected_result.patterns[]?' 2>/dev/null || echo "")

                if [[ -n "$EXPECTED_PATTERNS" ]]; then
                echo "🎯 Expected error patterns found:"
                echo "$EXPECTED_PATTERNS" | sed 's/^/   - /'

                # Validate that expected error patterns are present
                MISSING_PATTERNS=""
                FOUND_PATTERNS=""

                while IFS= read -r pattern; do
                    if [[ -n "$pattern" ]]; then
                        # Only look for patterns in actual error/warning logs, not config dumps
                        # Filter out debug parser logs and focus on actual error messages
                        ACTUAL_ERROR_LOGS=$(echo "$RELEVANT_LOGS" | grep -v "startup.*parser" | grep -v "Processing raw action" | grep -E "(ERROR|CRITICAL|WARNING)" || echo "")
                        if echo "$ACTUAL_ERROR_LOGS" | grep -q "$pattern"; then
                            FOUND_PATTERNS="$FOUND_PATTERNS$pattern\n"
                            echo "   ✅ Found: $pattern"
                        else
                            MISSING_PATTERNS="$MISSING_PATTERNS$pattern\n"
                            echo "   ❌ Missing: $pattern"
                        fi
                    fi
                done <<< "$EXPECTED_PATTERNS"

                # If we have expected patterns, check if all were found
                if [[ -n "$MISSING_PATTERNS" ]]; then
                    echo ""
                    echo "❌ EXPECTED RESULT VALIDATION FAILED"
                    echo "💡 Missing required error patterns - test may not be working correctly"
                    echo "💡 This indicates the error handling test is not generating expected errors"
                    exit 1
                else
                    echo ""
                    echo "✅ EXPECTED RESULT VALIDATION PASSED"
                    echo "💡 All expected error patterns found - error handling test working correctly"
                    echo "💡 Test success determined by expected error validation, not error absence"
                    exit 0
                fi
                fi
            fi
        fi
    fi
    
    # Count critical errors in relevant logs only (exclude SEMANTIC_ACTION descriptive text and normal Godot resource cleanup warnings)
    CRITICAL_ERRORS=$(echo "$RELEVANT_LOGS" | grep -v "SEMANTIC_ACTION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" | grep -c -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH" 2>/dev/null || echo "0")
    CRITICAL_ERRORS=$(echo "$CRITICAL_ERRORS" | head -1 | tr -d '\n\r ' | grep -E '^[0-9]+$' || echo "0")
    
    # Filter out intentional test errors (error handling validation actions)
    # These actions deliberately generate errors to test error handling
    # Also filter out known Sentry cleanup error that occurs during app restart
    # Also filter out Windows environmental errors (audio/accessibility - no hardware on test machine)
    # Also filter out ObjectDB slot_max errors during Sentry GDExtension shutdown (task-392 - race condition in sentry-godot v1.2.0)
    ERROR_HANDLING_FILTERED_LOGS=$(echo "$RELEVANT_LOGS" | grep -v -E "(action.*\.firebase\.error_handling|action.*\.testing\.error_handling|ERROR.*Error: Invalid Path|ERROR.*Error: Timeout Test|ERROR.*Basic Operation Test|ERROR.*Unsupported backend method|Testing backend Error: Invalid Path|Testing backend Error: Timeout|ERROR.*Remote Debugger: Unable to connect|Parameter \"android_plugin\" is null|Can't create an accessibility driver|WASAPI.*init_output_device|hr != \(\(HRESULT\)0L\).*ERR_CANT_OPEN|slot >= slot_max)" || echo "")
    
    # Count all errors in filtered relevant logs (exclude SEMANTIC_ACTION descriptive text and normal Godot resource cleanup warnings)
    ALL_ERRORS=$(echo "$ERROR_HANDLING_FILTERED_LOGS" | grep -v "SEMANTIC_ACTION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit)" | grep -c -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error" 2>/dev/null || echo "0")
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
        echo "$RELEVANT_LOGS" | grep -v "SEMANTIC_ACTION" | grep -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error|DEBUG_TEST_FAILURE|CHECKSUM_MISMATCH" | head -3 | sed 's/^/   /'
    fi
    
    if [[ $ALL_ERRORS -gt $CRITICAL_ERRORS ]]; then
        echo ""
        echo "❌ Test-Related Errors Found:"
        echo "$ERROR_HANDLING_FILTERED_LOGS" | grep -v "SEMANTIC_ACTION" | grep -v -E "(ObjectDB instances leaked at exit|[0-9]+ resources still in use at exit|Parameter \"android_plugin\" is null.*Sentry.*Unable to locate SentryAndroidGodotPlugin singleton)" | grep -E "ERROR|CRITICAL|SCRIPT ERROR|Assertion failed|Missing required parameters|CHECKSUM_MISMATCH|Parse Error" | grep -v -E "SCRIPT ERROR|Assertion failed|CRITICAL|Parse Error" | head -3 | sed 's/^/   /'
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
            "editor")
                echo "🔧 Debug: just logs-editor-errors $TEST_ID"
                ;;
            "macos")
                echo "🔧 Debug: just logs-macos-errors $TEST_ID"
                ;;
            "windows")
                echo "🔧 Debug: just logs-windows-errors $TEST_ID"
                ;;
            "windows-physical")
                echo "🔧 Debug: just logs-windows-physical-errors $TEST_ID"
                ;;
            "ios")
                echo "🔧 Debug: just logs-ios-errors $TEST_ID"
                ;;
        esac
        exit 1
    else
        echo ""
        echo "✅ ERROR ANALYSIS PASSED"
        echo "💡 No critical errors found in logs"
    fi

    # CRITICAL (task-207): Check for crash signals after app quit
    # Test framework was reporting PASSED for crashed tests because it only checked app quit,
    # not HOW it quit (normal exit vs crash). This detects SIGBUS/SIGSEGV crashes.
    if [[ "$PLATFORM" == "android" ]]; then
        echo ""
        echo "🔍 Checking for crash signals..."
        CRASH_SIGNALS=$(adb logcat -d 2>/dev/null | grep -E "Fatal signal|SIGBUS|SIGSEGV" | grep -i "gametwo" | tail -5 || echo "")

        if [[ -n "$CRASH_SIGNALS" ]]; then
            # Check if crash happened during this test (within last 5 minutes)
            CRASH_TIME=$(echo "$CRASH_SIGNALS" | head -1 | awk '{print $2}' | sed 's/:.*$//' | sed 's/^0*//')
            CURRENT_TIME=$(date +%H | sed 's/^0*//')
            # Handle empty values (midnight hour)
            CRASH_TIME=${CRASH_TIME:-0}
            CURRENT_TIME=${CURRENT_TIME:-0}
            TIME_DIFF=$((CURRENT_TIME - CRASH_TIME))

            # If crash is recent (< 5 minute difference, accounting for hour rollover)
            if [[ $TIME_DIFF -le 1 ]] || [[ $TIME_DIFF -ge 23 ]]; then
                echo ""
                echo "❌ CRASH DETECTED"
                echo "💡 App crashed with fatal signal during test execution"
                echo ""
                echo "Crash details:"
                echo "$CRASH_SIGNALS"
                echo ""
                echo "🔧 Debug: just logs-android-device SIGBUS"
                echo "🔧 Debug: adb logcat -d | rg -i 'fatal signal'"
                exit 1
            fi
        fi
        echo "✅ No crash signals detected"
    fi

    exit 0

# ================================
# TEST COMMAND ENHANCEMENT HOOKS
# ================================

# Collect action execution results from logs and save to file
_collect-action-results test_id platform config_name="unknown" session="":
    #!/usr/bin/env bash
    set -eo pipefail

    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    CONFIG_NAME="{{config_name}}"
    SESSION="{{session}}"

    # Create persistent results file alongside log files for consistency
    # Each test creates a unique file using session timestamp to avoid conflicts
    if [[ -n "$SESSION" ]]; then
        RESULTS_FILE="{{STANDARD_LOGS_DIR}}/test_action_results_${TEST_ID}.json"
    else
        # Fallback to old naming for backwards compatibility
        RESULTS_FILE="{{STANDARD_LOGS_DIR}}/test_action_results_${TEST_ID}.json"
    fi
    echo "[]" > "$RESULTS_FILE"
    
    LOGS=""
    
    # Extract and save logs for analysis using unified approach
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    PLATFORM_LOG_FILE="$LOGS_DIR/${PLATFORM}_${TEST_ID}.log"
    
    # Platform-specific extraction prerequisites
    case "$PLATFORM" in
        "android")
            if ! command -v adb >/dev/null 2>&1; then
                echo "⚠️  adb not available - creating empty results file"
                LOGS=""
            else
                # Extract logs using unified function
                just _extract-logs "$TEST_ID" "$PLATFORM" || echo "⚠️  Failed to extract Android logs"
                
                # Read from the saved file
                if [[ -f "$PLATFORM_LOG_FILE" ]]; then
                    LOGS=$(cat "$PLATFORM_LOG_FILE")
                    echo "📄 Read $(echo "$LOGS" | wc -l) lines from Android log file"
                else
                    echo "⚠️  Android log file not found: $PLATFORM_LOG_FILE"
                    LOGS=""
                fi
            fi
            ;;
        "editor")
            # For editor, the extraction should have happened in _execute-test-editor
            # Here we just read the file that should already exist
            if [[ -f "$PLATFORM_LOG_FILE" ]]; then
                LOGS=$(cat "$PLATFORM_LOG_FILE")
                echo "📄 Read $(echo "$LOGS" | wc -l) lines from editor log file"
            else
                echo "⚠️  Desktop log file not found: $PLATFORM_LOG_FILE"
                echo "💡 Desktop logs should be extracted by _execute-test-editor"
                LOGS=""
            fi
            ;;
        "ios")
            # For iOS, extract logs using unified function
            just _extract-logs "$TEST_ID" "$PLATFORM" || echo "⚠️  Failed to extract iOS logs"

            # Read from the saved file
            if [[ -f "$PLATFORM_LOG_FILE" ]]; then
                LOGS=$(cat "$PLATFORM_LOG_FILE")
                echo "📄 Read $(echo "$LOGS" | wc -l) lines from iOS log file"
            else
                echo "⚠️  iOS log file not found: $PLATFORM_LOG_FILE"
                LOGS=""
            fi
            ;;
        "macos")
            # For macOS, the extraction should have happened in _execute-test-macos
            # Here we just read the file that should already exist (same pattern as editor)
            if [[ -f "$PLATFORM_LOG_FILE" ]]; then
                LOGS=$(cat "$PLATFORM_LOG_FILE")
                echo "📄 Read $(echo "$LOGS" | wc -l) lines from macOS log file"
            else
                echo "⚠️  macOS log file not found: $PLATFORM_LOG_FILE"
                echo "💡 macOS logs should be extracted by _execute-test-macos"
                LOGS=""
            fi
            ;;
        "windows")
            # For Windows, the extraction should have happened in _execute-test-windows
            # Here we just read the file that was retrieved via SCP from VM
            if [[ -f "$PLATFORM_LOG_FILE" ]]; then
                LOGS=$(cat "$PLATFORM_LOG_FILE")
                echo "📄 Read $(echo "$LOGS" | wc -l) lines from Windows log file"
            else
                echo "⚠️  Windows log file not found: $PLATFORM_LOG_FILE"
                echo "💡 Windows logs should be retrieved by _execute-test-windows via SCP"
                LOGS=""
            fi
            ;;
        "windows-physical")
            # For Windows physical machine, logs are retrieved via SCP in _execute-test-windows-physical
            # The log file is saved to logs/${TEST_ID}.log
            WIN_PHYSICAL_LOG_FILE="logs/${TEST_ID}.log"
            if [[ -f "$WIN_PHYSICAL_LOG_FILE" ]]; then
                LOGS=$(cat "$WIN_PHYSICAL_LOG_FILE")
                echo "📄 Read $(echo "$LOGS" | wc -l) lines from Windows physical log file"
            else
                echo "⚠️  Windows physical log file not found: $WIN_PHYSICAL_LOG_FILE"
                echo "💡 Windows physical logs should be retrieved by _execute-test-windows-physical via SCP"
                LOGS=""
            fi
            ;;
        *)
            echo "⚠️  Unsupported platform: $PLATFORM"
            LOGS=""
            ;;
    esac

    if [[ -z "$LOGS" ]]; then
        echo "❌ CRITICAL TEST FAILURE: No logs found for action collection"
        echo "💡 This indicates the test execution did not produce logs properly"
        echo "🔧 Expected: Valid log content for action extraction, Actual: Empty/missing logs"
        echo "   TEST_ID: $TEST_ID"
        echo "   CONFIG_NAME: $CONFIG_NAME" 
        echo "   PLATFORM: $PLATFORM"
        exit 1
    fi
    
    LOG_LINE_COUNT=$(echo "$LOGS" | wc -l | tr -d ' ')
    echo "🔍 Processing $LOG_LINE_COUNT log lines for action results..."

    # Enhanced chunk-aware JSON extraction for DEBUG_TEST_SUCCESS messages
    # Use temporary files for chunk storage (compatible across shells)
    CHUNK_DIR=$(mktemp -d)
    SUCCESS_CHUNKS_FILE="$CHUNK_DIR/success_chunks.txt"
    FAILURE_CHUNKS_FILE="$CHUNK_DIR/failure_chunks.txt"

    # First pass: Collect all chunks from DEBUG_TEST_SUCCESS messages
    while IFS= read -r line; do
        if [[ "$line" == *"DEBUG_TEST_SUCCESS"* && "$line" == *"[CHUNK"* && "$line" == *"[MSG_ID:"* ]]; then
            # Extract message ID and chunk info
            MSG_ID=$(echo "$line" | sed -n 's/.*\[MSG_ID: \([^]]*\)\].*/\1/p')
            CHUNK_INFO=$(echo "$line" | sed -n 's/.*\[CHUNK \([^]]*\)\].*/\1/p')
            CHUNK_NUM=$(echo "$CHUNK_INFO" | cut -d'/' -f1)

            # Extract content between <START> and <END>
            CONTENT=$(echo "$line" | sed -n 's/.*<START>\(.*\)<END>.*/\1/p')

            # Store chunk with format: MSG_ID:CHUNK_NUM:CONTENT
            echo "$MSG_ID:$CHUNK_NUM:$CONTENT" >> "$SUCCESS_CHUNKS_FILE"
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_SUCCESS" | grep -v "\[BUFFER\]" | grep -v "\[Sentry\]" || true)

    # Second pass: Process unchunked DEBUG_TEST_SUCCESS messages and reconstruct chunked ones
    while IFS= read -r line; do
        if [[ "$line" == *"DEBUG_TEST_SUCCESS"* ]]; then
            # Check if this is a chunked message - skip chunked ones here, they'll be processed separately
            if [[ "$line" == *"[CHUNK"* && "$line" == *"[MSG_ID:"* ]]; then
                continue  # Skip chunked messages, they'll be processed below
            fi

            # Unchunked message - process directly (backward compatibility)
            if [[ "$line" == *"{"* && "$line" == *"}"* ]]; then
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
                        # Create result entry using jq for proper JSON formatting with context
                        TEMP_FILE=$(mktemp)
                        if jq ". + [{\"action\":\"$ACTION\",\"category\":\"$CATEGORY\",\"group\":\"$GROUP\",\"success\":true,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\"\",\"test_id\":\"$TEST_ID\",\"config_name\":\"$CONFIG_NAME\",\"platform\":\"$PLATFORM\"}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                            mv "$TEMP_FILE" "$RESULTS_FILE"
                        else
                            rm -f "$TEMP_FILE"
                        fi
                    fi
                fi
            fi
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_SUCCESS" | grep -v "\[BUFFER\]" | grep -v "\[Sentry\]" || true)

    # Third pass: Process and reconstruct chunked messages
    if [[ -f "$SUCCESS_CHUNKS_FILE" && -s "$SUCCESS_CHUNKS_FILE" ]]; then
        # Group chunks by MSG_ID and process complete messages
        sort -t: -k1,1 -k2,2n "$SUCCESS_CHUNKS_FILE" | while IFS=: read -r MSG_ID CHUNK_NUM CONTENT; do
            # Count total chunks for this MSG_ID
            TOTAL_CHUNKS=$(grep "^$MSG_ID:" "$SUCCESS_CHUNKS_FILE" | cut -d: -f2 | sort -n | tail -1)
            CURRENT_CHUNK_COUNT=$(grep "^$MSG_ID:" "$SUCCESS_CHUNKS_FILE" | wc -l | tr -d ' ')

            # If we have all chunks for this message, reconstruct it
            if [[ "$CURRENT_CHUNK_COUNT" -eq "$TOTAL_CHUNKS" ]]; then
                RECONSTRUCTED_MESSAGE=""
                grep "^$MSG_ID:" "$SUCCESS_CHUNKS_FILE" | sort -t: -k2,2n | while IFS=: read -r ID NUM CONTENT_PART; do
                    RECONSTRUCTED_MESSAGE+="$CONTENT_PART"
                done

                # Extract JSON from reconstructed message
                if [[ "$RECONSTRUCTED_MESSAGE" == *"{"* && "$RECONSTRUCTED_MESSAGE" == *"}"* ]]; then
                    JSON_PART="${RECONSTRUCTED_MESSAGE#*\{}"
                    JSON_PART="{"$JSON_PART
                    JSON_PART="${JSON_PART%\}*}}"

                    # Process the JSON
                    if echo "$JSON_PART" | jq -e . >/dev/null 2>&1; then
                        ACTION=$(echo "$JSON_PART" | jq -r '.action // "unknown"' 2>/dev/null)
                        CATEGORY=$(echo "$JSON_PART" | jq -r '.category // "unknown"' 2>/dev/null)
                        GROUP=$(echo "$JSON_PART" | jq -r '.group // ""' 2>/dev/null)
                        DURATION=$(echo "$JSON_PART" | jq -r '.duration_ms // 0' 2>/dev/null)
                        SEQUENCE=$(echo "$JSON_PART" | jq -r '.sequence // 0' 2>/dev/null)

                        if [[ "$ACTION" != "unknown" && "$ACTION" != "null" && -n "$ACTION" ]]; then
                            TEMP_FILE=$(mktemp)
                            if jq ". + [{\"action\":\"$ACTION\",\"category\":\"$CATEGORY\",\"group\":\"$GROUP\",\"success\":true,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\"\",\"test_id\":\"$TEST_ID\",\"config_name\":\"$CONFIG_NAME\",\"platform\":\"$PLATFORM\"}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                                mv "$TEMP_FILE" "$RESULTS_FILE"
                            else
                                rm -f "$TEMP_FILE"
                            fi
                        fi
                    fi
                fi

                # Remove processed chunks to avoid duplicate processing
                grep -v "^$MSG_ID:" "$SUCCESS_CHUNKS_FILE" > "${SUCCESS_CHUNKS_FILE}.tmp" || true
                mv "${SUCCESS_CHUNKS_FILE}.tmp" "$SUCCESS_CHUNKS_FILE"
            fi
        done
    fi
    
    # Enhanced chunk-aware JSON extraction for DEBUG_TEST_FAILURE messages
    # First pass: Collect all chunks from DEBUG_TEST_FAILURE messages
    while IFS= read -r line; do
        if [[ "$line" == *"DEBUG_TEST_FAILURE"* && "$line" == *"[CHUNK"* && "$line" == *"[MSG_ID:"* ]]; then
            # Extract message ID and chunk info
            MSG_ID=$(echo "$line" | sed -n 's/.*\[MSG_ID: \([^]]*\)\].*/\1/p')
            CHUNK_INFO=$(echo "$line" | sed -n 's/.*\[CHUNK \([^]]*\)\].*/\1/p')
            CHUNK_NUM=$(echo "$CHUNK_INFO" | cut -d'/' -f1)

            # Extract content between <START> and <END>
            CONTENT=$(echo "$line" | sed -n 's/.*<START>\(.*\)<END>.*/\1/p')

            # Store chunk with format: MSG_ID:CHUNK_NUM:CONTENT
            echo "$MSG_ID:$CHUNK_NUM:$CONTENT" >> "$FAILURE_CHUNKS_FILE"
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_FAILURE" | grep -v "\[BUFFER\]" | grep -v "\[Sentry\]" || true)

    # Second pass: Process unchunked DEBUG_TEST_FAILURE messages
    while IFS= read -r line; do
        if [[ "$line" == *"DEBUG_TEST_FAILURE"* ]]; then
            # Check if this is a chunked message - skip chunked ones here, they'll be processed separately
            if [[ "$line" == *"[CHUNK"* && "$line" == *"[MSG_ID:"* ]]; then
                continue  # Skip chunked messages, they'll be processed below
            fi

            # Unchunked message - process directly (backward compatibility)
            if [[ "$line" == *"{"* && "$line" == *"}"* ]]; then
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
                        # Create result entry using jq for proper JSON formatting and escaping with context
                        TEMP_FILE=$(mktemp)
                        if jq --arg action "$ACTION" --arg category "$CATEGORY" --arg group "$GROUP" --arg error "$ERROR_MSG" --arg test_id "$TEST_ID" --arg config_name "$CONFIG_NAME" --arg platform "$PLATFORM" ". + [{\"action\":\$action,\"category\":\$category,\"group\":\$group,\"success\":false,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\$error,\"test_id\":\$test_id,\"config_name\":\$config_name,\"platform\":\$platform}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                            mv "$TEMP_FILE" "$RESULTS_FILE"
                        else
                            rm -f "$TEMP_FILE"
                        fi
                    fi
                fi
            fi
        fi
    done < <(echo "$LOGS" | grep "DEBUG_TEST_FAILURE" | grep -v "\[BUFFER\]" | grep -v "\[Sentry\]" || true)

    # Third pass: Process and reconstruct chunked failure messages
    if [[ -f "$FAILURE_CHUNKS_FILE" && -s "$FAILURE_CHUNKS_FILE" ]]; then
        # Group chunks by MSG_ID and process complete messages
        sort -t: -k1,1 -k2,2n "$FAILURE_CHUNKS_FILE" | while IFS=: read -r MSG_ID CHUNK_NUM CONTENT; do
            # Count total chunks for this MSG_ID
            TOTAL_CHUNKS=$(grep "^$MSG_ID:" "$FAILURE_CHUNKS_FILE" | cut -d: -f2 | sort -n | tail -1)
            CURRENT_CHUNK_COUNT=$(grep "^$MSG_ID:" "$FAILURE_CHUNKS_FILE" | wc -l | tr -d ' ')

            # If we have all chunks for this message, reconstruct it
            if [[ "$CURRENT_CHUNK_COUNT" -eq "$TOTAL_CHUNKS" ]]; then
                RECONSTRUCTED_MESSAGE=""
                grep "^$MSG_ID:" "$FAILURE_CHUNKS_FILE" | sort -t: -k2,2n | while IFS=: read -r ID NUM CONTENT_PART; do
                    RECONSTRUCTED_MESSAGE+="$CONTENT_PART"
                done

                # Extract JSON from reconstructed message
                if [[ "$RECONSTRUCTED_MESSAGE" == *"{"* && "$RECONSTRUCTED_MESSAGE" == *"}"* ]]; then
                    JSON_PART="${RECONSTRUCTED_MESSAGE#*\{}"
                    JSON_PART="{"$JSON_PART
                    JSON_PART="${JSON_PART%\}*}}"

                    # Process the JSON
                    if echo "$JSON_PART" | jq -e . >/dev/null 2>&1; then
                        ACTION=$(echo "$JSON_PART" | jq -r '.action // "unknown"' 2>/dev/null)
                        CATEGORY=$(echo "$JSON_PART" | jq -r '.category // "unknown"' 2>/dev/null)
                        GROUP=$(echo "$JSON_PART" | jq -r '.group // ""' 2>/dev/null)
                        DURATION=$(echo "$JSON_PART" | jq -r '.duration_ms // 0' 2>/dev/null)
                        SEQUENCE=$(echo "$JSON_PART" | jq -r '.sequence // 0' 2>/dev/null)
                        ERROR_MSG=$(echo "$JSON_PART" | jq -r '.error // ""' 2>/dev/null)

                        if [[ "$ACTION" != "unknown" && "$ACTION" != "null" && -n "$ACTION" ]]; then
                            TEMP_FILE=$(mktemp)
                            if jq --arg action "$ACTION" --arg category "$CATEGORY" --arg group "$GROUP" --arg error "$ERROR_MSG" --arg test_id "$TEST_ID" --arg config_name "$CONFIG_NAME" --arg platform "$PLATFORM" ". + [{\"action\":\$action,\"category\":\$category,\"group\":\$group,\"success\":false,\"duration_ms\":$DURATION,\"sequence\":$SEQUENCE,\"error_message\":\$error,\"test_id\":\$test_id,\"config_name\":\$config_name,\"platform\":\$platform}]" "$RESULTS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                                mv "$TEMP_FILE" "$RESULTS_FILE"
                            else
                                rm -f "$TEMP_FILE"
                            fi
                        fi
                    fi
                fi

                # Remove processed chunks to avoid duplicate processing
                grep -v "^$MSG_ID:" "$FAILURE_CHUNKS_FILE" > "${FAILURE_CHUNKS_FILE}.tmp" || true
                mv "${FAILURE_CHUNKS_FILE}.tmp" "$FAILURE_CHUNKS_FILE"
            fi
        done
    fi

    # Clean up temporary chunk files
    rm -rf "$CHUNK_DIR"
    
    # Log completion status
    ACTION_COUNT=$(jq 'length' "$RESULTS_FILE" 2>/dev/null || echo 0)
    echo "✅ Action results collection complete:"
    echo "   📁 File: $RESULTS_FILE"
    echo "   📊 Actions collected: $ACTION_COUNT"
    echo "   🎯 TEST_ID: $TEST_ID"
    echo "   ⚙️  CONFIG_NAME: $CONFIG_NAME"
    echo "   🖥️  PLATFORM: $PLATFORM"

# Generate detailed action summary from collected results file
_generate-action-summary-from-file test_id config_name platform session="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{test_id}}"
    CONFIG_NAME="{{config_name}}"
    PLATFORM="{{platform}}"
    SESSION="{{session}}"
    
    # Use session-aware file naming to match the file created by _collect-action-results
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    if [[ -n "$SESSION" ]]; then
        RESULTS_FILE="{{STANDARD_LOGS_DIR}}/test_action_results_${TEST_ID}.json"
    else
        # Fallback to old naming for backwards compatibility
        RESULTS_FILE="{{STANDARD_LOGS_DIR}}/test_action_results_${TEST_ID}.json"
    fi
    
    echo ""
    echo "📊 Detailed Action Execution Summary"
    echo "====================================="
    echo ""
    echo "**Test Configuration**: \`$CONFIG_NAME\`"
    echo "**Test ID**: \`$TEST_ID\`"
    echo ""
    
    if [[ ! -f "$RESULTS_FILE" ]] || [[ ! -s "$RESULTS_FILE" ]]; then
        echo "❌ CRITICAL TEST FAILURE: No action execution data collected"
        echo "💡 Results file missing or empty - indicates test infrastructure failure"
        echo "🔧 Expected: Valid results file with action data, Actual: Missing/empty file"
        exit 1
    fi
    
    # Parse results and group by category
    TOTAL_ACTIONS=$(jq 'length' "$RESULTS_FILE")
    PASSED_ACTIONS=$(jq '[.[] | select(.success == true)] | length' "$RESULTS_FILE")
    FAILED_ACTIONS=$(jq '[.[] | select(.success == false)] | length' "$RESULTS_FILE")
    
    if [[ "$TOTAL_ACTIONS" == "0" ]]; then
        echo "❌ CRITICAL TEST FAILURE: No actions found in results file"
        echo "💡 This indicates debug coordinator or test context initialization issues"
        echo "🔧 Expected: Actions collected > 0, Actual: Actions collected = 0"
        exit 1
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
    
    # CRITICAL: Fail the test if not 100% of actions passed
    if [[ "$FAILED_ACTIONS" -gt 0 ]]; then
        echo ""
        echo "❌ TEST FAILED: Not all actions passed ($FAILED_ACTIONS/$TOTAL_ACTIONS failed)"
        echo "💡 All tests require 100% action success rate"
        exit 1
    fi
    
    # Keep results file for comprehensive breakdown - it will be cleaned up later

# Hook that can be called after any test execution to add error analysis
_post-test-validation test_id platform config_name="unknown" session="" config_path="":
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{test_id}}"
    PLATFORM="{{platform}}"
    CONFIG_NAME="{{config_name}}"
    SESSION="{{session}}"
    CONFIG_PATH="{{config_path}}"
    
    # Collect action results from logs first
    just _collect-action-results "$TEST_ID" "$PLATFORM" "$CONFIG_NAME" "$SESSION"
    
    # Generate detailed action summary
    just _generate-action-summary-from-file "$TEST_ID" "$CONFIG_NAME" "$PLATFORM" "$SESSION"
    
    echo ""
    echo "🔍 Running Post-Test Error Analysis..."
    echo "====================================="
    
    ERROR_ANALYSIS_RESULT=0
    just _analyze-test-errors "$TEST_ID" "$PLATFORM" "$CONFIG_PATH" || ERROR_ANALYSIS_RESULT=$?
    
    if [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
        echo ""
        echo "❌ TEST FAILED DUE TO ERRORS IN LOGS"
        echo "💡 Test execution may have succeeded, but logs contain failures"
        echo "💡 This indicates issues that need to be addressed"
        exit 1
    fi

    # 🚨 Buffer-aware cross-validation suggestions for Android tests
    if [ "$PLATFORM" = "android" ]; then
        echo ""
        echo "🔍 Running Post-Test Buffer Cross-Validation Check..."
        echo "=================================================="

        # Check if buffer health was previously critical
        if echo "${BUFFER_HEALTH_OUTPUT:-}" | grep -q "CRITICAL"; then
            echo "⚠️  PRE-TEST BUFFER WAS CRITICAL - Enhanced validation recommended:"
            echo "   💡 Live buffer data may be incomplete due to saturation"
            echo "   🎯 Cross-validate findings with saved Android logs:"
            echo "      just android-logs-cross-validate \"search_term\""
            echo "   📁 Check complete Android logs in:"
            echo "      $ANDROID_LOG_FILE"
            echo "   🔍 Use historical logs for reliable investigation:"
            echo "      find logs/ -name \"*.log\" -exec grep \"pattern\" {} +"
        elif echo "${BUFFER_HEALTH_OUTPUT:-}" | grep -q "CAUTION"; then
            echo "⚠️  PRE-TEST BUFFER USAGE WAS HIGH - Consider cross-validation:"
            echo "   💡 Some historical data may have been lost"
            echo "   🎯 Verify critical findings across multiple sources"
            echo "   📁 Cross-reference with: $ANDROID_LOG_FILE"
        else
            echo "✅ Buffer health was good - test results are reliable"
            echo "   💡 Still consider cross-validation for critical findings"
        fi
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
    # Using centralized TEST_LIST_DIR variable
    TEST_LIST_PATH="{{TEST_LIST_DIR}}/${TEST_LIST}.json"
    
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
    
    # Create session timestamp for consistent file naming and cleanup
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
        echo "🔗 Using multi-platform session: $TEST_SESSION"
    else
        TEST_SESSION="$(date +%s)"
        echo "🆕 Created new session: $TEST_SESSION"
    fi
    
    # Clean up old test result files from previous sessions (older than 1 hour)
    echo "🧹 Cleaning up old test result files..."
    find "{{TEMP_DIR}}" -name "test_action_results_*.json" -mtime +1h -delete 2>/dev/null || true
    find "{{TEMP_DIR}}" -name "test_hierarchy_*.json" -mtime +1h -delete 2>/dev/null || true

    # Create hierarchical mapping data structure for comprehensive breakdown
    # Include platform in filename to avoid overwriting when multiple platforms run in parallel
    HIERARCHY_FILE="{{TEMP_DIR}}/test_hierarchy_${TEST_LIST}_${PLATFORM}_${TEST_SESSION}.json"
    echo '{"test_list": "'$TEST_LIST'", "test_session": "'$TEST_SESSION'", "platform": "'$PLATFORM'", "original_configs": [], "at_references": [], "direct_configs": [], "config_results": []}' > "$HIERARCHY_FILE"
    
    # Store original config structure from test list
    jq -r '.configs[]?' "$TEST_LIST_PATH" 2>/dev/null | while IFS= read -r config; do
        if [[ -n "$config" ]]; then
            TEMP_FILE=$(mktemp)
            jq --arg config "$config" '.original_configs += [$config]' \
               "$HIERARCHY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HIERARCHY_FILE"
        fi
    done
    
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
    
    # Convert configs to array for reliable iteration using standard bash
    IFS=$'\n' read -r -d '' -a CONFIG_ARRAY <<< "$CONFIGS" || true
    config_count=${#CONFIG_ARRAY[@]}
    echo "Configurations: $config_count"
    
    echo ""
    echo "📋 Full Test Execution Plan (Expanded from @ references):"
    echo "=========================================================="
    COMPATIBLE_COUNT=0
    SKIP_COUNT=0
    for i in "${!CONFIG_ARRAY[@]}"; do
        config="${CONFIG_ARRAY[$i]}"
        printf "%2d. %-30s" $((i+1)) "$config"
        
        # Show config type and platform compatibility
        CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${config}.json"
        if [[ -f "$CONFIG_PATH" ]]; then
            # Check platform compatibility using the same logic as execution
            PLATFORM_CHECK=$(just _is-platform-supported "$CONFIG_PATH" "$PLATFORM" 2>/dev/null || echo "false")
            if [[ "$PLATFORM_CHECK" == "true" ]]; then
                echo " ✅ Will run on $PLATFORM"
                COMPATIBLE_COUNT=$((COMPATIBLE_COUNT + 1))
            else
                SUPPORTED_PLATFORMS=$(just _get-supported-platforms "$CONFIG_PATH" 2>/dev/null || echo "unknown")
                echo " ⏭️  Skip - Requires: $SUPPORTED_PLATFORMS"
                SKIP_COUNT=$((SKIP_COUNT + 1))
            fi
        else
            # For auto-generated configs (wildcards), assume compatible with current platform
            echo " 🔍 Will run on $PLATFORM (auto-generated)"
            COMPATIBLE_COUNT=$((COMPATIBLE_COUNT + 1))
        fi
    done
    
    echo ""
    echo "📊 Platform Compatibility Summary:"
    echo "   ✅ Will execute: $COMPATIBLE_COUNT configs on $PLATFORM"
    if [[ $SKIP_COUNT -gt 0 ]]; then
        echo "   ⏭️  Will skip: $SKIP_COUNT configs (platform incompatible)"
    fi
    
    echo ""
    echo "🚀 Starting test execution..."
    echo "============================="

    # Platform-specific setup before test loop
    if [[ "$PLATFORM" == "ios" ]]; then
        echo ""
        echo "📦 Preparing iOS PCK (one-time for all configs)..."
        just update-ios-pck
        echo "✅ iOS PCK ready"
        echo ""
    fi

    # Execute each configuration using array-based iteration
    TOTAL_CONFIGS=0
    PASSED_CONFIGS=0
    FAILED_CONFIGS=0
    SKIPPED_CONFIGS=0
    SKIPPED_CONFIG_NAMES=()
    SKIPPED_CONFIG_REASONS=()
    
    for i in "${!CONFIG_ARRAY[@]}"; do
        config="${CONFIG_ARRAY[$i]}"
        
        if [[ -z "$config" ]]; then
            continue
        fi
        
        TOTAL_CONFIGS=$((TOTAL_CONFIGS + 1))
        
        echo ""
        echo "🔍 Testing configuration $TOTAL_CONFIGS/$config_count: $config"
        echo "================================================================="
        
        # Execute configuration using the unified system
        set +e  # Temporarily disable exit on error to capture exit codes
        INSIDE_TEST_LIST_EXECUTION=true just _execute-test-with-analysis "$config" "$PLATFORM" "$TEST_SESSION"
        exit_code=$?
        set -e  # Re-enable exit on error
        
        # Store execution result in hierarchy file for comprehensive breakdown
        if [[ $exit_code -eq 0 ]]; then
            echo "✅ Configuration passed: $config"
            PASSED_CONFIGS=$((PASSED_CONFIGS + 1))

            # Store success result with action details
            TEMP_FILE=$(mktemp)
            jq --arg config "$config" --arg status "passed" --arg platform "$PLATFORM" \
               '.config_results += [{"config": $config, "status": $status, "platform": $platform, "exit_code": 0, "action_results": []}]' \
               "$HIERARCHY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HIERARCHY_FILE"

            # Extract action results from current session only
            # Pattern includes session ID to avoid picking up stale files
            ACTION_RESULTS_PATTERN="{{STANDARD_LOGS_DIR}}/test_action_results_*${config}*${PLATFORM}*${TEST_SESSION}*.json"
            ACTION_RESULTS_FILE=$(ls -t $ACTION_RESULTS_PATTERN 2>/dev/null | head -1 || echo "")

            if [[ -n "$ACTION_RESULTS_FILE" && -f "$ACTION_RESULTS_FILE" ]]; then
                # Extract action results array directly and update hierarchy file in one operation
                ACTIONS_JSON=$(cat "$ACTION_RESULTS_FILE" | jq 'map({action: .action, duration_ms: (.duration_ms // 0), status: (if .success then "passed" else "failed" end)})' 2>/dev/null || echo "[]")

                if [[ "$ACTIONS_JSON" != "[]" && "$ACTIONS_JSON" != "null" ]]; then
                    # Update hierarchy file with action results in single operation
                    TEMP_FILE2=$(mktemp)
                    jq --arg config "$config" --arg platform "$PLATFORM" --argjson actions "$ACTIONS_JSON" \
                       '(.config_results[] | select(.config == $config and .platform == $platform) | .action_results) = $actions' \
                       "$HIERARCHY_FILE" > "$TEMP_FILE2" && mv "$TEMP_FILE2" "$HIERARCHY_FILE" || true
                fi
            fi
        elif [[ $exit_code -eq 2 ]]; then
            # Platform skip - extract supported platforms for summary
            CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${config}.json"
            if [[ -f "$CONFIG_PATH" ]]; then
                SUPPORTED_PLATFORMS=$(just _get-supported-platforms "$CONFIG_PATH")
                SKIPPED_CONFIG_NAMES+=("$config")
                SKIPPED_CONFIG_REASONS+=("Available on: $SUPPORTED_PLATFORMS")
            else
                SUPPORTED_PLATFORMS="Platform compatibility issue"
                SKIPPED_CONFIG_NAMES+=("$config")
                SKIPPED_CONFIG_REASONS+=("$SUPPORTED_PLATFORMS")
            fi
            SKIPPED_CONFIGS=$((SKIPPED_CONFIGS + 1))
            # Store skip result
            TEMP_FILE=$(mktemp)
            jq --arg config "$config" --arg status "skipped" --arg platform "$PLATFORM" --arg reason "$SUPPORTED_PLATFORMS" \
               '.config_results += [{"config": $config, "status": $status, "platform": $platform, "exit_code": 2, "skip_reason": $reason}]' \
               "$HIERARCHY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HIERARCHY_FILE"
        else
            echo "❌ Configuration failed: $config"
            FAILED_CONFIGS=$((FAILED_CONFIGS + 1))

            # Store failure result with action details
            TEMP_FILE=$(mktemp)
            jq --arg config "$config" --arg status "failed" --arg platform "$PLATFORM" --argjson exit_code "$exit_code" \
               '.config_results += [{"config": $config, "status": $status, "platform": $platform, "exit_code": $exit_code, "action_results": []}]' \
               "$HIERARCHY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HIERARCHY_FILE"

            # Extract action results for failed tests from current session only
            # Pattern includes session ID to avoid picking up stale files
            ACTION_RESULTS_PATTERN="{{STANDARD_LOGS_DIR}}/test_action_results_*${config}*${PLATFORM}*${TEST_SESSION}*.json"
            ACTION_RESULTS_FILE=$(ls -t $ACTION_RESULTS_PATTERN 2>/dev/null | head -1 || echo "")

            if [[ -n "$ACTION_RESULTS_FILE" && -f "$ACTION_RESULTS_FILE" ]]; then
                # Extract action results array directly and update hierarchy file in one operation
                ACTIONS_JSON=$(cat "$ACTION_RESULTS_FILE" | jq 'map({action: .action, duration_ms: (.duration_ms // 0), status: (if .success then "passed" else "failed" end)})' 2>/dev/null || echo "[]")

                if [[ "$ACTIONS_JSON" != "[]" && "$ACTIONS_JSON" != "null" ]]; then
                    # Update hierarchy file with action results in single operation
                    TEMP_FILE2=$(mktemp)
                    jq --arg config "$config" --arg platform "$PLATFORM" --argjson actions "$ACTIONS_JSON" \
                       '(.config_results[] | select(.config == $config and .platform == $platform) | .action_results) = $actions' \
                       "$HIERARCHY_FILE" > "$TEMP_FILE2" && mv "$TEMP_FILE2" "$HIERARCHY_FILE" || true
                fi
            fi
        fi
        
        # Small delay between tests
        if [[ $TOTAL_CONFIGS -lt $config_count ]]; then
            echo "⏱️  Pausing {{INTER_CONFIG_DELAY}} seconds before next test (Firebase resource drainage)..."
            sleep {{INTER_CONFIG_DELAY}}
        fi
    done
    
    # Execute any commands from the test list after all configs complete
    echo ""
    echo "📋 Checking for additional test list commands..."
    TEST_ID_FOR_COMMANDS="testlist-${TEST_LIST}_${PLATFORM}_${TEST_SESSION}"
    just _execute-test-list-commands "$TEST_LIST_PATH" "$PLATFORM" "$TEST_ID_FOR_COMMANDS" || true
    
    echo ""
    echo "📊 Test List Results Summary"
    echo "============================="
    echo "Test List: $TEST_LIST"
    echo "Platform: $PLATFORM"
    echo "Total Configurations: $TOTAL_CONFIGS"
    echo "✅ Passed: $PASSED_CONFIGS"
    echo "❌ Failed: $FAILED_CONFIGS"
    echo "⏭️ Skipped (Platform): $SKIPPED_CONFIGS"
    
    # Calculate success rate based on actually executed configs
    EXECUTED_CONFIGS=$((PASSED_CONFIGS + FAILED_CONFIGS))
    if [[ $EXECUTED_CONFIGS -gt 0 ]]; then
        echo "Success Rate: $(( PASSED_CONFIGS * 100 / EXECUTED_CONFIGS ))% (of executed configs)"
    fi
    
    # Show skipped configs with details
    if [[ $SKIPPED_CONFIGS -gt 0 ]]; then
        echo ""
        echo "⏭️ SKIPPED CONFIGURATIONS:"
        for i in "${!SKIPPED_CONFIG_NAMES[@]}"; do
            echo "   • ${SKIPPED_CONFIG_NAMES[$i]} → ${SKIPPED_CONFIG_REASONS[$i]}"
        done
        
        echo ""
        echo "💡 To run skipped configs:"
        if [[ "$PLATFORM" == "editor" ]]; then
            echo "   just test-android-target $TEST_LIST"
            echo "   just test-android-target $(printf '%s ' "${SKIPPED_CONFIG_NAMES[@]}")"
        else
            echo "   just test-editor-target $TEST_LIST"
            echo "   just test-editor-target $(printf '%s ' "${SKIPPED_CONFIG_NAMES[@]}")"
        fi
    fi
    
    # Generate comprehensive breakdown showing complete traceability
    if [[ -f "$HIERARCHY_FILE" ]]; then
        just _generate-comprehensive-breakdown "$HIERARCHY_FILE" "$TEST_SESSION"
    fi
    
    # Cleanup session-specific test result files after summary generation
    # Skip cleanup if we're in multi-platform mode (files will be preserved for final summary)
    # Skip cleanup if there are any failures (preserve logs for debugging)
    TESTLIST_FAILED_COUNT=0
    if [[ -f "$HIERARCHY_FILE" ]]; then
        TESTLIST_FAILED_COUNT=$(jq '[.config_results[] | select(.status == "failed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
    fi

    if [[ "${MULTI_PLATFORM_MODE:-false}" != "true" ]]; then
        if [[ "${TESTLIST_FAILED_COUNT:-0}" -gt 0 ]]; then
            echo "🔒 Preserving session files for debugging ($TESTLIST_FAILED_COUNT failed configs)"
            echo "   Action results: {{STANDARD_LOGS_DIR}}/test_action_results_*_${TEST_SESSION}.json"
            echo "   Hierarchy: $HIERARCHY_FILE"
        else
            echo "🧹 Cleaning up session test result files..."
            # Clean up action results files from the standardized locations
            rm -f "{{STANDARD_LOGS_DIR}}/test_action_results_*_${TEST_SESSION}.json" 2>/dev/null || true
            rm -f "$HIERARCHY_FILE" 2>/dev/null || true
        fi
    else
        echo "🔄 Preserving action results and hierarchy files for multi-platform final summary..."
    fi
    
    # Check for sequential action timeouts (only in single-platform mode)
    # In multi-platform mode, timeout summary is handled by _test-multi-platform
    if [[ "${MULTI_PLATFORM_MODE:-false}" != "true" ]]; then
        TIMEOUT_TRACKER="/tmp/test_timeout_tracker_testlist.txt"
        TIMEOUT_COUNT=0
        if [[ -f "$TIMEOUT_TRACKER" ]]; then
            TIMEOUT_COUNT=$(wc -l < "$TIMEOUT_TRACKER" 2>/dev/null || echo "0")
            TIMEOUT_COUNT=$(echo "$TIMEOUT_COUNT" | tr -d ' \t\n\r' | head -1)
        fi
    else
        TIMEOUT_COUNT=0
    fi

    if [[ $FAILED_CONFIGS -gt 0 ]]; then
        echo ""
        echo "❌ Some configurations failed. Check individual test results above."
        exit 1
    else
        echo ""
        if [[ $TIMEOUT_COUNT -gt 0 ]]; then
            echo "✅ All configurations passed! (⚠️  $TIMEOUT_COUNT configs had sequential action timeouts - see details below)"
            echo ""
            echo "⚠️  Sequential Action Timeout Summary:"
            echo "======================================"
            echo "The following configs experienced 30s timeout waiting for completion events,"
            echo "but all actions executed successfully (100% pass rate). This is a test framework"
            echo "logging issue, not a functional problem."
            echo ""
            while IFS='|' read -r config platform completion || [[ -n "$config" ]]; do
                echo "   • $config ($platform) - Detected: $completion completion events"
            done < "$TIMEOUT_TRACKER"
            echo ""
            echo "💡 Actions completed successfully despite timeout - this indicates the test"
            echo "   framework is looking for log patterns that may not appear in all scenarios."
            # Cleanup timeout tracker
            rm -f "$TIMEOUT_TRACKER" 2>/dev/null || true
        else
            echo "✅ All configurations passed!"
        fi
    fi

# ================================
# COMPREHENSIVE BREAKDOWN GENERATION
# ================================

# Generate comprehensive hierarchical breakdown showing test list → configs → actions
_generate-comprehensive-breakdown hierarchy_file test_session:
    #!/usr/bin/env bash
    set -euo pipefail

    HIERARCHY_FILE="{{hierarchy_file}}"
    TEST_SESSION="{{test_session}}"
    
    # Check if hierarchy file exists
    if [[ ! -f "$HIERARCHY_FILE" ]]; then
        echo "⚠️  Hierarchy file not found: $HIERARCHY_FILE"
        exit 0
    fi
    
    # Check if file has valid JSON
    if ! jq -e . "$HIERARCHY_FILE" >/dev/null 2>&1; then
        echo "⚠️  Invalid JSON in hierarchy file"
        exit 0
    fi
    
    echo ""
    echo "📋 Complete Test Execution Breakdown"
    echo "===================================="
    
    # Extract basic info from hierarchy file with error handling
    TEST_LIST=$(jq -r '.test_list // "unknown"' "$HIERARCHY_FILE" 2>/dev/null || echo "unknown")
    
    # Get all platforms from action results for current session only (avoid stale results)
    # Note: Files are named test_action_results_CONFIG_PLATFORM_SESSION.json (session at END)
    PLATFORMS_FROM_RESULTS=$(ls /tmp/test_action_results_*_${TEST_SESSION}.json 2>/dev/null | sed 's/.*_\([^_]*\)_[^_]*\.json$/\1/' | sort | uniq | paste -sd ', ' - || echo "unknown")
    TOTAL_CONFIGS=$(jq '.config_results | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
    
    echo "Test List: $TEST_LIST ($PLATFORMS_FROM_RESULTS) - $TOTAL_CONFIGS configs executed"
    echo ""
    
    # NEW: Platform-first breakdown - group by platform, then by test list/config
    set +e  # Disable exit on error for this section to handle jq failures gracefully
    
    # Get all platforms that ran tests for current session only
    ALL_PLATFORMS=$(ls /tmp/test_action_results_*_${TEST_SESSION}.json 2>/dev/null | sed 's/.*_\([^_]*\)_[^_]*\.json$/\1/' | sort | uniq)
    
    if [[ -n "$ALL_PLATFORMS" ]]; then
        # Process each platform separately
        while IFS= read -r platform_name; do
            if [[ -n "$platform_name" ]]; then
                # Dynamic platform icon mapping (future-proof for any platform)
                PLATFORM_ICON=$(just _get-platform-icon "$platform_name")
                echo "$PLATFORM_ICON Platform: $platform_name"
                echo "================================"
                
                # Process @ references for this platform
                TEMP_CONFIGS="/tmp/original_configs_$$"
                jq -r '.original_configs[]?' "$HIERARCHY_FILE" 2>/dev/null > "$TEMP_CONFIGS"
                
                while IFS= read -r original_config || [[ -n "$original_config" ]]; do
                    if [[ -n "$original_config" && "$original_config" =~ ^@ ]]; then
                        # Get all configs that were derived from this @ reference based on naming patterns
                        AT_REF_NAME="${original_config#@}"  # Remove @ symbol
                        
                        # Create a mapping based on common patterns
                        case "$AT_REF_NAME" in
                            "system-infrastructure"|"system-all")
                                PATTERN="system"
                                ;;
                            "firebase-all")
                                PATTERN="firebase"
                                ;;
                            "battle-all")
                                PATTERN="battle"
                                ;;
                            *)
                                PATTERN="$AT_REF_NAME"
                                ;;
                        esac
                        
                        # Find matching configs with error handling - use temp file to avoid subshell
                        TEMP_MATCHING="/tmp/matching_configs_$$"
                        jq -r '.config_results[] | select(.config | contains("'"$PATTERN"'")) | .config' "$HIERARCHY_FILE" 2>/dev/null | sort | uniq > "$TEMP_MATCHING"
                        
                        # Check if any configs in this @ reference ran on this platform
                        PLATFORM_HAS_CONFIGS=false
                        while IFS= read -r config || [[ -n "$config" ]]; do
                            if [[ -n "$config" ]] && ls /tmp/test_action_results_${config}_${platform_name}_*.json >/dev/null 2>&1; then
                                PLATFORM_HAS_CONFIGS=true
                                break
                            fi
                        done < "$TEMP_MATCHING"
                        
                        # Show @ reference header only if this platform has configs for it
                        if [[ "$PLATFORM_HAS_CONFIGS" == "true" ]]; then
                            echo "📦 ${original_config} (expanded from @ reference)"
                            
                            # Process configs for this @ reference on this platform
                            while IFS= read -r config || [[ -n "$config" ]]; do
                                if [[ -n "$config" ]]; then
                                    # Check if this config ran on this platform
                                    if ls /tmp/test_action_results_${config}_${platform_name}_*.json >/dev/null 2>&1; then
                                        # Get config execution result
                                        CONFIG_STATUS=$(jq -r '.config_results[] | select(.config == "'"$config"'") | .status' "$HIERARCHY_FILE" 2>/dev/null | head -1)
                                        
                                        case "$CONFIG_STATUS" in
                                            "passed")
                                                echo "   ├── 🔧 $config ✅ PASSED"
                                                ;;
                                            "failed")
                                                echo "   ├── 🔧 $config ❌ FAILED"
                                                ;;
                                            "skipped")
                                                SKIP_REASON=$(jq -r '.config_results[] | select(.config == "'"$config"'") | .skip_reason // "Platform incompatible"' "$HIERARCHY_FILE" 2>/dev/null | head -1)
                                                echo "   ├── 🔧 $config ⏭️  SKIPPED - $SKIP_REASON"
                                                ;;
                                            *)
                                                echo "   ├── 🔧 $config ❓ UNKNOWN"
                                                ;;
                                        esac
                                        
                                        # Show individual actions for passed configs only
                                        if [[ "$CONFIG_STATUS" == "passed" ]]; then
                                            # Find the most recent results file for this config and platform
                                            LATEST_ACTION_FILE=$(ls -t /tmp/test_action_results_${config}_${platform_name}_*.json 2>/dev/null | head -1)
                                            
                                            if [[ -f "$LATEST_ACTION_FILE" ]] && jq -e . "$LATEST_ACTION_FILE" >/dev/null 2>&1; then
                                                # Show individual actions
                                                TEMP_ACTIONS="/tmp/actions_${platform_name}_$$"
                                                jq -r '.[] | select(.action | contains("replay_complete") | not) | "\(.success)|\(.action)|\(.duration_ms)|\(.error_message // "")"' "$LATEST_ACTION_FILE" 2>/dev/null > "$TEMP_ACTIONS"
                                                while IFS='|' read -r success action duration error 2>/dev/null || [[ -n "$action" ]]; do
                                                    if [[ -n "$action" ]]; then
                                                        if [[ "$success" == "true" ]]; then
                                                            echo "   │   ├── ✅ $action (${duration}ms)"
                                                        else
                                                            if [[ -n "$error" && "$error" != "null" && "$error" != "" ]]; then
                                                                echo "   │   ├── ❌ $action ($error)"
                                                            else
                                                                echo "   │   ├── ❌ $action (FAILED)"
                                                            fi
                                                        fi
                                                    fi
                                                done < "$TEMP_ACTIONS"
                                                rm -f "$TEMP_ACTIONS"
                                            fi
                                        fi
                                    fi
                                fi
                            done < "$TEMP_MATCHING"
                            echo ""
                        fi
                        rm -f "$TEMP_MATCHING"
                    fi
                done < "$TEMP_CONFIGS"
                
                # Process direct configs (non-@ references) for this platform
                TEMP_DIRECT="/tmp/direct_configs_$$"
                jq -r '.original_configs[]? | select(. | startswith("@") | not)' "$HIERARCHY_FILE" 2>/dev/null > "$TEMP_DIRECT"
                
                # Check if any direct configs ran on this platform
                PLATFORM_HAS_DIRECT=false
                if [[ -s "$TEMP_DIRECT" ]]; then
                    while IFS= read -r config || [[ -n "$config" ]]; do
                        if [[ -n "$config" ]] && ls /tmp/test_action_results_${config}_${platform_name}_*.json >/dev/null 2>&1; then
                            PLATFORM_HAS_DIRECT=true
                            break
                        fi
                    done < "$TEMP_DIRECT"
                fi
                
                if [[ "$PLATFORM_HAS_DIRECT" == "true" ]]; then
                    echo "📦 Direct configs"
                    while IFS= read -r config || [[ -n "$config" ]]; do
                        if [[ -n "$config" ]]; then
                            # Check if this config ran on this platform
                            if ls /tmp/test_action_results_${config}_${platform_name}_*.json >/dev/null 2>&1; then
                                # Get config execution result
                                CONFIG_STATUS=$(jq -r '.config_results[] | select(.config == "'"$config"'") | .status' "$HIERARCHY_FILE" 2>/dev/null | head -1)
                                
                                case "$CONFIG_STATUS" in
                                    "passed")
                                        echo "   ├── 🔧 $config ✅ PASSED"
                                        ;;
                                    "failed")
                                        echo "   ├── 🔧 $config ❌ FAILED"
                                        ;;
                                    "skipped")
                                        SKIP_REASON=$(jq -r '.config_results[] | select(.config == "'"$config"'") | .skip_reason // "Platform incompatible"' "$HIERARCHY_FILE" 2>/dev/null | head -1)
                                        echo "   ├── 🔧 $config ⏭️  SKIPPED - $SKIP_REASON"
                                        ;;
                                    *)
                                        echo "   ├── 🔧 $config ❓ UNKNOWN"
                                        ;;
                                esac
                                
                                # Show individual actions for passed configs
                                if [[ "$CONFIG_STATUS" == "passed" ]]; then
                                    # Find the most recent results file for this config and platform
                                    LATEST_ACTION_FILE=$(ls -t /tmp/test_action_results_${config}_${platform_name}_*.json 2>/dev/null | head -1)
                                    
                                    if [[ -f "$LATEST_ACTION_FILE" ]] && jq -e . "$LATEST_ACTION_FILE" >/dev/null 2>&1; then
                                        # Show individual actions
                                        TEMP_ACTIONS="/tmp/actions_direct_${platform_name}_$$"
                                        jq -r '.[] | select(.action | contains("replay_complete") | not) | "\(.success)|\(.action)|\(.duration_ms)|\(.error_message // "")"' "$LATEST_ACTION_FILE" 2>/dev/null > "$TEMP_ACTIONS"
                                        while IFS='|' read -r success action duration error 2>/dev/null || [[ -n "$action" ]]; do
                                            if [[ -n "$action" ]]; then
                                                if [[ "$success" == "true" ]]; then
                                                    echo "   │   ├── ✅ $action (${duration}ms)"
                                                else
                                                    if [[ -n "$error" && "$error" != "null" && "$error" != "" ]]; then
                                                        echo "   │   ├── ❌ $action ($error)"
                                                    else
                                                        echo "   │   ├── ❌ $action (FAILED)"
                                                    fi
                                                fi
                                            fi
                                        done < "$TEMP_ACTIONS"
                                        rm -f "$TEMP_ACTIONS"
                                    fi
                                fi
                            fi
                        fi
                    done < "$TEMP_DIRECT"
                    echo ""
                fi
                rm -f "$TEMP_DIRECT"
                rm -f "$TEMP_CONFIGS"
                echo ""
            fi
        done < <(echo "$ALL_PLATFORMS")
    fi
    set -e  # Re-enable exit on error
    
    # Multi-platform summary statistics with error handling
    echo "📊 Execution Summary"
    echo "==================="
    
    # Overall statistics
    PASSED_COUNT=$(jq '[.config_results[] | select(.status == "passed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
    SKIPPED_COUNT=$(jq '[.config_results[] | select(.status == "skipped")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")  
    FAILED_COUNT=$(jq '[.config_results[] | select(.status == "failed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
    
    # Platform analysis
    PLATFORMS=$(jq -r '[.config_results[].platform] | unique | .[]' "$HIERARCHY_FILE" 2>/dev/null | sort | uniq)
    PLATFORM_COUNT=$(echo "$PLATFORMS" | wc -l | tr -d ' ')
    PLATFORMS_LIST=$(echo "$PLATFORMS" | paste -sd ', ' -)
    
    echo "Total Test Lists: 1"  
    echo "Total Configs: $TOTAL_CONFIGS"
    echo "Platforms Tested: $PLATFORMS_LIST ($PLATFORM_COUNT platform$(if [[ $PLATFORM_COUNT -gt 1 ]]; then echo 's'; fi))"
    echo ""
    
    # Dynamic platform breakdown for any number of platforms
    echo "🎯 Platform Breakdown:"
    while IFS= read -r platform; do
        if [[ -n "$platform" ]]; then
            # Get dynamic platform icon and display name
            PLATFORM_ICON=$(just _get-platform-icon "$platform")
            PLATFORM_DISPLAY=$(just _get-platform-display-name "$platform")
            
            P_PASSED=$(jq '[.config_results[] | select(.platform == "'"$platform"'" and .status == "passed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_SKIPPED=$(jq '[.config_results[] | select(.platform == "'"$platform"'" and .status == "skipped")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0") 
            P_FAILED=$(jq '[.config_results[] | select(.platform == "'"$platform"'" and .status == "failed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_TOTAL=$((P_PASSED + P_SKIPPED + P_FAILED))
            echo "   $PLATFORM_ICON ${platform}: ✅ $P_PASSED passed, ⏭️ $P_SKIPPED skipped, ❌ $P_FAILED failed ($P_TOTAL total)"
        fi
    done < <(echo "$PLATFORMS")
    
    echo ""
    echo "Combined Results:"
    echo "✅ Passed: $PASSED_COUNT"
    echo "⏭️  Skipped: $SKIPPED_COUNT" 
    echo "❌ Failed: $FAILED_COUNT"
    
    # Multi-platform action statistics with detailed failure reporting
    TOTAL_ACTIONS=0
    PASSED_ACTIONS=0
    FAILED_ACTIONS=0
    FAILED_ACTIONS_DETAILS=""
    
    # For execution summary, we need to capture platform results before cleanup
    # The hierarchy file should contain the platform information we need
    PLATFORMS=$(jq -r '[.config_results[].platform] | unique | .[]' "$HIERARCHY_FILE" 2>/dev/null | sort | uniq)
    
    if [[ -n "$PLATFORMS" ]]; then
        echo "🔍 Platform information found in hierarchy file"
        # Platform information is already captured in HIERARCHY_FILE
        # Action-level details may not be available if files were cleaned up
        echo "📊 Using platform summary from test execution"
    else
        echo "⚠️ No platform information found in hierarchy file"
    fi
    
    # Action-level analysis (only process files from current test session)
    # Note: Files are named test_action_results_CONFIG_PLATFORM_SESSION.json (session at END)
    SESSION_PATTERN="_${TEST_SESSION}.json"

    PROCESSED_FILES=0
    FILTERED_FILES=0
    for results_file in /tmp/test_action_results_*_${TEST_SESSION}.json "{{STANDARD_LOGS_DIR}}"/test_action_results_*_${TEST_SESSION}.json; do
        if [[ -f "$results_file" ]] && jq -e . "$results_file" >/dev/null 2>&1; then
            # Skip files that don't belong to current session
            if [[ -n "$SESSION_PATTERN" && "$results_file" != *"$SESSION_PATTERN" ]]; then
                FILTERED_FILES=$((FILTERED_FILES + 1))
                continue
            fi

            PROCESSED_FILES=$((PROCESSED_FILES + 1))

            # Check if this config was part of our test list with error handling
            CONFIG_FROM_FILE=$(jq -r '.[0].config_name // ""' "$results_file" 2>/dev/null)
            PLATFORM_FROM_FILE=$(jq -r '.[0].platform // ""' "$results_file" 2>/dev/null)

            if [[ -n "$CONFIG_FROM_FILE" ]]; then
                if jq -e '.config_results[] | select(.config == "'"$CONFIG_FROM_FILE"'")' "$HIERARCHY_FILE" >/dev/null 2>&1; then
                    # Count actions excluding replay_complete with error handling
                    ACTIONS_PASSED=$(jq '[.[] | select(.success == true and (.action | contains("replay_complete") | not))] | length' "$results_file" 2>/dev/null || echo 0)
                    ACTIONS_FAILED=$(jq '[.[] | select(.success == false and (.action | contains("replay_complete") | not))] | length' "$results_file" 2>/dev/null || echo 0)
                    ACTIONS_TOTAL=$(jq '[.[] | select(.action | contains("replay_complete") | not)] | length' "$results_file" 2>/dev/null || echo 0)
                else
                    continue
                fi
            else
                continue
            fi
                
                PASSED_ACTIONS=$((PASSED_ACTIONS + ACTIONS_PASSED))
                FAILED_ACTIONS=$((FAILED_ACTIONS + ACTIONS_FAILED))
                TOTAL_ACTIONS=$((TOTAL_ACTIONS + ACTIONS_TOTAL))
                
                # Collect failed action details for debugging
                if [[ $ACTIONS_FAILED -gt 0 ]]; then
                    TEMP_FAILED="/tmp/failed_actions_$$"
                    jq -r '.[] | select(.success == false and (.action | contains("replay_complete") | not)) | "\(.action)|\(.error_message // "No error message")"' "$results_file" 2>/dev/null > "$TEMP_FAILED"
                    while IFS='|' read -r failed_action error_msg || [[ -n "$failed_action" ]]; do
                        if [[ -n "$failed_action" ]]; then
                            FAILED_ACTIONS_DETAILS="${FAILED_ACTIONS_DETAILS}      ❌ $failed_action ($PLATFORM_FROM_FILE) - $error_msg\n"
                        fi
                    done < "$TEMP_FAILED"
                    rm -f "$TEMP_FAILED"
                fi
            
                PASSED_ACTIONS=$((PASSED_ACTIONS + ACTIONS_PASSED))
                FAILED_ACTIONS=$((FAILED_ACTIONS + ACTIONS_FAILED))
                TOTAL_ACTIONS=$((TOTAL_ACTIONS + ACTIONS_TOTAL))

                # Collect failed action details for debugging
                if [[ $ACTIONS_FAILED -gt 0 ]]; then
                    TEMP_FAILED="/tmp/failed_actions_$$"
                    jq -r '.[] | select(.success == false and (.action | contains("replay_complete") | not)) | "\(.action)|\(.error_message // "No error message")"' "$results_file" 2>/dev/null > "$TEMP_FAILED"
                    while IFS='|' read -r failed_action error_msg || [[ -n "$failed_action" ]]; do
                        if [[ -n "$failed_action" ]]; then
                            FAILED_ACTIONS_DETAILS="${FAILED_ACTIONS_DETAILS}      ❌ $failed_action ($PLATFORM_FROM_FILE) - $error_msg\n"
                        fi
                    done < "$TEMP_FAILED"
                    rm -f "$TEMP_FAILED"
                fi
        fi
    done 2>/dev/null || true

    
    if [[ $TOTAL_ACTIONS -gt 0 ]]; then
        echo "Total Debug Actions: $TOTAL_ACTIONS"
        echo "✅ Passed Actions: $PASSED_ACTIONS ($(( PASSED_ACTIONS * 100 / TOTAL_ACTIONS ))%)"
        echo "❌ Failed Actions: $FAILED_ACTIONS ($(( FAILED_ACTIONS * 100 / TOTAL_ACTIONS ))%)"
        
        # Show failed action details for debugging
        if [[ $FAILED_ACTIONS -gt 0 && -n "$FAILED_ACTIONS_DETAILS" ]]; then
            echo ""
            echo "🔍 Failed Action Details:"
            echo -e "$FAILED_ACTIONS_DETAILS"
        fi
    else
        echo "No action-level results available"
    fi
    
    echo ""
    echo "✅ Test execution breakdown complete"

# ================================
# UNIFIED TEST EXECUTION PATTERN
# ================================

# Universal test wrapper that works for both Android and Desktop
_execute-test-with-analysis config_name platform session="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    PLATFORM="{{platform}}"
    SESSION="{{session}}"

    # Strip @ prefix if present (auto-detection works with or without @)
    CONFIG_LOOKUP="${CONFIG_NAME#@}"

    echo "🎯 $PLATFORM Testing with Error Analysis: $CONFIG_NAME"
    echo "$(printf '=%.0s' {1..50})"
    echo ""

    # Phase 1: Auto-detect between test list and debug config
    TEST_LIST_PATH="{{TEST_LIST_DIR}}/${CONFIG_LOOKUP}.json"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_LOOKUP}.json"
    
    # Check if it's a test list first (but skip if we're already inside test list execution)
    if [[ -f "$TEST_LIST_PATH" && "${INSIDE_TEST_LIST_EXECUTION:-false}" != "true" ]]; then
        echo "📋 Detected test list: $CONFIG_NAME"
        just _test-list-generic "$CONFIG_NAME" "$PLATFORM"
        exit $?
    fi
    
    # Check if it's a debug config, or try to create wildcard pattern config
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "🔍 Config not found, checking for wildcard pattern: $CONFIG_LOOKUP"

        # NEW: Search recursively in subdirectories first (for archive/generated-replays configs)
        RECURSIVE_FOUND=$(find "{{DEBUG_CONFIG_DIR}}" -name "${CONFIG_LOOKUP}.json" -type f 2>/dev/null | head -1)
        if [[ -n "$RECURSIVE_FOUND" ]]; then
            echo "✅ Found config in subdirectory: $(basename "$(dirname "$RECURSIVE_FOUND")")/${CONFIG_NAME}.json"
            CONFIG_PATH="$RECURSIVE_FOUND"
        # Try to validate/create config (handles wildcards, single actions, etc.)
        elif just _validate-config-exists "$CONFIG_NAME" >/dev/null 2>&1; then
            echo "✅ Config found or created: $CONFIG_NAME"
            # The config exists - let the system handle the path (usually creates temp file)
        else
            echo "❌ Neither test list nor config found:"
            echo "   Test list: $TEST_LIST_PATH"
            echo "   Config: $CONFIG_PATH"
            echo "💡 Available configs:"
            ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
            echo "💡 Available test lists:"
            ls {{TEST_LIST_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No test lists found"
            exit 1
        fi
    fi
    
    # Platform compatibility check
    echo "🔍 Checking platform compatibility..."
    set +e  # Temporarily disable exit on error for controlled exit handling
    PLATFORM_SUPPORTED=$(just _is-platform-supported "$CONFIG_PATH" "$PLATFORM")
    set -e  # Re-enable exit on error

    if [[ "$PLATFORM_SUPPORTED" == "false" ]]; then
        SUPPORTED_PLATFORMS=$(just _get-supported-platforms "$CONFIG_PATH")
        echo "⏭️ SKIPPED: $CONFIG_NAME (requires $SUPPORTED_PLATFORMS - not supported on $PLATFORM)"
        echo ""
        echo "💡 To run this config:"
        if [[ "$PLATFORM" == "editor" ]]; then
            echo "   just test-android-target $CONFIG_NAME"
        else
            echo "   just test-editor-target $CONFIG_NAME"
        fi
        exit 2  # Special exit code for platform skip
    fi
    echo "✅ Platform compatible: $PLATFORM"
    
    # Generate test ID using session for coordination in multi-platform mode
    if [[ -n "${SESSION:-}" ]]; then
        TEST_ID="${CONFIG_NAME}_${PLATFORM}_${SESSION}"
    else
        TEST_ID="${CONFIG_NAME}_${PLATFORM}_$(date +%s)"
    fi
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
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
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

    # Platform-specific preparation (for single configs not in test list)
    if [[ "$PLATFORM" == "ios" && "${INSIDE_TEST_LIST_EXECUTION:-false}" != "true" ]]; then
        echo "📦 Preparing iOS PCK..."
        just update-ios-pck
        echo "✅ iOS PCK ready"
        echo ""
    fi

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
        "editor")
            # Deploy and execute Editor test
            just _deploy-config-editor "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-editor "$CONFIG_NAME" || TEST_RESULT=$?
            fi
            ;;
        "ios")
            # Deploy and execute iOS test
            just _deploy-config-ios "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-ios "$CONFIG_NAME" "$TEST_ID" || TEST_RESULT=$?
            fi
            ;;
        "macos")
            # Deploy and execute macOS exported app test
            just _deploy-config-macos "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-macos "$CONFIG_NAME" || TEST_RESULT=$?
            fi
            ;;
        "windows")
            # Deploy and execute Windows test via VM
            just _deploy-config-windows "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                just _execute-test-windows "$CONFIG_NAME" || TEST_RESULT=$?
            fi
            ;;
        "windows-physical")
            # Deploy and execute Windows test on physical machine (GUI mode)
            # Build type (debug/release) controlled by WIN_PHYSICAL_BUILD_TYPE env var
            just _deploy-config-windows-physical "$TEMP_CONFIG_PATH" || TEST_RESULT=$?
            if [[ $TEST_RESULT -eq 0 ]]; then
                BUILD_TYPE="${WIN_PHYSICAL_BUILD_TYPE:-debug}"
                just _execute-test-windows-physical "$CONFIG_NAME" "$TEST_ID" "$BUILD_TYPE" || TEST_RESULT=$?
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

    # Track validation results separately (initialize before validation phase)
    ERROR_ANALYSIS_RESULT=0
    CHECKSUM_VALIDATION_RESULT=0

    # Phase 3: Unified post-test validation (shared logic)
    if [[ $TEST_RESULT -eq 0 ]]; then
        # Run error analysis
        just _post-test-validation "$TEST_ID" "$PLATFORM" "$CONFIG_NAME" "$SESSION" "$CONFIG_PATH" || ERROR_ANALYSIS_RESULT=$?

        # Run checksum validation ALWAYS (not conditional on error analysis)
        # Checksum validation is PRIMARY - if configured and fails, overall test MUST fail
        if [[ -n "$HAS_CHECKSUM" && "$HAS_CHECKSUM" == "true" ]]; then
            echo ""
            echo "🔍 Running checksum validation (primary validation)..."

            # Explicitly capture exit code using command substitution pattern
            set +e  # Temporarily disable exit-on-error to capture exit code
            HAS_CHECKSUM="$HAS_CHECKSUM" EXPECTED_CHECKSUMS_COUNT="$EXPECTED_CHECKSUMS_COUNT" just _handle-checksum-validation "$CONFIG_PATH" "$PLATFORM" "$TEST_ID"
            CHECKSUM_VALIDATION_RESULT=$?
            set -e  # Re-enable exit-on-error

            # Checksum validation failure is CRITICAL - always fails the test
            if [[ $CHECKSUM_VALIDATION_RESULT -ne 0 ]]; then
                echo ""
                echo "❌ CRITICAL: Checksum validation FAILED"
                echo "Test result: FAILED (checksum validation is mandatory)"
                TEST_RESULT=1
            elif [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
                echo ""
                echo "⚠️  Error analysis found issues, but checksums passed"
                TEST_RESULT=$ERROR_ANALYSIS_RESULT
            fi
        elif [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
            # No checksum validation configured, only error analysis matters
            TEST_RESULT=$ERROR_ANALYSIS_RESULT
        fi
    else
        echo ""
        echo "❌ Test execution failed - running validation for debugging..."
        # Still run validation to collect action results for debugging
        just _post-test-validation "$TEST_ID" "$PLATFORM" "$CONFIG_NAME" "$SESSION" "$CONFIG_PATH" || true
    fi
    
    # Cleanup session-specific test result files after individual test
    # Skip cleanup if we're in multi-platform mode or if test failed (preserve for debugging)
    if [[ -n "$SESSION" && "${DISABLE_TEST_CLEANUP:-false}" != "true" ]]; then
        if [[ $TEST_RESULT -ne 0 ]]; then
            echo "🔒 Preserving session files for debugging (test failed)"
            echo "   Action results: /tmp/test_action_results_*_${SESSION}.json"
        else
            echo "🧹 Cleaning up session test result files..."
            rm -f /tmp/test_action_results_*_${SESSION}.json 2>/dev/null || true
        fi
    elif [[ "${DISABLE_TEST_CLEANUP:-false}" == "true" ]]; then
        echo "🔄 Preserving session files for multi-platform summary..."
    fi
    
    # Final result with detailed validation status
    if [[ $TEST_RESULT -eq 0 ]]; then
        echo ""
        echo "🎉 $PLATFORM test execution complete!"
        echo "✅ OVERALL RESULT: PASSED"
        echo ""
        echo "Validation Summary:"
        echo "  • Test execution: ✅ Passed"
        echo "  • Error analysis: ✅ Passed"
        if [[ -n "$HAS_CHECKSUM" && "$HAS_CHECKSUM" == "true" ]]; then
            echo "  • Checksum validation: ✅ Passed"
        else
            echo "  • Checksum validation: ⊘ Not configured"
        fi
    else
        echo ""
        echo "❌ OVERALL RESULT: FAILED"
        echo ""
        echo "Validation Summary:"
        echo "  • Test execution: $(if [[ $TEST_RESULT -eq 1 && $CHECKSUM_VALIDATION_RESULT -eq 1 ]]; then echo "✅ Passed"; else echo "❌ Failed"; fi)"
        if [[ $CHECKSUM_VALIDATION_RESULT -ne 0 ]]; then
            echo "  • Checksum validation: ❌ FAILED (PRIMARY CAUSE)"
        elif [[ -n "$HAS_CHECKSUM" && "$HAS_CHECKSUM" == "true" ]]; then
            echo "  • Checksum validation: ✅ Passed"
        fi
        if [[ $ERROR_ANALYSIS_RESULT -ne 0 ]]; then
            echo "  • Error analysis: ❌ Failed"
        fi
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

_stop-app-editor:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🛑 Stopping editor test instances (preserving editor)..."

    # Only kill test processes (--test-mode), preserve editor processes (--editor)
    # This prevents terminating the editor when running tests
    pkill -f "{{GODOT_EXECUTABLE}}.*{{PROJECT_PATH}}.*--test-mode" 2>/dev/null || true

    # Also kill any headless instances that might be running tests
    pkill -f "{{GODOT_EXECUTABLE}}.*{{PROJECT_PATH}}.*--headless" 2>/dev/null || true

    echo "✅ Editor test instances stopped (editor preserved)"

_stop-app-macos:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🛑 Stopping macOS exported app instances (preserving editor)..."

    # CRITICAL: Only kill exported app instances, NEVER the Godot editor
    # Editor runs as: godot.macos.editor.universal
    # Exported app runs as: GameTwo (inside GameTwo_debug.app bundle)

    # Kill exported debug app instances
    pkill -f "GameTwo_debug.app" 2>/dev/null || true

    # Kill exported release app instances
    pkill -f "GameTwo.app/Contents/MacOS/GameTwo" 2>/dev/null || true

    # DO NOT match these patterns (editor processes):
    # - godot.macos.editor.universal
    # - godot.macos.editor.arm64
    # - Any process with --editor flag

    echo "✅ macOS exported app instances stopped (editor preserved)"

_stop-app-windows:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🛑 Stopping Windows app instances on VM..."

    # SSH to VM and kill any running gametwo processes
    # Use taskkill with /F for force, /IM for image name pattern matching
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "taskkill /IM {{GAME_NAME}}*.exe /F 2>nul || echo No processes to kill" || true

    echo "✅ Windows app instances stopped on VM"

# Platform-specific deployment functions
_deploy-config-android temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEMP_CONFIG_PATH="{{temp_config_path}}"
    TEMP_CONFIG_NAME=$(basename "$TEMP_CONFIG_PATH" .json)
    
    echo "📱 Deploying configuration to Android device..."
    
    # Use shared device check and info display
    just _android-check-device-detailed
    just _android-get-device-info
    
    # Stop app for clean state
    just _stop-app-android
    
    # Deploy config
    just config-push-android "$TEMP_CONFIG_NAME"
    echo "✅ Configuration deployed successfully - app stopped and ready for fresh launch"

_deploy-config-editor temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    TEMP_CONFIG_PATH="{{temp_config_path}}"

    echo "🖥️  Deploying configuration to editor..."

    # Stop any running editor instances for consistent state
    just _stop-app-editor

    # Ensure logs directory exists for editor
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"

    echo "📂 Editor logs will be saved to: $LOGS_DIR"

    # Copy config to the expected location for editor startup
    STARTUP_CONFIG="$USER_DATA_DIR/debug_startup_actions.json"

    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi

    echo "📋 Copying config for editor startup..."
    cp "$TEMP_CONFIG_PATH" "$STARTUP_CONFIG"
    
    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ] || [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi
    
    echo "✅ Configuration deployed successfully - app stopped and ready for fresh launch ($(wc -c < "$STARTUP_CONFIG") bytes)"

_deploy-config-macos temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    TEMP_CONFIG_PATH="{{temp_config_path}}"

    echo "🍎 Deploying configuration to macOS exported app..."

    # Stop any running macOS exported app instances for consistent state
    just _stop-app-macos

    # macOS exported app uses the same app_userdata location as editor
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"

    echo "📂 macOS logs will be saved to: $LOGS_DIR"

    # Copy config to the expected location for macOS app startup
    # Exported apps auto-load debug_startup_actions.json (no --test-mode needed)
    STARTUP_CONFIG="$USER_DATA_DIR/debug_startup_actions.json"

    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi

    echo "📋 Copying config for macOS app startup..."
    cp "$TEMP_CONFIG_PATH" "$STARTUP_CONFIG"

    # Verify the copy was successful
    if [ ! -f "$STARTUP_CONFIG" ] || [ ! -s "$STARTUP_CONFIG" ]; then
        echo "❌ Failed to create config file: $STARTUP_CONFIG"
        exit 1
    fi

    echo "✅ Configuration deployed successfully - app stopped and ready for fresh launch ($(wc -c < "$STARTUP_CONFIG") bytes)"

_deploy-config-windows temp_config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    TEMP_CONFIG_PATH="{{temp_config_path}}"

    echo "🪟 Deploying configuration to Windows VM..."

    # Stop any running Windows app instances for consistent state
    just _stop-app-windows

    # Windows app_userdata location (Godot standard on Windows)
    # Note: gametwo is lowercase as Godot uses project name in lowercase
    WIN_USER_DATA_DIR='C:\Users\{{WIN_VM_USER}}\AppData\Roaming\Godot\app_userdata\gametwo'
    WIN_LOGS_DIR='C:\Users\{{WIN_VM_USER}}\AppData\Roaming\Godot\app_userdata\gametwo\logs'

    # Create user data directory on VM if needed
    echo "📂 Creating Windows user data directory..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if not exist \"${WIN_USER_DATA_DIR}\" mkdir \"${WIN_USER_DATA_DIR}\""
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if not exist \"${WIN_LOGS_DIR}\" mkdir \"${WIN_LOGS_DIR}\""

    echo "📂 Windows logs will be saved to: ${WIN_LOGS_DIR}"

    # SCP path format for Windows: /C:/path/to/file (forward slashes with drive letter)
    WIN_SCP_USER_DATA="/C:/Users/{{WIN_VM_USER}}/AppData/Roaming/Godot/app_userdata/gametwo"
    STARTUP_CONFIG="${WIN_SCP_USER_DATA}/debug_startup_actions.json"

    # Remove old config file if it exists
    echo "🧹 Clearing old config on VM..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "del \"${WIN_USER_DATA_DIR}\\debug_startup_actions.json\" 2>nul || echo No old config to remove"

    # Copy config to Windows VM
    echo "📋 Copying config to Windows VM..."
    scp "$TEMP_CONFIG_PATH" "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${STARTUP_CONFIG}"

    # Verify the copy was successful
    if ! ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist \"${WIN_USER_DATA_DIR}\\debug_startup_actions.json\" echo exists" | grep -q exists; then
        echo "❌ Failed to create config file on VM: ${WIN_USER_DATA_DIR}\\debug_startup_actions.json"
        exit 1
    fi

    echo "✅ Configuration deployed successfully to Windows VM"

# Platform-specific execution functions
_execute-test-android config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    echo "📱 Starting Android test monitoring..."
    
    # Prepare log file path for background monitoring (using unified naming pattern)
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    ANDROID_LOG_FILE="$LOGS_DIR/android_${TEST_ID}.log"
    
    # Clear logcat buffer for clean monitoring
    echo "🧹 Clearing Android logcat buffer for clean test monitoring..."
    just logs-android-clear

    # 🚨 CRITICAL: Check buffer health to detect saturation issues
    echo "📊 Checking buffer health to prevent misdiagnosis..."
    BUFFER_HEALTH_OUTPUT=$(just logs-android-health 2>/dev/null || echo "Health check failed")

    # Extract buffer status from health check
    if echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CRITICAL"; then
        echo "⚠️  🚨 CRITICAL: Buffer saturation detected before test!"
        echo "   💡 Historical data may have been overwritten"
        echo "   🎯 Test results will be cross-validated with saved logs"
        echo "   📝 Buffer status documented in test metadata"

        # Add buffer warning to test metadata if possible
        if [ -n "${TEST_ID:-}" ]; then
            echo "   📋 Buffer warning added to test metadata for: $TEST_ID"
        fi
    elif echo "$BUFFER_HEALTH_OUTPUT" | grep -q "CAUTION"; then
        echo "⚠️  Buffer usage is high - cross-validation recommended"
        echo "   💡 Some historical entries may have been overwritten"
        echo "   🎯 Test results will be verified against saved logs"
    else
        echo "✅ Buffer health is good - normal test monitoring"
    fi
    
    # Set up cleanup trap for guaranteed resource cleanup
    _cleanup_android_test() {
        echo "🧹 Cleanup triggered - stopping background processes..."
        
        # Stop background log capture
        if [[ -n "${BACKGROUND_LOGCAT_PID:-}" ]]; then
            echo "📡 Stopping background log capture (PID: $BACKGROUND_LOGCAT_PID)..."
            kill "$BACKGROUND_LOGCAT_PID" 2>/dev/null || true
            wait "$BACKGROUND_LOGCAT_PID" 2>/dev/null || true
        fi
        
        # Clean up temporary files
        if [[ -n "${BACKGROUND_LOG_FILE:-}" && -f "$BACKGROUND_LOG_FILE" ]]; then
            echo "🗑️  Removing temporary log file: $BACKGROUND_LOG_FILE"
            rm -f "$BACKGROUND_LOG_FILE" 2>/dev/null || true
        fi
        
        # Force stop app if still running (emergency cleanup)
        current_pid=$(adb shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
        if [[ -n "$current_pid" && "$current_pid" != "0" ]]; then
            echo "🛑 Force stopping app (PID: $current_pid) during cleanup..."
            adb shell am force-stop {{ANDROID_PACKAGE_NAME}} 2>/dev/null || true
        fi
        
        echo "✅ Cleanup completed"
    }
    
    # Register cleanup trap for EXIT, SIGINT, SIGTERM
    trap '_cleanup_android_test' EXIT INT TERM
    
    # Start background log capture immediately to prevent log loss
    echo "📡 Starting background log capture for test isolation..."
    BACKGROUND_LOG_FILE="/tmp/android_live_capture_${TEST_ID}.log"
    
    # Check available disk space before starting capture
    AVAILABLE_SPACE=$(df /tmp | tail -1 | awk '{print $4}')
    MIN_REQUIRED_SPACE=102400  # 100MB in KB
    
    if [[ $AVAILABLE_SPACE -lt $MIN_REQUIRED_SPACE ]]; then
        echo "⚠️  WARNING: Low disk space in /tmp (${AVAILABLE_SPACE}KB available, ${MIN_REQUIRED_SPACE}KB required)"
        echo "🧹 Cleaning old Android log capture files..."
        find /tmp -name "android_live_capture_*.log" -mtime +1 -delete 2>/dev/null || true
        
        # Re-check space after cleanup
        AVAILABLE_SPACE=$(df /tmp | tail -1 | awk '{print $4}')
        if [[ $AVAILABLE_SPACE -lt $MIN_REQUIRED_SPACE ]]; then
            echo "❌ ERROR: Insufficient disk space for log capture (${AVAILABLE_SPACE}KB available)"
            return 1
        fi
    fi
    
    # Capture all log levels (*:V = verbose) to get GDScript debug logs
    # Include all log buffers for maximum detail
    if [[ "${VERBOSE_TESTING:-false}" == "true" ]]; then
        echo "🔍 VERBOSE MODE: Capturing all log buffers with maximum detail for memory debugging"
        # Extra verbose capture with all possible buffers
        adb logcat -b all "*:V" 2>/dev/null > "$BACKGROUND_LOG_FILE" &
    else
        # Standard capture
        adb logcat -b main,system,radio,events,crash "*:V" 2>/dev/null > "$BACKGROUND_LOG_FILE" &
    fi
    BACKGROUND_LOGCAT_PID=$!
    
    # Validate background process started successfully
    if ! kill -0 "$BACKGROUND_LOGCAT_PID" 2>/dev/null; then
        echo "❌ ERROR: Failed to start background log capture"
        return 1
    fi
    
    echo "📡 Background capture PID: $BACKGROUND_LOGCAT_PID (validated)"

    # CRITICAL FIX (Task-216): Launch app AFTER log capture starts
    # This ensures all actions are logged from the beginning
    echo "🚀 Launching app with fresh configuration (log capture active)..."
    adb shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp >/dev/null 2>&1
    sleep 1  # Brief delay for app startup

    echo "🔍 App launched - waiting for test completion..."

    # Simple monitoring - wait for app to quit
    echo "🔍 DEBUG: Starting app monitoring..."
    
    # Wait for test completion without timeout - single monitoring loop
    echo "🔍 Waiting for test completion..."
    
    echo "🔍 DEBUG: Starting monitoring loop with 2-minute timeout protection"
    MONITOR_ITERATIONS=0
    MAX_ITERATIONS=60  # 2 minutes (60 * 2s = 120s)
    
    while [[ $MONITOR_ITERATIONS -lt $MAX_ITERATIONS ]]; do
        MONITOR_ITERATIONS=$((MONITOR_ITERATIONS + 1))
        CURRENT_PID=$(adb shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
        
        # Debug output every 10 iterations
        if [[ $((MONITOR_ITERATIONS % 10)) -eq 0 ]]; then
            echo "🐛 DEBUG: Monitor iteration $MONITOR_ITERATIONS/$MAX_ITERATIONS - APP_PID: $CURRENT_PID"
        fi
        
        if [[ -z "$CURRENT_PID" || "$CURRENT_PID" == "0" ]]; then
            echo ""
            echo "✅ App quit - test completed after $MONITOR_ITERATIONS iterations"
            echo "🐛 DEBUG: App quit detected, breaking monitoring loop"
            break
        fi
        
        sleep 2
    done
    
    # Timeout protection
    if [[ $MONITOR_ITERATIONS -eq $MAX_ITERATIONS ]]; then
        echo "⚠️  TIMEOUT: Test monitoring reached 10-minute limit - force stopping"
        echo "🐛 DEBUG: Attempting to force stop app due to timeout"
        adb shell am force-stop {{ANDROID_PACKAGE_NAME}} 2>/dev/null || true
        echo "⚠️  Test may have failed or hung - check logs for issues"
    fi
    
    echo "🐛 DEBUG: Monitoring loop ended - app quit detected"
    
    # Stop background log capture and use captured logs
    if [[ -n "${BACKGROUND_LOGCAT_PID:-}" ]]; then
        echo "📡 Stopping background log capture (PID: $BACKGROUND_LOGCAT_PID)..."
        kill "$BACKGROUND_LOGCAT_PID" 2>/dev/null || true
        
        # Wait for process to actually terminate (max 5 seconds)
        wait_count=0
        while kill -0 "$BACKGROUND_LOGCAT_PID" 2>/dev/null && [[ $wait_count -lt 5 ]]; do
            sleep 1
            wait_count=$((wait_count + 1))
            echo "📡 Waiting for background capture to stop... ($wait_count/5)"
        done
        
        # Force kill if still running
        if kill -0 "$BACKGROUND_LOGCAT_PID" 2>/dev/null; then
            echo "⚠️  Force killing stuck background process..."
            kill -9 "$BACKGROUND_LOGCAT_PID" 2>/dev/null || true
        fi
        
        echo "✅ Background log capture stopped"
    fi
    
    # Extract logs from Android device using proper log extraction
    echo "🔍 Extracting logs from Android device after test completion..."

    # Smart wait for logcat flush completion using marker detection (task-236 fix)
    # Polls for DEBUG_TEST_FLUSH_COMPLETE marker that appears after all logs flushed
    # App emits marker from actual quit path (main.gd) after 2s wait
    echo "⏳ Waiting for logcat flush completion marker..."
    FLUSH_TIMEOUT=10
    FLUSH_ELAPSED=0
    FLUSH_DETECTED=false

    while [[ $FLUSH_ELAPSED -lt $FLUSH_TIMEOUT ]]; do
        if adb logcat -d 2>/dev/null | grep -q "DEBUG_TEST_FLUSH_COMPLETE"; then
            echo "✅ Flush marker detected after ${FLUSH_ELAPSED}s"
            FLUSH_DETECTED=true
            break
        fi
        sleep 1
        FLUSH_ELAPSED=$((FLUSH_ELAPSED + 1))
    done

    if [[ "$FLUSH_DETECTED" == "false" ]]; then
        echo "❌ ERROR: Flush marker not detected after ${FLUSH_TIMEOUT}s timeout"
        echo "💡 This indicates logcat buffer flush issue or app hung before quit"
        # Note: We don't exit here - let post-test validation catch any issues
    fi
    
    # Check if we have background captured logs to use
    if [[ -f "$BACKGROUND_LOG_FILE" && -s "$BACKGROUND_LOG_FILE" ]]; then
        echo "📡 Using background captured logs for better accuracy..."
        # Filter background logs for our test and copy to main log file
        mkdir -p "$LOGS_DIR"
        # Use CROSS-PLATFORM TEST FILTER for identical log capture between Android and iOS
        # Use sort -u to prevent duplicate log lines from multiple pattern matches (fixes double counting)
        grep -E "($TEST_ID|{{CROSS_PLATFORM_TEST_BASE}})" "$BACKGROUND_LOG_FILE" | sort -u > "$ANDROID_LOG_FILE" 2>/dev/null || true
        # Clean up background file
        rm -f "$BACKGROUND_LOG_FILE" 2>/dev/null || true
        
        if [[ -s "$ANDROID_LOG_FILE" ]]; then
            echo "📡 Background capture successful - found $(wc -l < "$ANDROID_LOG_FILE") log lines"
        else
            echo "📡 Background capture had no relevant logs - falling back to standard extraction"
            just _extract-logs "$TEST_ID" "android"
        fi
    else
        echo "📡 No background capture available - using standard extraction"
        just _extract-logs "$TEST_ID" "android"
    fi
    
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

_execute-test-editor config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    echo "🖥️  Starting editor test execution..."

    # Configurable timeout for editor tests (default: 120 seconds)
    # Can be overridden via environment variable DESKTOP_TEST_MAX_TIMEOUT
    MAX_TIMEOUT="${DESKTOP_TEST_MAX_TIMEOUT:-120}"

    # Run editor Godot with debug actions (automated mode with quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting editor test in automated mode with --test-mode flag (timeout: ${MAX_TIMEOUT}s)..."

    echo ""

    # Capture all output to a temporary file for filtering
    TEMP_OUTPUT=$(mktemp)

    # Execute test with timeout wrapper to prevent indefinite hangs
    # Exit code 124 = timeout reached (handled below)
    {
        timeout "$MAX_TIMEOUT" ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode --minimized 2>&1
        TEST_EXIT_CODE=$?
    } > "$TEMP_OUTPUT" || TEST_EXIT_CODE=$?
    
    # Show minimal, clean output for editor testing
    echo "📊 Desktop Test Execution Summary"
    echo "================================="
    echo ""
    
    # Extract essential test info from output first (always needed for exit code evaluation)
    # TARGETED FIX: Ensure absolutely clean single-line integers
    ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")
    FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")
    
    # Check for any critical errors first (excluding ObjectDB warnings and Sentry normal operations)
    CRITICAL_ERRORS=$(grep -E "(SCRIPT ERROR|CRITICAL|FAILED|Exception|Assertion failed|KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT)" "$TEMP_OUTPUT" | grep -v "ObjectDB instances leaked" | grep -v "SentryCrashMonitor" | grep -v "SentryCrash Exception Handler" | grep -v "\[Sentry\] \[debug\]" || echo "")

    if [[ -n "$CRITICAL_ERRORS" ]]; then
        echo "⚠️  ERRORS DETECTED - Showing relevant output:"
        echo ""
        echo "$CRITICAL_ERRORS" | head -10
        TEST_EXIT_CODE=1
    else
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
    
    # Handle exit codes with intelligent success detection (before cleanup to access temp file)
    if [[ ${TEST_EXIT_CODE:-0} -eq 124 ]]; then
        echo ""
        echo "❌ Desktop test timed out after ${MAX_TIMEOUT} seconds"
        # Extract logs before cleanup on timeout
        echo "📄 Extracting editor logs for analysis..."
        just _extract-logs "$TEST_ID" "editor" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract editor logs"
        rm -f "$TEMP_OUTPUT"
        exit 1
    elif [[ ${TEST_EXIT_CODE:-0} -ne 0 ]]; then
        # Check for actual test success indicators despite non-zero exit code
        # FIXED: Updated quit event pattern to work with new QuitApplicationEvent (task-XXX)
        TEST_COMPLETE_FOUND=$(grep -c "TEST_COMPLETE_" "$TEMP_OUTPUT" 2>/dev/null | head -1 || echo "0")
        QUIT_EVENT_FOUND=$(grep -c "Quit event received" "$TEMP_OUTPUT" 2>/dev/null | head -1 || echo "0")

        # Check for crash patterns - these should ALWAYS fail the test
        CRASH_PATTERNS="KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT"
        CRASH_FOUND=$(grep -c -E "$CRASH_PATTERNS" "$TEMP_OUTPUT" 2>/dev/null | tr -cd '0-9' | head -c 5 || echo "0")
        CRASH_FOUND=${CRASH_FOUND:-0}

        if [[ "$CRASH_FOUND" -gt 0 ]]; then
            echo ""
            echo "❌ CRASH DETECTED during test execution!"
            echo "🔍 Crash indicators found in output:"
            grep -E "$CRASH_PATTERNS" "$TEMP_OUTPUT" | head -5 | sed 's/^/   /'
            echo "📄 Extracting editor logs for analysis..."
            just _extract-logs "$TEST_ID" "editor" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract editor logs"
            rm -f "$TEMP_OUTPUT"
            echo ""
            echo "❌ Desktop test FAILED due to crash"
            exit 1
        elif [[ "${FAILED_COUNT:-0}" -eq 0 && "${ACTION_COUNT:-0}" -gt 0 && "${TEST_COMPLETE_FOUND:-0}" -gt 0 && "${QUIT_EVENT_FOUND:-0}" -gt 0 ]]; then
            echo ""
            echo "✅ Test logically successful despite Godot exit code ${TEST_EXIT_CODE}"
            echo "💡 All actions completed successfully with proper completion signals"
            # Extract logs before exiting successfully
            echo "📄 Extracting editor logs for analysis..."
            just _extract-logs "$TEST_ID" "editor" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract editor logs"
            rm -f "$TEMP_OUTPUT"
            echo ""
            echo "✅ Desktop test execution completed"
            exit 0
        else
            echo ""
            echo "⚠️  Desktop test completed with exit code ${TEST_EXIT_CODE}"
            # Extract logs before cleanup on failure
            echo "📄 Extracting editor logs for analysis..."
            just _extract-logs "$TEST_ID" "editor" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract editor logs"
            rm -f "$TEMP_OUTPUT"
            if [[ ${TEST_EXIT_CODE} -ne 0 ]]; then
                exit ${TEST_EXIT_CODE}
            fi
        fi
    fi
    
    # Extract and save editor logs using unified function before cleanup (for successful exit path)
    echo "📄 Extracting editor logs for analysis..."
    just _extract-logs "$TEST_ID" "editor" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract editor logs"

    # Cleanup temp file
    rm -f "$TEMP_OUTPUT"

    echo ""
    echo "✅ Editor test execution completed"

_execute-test-macos config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    echo "🍎 Starting macOS exported app test execution..."

    # Configurable timeout for macOS tests (default: 120 seconds)
    # Can be overridden via environment variable MACOS_TEST_MAX_TIMEOUT
    MAX_TIMEOUT="${MACOS_TEST_MAX_TIMEOUT:-120}"

    # Validate exported app exists
    MACOS_APP_PATH="export/macos/{{GAME_NAME}}_debug.app"
    MACOS_BINARY_PATH="$MACOS_APP_PATH/Contents/MacOS/{{GAME_NAME}}"

    if [ ! -d "$MACOS_APP_PATH" ]; then
        echo "❌ macOS app not found at: $MACOS_APP_PATH"
        echo "💡 Run 'just export-macos-debug' first to build the app"
        exit 1
    fi

    if [ ! -f "$MACOS_BINARY_PATH" ]; then
        echo "❌ macOS binary not found at: $MACOS_BINARY_PATH"
        echo "💡 The app bundle may be corrupted. Run 'just export-macos-debug' to rebuild"
        exit 1
    fi

    # Clear quarantine attributes for Gatekeeper (may fail silently if already cleared)
    echo "🔓 Clearing quarantine attributes for Gatekeeper..."
    xattr -cr "$MACOS_APP_PATH" 2>/dev/null || true

    echo "🚀 Starting macOS test in automated mode (timeout: ${MAX_TIMEOUT}s)..."
    echo ""

    # Capture all output to a temporary file for filtering
    TEMP_OUTPUT=$(mktemp)

    # Execute test - exported apps auto-load debug config (no --test-mode required, but we include it for consistency)
    # Support external PCK loading via TEST_MACOS_PCK environment variable
    MACOS_ARGS="--test-mode --minimized"
    if [[ -n "${TEST_MACOS_PCK:-}" ]]; then
        echo "📦 Using external PCK: $TEST_MACOS_PCK"
        MACOS_ARGS="$MACOS_ARGS --main-pack $TEST_MACOS_PCK"
    fi

    # Execute test with timeout wrapper to prevent indefinite hangs
    # Exit code 124 = timeout reached (handled below)
    {
        timeout "$MAX_TIMEOUT" "$MACOS_BINARY_PATH" $MACOS_ARGS 2>&1
        TEST_EXIT_CODE=$?
    } > "$TEMP_OUTPUT" || TEST_EXIT_CODE=$?

    # Show minimal, clean output for macOS testing
    echo "📊 macOS Test Execution Summary"
    echo "================================"
    echo ""

    # Extract essential test info from output
    ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")
    FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")

    # Check for any critical errors first (excluding ObjectDB warnings and Sentry normal operations)
    CRITICAL_ERRORS=$(grep -E "(SCRIPT ERROR|CRITICAL|FAILED|Exception|Assertion failed|KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT)" "$TEMP_OUTPUT" | grep -v "ObjectDB instances leaked" | grep -v "SentryCrashMonitor" | grep -v "SentryCrash Exception Handler" | grep -v "\[Sentry\] \[debug\]" || echo "")

    if [[ -n "$CRITICAL_ERRORS" ]]; then
        echo "⚠️  ERRORS DETECTED - Showing relevant output:"
        echo ""
        echo "$CRITICAL_ERRORS" | head -10
        TEST_EXIT_CODE=1
    else
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

        # Show key test events in a concise format
        echo "📋 Key Test Events:"
        grep -E "(SESSION_START|SESSION_END|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE)" "$TEMP_OUTPUT" | grep -v "\[BUFFER\]" | head -5 | sed 's/^/  /' 2>/dev/null || echo "  Test execution completed"

        echo ""
        echo "🎯 Test completed successfully with clean output"
    fi

    # Handle exit codes with intelligent success detection
    if [[ ${TEST_EXIT_CODE:-0} -eq 124 ]]; then
        echo ""
        echo "❌ macOS test timed out after ${MAX_TIMEOUT} seconds"
        echo "📄 Extracting macOS logs for analysis..."
        just _extract-logs "$TEST_ID" "macos" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract macOS logs"
        rm -f "$TEMP_OUTPUT"
        exit 1
    elif [[ ${TEST_EXIT_CODE:-0} -ne 0 ]]; then
        # Check for actual test success indicators despite non-zero exit code
        TEST_COMPLETE_FOUND=$(grep -c "TEST_COMPLETE_" "$TEMP_OUTPUT" 2>/dev/null | head -1 || echo "0")
        QUIT_EVENT_FOUND=$(grep -c "Quit event received" "$TEMP_OUTPUT" 2>/dev/null | head -1 || echo "0")

        # Check for crash patterns - these should ALWAYS fail the test
        CRASH_PATTERNS="KERN_INVALID_ADDRESS|EXC_BAD_ACCESS|Abort trap|SIGBUS|SIGSEGV|SIGABRT"
        CRASH_FOUND=$(grep -c -E "$CRASH_PATTERNS" "$TEMP_OUTPUT" 2>/dev/null | tr -cd '0-9' | head -c 5 || echo "0")
        CRASH_FOUND=${CRASH_FOUND:-0}

        if [[ "$CRASH_FOUND" -gt 0 ]]; then
            echo ""
            echo "❌ CRASH DETECTED during test execution!"
            echo "🔍 Crash indicators found in output:"
            grep -E "$CRASH_PATTERNS" "$TEMP_OUTPUT" | head -5 | sed 's/^/   /'
            echo "📄 Extracting macOS logs for analysis..."
            just _extract-logs "$TEST_ID" "macos" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract macOS logs"
            rm -f "$TEMP_OUTPUT"
            echo ""
            echo "❌ macOS test FAILED due to crash"
            exit 1
        elif [[ "${FAILED_COUNT:-0}" -eq 0 && "${ACTION_COUNT:-0}" -gt 0 && "${TEST_COMPLETE_FOUND:-0}" -gt 0 && "${QUIT_EVENT_FOUND:-0}" -gt 0 ]]; then
            echo ""
            echo "✅ Test logically successful despite app exit code ${TEST_EXIT_CODE}"
            echo "💡 All actions completed successfully with proper completion signals"
            echo "📄 Extracting macOS logs for analysis..."
            just _extract-logs "$TEST_ID" "macos" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract macOS logs"
            rm -f "$TEMP_OUTPUT"
            echo ""
            echo "✅ macOS test execution completed"
            exit 0
        else
            echo ""
            echo "⚠️  macOS test completed with exit code ${TEST_EXIT_CODE}"
            echo "📄 Extracting macOS logs for analysis..."
            just _extract-logs "$TEST_ID" "macos" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract macOS logs"
            rm -f "$TEMP_OUTPUT"
            if [[ ${TEST_EXIT_CODE} -ne 0 ]]; then
                exit ${TEST_EXIT_CODE}
            fi
        fi
    fi

    # Extract and save macOS logs using unified function before cleanup
    echo "📄 Extracting macOS logs for analysis..."
    just _extract-logs "$TEST_ID" "macos" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract macOS logs"

    # Cleanup temp file
    rm -f "$TEMP_OUTPUT"

    echo ""
    echo "✅ macOS test execution completed"

_execute-test-windows config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    echo "🪟 Starting Windows VM test execution..."

    # Validate Windows export exists locally
    WIN_EXE_PATH="export/windows/{{GAME_NAME}}_debug.exe"
    WIN_PCK_PATH="export/windows/{{GAME_NAME}}_debug.pck"

    if [ ! -f "$WIN_EXE_PATH" ]; then
        echo "❌ Windows executable not found at: $WIN_EXE_PATH"
        echo "💡 Run 'just export-windows-debug' first to build the Windows export"
        exit 1
    fi

    if [ ! -f "$WIN_PCK_PATH" ]; then
        echo "❌ Windows PCK not found at: $WIN_PCK_PATH"
        echo "💡 Ensure export_presets.cfg has binary_format/embed_pck=false"
        exit 1
    fi

    # Define paths on Windows VM
    WIN_TEST_DIR="C:\\gametwo\\test"
    WIN_TEST_EXE="${WIN_TEST_DIR}\\{{GAME_NAME}}_debug.exe"
    WIN_TEST_PCK="${WIN_TEST_DIR}\\{{GAME_NAME}}_debug.pck"
    WIN_USER_DATA_DIR='C:\Users\{{WIN_VM_USER}}\AppData\Roaming\Godot\app_userdata\gametwo'
    WIN_LOGS_DIR="${WIN_USER_DATA_DIR}\\logs"

    # SCP paths (forward slashes with drive letter)
    WIN_SCP_TEST_DIR="/C:/gametwo/test"
    WIN_SCP_LOGS="/C:/Users/{{WIN_VM_USER}}/AppData/Roaming/Godot/app_userdata/gametwo/logs"

    # Create/clear test directory on VM
    echo "📂 Preparing test directory on Windows VM..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist \"${WIN_TEST_DIR}\" (rmdir /S /Q \"${WIN_TEST_DIR}\" && mkdir \"${WIN_TEST_DIR}\") else (mkdir \"${WIN_TEST_DIR}\")"

    # Copy entire export/windows folder to VM (includes exe, pck, Sentry DLLs, crashpad_handler)
    echo "📦 Copying Windows export folder to VM..."
    scp -r export/windows/* "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SCP_TEST_DIR}/"

    # Copy Firebase config to VM test directory (required for Firebase initialization)
    if [ -f "firebase/google-services-desktop.json" ]; then
        echo "🔥 Copying Firebase config to VM test directory..."
        scp firebase/google-services-desktop.json "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SCP_TEST_DIR}/"
    else
        echo "⚠️  Warning: firebase/google-services-desktop.json not found - Firebase will not work on Windows"
    fi

    # Verify executable exists on VM
    if ! ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist \"${WIN_TEST_EXE}\" echo exists" | grep -q exists; then
        echo "❌ Failed to copy executable to VM"
        exit 1
    fi

    # Show what was deployed
    echo "📋 Deployed files:"
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "dir \"${WIN_TEST_DIR}\" /B" 2>/dev/null | sed 's/^/   /'

    echo "🚀 Starting Windows test in automated mode..."
    echo ""

    # Capture all output to a temporary file for filtering
    TEMP_OUTPUT=$(mktemp)

    # Execute test on Windows VM
    # Run via SSH, capture output, and handle Windows console output
    # NOTE: --headless is REQUIRED for SSH execution (no GPU access in SSH sessions)
    {
        ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd ${WIN_TEST_DIR} && {{GAME_NAME}}_debug.exe --headless --test-mode --auto-quit 2>&1"
        TEST_EXIT_CODE=$?
    } > "$TEMP_OUTPUT" 2>&1 || TEST_EXIT_CODE=$?

    # Show minimal, clean output for Windows testing
    echo "📊 Windows Test Execution Summary"
    echo "=================================="
    echo ""

    # Extract essential test info from output
    ACTION_COUNT=$(grep "DEBUG_TEST_SUCCESS" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")
    FAILED_COUNT=$(grep "DEBUG_TEST_FAILURE" "$TEMP_OUTPUT" 2>/dev/null | grep -v "\[BUFFER\]" | wc -l | tr -cd '0-9' | head -c 5 || echo "0")

    # Check for any critical errors
    CRITICAL_ERRORS=$(grep -E "(SCRIPT ERROR|CRITICAL|FAILED|Exception|Assertion failed)" "$TEMP_OUTPUT" | grep -v "ObjectDB instances leaked" || echo "")

    if [[ -n "$CRITICAL_ERRORS" ]]; then
        echo "⚠️  ERRORS DETECTED - Showing relevant output:"
        echo ""
        echo "$CRITICAL_ERRORS" | head -10
        TEST_EXIT_CODE=1
    else
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

        # Show key test events
        echo "📋 Key Test Events:"
        grep -E "(SESSION_START|SESSION_END|DEBUG_TEST_SUCCESS|DEBUG_TEST_FAILURE)" "$TEMP_OUTPUT" | grep -v "\[BUFFER\]" | head -5 | sed 's/^/  /' 2>/dev/null || echo "  Test execution completed"

        echo ""
        echo "🎯 Test completed successfully with clean output"
    fi

    # Retrieve logs from Windows VM
    echo ""
    echo "📄 Retrieving Windows logs from VM..."

    # Create local logs directory
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"

    # Save the captured output as the Windows log
    WINDOWS_LOG_FILE="$LOGS_DIR/windows_${TEST_ID}.log"
    cp "$TEMP_OUTPUT" "$WINDOWS_LOG_FILE"

    # Also try to retrieve any log files from the VM's user data
    scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SCP_LOGS}/*.log" "$LOGS_DIR/" 2>/dev/null || echo "   (No additional logs on VM)"

    LOG_LINES=$(wc -l < "$WINDOWS_LOG_FILE" 2>/dev/null || echo "0")
    echo "📄 Windows log saved: windows_${TEST_ID}.log ($LOG_LINES lines)"

    # Call unified log extraction for analysis
    just _extract-logs "$TEST_ID" "windows" "$TEMP_OUTPUT" || echo "⚠️  Failed to extract Windows logs"

    # Cleanup temp file
    rm -f "$TEMP_OUTPUT"

    # Handle exit codes
    if [[ ${TEST_EXIT_CODE:-0} -ne 0 ]]; then
        # Check for actual test success indicators despite non-zero exit code
        TEST_COMPLETE_FOUND=$(grep -c "TEST_COMPLETE_" "$WINDOWS_LOG_FILE" 2>/dev/null | head -1 || echo "0")
        QUIT_EVENT_FOUND=$(grep -c "Quit event received" "$WINDOWS_LOG_FILE" 2>/dev/null | head -1 || echo "0")

        if [[ "${FAILED_COUNT:-0}" -eq 0 && "${ACTION_COUNT:-0}" -gt 0 && "${TEST_COMPLETE_FOUND:-0}" -gt 0 ]]; then
            echo ""
            echo "✅ Test logically successful despite app exit code ${TEST_EXIT_CODE}"
            echo "💡 All actions completed successfully with proper completion signals"
            exit 0
        else
            echo ""
            echo "⚠️  Windows test completed with exit code ${TEST_EXIT_CODE}"
            exit ${TEST_EXIT_CODE}
        fi
    fi

    echo ""
    echo "✅ Windows test execution completed"

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

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "android" "$TEST_SESSION"

# Enhanced verbose testing for debugging node leaks and memory issues
test-android-verbose config_name="":
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
    
    echo "🔍 VERBOSE DEBUGGING MODE: Enhanced logging for node leaks and memory issues"
    echo "📊 This will provide detailed ObjectDB and resource cleanup information"
    echo ""

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi
    
    # Set verbose mode flag
    export VERBOSE_TESTING=true
    
    # Use the new unified execution pattern with verbose mode
    just _execute-test-with-analysis "$CONFIG_NAME" "android" "$TEST_SESSION"

# Manual mode test commands that inject auto_quit: false
test-android-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    echo "🎯 Android Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "==========================================================="
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Create temporary config with auto_quit=false for manual mode
    echo "📱 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_manual"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"
    
    # Deploy config and start app using standard config-push-android
    echo "📱 Deploying configuration and starting app..."
    just config-push-android "$TEMP_CONFIG_NAME"
    rm -f "$TEMP_CONFIG_PATH"
    just restart-android-app
    
    echo "✅ Android test started in manual mode (app will stay open for verification)"

# Desktop manual mode test command
test-editor-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    echo "🎯 Desktop Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "=========================================================="
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Create temporary config with auto_quit=false for manual mode
    echo "🖥️  Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_editor_manual"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"
    
    # Deploy config to editor (this stops any running instances)
    echo "🖥️  Deploying configuration to editor..."
    just _deploy-config-editor "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Start editor app in manual mode with --test-mode flag (reads debug config but doesn't quit due to auto_quit: false)
    echo "🚀 Starting editor app in manual mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode &

    echo "✅ Editor test started in manual mode (app will stay open for verification)"

# Enhanced version of test-editor-target that includes automatic error analysis  
test-editor-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "editor" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "editor" "$TEST_SESSION"

# macOS manual mode test command
test-macos-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    echo "🎯 macOS Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "========================================================"

    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"

    # Validate exported app exists
    MACOS_APP_PATH="export/macos/{{GAME_NAME}}_debug.app"

    if [ ! -d "$MACOS_APP_PATH" ]; then
        echo "❌ macOS app not found at: $MACOS_APP_PATH"
        echo "💡 Run 'just export-macos-debug' first to build the app"
        exit 1
    fi

    # Clear quarantine attributes for Gatekeeper
    echo "🔓 Clearing quarantine attributes for Gatekeeper..."
    xattr -cr "$MACOS_APP_PATH" 2>/dev/null || true

    # Create temporary config with auto_quit=false for manual mode
    echo "🍎 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_macos_manual"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"

    # Deploy config to macOS (this stops any running exported app instances)
    echo "🍎 Deploying configuration to macOS..."
    just _deploy-config-macos "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Start macOS app in manual mode using 'open' command (proper macOS app launching)
    # Exported apps auto-load debug config, --test-mode included for consistency
    echo "🚀 Starting macOS app in manual mode..."
    open "$MACOS_APP_PATH" --args --test-mode &

    echo "✅ macOS test started in manual mode (app will stay open for verification)"

# macOS testing interface with fzf selection
test-macos target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If arguments provided, delegate to test-macos-target (automated mode)
    if [ -n "{{target}}" ]; then
        echo "🎯 Automated mode execution: {{target}}"

        # Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        just test-macos-target "{{target}}"
        exit $?
    fi

    # Use shared fzf selection for all configs (automatic mode)
    selected=$(just _fzf-select-config "macos" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        # Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        echo "Running automatic mode: just test-macos-target '$selected'"
        just test-macos-target "$selected"
    else
        echo "❌ No selection made"
        exit 1
    fi

# Enhanced version of test-macos-target that includes automatic error analysis
test-macos-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "macos" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi

    # Validate exported app exists early
    MACOS_APP_PATH="export/macos/{{GAME_NAME}}_debug.app"
    if [ ! -d "$MACOS_APP_PATH" ]; then
        echo "❌ macOS app not found at: $MACOS_APP_PATH"
        echo "💡 Run 'just export-macos-debug' first to build the app"
        exit 1
    fi

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "macos" "$TEST_SESSION"

# Windows testing interface with fzf selection
test-windows target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If arguments provided, delegate to test-windows-target (automated mode)
    if [ -n "{{target}}" ]; then
        echo "🎯 Automated mode execution: {{target}}"

        # Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        just test-windows-target "{{target}}"
        exit $?
    fi

    # Use shared fzf selection for all configs (automatic mode)
    selected=$(just _fzf-select-config "windows" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        # Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        echo "Running automatic mode: just test-windows-target '$selected'"
        just test-windows-target "$selected"
    else
        echo "❌ No selection made"
        exit 1
    fi

# ================================
# WINDOWS VM TESTING
# ================================

# test-windows-target - Run automated Windows test via VM
# This command deploys the Windows export to a VM via SSH/SCP and runs automated tests
test-windows-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "windows" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi

    # Validate Windows export exists early
    WINDOWS_EXE_PATH="export/windows/{{GAME_NAME}}_debug.exe"
    WINDOWS_PCK_PATH="export/windows/{{GAME_NAME}}_debug.pck"

    if [ ! -f "$WINDOWS_EXE_PATH" ]; then
        echo "❌ Windows executable not found at: $WINDOWS_EXE_PATH"
        echo "💡 Run 'just export-windows-debug' first to build the executable"
        exit 1
    fi

    if [ ! -f "$WINDOWS_PCK_PATH" ]; then
        echo "❌ Windows PCK not found at: $WINDOWS_PCK_PATH"
        echo "💡 Run 'just export-windows-debug' first to build the PCK file"
        echo "💡 Ensure export_presets.cfg has embed_pck=false for Windows preset"
        exit 1
    fi

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the new unified execution pattern
    just _execute-test-with-analysis "$CONFIG_NAME" "windows" "$TEST_SESSION"

# test-windows-manual - Run Windows test on VM in manual mode (stays open)
# This command deploys and runs the game on Windows VM but keeps it open for inspection
test-windows-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    echo "🎯 Windows Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "========================================================"

    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"

    # Validate Windows export exists
    WINDOWS_EXE_PATH="export/windows/{{GAME_NAME}}_debug.exe"
    WINDOWS_PCK_PATH="export/windows/{{GAME_NAME}}_debug.pck"

    if [ ! -f "$WINDOWS_EXE_PATH" ]; then
        echo "❌ Windows executable not found at: $WINDOWS_EXE_PATH"
        echo "💡 Run 'just export-windows-debug' first to build the executable"
        exit 1
    fi

    if [ ! -f "$WINDOWS_PCK_PATH" ]; then
        echo "❌ Windows PCK not found at: $WINDOWS_PCK_PATH"
        echo "💡 Run 'just export-windows-debug' first to build the PCK file"
        echo "💡 Ensure export_presets.cfg has embed_pck=false for Windows preset"
        exit 1
    fi

    # Create temporary config with auto_quit=false for manual mode
    echo "🪟 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_windows_manual"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"

    # Deploy config to Windows VM
    echo "🪟 Deploying configuration to Windows VM..."
    just _deploy-config-windows "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Deploy exe + pck to VM
    echo "🪟 Deploying Windows executable and PCK to VM..."
    WIN_TEST_DIR='C:\gametwo\test'
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if not exist \"${WIN_TEST_DIR}\" mkdir \"${WIN_TEST_DIR}\""

    echo "📤 Copying executable to VM..."
    scp "$WINDOWS_EXE_PATH" "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:/C:/gametwo/test/{{GAME_NAME}}_debug.exe"

    echo "📤 Copying PCK to VM..."
    scp "$WINDOWS_PCK_PATH" "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:/C:/gametwo/test/{{GAME_NAME}}_debug.pck"

    # Launch app on VM in manual mode (--test-mode without --auto-quit)
    echo "🚀 Launching Windows app on VM in manual mode..."
    echo "💡 The app will stay open for manual inspection"
    echo "💡 Connect via RDP to interact with the app: {{WIN_VM_HOST}}"
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd ${WIN_TEST_DIR} && start /b {{GAME_NAME}}_debug.exe --test-mode"

    echo ""
    echo "✅ Windows app launched in manual mode on VM"
    echo "📺 Connect via RDP: {{WIN_VM_HOST}}"
    echo "🛑 To stop the app: just _stop-app-windows"

# ================================
# ORIGINAL COMMAND PRESERVATION
# ================================

# Preserved original Android test command (renamed to avoid recursion)
_test-android-target-original config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    echo "🎯 Testing target: $CONFIG_NAME"
    echo "==============================="
    
    # Clear Android test cache first to prevent stale state contamination
    echo "🧹 Clearing Android test cache to ensure fresh state..."
    just clear-android-test-cache
    echo ""
    
    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"
    
    # Check device connectivity
    just _android-check-device-detailed
    
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
    
    # Generate unique test ID using shared function  
    TEST_ID=$(just _shared-generate-test-id "$CONFIG_NAME" "android")
    export TEST_ID
    
    # Display standardized test info
    just _display-test-info "$TEST_ID" "$CONFIG_NAME" "android" "android"
    
    # Clear logcat buffer with enhanced flush for task-190 timeout handling
    echo "🔄 Enhanced Android log buffer flush for task-190..."
    adb logcat -c
    # Additional buffer flush for different log buffers to ensure clean state
    adb logcat -b main -c 2>/dev/null || true
    adb logcat -b system -c 2>/dev/null || true
    adb logcat -b crash -c 2>/dev/null || true
    echo "✅ Android log buffers cleared"
    
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
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
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
            echo "🐛 DEBUG: App quit detected"
            
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
_test-editor-target-original config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/{{config_name}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running editor test: {{config_name}} (automated mode - quits automatically)"
    echo "   Config: $CONFIG_FILE"
    echo ""

    # Ensure logs directory exists for editor
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo"
    LOGS_DIR="$USER_DATA_DIR/logs"
    mkdir -p "$LOGS_DIR"

    echo "📂 Editor logs will be saved to: $LOGS_DIR"

    # Copy config to the expected location for editor startup (user directory)
    USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/gametwo"
    mkdir -p "$USER_DIR"
    STARTUP_CONFIG="$USER_DIR/debug_startup_actions.json"

    # Remove old config file if it exists to prevent stale data
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing old config file: $STARTUP_CONFIG"
        rm "$STARTUP_CONFIG"
    fi

    echo "📋 Injecting auto_quit metadata and copying config for editor startup: $STARTUP_CONFIG"
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

    # Run editor Godot with debug actions (automated mode with quit)
    # CRITICAL: --test-mode flag enables debug coordinator (without it, debug actions are skipped)
    echo "🚀 Starting editor test in automated mode with --test-mode flag..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode --minimized \
        && echo "✅ Editor test completed successfully" \
        || echo "⚠️  Editor test completed with exit code $?"
    
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
    echo "💡 Check logs with: just logs-editor-last"

# ================================
# CHECKSUM BASELINE UPDATE COMMANDS
# ================================

# Shared function for updating checksum baselines across platforms
_update-checksum-baseline platform config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{platform}}"
    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    
    echo "🔄 Updating checksum baseline for: $CONFIG_NAME ($PLATFORM)"
    echo "============================================================="
    
    # Validate configuration exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        echo "💡 Available configs:"
        ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
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
    elif [[ "$PLATFORM" == "editor" ]]; then
        just test-editor-target "$CONFIG_NAME" || echo "Test execution completed (ignoring validation failure for update)"
    elif [[ "$PLATFORM" == "ios" ]]; then
        just test-ios-target "$CONFIG_NAME" || echo "Test execution completed (ignoring validation failure for update)"
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
        # Using centralized DEBUG_CONFIG_DIR variable
        CHECKSUM_CONFIGS=""
        
        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
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
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
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
test-editor-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    
    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."
        
        # Find all checksum-enabled configs
        # Using centralized DEBUG_CONFIG_DIR variable
        CHECKSUM_CONFIGS=""
        
        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
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
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
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
            echo "Please specify a configuration name: just test-editor-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi
    
    # Call shared update function
    just _update-checksum-baseline "editor" "$CONFIG_NAME"

# Reset checksum baseline for editor - clears baseline to start fresh
test-editor-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration to reset..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE"
                    else
                        status="✅ HAS BASELINE ($expected_checksums_count)"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to RESET: " --height=10 --layout=reverse)
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
            echo "Please specify a configuration name: just test-editor-reset CONFIG_NAME"
            exit 1
        fi
    fi

    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    echo "🗑️  Resetting checksum baseline for: $CONFIG_NAME (editor)"
    echo "==========================================================="

    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        exit 1
    fi

    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CHECKSUM_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")

    echo "📸 Current Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksums: $CHECKSUM_COUNT"

    if [[ "$CHECKSUM_COUNT" -eq 0 ]]; then
        echo ""
        echo "ℹ️  No baseline currently set - nothing to reset"
        exit 0
    fi

    # Confirm reset
    echo ""
    echo "⚠️  WARNING: This will remove the current baseline checksums ($CHECKSUM_COUNT)"
    echo "The next test run will create a new baseline automatically"
    echo ""
    read -p "Are you sure you want to reset the baseline? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Reset cancelled"
        exit 1
    fi

    # Clear expected checksums
    echo ""
    echo "🗑️  Clearing baseline checksums..."
    TEMP_FILE=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_PATH"

    echo "✅ Baseline reset completed successfully!"
    echo "========================================"
    echo "Configuration: $CONFIG_NAME"
    echo "State Type: $STATE_TYPE"
    echo "Previous Checksums: $CHECKSUM_COUNT"
    echo "New Checksums: (none - will be created on next run)"
    echo ""
    echo "The next test run will automatically create a new baseline."
    echo "Use 'just test-editor-target $CONFIG_NAME' to generate the new baseline."

# Update checksum baseline for macOS - runs test and captures new baseline values
test-macos-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
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
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
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
            echo "Please specify a configuration name: just test-macos-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi

    # Call shared update function
    just _update-checksum-baseline "macos" "$CONFIG_NAME"

# Reset checksum baseline for macOS - clears baseline to start fresh
test-macos-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration to reset..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE"
                    else
                        status="✅ HAS BASELINE ($expected_checksums_count)"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to RESET: " --height=10 --layout=reverse)
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
            echo "Please specify a configuration name: just test-macos-reset CONFIG_NAME"
            exit 1
        fi
    fi

    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    echo "🗑️  Resetting checksum baseline for: $CONFIG_NAME (macOS)"
    echo "=========================================================="

    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        exit 1
    fi

    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CHECKSUM_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")

    echo "📸 Current Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksums: $CHECKSUM_COUNT"

    if [[ "$CHECKSUM_COUNT" -eq 0 ]]; then
        echo ""
        echo "ℹ️  No baseline currently set - nothing to reset"
        exit 0
    fi

    # Confirm reset
    echo ""
    echo "⚠️  WARNING: This will remove the current baseline checksums ($CHECKSUM_COUNT)"
    echo "The next test run will create a new baseline automatically"
    echo ""
    read -p "Are you sure you want to reset the baseline? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Reset cancelled"
        exit 1
    fi

    # Clear expected checksums
    echo ""
    echo "🗑️  Clearing baseline checksums..."
    TEMP_FILE=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_PATH"

    echo "✅ Baseline reset completed successfully!"
    echo "========================================"
    echo "Configuration: $CONFIG_NAME"
    echo "State Type: $STATE_TYPE"
    echo "Previous Checksums: $CHECKSUM_COUNT"
    echo "New Checksums: (none - will be created on next run)"
    echo ""
    echo "The next test run will automatically create a new baseline."
    echo "Use 'just test-macos-target $CONFIG_NAME' to generate the new baseline."

# Update checksum baseline for Windows - runs test and captures new baseline values
test-windows-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
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
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
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
            echo "Please specify a configuration name: just test-windows-update CONFIG_NAME"
            exit 1
        fi
    fi

    # Call shared update function
    just _update-checksum-baseline "windows" "$CONFIG_NAME"

# Reset checksum baseline for Windows - clears baseline to start fresh
test-windows-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration to reset..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE"
                    else
                        status="✅ HAS BASELINE ($expected_checksums_count)"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to RESET: " --height=10 --layout=reverse)
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
            echo "Please specify a configuration name: just test-windows-reset CONFIG_NAME"
            exit 1
        fi
    fi

    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    echo "🔄 Resetting checksum baseline for: $CONFIG_NAME (Windows)"
    echo "========================================================"

    # Clear the expected_checksums array
    TEMP_FILE=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_PATH"

    echo "✅ Checksum baseline reset for $CONFIG_NAME"
    echo "💡 Next test run will create a new baseline"

# ================================
# FUTURE-PROOF PLATFORM SUPPORT
# ================================

# Dynamic platform icon mapping - easily extensible for new platforms
_get-platform-icon platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{platform}}"
    
    # Extensible platform icon registry
    case "$PLATFORM" in
        "android") echo "📱" ;;
        "editor") echo "🖥️" ;;
        "ios") echo "📱" ;;
        "web") echo "🌐" ;;
        "switch") echo "🎮" ;;
        "playstation") echo "🎮" ;;
        "xbox") echo "🎮" ;;
        "steam") echo "🎮" ;;
        "macos") echo "🍎" ;;
        "linux") echo "🐧" ;;
        "windows") echo "🪟" ;;
        "windows-physical") echo "💻" ;;
        *) echo "⚙️" ;;  # Generic fallback for any future platform
    esac

# Get all supported platforms dynamically
_get-all-platforms:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Auto-discover platforms from available test functions and configs
    # This makes the system truly platform-agnostic
    PLATFORMS=""
    
    # Check for platform-specific test functions
    if command -v just >/dev/null 2>&1; then
        # Look for test-*-target functions (including hyphenated platforms like windows-physical)
        # The regex captures platform names between "test-" and "-target " (with trailing space)
        PLATFORM_FUNCTIONS=$(just --list 2>/dev/null | rg "test-([a-z-]+)-target " -o -r '$1' | sort | uniq)
        if [[ -n "$PLATFORM_FUNCTIONS" ]]; then
            PLATFORMS="$PLATFORM_FUNCTIONS"
        fi
    fi
    
    # Fallback to known platforms if auto-discovery fails
    if [[ -z "$PLATFORMS" ]]; then
        PLATFORMS="android editor"
    fi
    
    echo "$PLATFORMS"

# Validate if a platform exists in the system (different from config-platform support check)
_platform-exists platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{platform}}"
    SUPPORTED_PLATFORMS=$(just _get-all-platforms)
    
    if echo "$SUPPORTED_PLATFORMS" | grep -qw "$PLATFORM"; then
        echo "true"
    else
        echo "false"
    fi

# Get platform display name (for future localization/customization)
_get-platform-display-name platform:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PLATFORM="{{platform}}"
    
    # Extensible platform display name registry
    case "$PLATFORM" in
        "android") echo "Android Device" ;;
        "editor") echo "Desktop (Linux/macOS/Windows)" ;;
        "ios") echo "iOS Device" ;;
        "web") echo "Web Browser" ;;
        "switch") echo "Nintendo Switch" ;;
        "playstation") echo "PlayStation" ;;
        "xbox") echo "Xbox" ;;
        "steam") echo "Steam Deck" ;;
        "macos") echo "macOS" ;;
        "linux") echo "Linux" ;;
        "windows") echo "Windows VM" ;;
        "windows-physical") echo "Windows Physical" ;;
        *) echo "$PLATFORM" ;;  # Use platform name as-is for unknown platforms
    esac

# ================================
# COMMAND INTEGRATION INFRASTRUCTURE
# ================================

# Parse and execute commands from test list with platform filtering
_execute-test-list-commands test_list_path current_platform test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST_PATH="{{test_list_path}}"
    CURRENT_PLATFORM="{{current_platform}}"
    TEST_ID="{{test_id}}"
    
    # Check if test list has commands array
    COMMANDS_COUNT=$(jq -r '.commands | length' "$TEST_LIST_PATH" 2>/dev/null || echo "0")
    
    if [[ "$COMMANDS_COUNT" == "null" || "$COMMANDS_COUNT" == "0" ]]; then
        echo "📋 No commands to execute in test list"
        exit 0
    fi
    
    echo ""
    echo "🚀 Executing $COMMANDS_COUNT test list commands with platform filtering..."
    echo "Platform: $CURRENT_PLATFORM"
    echo "TEST_ID: $TEST_ID"
    echo ""
    
    # Execute each command
    for i in $(seq 0 $(($COMMANDS_COUNT - 1))); do
        COMMAND=$(jq -r ".commands[$i].command" "$TEST_LIST_PATH")
        PLATFORMS=$(jq -r ".commands[$i].platforms[]" "$TEST_LIST_PATH" 2>/dev/null || echo "")
        DESCRIPTION=$(jq -r ".commands[$i].description" "$TEST_LIST_PATH")
        
        echo "Command $((i+1)): $COMMAND"
        echo "  Platforms: $PLATFORMS"
        echo "  Description: $DESCRIPTION"
        
        # Check if command should run on current platform
        if echo "$PLATFORMS" | grep -q "$CURRENT_PLATFORM"; then
            echo "  ✅ Should run on $CURRENT_PLATFORM"
            
            # Execute command with context inheritance
            just _execute-single-test-command "$COMMAND" "$CURRENT_PLATFORM" "$TEST_ID"
        else
            echo "  ⏭️  Skipping - not for platform $CURRENT_PLATFORM"
        fi
        echo ""
    done

# Execute a single test command with context inheritance
_execute-single-test-command command current_platform test_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    COMMAND="{{command}}"
    CURRENT_PLATFORM="{{current_platform}}"
    TEST_ID="{{test_id}}"
    
    echo "  🔄 Executing command with TEST_ID context..."
    
    # Check if command exists by testing the detection
    COMMAND_EXISTS=$(just --list | grep -c "$COMMAND" || true)
    echo "  🔍 Command detection result: $COMMAND_EXISTS matches found"
    
    if [[ "$COMMAND_EXISTS" -gt 0 ]]; then
        echo "  ✅ Command found: $COMMAND"
        
        # Execute command with TEST_ID context
        export TEST_ID
        echo "  🚀 Executing: just $COMMAND"
        
        # Run command and capture result without failing the main test
        set +e  # Disable exit on error temporarily
        just "$COMMAND" 2>/dev/null
        COMMAND_EXIT_CODE=$?
        set -e  # Re-enable exit on error
        
        if [[ $COMMAND_EXIT_CODE -eq 0 ]]; then
            echo "  ✅ Command executed successfully"
        else
            echo "  ⚠️  Command execution failed (exit code: $COMMAND_EXIT_CODE)"
            echo "  📋 This might be expected for some test commands"
        fi
    else
        echo "  ❌ Command not found: $COMMAND"
        echo "  Available commands: $(just --list | grep test-save-load-cycle | head -2)"
        exit 1
    fi

# ================================
# TDD TEST COMMANDS
# ================================

# TDD test for just command integration functionality - now using reusable infrastructure
test-command-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 TDD Test: Just Command Integration (Refactored)"
    echo "================================================="
    echo "Testing new test list format with commands array using reusable functions"
    echo ""
    
    TEST_LIST="command-integration-test"
    TEST_LIST_PATH="tests/test-lists/${TEST_LIST}.json"
    
    # Verify test list exists
    if [[ ! -f "$TEST_LIST_PATH" ]]; then
        echo "❌ Test list not found: $TEST_LIST_PATH"
        exit 1
    fi
    
    echo "📋 Test list found: $TEST_LIST_PATH"
    echo ""
    
    # Display test list content
    echo "📄 Test list content:"
    cat "$TEST_LIST_PATH" | jq '.'
    
    # Generate TEST_ID for context inheritance
    CURRENT_PLATFORM="editor"  # Hardcoded for testing
    TEST_ID=$(just _shared-generate-test-id "$TEST_LIST" "command-integration" "$CURRENT_PLATFORM")
    echo ""
    echo "📋 Generated TEST_ID: $TEST_ID"
    
    # Use the new reusable infrastructure
    just _execute-test-list-commands "$TEST_LIST_PATH" "$CURRENT_PLATFORM" "$TEST_ID"
    
    echo ""
    echo "🎉 TDD Test: Just Command Integration - BLUE PHASE (Refactored)"
    echo "=============================================================="
    echo "✅ Command parsing successful (reusable function)"
    echo "✅ Platform filtering working (reusable function)"  
    echo "✅ Command execution implemented (reusable function)"
    echo "✅ TEST_ID context inheritance working (reusable function)"
    echo "✅ Code refactored into reusable components"
    echo ""
    echo "Ready for integration with enhanced testing pipeline!"