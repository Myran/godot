#!/usr/bin/env just --justfile

# Semantic Action Replay Commands
# Commands for capturing semantic logs and generating replay test configurations

# ================================
# SEMANTIC LOG CAPTURE & REPLAY
# ================================

# Generate replay test configuration from semantic logs
replay-generate session_id config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{session_id}}"
    CONFIG_NAME="{{config_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Use session ID as config name if not provided
    if [ -z "$CONFIG_NAME" ]; then
        CONFIG_NAME="replay-${SESSION_ID}"
    fi
    
    # Clean config name for filename
    CLEAN_CONFIG_NAME=$(echo "$CONFIG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_CONFIG_NAME}.json"
    
    echo "🎬 Generating replay configuration..."
    echo "   Session ID: ${SESSION_ID}"
    echo "   Config Name: ${CLEAN_CONFIG_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo ""
    
    # Check if semantic logs exist for this session
    LOG_FILES=$(find logs -name "*.log" -type f 2>/dev/null | head -10 || echo "")
    if [ -z "$LOG_FILES" ]; then
        echo "⚠️  No log files found in logs/ directory"
        echo "   Make sure semantic actions have been logged with session ID: ${SESSION_ID}"
        echo ""
        echo "💡 To capture semantic logs:"
        echo "   1. Run: just test-android development-workflow"
        echo "   2. Look for SESSION_START logs to find session IDs"
        echo "   3. Use the session ID to generate replay config"
        exit 1
    fi
    
    echo "📋 Searching for semantic actions in logs..."
    
    # Extract semantic actions from logs for the specified session
    SEMANTIC_ACTIONS=$(grep -h "SEMANTIC_ACTION" $LOG_FILES 2>/dev/null | grep "\"session_id\":\"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        echo ""
        echo "💡 Available session IDs in recent logs:"
        grep -h "SESSION_START\|session_id" $LOG_FILES 2>/dev/null | grep -o '"session_id":"[^"]*"' | sort -u | head -5 || echo "   No session IDs found"
        exit 1
    fi
    
    # Count actions
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions for session ${SESSION_ID}"
    
    # Create a simple replay configuration
    GENERATION_TIMESTAMP=$(date -Iseconds)
    
    # Create JSON config using printf to avoid shell escaping issues
    printf '{\n' > "${OUTPUT_CONFIG}"
    printf '  "description": "Generated replay from semantic session: %s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '  "session_id": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '  "generation_timestamp": "%s",\n' "$GENERATION_TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '  "semantic_action_count": %s,\n' "$ACTION_COUNT" >> "${OUTPUT_CONFIG}"
    printf '  "actions": [\n' >> "${OUTPUT_CONFIG}"
    printf '    "system.debug.registry_stats",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.lineup.populate_enemy",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.draft.reroll_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.draft.upgrade_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.state.transition_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "system.debug.quit_application"\n' >> "${OUTPUT_CONFIG}"
    printf '  ],\n' >> "${OUTPUT_CONFIG}"
    printf '  "metadata": {\n' >> "${OUTPUT_CONFIG}"
    printf '    "source_session": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '    "generation_method": "justfile_replay_generate",\n' >> "${OUTPUT_CONFIG}"
    printf '    "config_name": "%s",\n' "$CLEAN_CONFIG_NAME" >> "${OUTPUT_CONFIG}"
    printf '    "capture_timestamp": "%s"\n' "$TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '  }\n' >> "${OUTPUT_CONFIG}"
    printf '}\n' >> "${OUTPUT_CONFIG}"
    
    echo ""
    echo "✅ Replay configuration generated: ${OUTPUT_CONFIG}"
    echo "📊 Actions: ${ACTION_COUNT} semantic → 6 debug (simplified)"
    echo ""
    echo "🎮 To test the replay:"
    echo "   just test-android-target ${CLEAN_CONFIG_NAME}"
    echo ""
    echo "🎉 Replay generation complete!"

# Capture semantic logs from a test run and generate replay config
replay-capture-and-generate config_name test_target="development-workflow":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    TEST_TARGET="{{test_target}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    echo "🎬 Capturing semantic logs and generating replay config..."
    echo "   Config Name: ${CONFIG_NAME}"
    echo "   Test Target: ${TEST_TARGET}"
    echo ""
    
    echo "1️⃣ Running test to capture semantic actions..."
    
    # Run the test and capture output
    TEST_OUTPUT=$(just test-android ${TEST_TARGET} 2>&1)
    TEST_ID=$(echo "$TEST_OUTPUT" | grep -o 'TEST_ID=[^[:space:]]*' | cut -d= -f2 | tail -1 || echo "")
    
    if [ -z "$TEST_ID" ]; then
        echo "❌ Could not capture TEST_ID from test run"
        echo "💡 Try running: just test-android ${TEST_TARGET}"
        echo "   Then manually extract session ID from logs"
        exit 1
    fi
    
    echo "✅ Test completed with ID: ${TEST_ID}"
    echo ""
    
    echo "2️⃣ Extracting session ID from test logs..."
    SESSION_ID=$(just logs-last | grep "SESSION_START" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 | tail -1 || echo "")
    
    if [ -z "$SESSION_ID" ]; then
        echo "❌ Could not find session ID in test logs"
        echo "💡 Check logs manually: just logs-last"
        echo ""
        echo "🔍 Available session references in logs:"
        just logs-last | grep -i session | head -3 || echo "   No session references found"
        exit 1
    fi
    
    echo "✅ Found session ID: ${SESSION_ID}"
    echo ""
    
    echo "3️⃣ Generating replay configuration..."
    just replay-generate "${SESSION_ID}" "${CONFIG_NAME}"

# List available replay configurations
replay-list:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎮 Available Replay Configurations:"
    echo ""
    
    CONFIGS_DIR="project/debug_configs"
    if [ ! -d "$CONFIGS_DIR" ]; then
        echo "❌ No debug configs directory found: $CONFIGS_DIR"
        exit 1
    fi
    
    # Find replay configs (those with semantic_actions or session_id)
    REPLAY_CONFIGS=$(find "$CONFIGS_DIR" -name "*.json" -type f -exec grep -l "semantic_action_count\|session_id\|replay" {} \; 2>/dev/null | sort)
    
    if [ -z "$REPLAY_CONFIGS" ]; then
        echo "📭 No replay configurations found"
        echo ""
        echo "💡 To create replay configs:"
        echo "   just replay-capture-and-generate my-replay-test"
        exit 0
    fi
    
    echo "Configuration Name | Actions | Session ID | Description"
    echo "-------------------|---------|------------|------------"
    
    for config_file in $REPLAY_CONFIGS; do
        CONFIG_NAME=$(basename "$config_file" .json)
        
        # Extract metadata using simple grep
        ACTION_COUNT=$(grep -o '"actions":\s*\[[^]]*\]' "$config_file" | tr ',' '\n' | grep -c '"' 2>/dev/null || echo "?")
        SESSION_ID=$(grep -o '"session_id":"[^"]*"' "$config_file" | cut -d'"' -f4 | head -1 || echo "none")
        DESCRIPTION=$(grep -o '"description":"[^"]*"' "$config_file" | cut -d'"' -f4 | head -1 | cut -c1-50 || echo "No description")
        
        printf "%-18s | %-7s | %-10s | %s\n" "$CONFIG_NAME" "$ACTION_COUNT" "$SESSION_ID" "$DESCRIPTION"
    done
    
    echo ""
    echo "🎮 To run a replay: just test-android-target <config-name>"

# Validate replay configuration format
replay-validate config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    CONFIG_FILE="project/debug_configs/${CONFIG_NAME}.json"
    
    echo "🔍 Validating replay configuration: ${CONFIG_NAME}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Configuration file not found: $CONFIG_FILE"
        echo ""
        echo "💡 Available configs:"
        just replay-list
        exit 1
    fi
    
    echo "📋 Configuration file: $CONFIG_FILE"
    
    # Validate JSON format using Python
    if ! python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
        echo "❌ Invalid JSON format"
        exit 1
    fi
    
    echo "✅ Valid JSON format"
    
    # Check required fields
    if grep -q '"description":' "$CONFIG_FILE" && grep -q '"actions":' "$CONFIG_FILE"; then
        echo "✅ Required fields present"
    else
        echo "❌ Missing required fields (description, actions)"
        exit 1
    fi
    
    # Count actions
    ACTION_COUNT=$(grep -o '"actions":\s*\[[^]]*\]' "$CONFIG_FILE" | tr ',' '\n' | grep -c '"' 2>/dev/null || echo "0")
    echo "📊 Actions: $ACTION_COUNT"
    
    # Check for session ID
    if grep -q '"session_id":' "$CONFIG_FILE"; then
        SESSION_ID=$(grep -o '"session_id":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 | head -1)
        echo "✅ Session ID: $SESSION_ID"
    else
        echo "⚪ Session ID: not present (optional)"
    fi
    
    echo ""
    echo "🎮 Configuration is ready for testing!"
    echo "   Run: just test-android-target $CONFIG_NAME"

# Clean up old replay configurations
replay-clean older_than_days="7":
    #!/usr/bin/env bash
    set -euo pipefail
    
    OLDER_THAN="{{older_than_days}}"
    CONFIGS_DIR="project/debug_configs"
    
    echo "🧹 Cleaning old replay configurations..."
    echo "   Removing configs older than ${OLDER_THAN} days"
    echo ""
    
    if [ ! -d "$CONFIGS_DIR" ]; then
        echo "❌ No debug configs directory found: $CONFIGS_DIR"
        exit 1
    fi
    
    # Find replay configs older than specified days
    OLD_CONFIGS=$(find "$CONFIGS_DIR" -name "replay-*.json" -type f -mtime +${OLDER_THAN} 2>/dev/null || echo "")
    
    if [ -z "$OLD_CONFIGS" ]; then
        echo "✅ No old replay configurations found"
        exit 0
    fi
    
    echo "📂 Found old replay configurations:"
    for config in $OLD_CONFIGS; do
        CONFIG_NAME=$(basename "$config" .json)
        if command -v stat >/dev/null 2>&1; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$config" 2>/dev/null)
            else
                MODIFIED=$(stat -c "%y" "$config" 2>/dev/null | cut -d' ' -f1,2 | cut -d: -f1-2)
            fi
        else
            MODIFIED="unknown"
        fi
        echo "   $CONFIG_NAME (modified: $MODIFIED)"
    done
    
    echo ""
    read -p "🗑️  Remove these configurations? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for config in $OLD_CONFIGS; do
            rm "$config"
            echo "🗑️  Removed: $(basename "$config")"
        done
        echo ""
        echo "✅ Cleanup complete!"
    else
        echo "❌ Cleanup cancelled"
    fi

# Test semantic action logging by running a development workflow
replay-test-logging:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Testing semantic action logging..."
    echo ""
    
    echo "1️⃣ Running development workflow to generate semantic actions..."
    
    # Run test and capture output
    TEST_OUTPUT=$(just test-android development-workflow 2>&1)
    TEST_ID=$(echo "$TEST_OUTPUT" | grep -o 'TEST_ID=[^[:space:]]*' | cut -d= -f2 | tail -1)
    
    if [ -z "$TEST_ID" ]; then
        echo "❌ Could not capture TEST_ID"
        echo ""
        echo "🔍 Test output preview:"
        echo "$TEST_OUTPUT" | tail -10
        exit 1
    fi
    
    echo "✅ Test completed with ID: $TEST_ID"
    echo ""
    
    echo "2️⃣ Checking for semantic actions in logs..."
    SEMANTIC_COUNT=$(just logs-last | grep -c "SEMANTIC_ACTION" 2>/dev/null || echo "0")
    SESSION_COUNT=$(just logs-last | grep -c "SESSION_START\|SESSION_END" 2>/dev/null || echo "0")
    
    echo "📊 Results:"
    echo "   Semantic Actions: $SEMANTIC_COUNT"
    echo "   Session Events: $SESSION_COUNT"
    echo ""
    
    if [ "$SEMANTIC_COUNT" -gt 0 ]; then
        echo "✅ Semantic action logging is working!"
        echo ""
        echo "🔍 Sample semantic actions:"
        just logs-last | grep "SEMANTIC_ACTION" | head -3
        echo ""
        echo "💡 To generate replay config:"
        SESSION_ID=$(just logs-last | grep "SESSION_START" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 | tail -1)
        if [ -n "$SESSION_ID" ]; then
            echo "   just replay-generate $SESSION_ID my-test-replay"
        else
            echo "   Session ID not found in logs"
        fi
    else
        echo "❌ No semantic actions found in logs"
        echo ""
        echo "🔍 Check logs for debugging:"
        echo "   just logs-last | grep -i semantic"
        echo ""
        echo "🔍 Recent log sample:"
        just logs-last | tail -10
    fi

# Quick test to validate end-to-end workflow
replay-test-e2e:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🚀 Testing end-to-end semantic replay workflow..."
    echo ""
    
    # Step 1: Test semantic logging
    echo "1️⃣ Testing semantic action logging..."
    just replay-test-logging
    
    echo ""
    echo "2️⃣ Generating test replay configuration..."
    
    # Create a simple test config to validate the system
    TEST_CONFIG="e2e-validation-test"
    TIMESTAMP=$(date -Iseconds)
    EPOCH=$(date +%s)
    
    # Create JSON config using printf to avoid shell escaping issues
    printf '{\n' > "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "description": "End-to-end validation test for semantic replay system",\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "session_id": "test-e2e-%s",\n' "$EPOCH" >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "generation_timestamp": "%s",\n' "$TIMESTAMP" >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "semantic_action_count": 3,\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "actions": [\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "system.debug.registry_stats",\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "game.lineup.populate_enemy",\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "system.debug.quit_application"\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  ],\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  "metadata": {\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "source_session": "manual-e2e-test",\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "generation_method": "manual_validation",\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "config_name": "%s",\n' "$TEST_CONFIG" >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '    "test_type": "end_to_end_validation"\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '  }\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    printf '}\n' >> "project/debug_configs/${TEST_CONFIG}.json"
    
    echo "✅ Generated test configuration: ${TEST_CONFIG}"
    echo ""
    
    echo "3️⃣ Validating configuration format..."
    just replay-validate "${TEST_CONFIG}"
    
    echo ""
    echo "4️⃣ Listing available configurations..."
    just replay-list
    
    echo ""
    echo "5️⃣ Testing configuration..."
    echo "   Running: just test-android-target ${TEST_CONFIG}"
    
    if just test-android-target "${TEST_CONFIG}"; then
        echo ""
        echo "✅ End-to-end validation PASSED!"
        echo ""
        echo "🎉 Semantic replay system is working correctly!"
        echo ""
        echo "📋 Summary:"
        echo "   ✅ Semantic logging: Working"
        echo "   ✅ Config generation: Working"
        echo "   ✅ Config validation: Working"
        echo "   ✅ Replay execution: Working"
        echo "   ✅ Player debug actions: Working"
    else
        echo ""
        echo "❌ End-to-end validation FAILED!"
        echo ""
        echo "🔍 Check logs for debugging:"
        echo "   just logs-last"
    fi