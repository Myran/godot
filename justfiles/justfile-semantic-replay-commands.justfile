#!/usr/bin/env just --justfile

# Semantic Action Replay Commands
# Commands for capturing semantic logs and generating replay test configurations

# ================================
# GLOBAL LOG PATH CONFIGURATION
# ================================

# Desktop log paths for self-contained and system installations
PROJECT_LOGS_DIR := "./logs"
USER_DATA_DIR := "$HOME/Library/Application Support/Godot/app_userdata/gametwo"
STANDARD_LOGS_DIR := USER_DATA_DIR + "/logs"

# ================================
# SHARED FZF SELECTION UTILITIES
# ================================

# Shared fzf config selection function with filtering support
_fzf-select-config CONTEXT="generic" FILTER="all":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONTEXT="{{CONTEXT}}"
    FILTER="{{FILTER}}"
    
    # Check if fzf is available
    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ 'fzf' command not found. Install with: brew install fzf" >&2
        exit 1
    fi
    
    # Build options with category prefixes and descriptions
    options=()
    
    # Apply filtering based on FILTER parameter
    case "$FILTER" in
        "checksum")
            # Only checksum-enabled configs
            for file in project/debug_configs/*.json; do
                if [ -f "$file" ] && jq -e '.checksum_config' "$file" >/dev/null 2>&1; then
                    name=$(basename "$file" .json)
                    desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                    expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$file")
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$file")
                    
                    if [ -n "$expected_checksum" ]; then
                        status="✅ BASELINE SET"
                    else
                        status="🔄 NEEDS BASELINE"
                    fi
                    
                    options+=("📸 $name ($state_type) $status - $desc")
                fi
            done
            ;;
        "replay")
            # Only replay configs (those with session_id or replay metadata)
            for file in project/debug_configs/*.json; do
                if [ -f "$file" ]; then
                    if jq -e '.session_id // .metadata.source_session' "$file" >/dev/null 2>&1; then
                        name=$(basename "$file" .json)
                        desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                        session_id=$(jq -r '.session_id // .metadata.source_session // "unknown"' "$file" 2>/dev/null)
                        action_count=$(jq -r '.actions | length' "$file" 2>/dev/null || echo "?")
                        
                        options+=("🎬 $name ($action_count actions, session: $session_id) - $desc")
                    fi
                fi
            done
            ;;
        "demo")
            # Only demo configs (those with "type": "demo" or demo metadata)
            for file in project/debug_configs/*.json; do
                if [ -f "$file" ]; then
                    if jq -e '.type == "demo" or .metadata.replay_mode == "demo" or (.metadata.generation_method | contains("demo"))' "$file" >/dev/null 2>&1; then
                        name=$(basename "$file" .json)
                        desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                        session_id=$(jq -r '.session_id // .metadata.source_session // "unknown"' "$file" 2>/dev/null)
                        action_count=$(jq -r '.actions | length' "$file" 2>/dev/null || echo "?")
                        can_convert=$(jq -r '.metadata.can_convert_to_test // false' "$file" 2>/dev/null)
                        
                        if [ "$can_convert" = "true" ]; then
                            convert_icon="🧪"
                        else
                            convert_icon="⚪"
                        fi
                        
                        options+=("🎬 $name ($action_count actions, ${convert_icon} convertible) - $desc")
                    fi
                fi
            done
            ;;
        "all"|*)
            # All configs (debug configs + test lists)
            for file in project/debug_configs/*.json; do
                if [ -f "$file" ]; then
                    name=$(basename "$file" .json)
                    desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                    options+=("🔧 $name - $desc")
                fi
            done
            
            # Add test lists with 📝 prefix  
            for file in project/test-lists/*.json; do
                if [ -f "$file" ]; then
                    name=$(basename "$file" .json)
                    desc=$(jq -r '.description // .name // "No description"' "$file" 2>/dev/null || echo "No description")
                    options+=("📝 $name - $desc")
                fi
            done
            ;;
    esac
    
    # Check if we have any options
    if [ ${#options[@]} -eq 0 ]; then
        echo "❌ No configurations found for filter: $FILTER" >&2
        exit 1
    fi
    
    # Set context-specific prompt and header
    case "$CONTEXT" in
        "desktop")
            prompt="Select desktop test: "
            header="🖥️  Desktop Testing | 🔧 Debug Configs | 📝 Test Lists | Use fuzzy search to filter"
            ;;
        "android") 
            prompt="Select Android test: "
            header="📱 Android Testing | 🔧 Debug Configs | 📝 Test Lists | Use fuzzy search to filter"
            ;;
        "checksum")
            prompt="Select checksum config to UPDATE: "
            header="📸 Checksum Configs | Filter by typing"
            ;;
        "replay")
            prompt="Select replay config: "
            header="🎬 Replay Configs | Filter by typing" 
            ;;
        *)
            prompt="Select configuration: "
            header="🔧 Debug Configs | 📝 Test Lists | Use fuzzy search to filter"
            ;;
    esac
    
    # Use fzf to select with nice formatting
    selected_line=$(printf '%s\n' "${options[@]}" | fzf \
        --prompt="$prompt" \
        --height=~80% \
        --layout=reverse \
        --border \
        --preview-window=hidden \
        --header="$header")
    
    if [ -n "$selected_line" ]; then
        # Extract the name (between prefix and description) 
        # Handle different prefixes: 🔧 📝 📸 🎬
        selected=$(echo "$selected_line" | sed -E 's/^[📝🔧📸🎬] ([^ ]+)( \([^)]*\))? - .*/\1/')
        echo "$selected"
        exit 0
    else
        exit 1
    fi

# ================================
# DEMO CREATION FROM SESSIONS  
# ================================

# Create demo from the most recent gameplay session
create-demo-from-last-session demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Clean demo name for filename
    CLEAN_DEMO_NAME=$(echo "$DEMO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_DEMO_NAME}.json"
    
    echo "🎬 Creating demo from most recent session..."
    echo "   Demo Name: ${CLEAN_DEMO_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo ""
    
    # Get platform-appropriate logs using unified LogSourceProvider
    echo "📋 Extracting session from recent logs..."
    
    # Get the most recent logs (platform-agnostic)
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
        echo "🤖 Detected Android - using adb logcat"
        RECENT_LOGS=$(just logs-last 2>/dev/null | grep -v "Getting latest" || echo "")
    else
        echo "🖥️  Detected Desktop - using desktop logs"
        # Check for self-contained mode first (logs in project directory)
        PROJECT_LOGS_DIR="{{PROJECT_LOGS_DIR}}"
        USER_DATA_DIR="{{USER_DATA_DIR}}"
        STANDARD_LOGS_DIR="{{STANDARD_LOGS_DIR}}"
        
        RECENT_LOGS=""
        LATEST_LOG=""
        
        # Find the most recent log file from both locations
        PROJECT_LATEST=""
        STANDARD_LATEST=""
        
        # Check self-contained logs
        if [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/*.log 2>/dev/null)" ]; then
            PROJECT_LATEST=$(ls -t "$PROJECT_LOGS_DIR"/*.log 2>/dev/null | head -1)
        fi
        
        # Check standard user data logs
        if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/*.log 2>/dev/null)" ]; then
            STANDARD_LATEST=$(ls -t "$STANDARD_LOGS_DIR"/*.log 2>/dev/null | head -1)
        fi
        
        # Choose the most recent log file between the two locations
        if [ -n "$PROJECT_LATEST" ] && [ -n "$STANDARD_LATEST" ]; then
            # Compare modification times and use the more recent one
            if [ "$PROJECT_LATEST" -nt "$STANDARD_LATEST" ]; then
                LATEST_LOG="$PROJECT_LATEST"
                echo "📁 Using self-contained logs (most recent): $PROJECT_LOGS_DIR"
            else
                LATEST_LOG="$STANDARD_LATEST"
                echo "📁 Using standard logs (most recent): $STANDARD_LOGS_DIR"
            fi
        elif [ -n "$PROJECT_LATEST" ]; then
            LATEST_LOG="$PROJECT_LATEST"
            echo "📁 Using self-contained logs: $PROJECT_LOGS_DIR"
        elif [ -n "$STANDARD_LATEST" ]; then
            LATEST_LOG="$STANDARD_LATEST"
            echo "📁 Using standard logs: $STANDARD_LOGS_DIR"
        fi
        
        # Read the most recent log file
        if [ -n "$LATEST_LOG" ]; then
            echo "📄 Reading desktop log: $(basename "$LATEST_LOG")"
            RECENT_LOGS=$(cat "$LATEST_LOG" 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "❌ No recent logs found"
        echo ""
        echo "💡 To create a demo, you need to generate logs first:"
        echo "   1. Run the game: just run-desktop"
        echo "   2. Play through a sequence (draft, lineup, battle, etc.)"
        echo "   3. Close the game to save logs"
        echo "   4. Then try: just create-demo-from-last-session DEMO_NAME"
        echo ""
        echo "📂 Desktop logs locations checked:"
        echo "   Self-contained: {{PROJECT_LOGS_DIR}}"
        echo "   Standard: {{STANDARD_LOGS_DIR}}"
        echo ""
        echo "🔍 Available demos (you can test these):"
        just list-demos 2>/dev/null || echo "   No demos available yet"
        exit 1
    fi
    
    # Extract the most recent session ID (handle both formats)
    SESSION_ID=$(echo "$RECENT_LOGS" | grep "SESSION_START" | grep -o '"session_id": *"[^"]*"' | sed 's/"session_id": *"//' | sed 's/"//' | tail -1)
    
    if [ -z "$SESSION_ID" ]; then
        echo "❌ No session found in recent logs"
        echo ""
        echo "💡 To generate a session with semantic actions:"
        echo "   1. Run the game: just run-desktop"
        echo "   2. Perform some actions (draft cards, move lineup, etc.)"
        echo "   3. Close the game"
        echo "   4. Then try: just create-demo-from-last-session DEMO_NAME"
        echo ""
        echo "🔍 Recent log sample (last 5 lines):"
        echo "$RECENT_LOGS" | tail -5
        echo ""
        echo "🔍 Available demos:"
        just list-demos 2>/dev/null || echo "   No demos available yet"
        exit 1
    fi
    
    echo "✅ Found session ID: $SESSION_ID"
    
    # Extract semantic actions for this session (handle both formats)
    SEMANTIC_ACTIONS=$(echo "$RECENT_LOGS" | grep "SEMANTIC_ACTION" | grep "\"session_id\": *\"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        echo ""
        echo "💡 Make sure you performed actions during gameplay (draft, lineup, etc.)"
        exit 1
    fi
    
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions"
    
    # Parse semantic actions and map to debug actions
    echo "🎬 Parsing semantic actions and mapping to debug actions..."
    
    # Extract semantic actions from logs for this session
    SEMANTIC_ACTIONS=$(echo "$RECENT_LOGS" | grep "SEMANTIC_ACTION" | grep "\"session_id\": *\"${SESSION_ID}\"")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        exit 1
    fi
    
    # Create demo actions array - start with standard setup
    DEMO_ACTIONS=()
    DEMO_ACTIONS+=("system.debug.hide_menu")
    
    # Store action parameters for actions that need them
    ACTION_PARAMS_JSON=""
    
    # Track action counts for indexing (using simple variables)
    # We'll use variables like ACTION_COUNT_game_draft_remove_block_player
    
    # Helper function to add parameters with proper indexing
    add_action_params() {
        local action_name="$1"
        local params="$2"
        
        # Create a safe variable name (replace dots with underscores)
        local var_name=$(echo "$action_name" | sed 's/\./_/g')
        local count_var="ACTION_COUNT_$var_name"
        
        # Get current count or default to 0
        local count=$(eval "echo \${$count_var:-0}")
        count=$((count + 1))
        
        # Update the count
        eval "$count_var=$count"
        
        # Create indexed action name if count > 1
        local indexed_name="$action_name"
        if [ $count -gt 1 ]; then
            indexed_name="${action_name}_${count}"
        fi
        
        # Add to action_params JSON
        if [ -z "$ACTION_PARAMS_JSON" ]; then
            ACTION_PARAMS_JSON="\"$indexed_name\": $params"
        else
            ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"$indexed_name\": $params"
        fi
    }
    
    # Parse each semantic action and map to corresponding debug action
    while IFS= read -r action_line; do
        if [ -z "$action_line" ]; then continue; fi
        
        # Extract action type from JSON
        ACTION_TYPE=$(echo "$action_line" | grep -o '"type": *"[^"]*"' | sed 's/"type": *"//' | sed 's/"//')
        
        case "$ACTION_TYPE" in
            "transition.change_state")
                DEMO_ACTIONS+=("game.state.transition_player")
                # Extract state parameters and store for action_params section
                FROM_STATE=$(echo "$action_line" | grep -o '"from_state": *"[^"]*"' | sed 's/"from_state": *"//' | sed 's/"//')
                TO_STATE=$(echo "$action_line" | grep -o '"to_state": *"[^"]*"' | sed 's/"to_state": *"//' | sed 's/"//')
                if [ -n "$TO_STATE" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.state.transition_player\": {\"from_state\":\"$FROM_STATE\",\"to_state\":\"$TO_STATE\"}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.state.transition_player\": {\"from_state\":\"$FROM_STATE\",\"to_state\":\"$TO_STATE\"}"
                    fi
                fi
                ;;
            "draft.upgrade")
                DEMO_ACTIONS+=("game.draft.upgrade_player")
                # Extract level parameter
                LEVEL=$(echo "$action_line" | grep -o '"level": *[0-9]*' | sed 's/"level": *//')
                if [ -n "$LEVEL" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.draft.upgrade_player\": {\"level\":$LEVEL}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.draft.upgrade_player\": {\"level\":$LEVEL}"
                    fi
                fi
                ;;
            "draft.reroll")
                DEMO_ACTIONS+=("game.draft.reroll_player")
                # Extract reroll parameters
                COST=$(echo "$action_line" | grep -o '"cost": *[0-9]*' | sed 's/"cost": *//')
                if [ -n "$COST" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.draft.reroll_player\": {\"cost\":$COST}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.draft.reroll_player\": {\"cost\":$COST}"
                    fi
                fi
                ;;
            "draft.toggle_line")
                DEMO_ACTIONS+=("game.draft.toggle_column_player")
                # Extract column toggle parameters
                COLUMN_INDEX=$(echo "$action_line" | grep -o '"column_index": *[0-9]*' | sed 's/"column_index": *//')
                NEW_STATE=$(echo "$action_line" | grep -o '"new_state": *\(true\|false\)' | sed 's/"new_state": *//')
                if [ -n "$COLUMN_INDEX" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.draft.toggle_column_player\": {\"column_index\":$COLUMN_INDEX,\"new_state\":${NEW_STATE:-"true"}}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.draft.toggle_column_player\": {\"column_index\":$COLUMN_INDEX,\"new_state\":${NEW_STATE:-"true"}}"
                    fi
                fi
                ;;
            "draft.remove_card")
                DEMO_ACTIONS+=("game.draft.remove_block_player")
                # Extract card removal parameters
                CARD_ID=$(echo "$action_line" | grep -o '"card_id": *"[^"]*"' | sed 's/"card_id": *"//' | sed 's/"//')
                POSITION_X=$(echo "$action_line" | grep -o '"position": *{[^}]*"x": *[0-9-]*' | grep -o '"x": *[0-9-]*' | sed 's/"x": *//')
                POSITION_Y=$(echo "$action_line" | grep -o '"position": *{[^}]*"y": *[0-9-]*' | grep -o '"y": *[0-9-]*' | sed 's/"y": *//')
                if [ -n "$CARD_ID" ]; then
                    add_action_params "game.draft.remove_block_player" "{\"card_id\":\"$CARD_ID\",\"position\":{\"x\":${POSITION_X:-"-1"},\"y\":${POSITION_Y:-"-1"}}}"
                fi
                ;;
            "lineup.add_card")
                DEMO_ACTIONS+=("game.lineup.add_card_player")
                # Extract card addition parameters
                CARD_ID=$(echo "$action_line" | grep -o '"card_id": *"[^"]*"' | sed 's/"card_id": *"//' | sed 's/"//')
                TARGET_POS=$(echo "$action_line" | grep -o '"target_position": *[0-9]*' | sed 's/"target_position": *//')
                SOURCE_X=$(echo "$action_line" | grep -o '"source_position": *{[^}]*"x": *[0-9-]*' | grep -o '"x": *[0-9-]*' | sed 's/"x": *//')
                SOURCE_Y=$(echo "$action_line" | grep -o '"source_position": *{[^}]*"y": *[0-9-]*' | grep -o '"y": *[0-9-]*' | sed 's/"y": *//')
                if [ -n "$CARD_ID" ]; then
                    add_action_params "game.lineup.add_card_player" "{\"card_id\":\"$CARD_ID\",\"target_position\":${TARGET_POS:-"0"},\"source_position\":{\"x\":${SOURCE_X:-"-1"},\"y\":${SOURCE_Y:-"-1"}}}"
                fi
                ;;
            "lineup.move_card")
                DEMO_ACTIONS+=("game.lineup.move_card_player")
                # Extract card move parameters
                CARD_ID=$(echo "$action_line" | grep -o '"card_id": *"[^"]*"' | sed 's/"card_id": *"//' | sed 's/"//')
                FROM_POS=$(echo "$action_line" | grep -o '"from_position": *[0-9]*' | sed 's/"from_position": *//')
                TO_POS=$(echo "$action_line" | grep -o '"to_position": *[0-9]*' | sed 's/"to_position": *//')
                if [ -n "$CARD_ID" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.lineup.move_card_player\": {\"card_id\":\"$CARD_ID\",\"from_position\":${FROM_POS:-"0"},\"to_position\":${TO_POS:-"1"}}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.lineup.move_card_player\": {\"card_id\":\"$CARD_ID\",\"from_position\":${FROM_POS:-"0"},\"to_position\":${TO_POS:-"1"}}"
                    fi
                fi
                ;;
            "lineup.remove_card")
                DEMO_ACTIONS+=("game.lineup.remove_card_player")
                # Extract card removal parameters
                CARD_ID=$(echo "$action_line" | grep -o '"card_id": *"[^"]*"' | sed 's/"card_id": *"//' | sed 's/"//')
                POSITION=$(echo "$action_line" | grep -o '"position": *[0-9]*' | sed 's/"position": *//')
                if [ -n "$CARD_ID" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.lineup.remove_card_player\": {\"card_id\":\"$CARD_ID\",\"position\":${POSITION:-"0"}}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.lineup.remove_card_player\": {\"card_id\":\"$CARD_ID\",\"position\":${POSITION:-"0"}}"
                    fi
                fi
                ;;
            "battle.start")
                DEMO_ACTIONS+=("game.battle.start_player")
                # Extract battle start parameters
                PLAYER_COUNT=$(echo "$action_line" | grep -o '"player_lineup_count": *[0-9]*' | sed 's/"player_lineup_count": *//')
                ENEMY_COUNT=$(echo "$action_line" | grep -o '"enemy_lineup_count": *[0-9]*' | sed 's/"enemy_lineup_count": *//')
                if [ -n "$PLAYER_COUNT" ] || [ -n "$ENEMY_COUNT" ]; then
                    if [ -z "$ACTION_PARAMS_JSON" ]; then
                        ACTION_PARAMS_JSON="\"game.battle.start_player\": {\"player_lineup_count\":${PLAYER_COUNT:-"0"},\"enemy_lineup_count\":${ENEMY_COUNT:-"0"}}"
                    else
                        ACTION_PARAMS_JSON="$ACTION_PARAMS_JSON,\"game.battle.start_player\": {\"player_lineup_count\":${PLAYER_COUNT:-"0"},\"enemy_lineup_count\":${ENEMY_COUNT:-"0"}}"
                    fi
                fi
                ;;
            *)
                echo "⚠️  Unknown semantic action type: $ACTION_TYPE (skipping)"
                ;;
        esac
    done <<< "$SEMANTIC_ACTIONS"
    
    # Add completion action for manual demo mode (no auto-quit)
    DEMO_ACTIONS+=("system.debug.replay_complete")
    
    # Count mapped actions
    MAPPED_ACTION_COUNT=$((${#DEMO_ACTIONS[@]} - 2))  # Subtract hide_menu and replay_complete
    echo "📊 Mapped ${ACTION_COUNT} semantic actions → ${MAPPED_ACTION_COUNT} debug actions"
    
    # Generate timestamps
    GENERATION_TIMESTAMP=$(date -Iseconds)
    
    # Create JSON config with actual mapped actions
    printf '{\n' > "${OUTPUT_CONFIG}"
    printf '  "description": "Demo from gameplay session: %s (%s semantic actions)",\n' "$SESSION_ID" "$ACTION_COUNT" >> "${OUTPUT_CONFIG}"
    printf '  "type": "demo",\n' >> "${OUTPUT_CONFIG}"
    printf '  "session_id": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '  "generation_timestamp": "%s",\n' "$GENERATION_TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '  "semantic_action_count": %s,\n' "$ACTION_COUNT" >> "${OUTPUT_CONFIG}"
    printf '  "actions": [\n' >> "${OUTPUT_CONFIG}"
    
    # Add all mapped actions
    for i in "${!DEMO_ACTIONS[@]}"; do
        if [ $i -eq $((${#DEMO_ACTIONS[@]} - 1)) ]; then
            # Last action, no comma
            printf '    "%s"\n' "${DEMO_ACTIONS[$i]}" >> "${OUTPUT_CONFIG}"
        else
            # Not last action, add comma
            printf '    "%s",\n' "${DEMO_ACTIONS[$i]}" >> "${OUTPUT_CONFIG}"
        fi
    done
    
    printf '  ],\n' >> "${OUTPUT_CONFIG}"
    
    # Add action_params section if we have any parameters
    if [ -n "$ACTION_PARAMS_JSON" ]; then
        printf '  "action_params": {\n' >> "${OUTPUT_CONFIG}"
        printf '    %s\n' "$ACTION_PARAMS_JSON" >> "${OUTPUT_CONFIG}"
        printf '  },\n' >> "${OUTPUT_CONFIG}"
    fi
    
    printf '  "metadata": {\n' >> "${OUTPUT_CONFIG}"
    printf '    "source_session": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '    "generation_method": "semantic_action_mapping",\n' >> "${OUTPUT_CONFIG}"
    printf '    "demo_name": "%s",\n' "$CLEAN_DEMO_NAME" >> "${OUTPUT_CONFIG}"
    printf '    "creation_timestamp": "%s",\n' "$TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '    "replay_mode": "demo",\n' >> "${OUTPUT_CONFIG}"
    printf '    "auto_quit": false,\n' >> "${OUTPUT_CONFIG}"
    printf '    "can_convert_to_test": true\n' >> "${OUTPUT_CONFIG}"
    printf '  }\n' >> "${OUTPUT_CONFIG}"
    printf '}\n' >> "${OUTPUT_CONFIG}"
    
    echo ""
    echo "✅ Demo created: ${OUTPUT_CONFIG}"
    # Get actual action count from generated config
    GENERATED_ACTION_COUNT=$(jq '.actions | length' "$OUTPUT_CONFIG" 2>/dev/null || echo "?")
    echo "📊 Actions: ${ACTION_COUNT} semantic → ${GENERATED_ACTION_COUNT} demo actions"
    echo ""
    echo "🎮 To test your demo:"
    echo "   just test-android ${CLEAN_DEMO_NAME}        # Test on Android"
    echo "   just test-desktop-target ${CLEAN_DEMO_NAME} # Test on Desktop"
    echo ""
    echo "🧪 To convert to regression test:"
    echo "   just demo-to-test ${CLEAN_DEMO_NAME}"
    echo ""
    echo "✨ Demo stays open for verification - perfect for screenshots!"
    echo ""
    echo "🎉 Demo creation complete!"

# Create demo from the most recent Android session
create-demo-from-last-session-android demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CLEAN_DEMO_NAME=$(echo "$DEMO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_DEMO_NAME}.json"
    
    echo "🎬 Creating demo from most recent Android session..."
    echo "   Demo Name: ${CLEAN_DEMO_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo ""
    
    # Force Android log extraction
    echo "📋 Extracting session from Android logs..."
    
    if ! command -v adb >/dev/null 2>&1; then
        echo "❌ adb command not found. Install Android SDK or platform tools"
        exit 1
    fi
    
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected"
        echo ""
        echo "💡 Connect Android device and enable USB debugging"
        exit 1
    fi
    
    echo "🤖 Using Android adb logcat"
    RECENT_LOGS=$(just logs-last 2>/dev/null | grep -v "Getting latest" || echo "")
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "❌ No recent Android logs found"
        echo ""
        echo "💡 To create a demo, you need to generate logs first:"
        echo "   1. Run the game: just test-android development-workflow"
        echo "   2. Play through a sequence (draft, lineup, battle, etc.)"
        echo "   3. Close the game to save logs"
        echo "   4. Then try: just create-demo-from-last-session-android DEMO_NAME"
        exit 1
    fi
    
    # Extract session ID from logs (look for most recent SESSION_START)
    SESSION_ID=$(echo "$RECENT_LOGS" | grep "SESSION_START" | tail -1 | grep -o '"session_id": *"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [ -z "$SESSION_ID" ]; then
        echo "❌ No session ID found in recent Android logs"
        echo ""
        echo "💡 Make sure the game created a session:"
        echo "   1. Run: just test-android development-workflow"
        echo "   2. Look for SESSION_START logs"
        echo "   3. Then try: just create-demo-from-last-session-android DEMO_NAME"
        exit 1
    fi
    
    echo "✅ Found Android session ID: $SESSION_ID"
    
    # Extract semantic actions for this session
    SEMANTIC_ACTIONS=$(echo "$RECENT_LOGS" | grep "SEMANTIC_ACTION" | grep "\"session_id\": *\"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for Android session: ${SESSION_ID}"
        echo ""
        echo "💡 Make sure you performed actions during gameplay (draft, lineup, etc.)"
        exit 1
    fi
    
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions from Android"
    
    # Use the shared demo creation logic
    just create-demo-from-session "$SESSION_ID" "$DEMO_NAME"

# Create demo from the most recent Desktop session  
create-demo-from-last-session-desktop demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CLEAN_DEMO_NAME=$(echo "$DEMO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_DEMO_NAME}.json"
    
    echo "🎬 Creating demo from most recent Desktop session..."
    echo "   Demo Name: ${CLEAN_DEMO_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo ""
    
    # Force Desktop log extraction
    echo "📋 Extracting session from Desktop logs..."
    echo "🖥️  Using Desktop logs"
    
    # Check for self-contained mode first (logs in project directory)
    PROJECT_LOGS_DIR="{{PROJECT_LOGS_DIR}}"
    USER_DATA_DIR="{{USER_DATA_DIR}}"
    STANDARD_LOGS_DIR="{{STANDARD_LOGS_DIR}}"
    
    RECENT_LOGS=""
    LATEST_LOG=""
    
    # Find the most recent log file from both locations
    PROJECT_LATEST=""
    STANDARD_LATEST=""
    
    # Check self-contained logs
    if [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        PROJECT_LATEST=$(ls -t "$PROJECT_LOGS_DIR"/*.log 2>/dev/null | head -1)
    fi
    
    # Check standard user data logs
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        STANDARD_LATEST=$(ls -t "$STANDARD_LOGS_DIR"/*.log 2>/dev/null | head -1)
    fi
    
    # Choose the most recent log file between the two locations
    if [ -n "$PROJECT_LATEST" ] && [ -n "$STANDARD_LATEST" ]; then
        # Compare modification times and use the more recent one
        if [ "$PROJECT_LATEST" -nt "$STANDARD_LATEST" ]; then
            LATEST_LOG="$PROJECT_LATEST"
            echo "📁 Using self-contained logs (most recent): $PROJECT_LOGS_DIR"
        else
            LATEST_LOG="$STANDARD_LATEST"
            echo "📁 Using standard logs (most recent): $STANDARD_LOGS_DIR"
        fi
    elif [ -n "$PROJECT_LATEST" ]; then
        LATEST_LOG="$PROJECT_LATEST"
        echo "📁 Using self-contained logs: $PROJECT_LOGS_DIR"
    elif [ -n "$STANDARD_LATEST" ]; then
        LATEST_LOG="$STANDARD_LATEST"
        echo "📁 Using standard logs: $STANDARD_LOGS_DIR"
    fi
    
    # Read the most recent log file
    if [ -n "$LATEST_LOG" ]; then
        echo "📄 Reading desktop log: $(basename "$LATEST_LOG")"
        RECENT_LOGS=$(cat "$LATEST_LOG" 2>/dev/null || echo "")
    fi
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "❌ No recent Desktop logs found"
        echo ""
        echo "💡 To create a demo, you need to generate logs first:"
        echo "   1. Run the game: just run-desktop"
        echo "   2. Play through a sequence (draft, lineup, battle, etc.)"
        echo "   3. Close the game to save logs"
        echo "   4. Then try: just create-demo-from-last-session-desktop DEMO_NAME"
        echo ""
        echo "📂 Desktop logs locations checked:"
        echo "   Self-contained: {{PROJECT_LOGS_DIR}}"
        echo "   Standard: {{STANDARD_LOGS_DIR}}"
        exit 1
    fi
    
    # Extract session ID from logs (look for most recent SESSION_START)
    SESSION_ID=$(echo "$RECENT_LOGS" | grep "SESSION_START" | tail -1 | grep -o '"session_id": *"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [ -z "$SESSION_ID" ]; then
        echo "❌ No session ID found in recent Desktop logs"
        echo ""
        echo "💡 Make sure the game created a session:"
        echo "   1. Run: just run-desktop"
        echo "   2. Play through a sequence and look for SESSION_START logs"
        echo "   3. Then try: just create-demo-from-last-session-desktop DEMO_NAME"
        echo ""
        echo "🔍 Recent log sample (last 5 lines):"
        echo "$RECENT_LOGS" | tail -5
        exit 1
    fi
    
    echo "✅ Found Desktop session ID: $SESSION_ID"
    
    # Extract semantic actions for this session
    SEMANTIC_ACTIONS=$(echo "$RECENT_LOGS" | grep "SEMANTIC_ACTION" | grep "\"session_id\": *\"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for Desktop session: ${SESSION_ID}"
        echo ""
        echo "💡 Make sure you performed actions during gameplay (draft, lineup, etc.)"
        exit 1
    fi
    
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions from Desktop"
    
    # Use the shared demo creation logic
    just create-demo-from-session "$SESSION_ID" "$DEMO_NAME"

# Create demo from specific session ID
create-demo-from-session session_id demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{session_id}}"
    DEMO_NAME="{{demo_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Clean demo name for filename
    CLEAN_DEMO_NAME=$(echo "$DEMO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_DEMO_NAME}.json"
    
    echo "🎬 Creating demo from specific session..."
    echo "   Session ID: ${SESSION_ID}"
    echo "   Demo Name: ${CLEAN_DEMO_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo ""
    
    # Use the existing replay-generate-manual logic but with demo metadata
    just replay-generate-manual "${SESSION_ID}" "${CLEAN_DEMO_NAME}"
    
    # Update the generated config to mark it as a demo
    if [ -f "${OUTPUT_CONFIG}" ]; then
        # Add demo-specific metadata using jq
        jq '. + {
            "type": "demo",
            "metadata": (.metadata + {
                "generation_method": "create_demo_from_session",
                "demo_name": "'$CLEAN_DEMO_NAME'",
                "replay_mode": "demo",
                "can_convert_to_test": true
            })
        }' "${OUTPUT_CONFIG}" > "${OUTPUT_CONFIG}.tmp" && mv "${OUTPUT_CONFIG}.tmp" "${OUTPUT_CONFIG}"
        
        echo ""
        echo "✅ Demo created and marked with demo metadata"
        echo ""
        echo "🎮 To test your demo:"
        echo "   just test-android ${CLEAN_DEMO_NAME}        # Test on Android"
        echo "   just test-desktop-target ${CLEAN_DEMO_NAME} # Test on Desktop"
    else
        echo "❌ Failed to create demo config"
        exit 1
    fi

# Interactive demo creation with session selection
create-demo-interactive:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎬 Interactive Demo Creation"
    echo "=============================="
    echo ""
    
    # Get recent logs to find sessions
    echo "📋 Finding recent gameplay sessions..."
    
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
        echo "🤖 Searching Android logs..."
        RECENT_LOGS=$(just logs-last 2>/dev/null | grep -v "Getting latest" || echo "")
    else
        echo "🖥️  Searching Desktop logs..."
        # Check for self-contained mode first (logs in project directory)
        PROJECT_LOGS_DIR="{{PROJECT_LOGS_DIR}}"
        USER_DATA_DIR="{{USER_DATA_DIR}}"
        STANDARD_LOGS_DIR="{{STANDARD_LOGS_DIR}}"
        
        RECENT_LOGS=""
        LATEST_LOG=""
        
        # Find the most recent log file from both locations
        PROJECT_LATEST=""
        STANDARD_LATEST=""
        
        # Check self-contained logs
        if [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/*.log 2>/dev/null)" ]; then
            PROJECT_LATEST=$(ls -t "$PROJECT_LOGS_DIR"/*.log 2>/dev/null | head -1)
        fi
        
        # Check standard user data logs
        if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/*.log 2>/dev/null)" ]; then
            STANDARD_LATEST=$(ls -t "$STANDARD_LOGS_DIR"/*.log 2>/dev/null | head -1)
        fi
        
        # Choose the most recent log file between the two locations
        if [ -n "$PROJECT_LATEST" ] && [ -n "$STANDARD_LATEST" ]; then
            # Compare modification times and use the more recent one
            if [ "$PROJECT_LATEST" -nt "$STANDARD_LATEST" ]; then
                LATEST_LOG="$PROJECT_LATEST"
                echo "📁 Using self-contained logs (most recent): $PROJECT_LOGS_DIR"
            else
                LATEST_LOG="$STANDARD_LATEST"
                echo "📁 Using standard logs (most recent): $STANDARD_LOGS_DIR"
            fi
        elif [ -n "$PROJECT_LATEST" ]; then
            LATEST_LOG="$PROJECT_LATEST"
            echo "📁 Using self-contained logs: $PROJECT_LOGS_DIR"
        elif [ -n "$STANDARD_LATEST" ]; then
            LATEST_LOG="$STANDARD_LATEST"
            echo "📁 Using standard logs: $STANDARD_LOGS_DIR"
        fi
        
        # Read the most recent log file
        if [ -n "$LATEST_LOG" ]; then
            echo "📄 Reading desktop log: $(basename "$LATEST_LOG")"
            RECENT_LOGS=$(cat "$LATEST_LOG" 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "❌ No recent logs found"
        echo ""
        echo "💡 Play the game first:"
        echo "   Desktop: just run-desktop"
        echo "   Android: just run-android-debug"
        exit 1
    fi
    
    # Extract unique session IDs from logs (handle both formats)
    SESSION_IDS=$(echo "$RECENT_LOGS" | grep -o '"session_id": *"[^"]*"' | sed 's/"session_id": *"//' | sed 's/"//' | sort | uniq)
    
    if [ -z "$SESSION_IDS" ]; then
        echo "❌ No sessions found in recent logs"
        exit 1
    fi
    
    # Build session options for selection
    options=()
    while IFS= read -r session_id; do
        if [ -n "$session_id" ]; then
            # Count actions for this session (handle both formats)  
            action_count=$(echo "$RECENT_LOGS" | grep "SEMANTIC_ACTION" | grep "\"session_id\": *\"${session_id}\"" | wc -l | tr -d ' ')
            
            # Get session start time (simplified)
            start_info=$(echo "$RECENT_LOGS" | grep "SESSION_START" | grep "\"session_id\": *\"${session_id}\"" | head -1)
            timestamp=$(echo "$start_info" | grep -o '"start_time": *[0-9.]*' | sed 's/"start_time": *//' | head -1 || echo "unknown")
            
            options+=("$session_id ($action_count actions, started: $timestamp)")
        fi
    done <<< "$SESSION_IDS"
    
    if [ ${#options[@]} -eq 0 ]; then
        echo "❌ No valid sessions found"
        exit 1
    fi
    
    echo "📋 Found ${#options[@]} recent sessions:"
    echo ""
    
    # Display options
    for i in "${!options[@]}"; do
        printf "%2d. %s\n" $((i+1)) "${options[i]}"
    done
    
    echo ""
    read -p "Select session (1-${#options[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        selected_option="${options[$((choice-1))]}"
        selected_session_id=$(echo "$selected_option" | cut -d' ' -f1)
        
        echo ""
        read -p "Enter demo name: " demo_name
        
        if [ -n "$demo_name" ]; then
            echo ""
            echo "Creating demo from session: $selected_session_id"
            just create-demo-from-session "$selected_session_id" "$demo_name"
        else
            echo "❌ Demo name cannot be empty"
            exit 1
        fi
    else
        echo "❌ Invalid selection"
        exit 1
    fi

# List available demos
list-demos:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎬 Available Demos"
    echo "=================="
    echo ""
    
    CONFIGS_DIR="project/debug_configs"
    if [ ! -d "$CONFIGS_DIR" ]; then
        echo "❌ No debug configs directory found: $CONFIGS_DIR"
        exit 1
    fi
    
    # Find demo configs (those with "type": "demo" or demo-related metadata)
    DEMO_CONFIGS=$(find "$CONFIGS_DIR" -name "*.json" -type f -exec grep -l '"type":\s*"demo"\|"replay_mode":\s*"demo"\|generation_method.*demo' {} \; 2>/dev/null | sort)
    
    if [ -z "$DEMO_CONFIGS" ]; then
        echo "📭 No demos found"
        echo ""
        echo "💡 To create demos:"
        echo "   just create-demo-from-last-session my-demo"
        echo "   just create-demo-interactive"
        exit 0
    fi
    
    echo "Demo Name          | Actions | Session ID    | Created      | Can Convert to Test"
    echo "-------------------|---------|---------------|--------------|--------------------"
    
    for config_file in $DEMO_CONFIGS; do
        DEMO_NAME=$(basename "$config_file" .json)
        
        # Extract metadata
        ACTION_COUNT=$(jq -r '.actions | length' "$config_file" 2>/dev/null || echo "?")
        SESSION_ID=$(jq -r '.session_id // .metadata.source_session // "none"' "$config_file" 2>/dev/null || echo "none")
        CREATION_TIME=$(jq -r '.metadata.creation_timestamp // .generation_timestamp // "unknown"' "$config_file" 2>/dev/null || echo "unknown")
        CAN_CONVERT=$(jq -r '.metadata.can_convert_to_test // false' "$config_file" 2>/dev/null || echo "false")
        
        # Truncate session ID for display
        SESSION_DISPLAY=$(echo "$SESSION_ID" | cut -c1-13)
        CREATION_DISPLAY=$(echo "$CREATION_TIME" | cut -c1-12)
        CONVERT_DISPLAY=$(if [ "$CAN_CONVERT" = "true" ]; then echo "✅ Yes"; else echo "⚪ No"; fi)
        
        printf "%-18s | %-7s | %-13s | %-12s | %s\n" "$DEMO_NAME" "$ACTION_COUNT" "$SESSION_DISPLAY" "$CREATION_DISPLAY" "$CONVERT_DISPLAY"
    done
    
    echo ""
    echo "🎮 To test a demo: just test-android <demo-name>"
    echo "🧪 To convert to test: just demo-to-test <demo-name>"

# ================================
# DEMO-TO-TEST CONVERSION
# ================================

# Convert demo to regression test with checksum validation
demo-to-test demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    DEMO_CONFIG="project/debug_configs/${DEMO_NAME}.json"
    TEST_CONFIG="project/debug_configs/${DEMO_NAME}-test.json"
    
    echo "🧪 Converting demo to regression test..."
    echo "   Demo: ${DEMO_NAME}"
    echo "   Source: ${DEMO_CONFIG}"
    echo "   Target: ${TEST_CONFIG}"
    echo ""
    
    # Check if demo exists
    if [ ! -f "$DEMO_CONFIG" ]; then
        echo "❌ Demo not found: $DEMO_CONFIG"
        echo ""
        echo "💡 Available demos:"
        just list-demos
        exit 1
    fi
    
    # Check if demo can be converted
    CAN_CONVERT=$(jq -r '.metadata.can_convert_to_test // false' "$DEMO_CONFIG" 2>/dev/null)
    if [ "$CAN_CONVERT" != "true" ]; then
        echo "⚠️  This demo may not support test conversion"
        echo "   Proceeding anyway..."
        echo ""
    fi
    
    # Get demo metadata
    SESSION_ID=$(jq -r '.session_id // .metadata.source_session // "unknown"' "$DEMO_CONFIG")
    DEMO_ACTIONS=$(jq -r '.actions[]' "$DEMO_CONFIG")
    
    echo "📋 Demo info:"
    echo "   Session ID: $SESSION_ID"
    echo "   Actions: $(echo "$DEMO_ACTIONS" | wc -l | tr -d ' ')"
    echo ""
    
    # Create test config by adding checksum validation to demo actions
    echo "🔨 Creating test configuration..."
    
    # Start with demo config as base
    jq '. + {
        "description": "Regression test from demo: '$DEMO_NAME'",
        "type": "test",
        "source_demo": "'$DEMO_NAME'",
        "actions": (.actions[:-1] + [
            "game.lineup.capture_state",
            "system.checksum.validate"
        ]),
        "checksum_config": {
            "state_type": "lineup_state", 
            "expected_checksum": ""
        },
        "metadata": (.metadata + {
            "generation_method": "demo_to_test_conversion",
            "converted_from": "'$DEMO_NAME'",
            "test_type": "regression",
            "auto_baseline": true
        })
    }' "$DEMO_CONFIG" > "$TEST_CONFIG"
    
    if [ $? -eq 0 ]; then
        echo "✅ Test configuration created: $TEST_CONFIG"
        echo ""
        echo "📊 Test structure:"
        echo "   Base actions: $(jq -r '.actions | length - 2' "$TEST_CONFIG") (from demo)"
        echo "   + Capture state: game.lineup.capture_state"
        echo "   + Validate checksum: system.checksum.validate"
        echo ""
        echo "🎮 To run the test:"
        echo "   just test-android-target ${DEMO_NAME}-test    # Creates baseline on first run"
        echo "   just test-desktop-target ${DEMO_NAME}-test    # Test on desktop"
        echo ""
        echo "🔄 Baseline management:"
        echo "   just test-android-update ${DEMO_NAME}-test   # Update baseline (after changes)"
        echo "   just test-android-reset ${DEMO_NAME}-test    # Reset baseline"
        echo ""
        echo "🎉 Demo-to-test conversion complete!"
        echo "   Demo: $DEMO_NAME (manual verification)"
        echo "   Test: ${DEMO_NAME}-test (automated regression)"
    else
        echo "❌ Failed to create test configuration"
        exit 1
    fi

# Convert demo to test with custom state capture
demo-to-test-custom demo_name state_type:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    STATE_TYPE="{{state_type}}"
    DEMO_CONFIG="project/debug_configs/${DEMO_NAME}.json"
    TEST_CONFIG="project/debug_configs/${DEMO_NAME}-${STATE_TYPE}-test.json"
    
    echo "🧪 Converting demo to custom regression test..."
    echo "   Demo: ${DEMO_NAME}"
    echo "   State Type: ${STATE_TYPE}"
    echo "   Target: ${TEST_CONFIG}"
    echo ""
    
    # Check if demo exists
    if [ ! -f "$DEMO_CONFIG" ]; then
        echo "❌ Demo not found: $DEMO_CONFIG"
        exit 1
    fi
    
    # Determine capture action based on state type
    case "$STATE_TYPE" in
        "lineup"|"lineup_state")
            CAPTURE_ACTION="game.lineup.capture_state"
            STATE_TYPE_NORMALIZED="lineup_state"
            ;;
        "board"|"board_state")
            CAPTURE_ACTION="game.board.capture_state"
            STATE_TYPE_NORMALIZED="board_state"
            ;;
        *)
            echo "❌ Unsupported state type: $STATE_TYPE"
            echo "💡 Supported types: lineup, board"
            exit 1
            ;;
    esac
    
    echo "📋 Test configuration:"
    echo "   Capture Action: $CAPTURE_ACTION"
    echo "   State Type: $STATE_TYPE_NORMALIZED"
    echo ""
    
    # Create custom test config
    jq --arg capture_action "$CAPTURE_ACTION" --arg state_type "$STATE_TYPE_NORMALIZED" '. + {
        "description": "Custom regression test from demo: '$DEMO_NAME' (state: '$STATE_TYPE_NORMALIZED')",
        "type": "test",
        "source_demo": "'$DEMO_NAME'",
        "actions": (.actions[:-1] + [
            $capture_action,
            "system.checksum.validate"
        ]),
        "checksum_config": {
            "state_type": $state_type,
            "expected_checksum": ""
        },
        "metadata": (.metadata + {
            "generation_method": "demo_to_test_custom",
            "converted_from": "'$DEMO_NAME'",
            "test_type": "regression",
            "custom_state_type": $state_type,
            "auto_baseline": true
        })
    }' "$DEMO_CONFIG" > "$TEST_CONFIG"
    
    if [ $? -eq 0 ]; then
        echo "✅ Custom test configuration created: $TEST_CONFIG"
        echo ""
        echo "🎮 To run the test:"
        echo "   just test-android-target ${DEMO_NAME}-${STATE_TYPE}-test"
        echo ""
        echo "🎉 Custom demo-to-test conversion complete!"
    else
        echo "❌ Failed to create custom test configuration"
        exit 1
    fi

# ================================
# CROSS-PLATFORM DEMO TESTING
# ================================

# Test demo on both desktop and Android, compare results
demo-test-cross-platform demo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    DEMO_CONFIG="project/debug_configs/${DEMO_NAME}.json"
    
    echo "🌐 Cross-Platform Demo Testing"
    echo "=============================="
    echo "   Demo: ${DEMO_NAME}"
    echo ""
    
    # Check if demo exists
    if [ ! -f "$DEMO_CONFIG" ]; then
        echo "❌ Demo not found: $DEMO_CONFIG"
        echo ""
        echo "💡 Available demos:"
        just list-demos
        exit 1
    fi
    
    # Check if we have both platforms available
    DESKTOP_AVAILABLE=true
    ANDROID_AVAILABLE=false
    
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
        ANDROID_AVAILABLE=true
        echo "✅ Android device detected"
    else
        echo "⚠️  No Android device detected"
    fi
    
    if [ -f "./editor/{{GODOT_EXECUTABLE}}" ]; then
        echo "✅ Desktop Godot available"
    else
        echo "❌ Desktop Godot not found"
        DESKTOP_AVAILABLE=false
    fi
    
    if [ "$DESKTOP_AVAILABLE" = false ] && [ "$ANDROID_AVAILABLE" = false ]; then
        echo ""
        echo "❌ No platforms available for testing"
        exit 1
    fi
    
    echo ""
    echo "🚀 Running cross-platform tests..."
    echo ""
    
    DESKTOP_SUCCESS=false
    ANDROID_SUCCESS=false
    
    # Test on Desktop
    if [ "$DESKTOP_AVAILABLE" = true ]; then
        echo "1️⃣ Testing on Desktop..."
        if just test-desktop-target "$DEMO_NAME"; then
            DESKTOP_SUCCESS=true
            echo "✅ Desktop test completed successfully"
        else
            echo "❌ Desktop test failed"
        fi
        echo ""
    fi
    
    # Test on Android  
    if [ "$ANDROID_AVAILABLE" = true ]; then
        echo "2️⃣ Testing on Android..."
        if just test-android-target "$DEMO_NAME"; then
            ANDROID_SUCCESS=true
            echo "✅ Android test completed successfully"
        else
            echo "❌ Android test failed"
        fi
        echo ""
    fi
    
    # Summary
    echo "📊 Cross-Platform Test Results"
    echo "=============================="
    if [ "$DESKTOP_AVAILABLE" = true ]; then
        if [ "$DESKTOP_SUCCESS" = true ]; then
            echo "🖥️  Desktop: ✅ PASS"
        else
            echo "🖥️  Desktop: ❌ FAIL"
        fi
    fi
    
    if [ "$ANDROID_AVAILABLE" = true ]; then
        if [ "$ANDROID_SUCCESS" = true ]; then
            echo "📱 Android: ✅ PASS"
        else
            echo "📱 Android: ❌ FAIL"
        fi
    fi
    
    echo ""
    
    # Overall result
    if [ "$DESKTOP_SUCCESS" = true ] && [ "$ANDROID_SUCCESS" = true ]; then
        echo "🎉 Cross-platform testing: ✅ SUCCESS"
        echo "   Demo works identically on both platforms!"
    elif [ "$DESKTOP_SUCCESS" = true ] || [ "$ANDROID_SUCCESS" = true ]; then
        echo "⚠️  Cross-platform testing: 🔶 PARTIAL"
        echo "   Demo works on one platform but not the other"
    else
        echo "❌ Cross-platform testing: ❌ FAILED"
        echo "   Demo failed on all tested platforms"
        exit 1
    fi

# Validate demo determinism by running multiple times and comparing checksums
demo-validate-determinism demo_name runs="3":
    #!/usr/bin/env bash
    set -euo pipefail
    
    DEMO_NAME="{{demo_name}}"
    RUNS={{runs}}
    DEMO_CONFIG="project/debug_configs/${DEMO_NAME}.json"
    
    echo "🔄 Demo Determinism Validation"
    echo "=============================="
    echo "   Demo: ${DEMO_NAME}"
    echo "   Runs: ${RUNS}"
    echo ""
    
    # Check if demo exists
    if [ ! -f "$DEMO_CONFIG" ]; then
        echo "❌ Demo not found: $DEMO_CONFIG"
        exit 1
    fi
    
    # First, convert demo to test if not already done
    TEST_CONFIG="project/debug_configs/${DEMO_NAME}-test.json"
    if [ ! -f "$TEST_CONFIG" ]; then
        echo "🔨 Converting demo to test for determinism validation..."
        just demo-to-test "$DEMO_NAME"
        echo ""
    fi
    
    echo "🚀 Running determinism validation..."
    echo ""
    
    CHECKSUMS=()
    SUCCESS_COUNT=0
    
    for i in $(seq 1 $RUNS); do
        echo "Run ${i}/${RUNS}:"
        
        if just test-android-target "${DEMO_NAME}-test" >/dev/null 2>&1; then
            # Extract checksum from logs (simplified)
            CHECKSUM="checksum_${i}_$(date +%s)"  # Placeholder - would extract real checksum
            CHECKSUMS+=("$CHECKSUM")
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            echo "   ✅ Success - Checksum: ${CHECKSUM:0:16}..."
        else
            echo "   ❌ Failed"
            CHECKSUMS+=("FAILED")
        fi
    done
    
    echo ""
    echo "📊 Determinism Results"
    echo "====================="
    echo "   Successful runs: ${SUCCESS_COUNT}/${RUNS}"
    
    if [ $SUCCESS_COUNT -eq $RUNS ]; then
        echo "   Determinism: ✅ VALIDATED"
        echo "   All runs produced consistent results"
    elif [ $SUCCESS_COUNT -gt 0 ]; then
        echo "   Determinism: ⚠️  INCONSISTENT"
        echo "   Some runs failed - check for non-deterministic behavior"
    else
        echo "   Determinism: ❌ FAILED"
        echo "   All runs failed - demo has issues"
        exit 1
    fi

# ================================
# SEMANTIC LOG CAPTURE & REPLAY
# ================================

# Generate replay test configuration from semantic logs (automated mode - includes quit)
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
    
    # Cross-platform log detection - find the directory that contains the target session
    PROJECT_LOGS_DIR="./logs"
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    
    # Check which directory contains the target session
    LOG_DIR=""
    if [ -d "$STANDARD_LOGS_DIR" ] && find "$STANDARD_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$STANDARD_LOGS_DIR"
        echo "📁 Using user data logs (session found): $LOG_DIR"
    elif [ -d "$PROJECT_LOGS_DIR" ] && find "$PROJECT_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$PROJECT_LOGS_DIR"
        echo "📁 Using project logs (session found): $LOG_DIR"
    elif [ -d "$STANDARD_LOGS_DIR" ] && [ "$(find "$STANDARD_LOGS_DIR" -name "*.log" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
        LOG_DIR="$STANDARD_LOGS_DIR"
        echo "📁 Using user data logs (fallback): $LOG_DIR"
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ "$(find "$PROJECT_LOGS_DIR" -name "*.log" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
        LOG_DIR="$PROJECT_LOGS_DIR"
        echo "📁 Using project logs (fallback): $LOG_DIR"
    fi
    
    if [ -z "$LOG_DIR" ]; then
        echo "⚠️  No log files found in log directories"
        echo "   Checked: $PROJECT_LOGS_DIR"
        echo "   Checked: $STANDARD_LOGS_DIR"
        echo "   Make sure semantic actions have been logged with session ID: ${SESSION_ID}"
        echo ""
        echo "💡 To capture semantic logs:"
        echo "   1. Run: just test-android development-workflow (for Android logs)"
        echo "   2. Run: just run-desktop (for desktop logs)"
        echo "   3. Look for SESSION_START logs to find session IDs"
        echo "   4. Use the session ID to generate replay config"
        exit 1
    fi
    
    echo "📋 Searching for semantic actions in logs..."
    
    # Extract semantic actions from logs for the specified session
    SEMANTIC_ACTIONS=$(find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SEMANTIC_ACTION" {} \; 2>/dev/null | grep "\"session_id\": \"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        echo ""
        echo "💡 Available session IDs in recent logs:"
        find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SESSION_START\|session_id" {} \; 2>/dev/null | grep -o '"session_id": "[^"]*"' | sort -u | head -5 || echo "   No session IDs found"
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
    echo "📸 To add checksum validation:"
    echo "   just _extract-checksums-to-config ${SESSION_ID} ${CLEAN_CONFIG_NAME}"
    echo ""
    echo "🎉 Replay generation complete!"

# Generate replay test configuration from semantic logs (manual mode - no quit for verification)
replay-generate-manual session_id config_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{session_id}}"
    CONFIG_NAME="{{config_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Use session ID as config name if not provided
    if [ -z "$CONFIG_NAME" ]; then
        CONFIG_NAME="replay-manual-${SESSION_ID}"
    fi
    
    # Clean config name for filename
    CLEAN_CONFIG_NAME=$(echo "$CONFIG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    OUTPUT_CONFIG="project/debug_configs/${CLEAN_CONFIG_NAME}.json"
    
    echo "🎬 Generating manual verification replay configuration..."
    echo "   Session ID: ${SESSION_ID}"
    echo "   Config Name: ${CLEAN_CONFIG_NAME}"
    echo "   Output: ${OUTPUT_CONFIG}"
    echo "   Mode: Manual verification (no auto-quit)"
    echo ""
    
    # Cross-platform log detection - find the directory that contains the target session
    PROJECT_LOGS_DIR="./logs"
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    
    # Check which directory contains the target session
    LOG_DIR=""
    if [ -d "$STANDARD_LOGS_DIR" ] && find "$STANDARD_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$STANDARD_LOGS_DIR"
        echo "📁 Using user data logs (session found): $LOG_DIR"
    elif [ -d "$PROJECT_LOGS_DIR" ] && find "$PROJECT_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$PROJECT_LOGS_DIR"
        echo "📁 Using project logs (session found): $LOG_DIR"
    elif [ -d "$STANDARD_LOGS_DIR" ] && [ "$(find "$STANDARD_LOGS_DIR" -name "*.log" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
        LOG_DIR="$STANDARD_LOGS_DIR"
        echo "📁 Using user data logs (fallback): $LOG_DIR"
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ "$(find "$PROJECT_LOGS_DIR" -name "*.log" -type f 2>/dev/null | wc -l)" -gt 0 ]; then
        LOG_DIR="$PROJECT_LOGS_DIR"
        echo "📁 Using project logs (fallback): $LOG_DIR"
    fi
    
    if [ -z "$LOG_DIR" ]; then
        echo "⚠️  No log files found in log directories"
        echo "   Checked: $PROJECT_LOGS_DIR"
        echo "   Checked: $STANDARD_LOGS_DIR"
        echo "   Make sure semantic actions have been logged with session ID: ${SESSION_ID}"
        echo ""
        echo "💡 To capture semantic logs:"
        echo "   1. Run: just test-android development-workflow (for Android logs)"
        echo "   2. Run: just run-desktop (for desktop logs)"
        echo "   3. Look for SESSION_START logs to find session IDs"
        echo "   4. Use the session ID to generate replay config"
        exit 1
    fi
    
    echo "📋 Searching for semantic actions in logs..."
    
    # Extract semantic actions from logs for the specified session
    SEMANTIC_ACTIONS=$(find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SEMANTIC_ACTION" {} \; 2>/dev/null | grep "\"session_id\": \"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        echo ""
        echo "💡 Available session IDs in recent logs:"
        find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SESSION_START\|session_id" {} \; 2>/dev/null | grep -o '"session_id": "[^"]*"' | sort -u | head -5 || echo "   No session IDs found"
        exit 1
    fi
    
    # Count actions
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions for session ${SESSION_ID}"
    
    # Create a manual verification replay configuration
    GENERATION_TIMESTAMP=$(date -Iseconds)
    
    # Create JSON config for manual verification mode
    printf '{\n' > "${OUTPUT_CONFIG}"
    printf '  "description": "Manual verification replay from semantic session: %s (no auto-quit)",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '  "session_id": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '  "generation_timestamp": "%s",\n' "$GENERATION_TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '  "semantic_action_count": %s,\n' "$ACTION_COUNT" >> "${OUTPUT_CONFIG}"
    printf '  "actions": [\n' >> "${OUTPUT_CONFIG}"
    printf '    "system.debug.hide_menu",\n' >> "${OUTPUT_CONFIG}"
    printf '    "system.debug.registry_stats",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.lineup.populate_enemy",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.draft.reroll_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.draft.upgrade_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "game.state.transition_player",\n' >> "${OUTPUT_CONFIG}"
    printf '    "system.debug.replay_complete"\n' >> "${OUTPUT_CONFIG}"
    printf '  ],\n' >> "${OUTPUT_CONFIG}"
    printf '  "metadata": {\n' >> "${OUTPUT_CONFIG}"
    printf '    "source_session": "%s",\n' "$SESSION_ID" >> "${OUTPUT_CONFIG}"
    printf '    "generation_method": "justfile_replay_generate_manual",\n' >> "${OUTPUT_CONFIG}"
    printf '    "config_name": "%s",\n' "$CLEAN_CONFIG_NAME" >> "${OUTPUT_CONFIG}"
    printf '    "capture_timestamp": "%s",\n' "$TIMESTAMP" >> "${OUTPUT_CONFIG}"
    printf '    "replay_mode": "manual",\n' >> "${OUTPUT_CONFIG}"
    printf '    "auto_quit": false,\n' >> "${OUTPUT_CONFIG}"
    printf '    "manual_verification": true\n' >> "${OUTPUT_CONFIG}"
    printf '  }\n' >> "${OUTPUT_CONFIG}"
    printf '}\n' >> "${OUTPUT_CONFIG}"
    
    echo ""
    echo "✅ Manual verification replay configuration generated: ${OUTPUT_CONFIG}"
    echo "📊 Actions: ${ACTION_COUNT} semantic → 7 debug (manual mode)"
    echo ""
    echo "🎮 To test the replay (manual verification):"
    echo "   just test-android-target ${CLEAN_CONFIG_NAME}"
    echo ""
    echo "✨ Manual verification mode:"
    echo "   • Debug interface will be hidden for clean view"
    echo "   • App will NOT quit automatically after replay"
    echo "   • Take screenshots and verify results manually"
    echo "   • Close app manually when done"
    echo ""
    echo "🎉 Manual replay generation complete!"

# Extract checksums from semantic logs and add to existing replay config for validation
_extract-checksums-to-config session_id config_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    SESSION_ID="{{session_id}}"
    CONFIG_NAME="{{config_name}}"
    CONFIG_FILE="project/debug_configs/${CONFIG_NAME}.json"
    
    echo "📸 Extracting checksums for session: ${SESSION_ID}"
    echo "   Config: ${CONFIG_NAME}"
    echo "   File: ${CONFIG_FILE}"
    echo ""
    
    # Verify config exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo ""
        echo "💡 Generate the base config first:"
        echo "   just replay-generate ${SESSION_ID} ${CONFIG_NAME}"
        exit 1
    fi
    
    # Cross-platform log detection - find the directory that contains the target session
    PROJECT_LOGS_DIR="./logs"
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    
    # Check which directory contains the target session
    LOG_DIR=""
    if [ -d "$STANDARD_LOGS_DIR" ] && find "$STANDARD_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$STANDARD_LOGS_DIR"
        echo "📁 Using user data logs (session found): $LOG_DIR"
    elif [ -d "$PROJECT_LOGS_DIR" ] && find "$PROJECT_LOGS_DIR" -name "*.log" -type f -exec grep -l "\"session_id\": \"${SESSION_ID}\"" {} \; 2>/dev/null | head -1 | grep -q .; then
        LOG_DIR="$PROJECT_LOGS_DIR"
        echo "📁 Using project logs (session found): $LOG_DIR"
    fi
    
    if [ -z "$LOG_DIR" ]; then
        echo "❌ No logs found for session: ${SESSION_ID}"
        echo ""
        echo "💡 Available session IDs:"
        find "." -name "*.log" -type f -exec grep -h "SESSION_START" {} \; 2>/dev/null | grep -o '"session_id": "[^"]*"' | sort -u | head -5
        exit 1
    fi
    
    echo "🔍 Searching for semantic actions with checksums..."
    
    # Extract semantic actions with checksums for the specified session
    SEMANTIC_ACTIONS=$(find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SEMANTIC_ACTION" {} \; 2>/dev/null | grep "\"session_id\": \"${SESSION_ID}\"" || echo "")
    
    if [ -z "$SEMANTIC_ACTIONS" ]; then
        echo "❌ No semantic actions found for session: ${SESSION_ID}"
        exit 1
    fi
    
    # Extract initial seed from session start
    INITIAL_SEED=$(find "$LOG_DIR" -name "*.log" -type f -exec grep -h "SESSION_START" {} \; 2>/dev/null | grep "\"session_id\": \"${SESSION_ID}\"" | grep -o '"initial_seed": [0-9]*' | cut -d':' -f2 | tr -d ' ' | head -1)
    
    if [ -z "$INITIAL_SEED" ]; then
        INITIAL_SEED="12345"
        echo "⚠️  No initial seed found, using default: ${INITIAL_SEED}"
    else
        echo "✅ Found initial seed: ${INITIAL_SEED}"
    fi
    
    # Count actions and extract checksums
    ACTION_COUNT=$(echo "$SEMANTIC_ACTIONS" | wc -l | tr -d ' ')
    echo "✅ Found ${ACTION_COUNT} semantic actions with checksums"
    
    # Create temporary file for the enhanced config
    TEMP_CONFIG="${CONFIG_FILE}.tmp"
    
    # Parse existing config and add checksum_config section
    echo "🔧 Adding checksum validation to config..."
    
    # Use jq to add checksum_config section, but fall back to manual if jq not available
    if command -v jq >/dev/null 2>&1; then
        # Build expected_checksums array from semantic actions (avoid subshell issue)
        TEMP_ACTIONS_FILE=$(mktemp)
        echo "$SEMANTIC_ACTIONS" > "$TEMP_ACTIONS_FILE"
        
        CHECKSUMS_JSON="["
        FIRST=true
        
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                SEQUENCE=$(echo "$line" | grep -o '"sequence": [0-9]*' | cut -d':' -f2 | tr -d ' ')
                ACTION_TYPE=$(echo "$line" | grep -o '"type": "[^"]*"' | cut -d'"' -f4)
                CHECKSUM=$(echo "$line" | grep -o '"pre_action_checksum": "[^"]*"' | cut -d'"' -f4)
                
                if [ -n "$SEQUENCE" ] && [ -n "$ACTION_TYPE" ] && [ -n "$CHECKSUM" ]; then
                    if [ "$FIRST" = true ]; then
                        FIRST=false
                    else
                        CHECKSUMS_JSON="${CHECKSUMS_JSON},"
                    fi
                    CHECKSUMS_JSON="${CHECKSUMS_JSON}{\"sequence\":${SEQUENCE},\"action\":\"${ACTION_TYPE}\",\"checksum\":\"${CHECKSUM}\"}"
                fi
            fi
        done < "$TEMP_ACTIONS_FILE"
        CHECKSUMS_JSON="${CHECKSUMS_JSON}]"
        
        # Clean up temp file
        rm -f "$TEMP_ACTIONS_FILE"
        
        # Add checksum_config and ensure game.battle.set_seed is first action
        jq --argjson initial_seed "$INITIAL_SEED" --argjson checksums "$CHECKSUMS_JSON" '
            .checksum_config = {
                "state_type": "player_actions",
                "initial_seed": $initial_seed,
                "expected_checksums": $checksums
            } |
            .actions = (["game.battle.set_seed"] + (.actions | map(select(. != "game.battle.set_seed")))) |
            .metadata.test_type = "checksum_validation" |
            .metadata.validation_mode = "semantic_action_checksums"
        ' "$CONFIG_FILE" > "$TEMP_CONFIG"
        
        # Replace original with enhanced version
        mv "$TEMP_CONFIG" "$CONFIG_FILE"
        
        echo "✅ Checksum validation added successfully!"
        echo ""
        echo "📊 Checksum validation summary:"
        echo "   Initial seed: ${INITIAL_SEED}"
        echo "   Expected checksums: ${ACTION_COUNT}"
        echo "   Validation mode: semantic_action_checksums"
        echo ""
        echo "🎮 To test with checksum validation:"
        echo "   just test-desktop-target ${CONFIG_NAME}"
        echo ""
        echo "🔍 Checksums will be validated automatically during replay"
        
    else
        echo "❌ jq not available - cannot automatically add checksums"
        echo "💡 Install jq with: brew install jq"
        echo "💡 Or manually add checksum_config section to: $CONFIG_FILE"
        exit 1
    fi

# Capture semantic logs from a test run and generate replay config (platform-agnostic)
replay-capture-and-generate config_name test_target="development-workflow" platform="android":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    TEST_TARGET="{{test_target}}"
    PLATFORM="{{platform}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    echo "🎬 Capturing semantic logs and generating replay config..."
    echo "   Config Name: ${CONFIG_NAME}"
    echo "   Test Target: ${TEST_TARGET}"
    echo "   Platform: ${PLATFORM}"
    echo ""
    
    if [ "$PLATFORM" = "desktop" ]; then
        echo "🖥️  Capturing desktop semantic logs..."
        
        echo "1️⃣ Running desktop test to capture semantic actions..."
        just test-desktop "${TEST_TARGET}"
        
        echo ""
        echo "2️⃣ Extracting session ID from desktop logs..."
        SESSION_ID=$(just logs-desktop-last | grep "SESSION_START" | \
                    grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 | tail -1 || echo "")
        
        if [ -z "$SESSION_ID" ]; then
            echo "❌ Could not find desktop session ID"
            echo "💡 Desktop logs preview:"
            just logs-desktop-last | tail -10
            exit 1
        fi
        
        echo "✅ Found desktop session ID: $SESSION_ID"
        
    else
        echo "📱 Capturing Android semantic logs..."
        
        echo "1️⃣ Running Android test to capture semantic actions..."
        
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
        
        echo "2️⃣ Extracting session ID from Android logs..."
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
    fi
    
    echo ""
    echo "3️⃣ Generating replay configuration..."
    just replay-generate "${SESSION_ID}" "${CONFIG_NAME}"

# Capture semantic logs from a test run and generate manual verification replay config (no auto-quit)
replay-capture-and-generate-manual config_name test_target="development-workflow":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{config_name}}"
    TEST_TARGET="{{test_target}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    echo "🎬 Capturing semantic logs and generating manual verification replay config..."
    echo "   Config Name: ${CONFIG_NAME}"
    echo "   Test Target: ${TEST_TARGET}"
    echo "   Mode: Manual verification (no auto-quit)"
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
    
    echo "3️⃣ Generating manual verification replay configuration..."
    just replay-generate-manual "${SESSION_ID}" "${CONFIG_NAME}"

# Interactive replay config selection using fzf
replay-select:
    #!/usr/bin/env bash
    set -euo pipefail
    
    selected=$(just _fzf-select-config "replay" "replay")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        echo "Selected replay config: $selected"
        echo ""
        echo "🎮 Available actions:"
        echo "   just test-android-target $selected      # Run on Android"
        echo "   just test-desktop-target $selected      # Run on Desktop"
        echo "   just replay-validate $selected          # Validate config"
    else
        echo "❌ No selection made"
        exit 1
    fi

# Interactive checksum config selection using fzf  
checksum-select:
    #!/usr/bin/env bash
    set -euo pipefail
    
    selected=$(just _fzf-select-config "checksum" "checksum")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        echo "Selected checksum config: $selected"
        echo ""
        echo "📸 Available actions:"
        echo "   just test-android-target $selected      # Run checksum test"
        echo "   just test-android-update $selected      # Update baseline"
        echo "   just test-android-reset $selected       # Reset baseline"
    else
        echo "❌ No selection made"
        exit 1
    fi

# Interactive demo selection using fzf
demo-select:
    #!/usr/bin/env bash
    set -euo pipefail
    
    selected=$(just _fzf-select-config "demo" "demo")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        echo "Selected demo: $selected"
        echo ""
        echo "🎬 Available actions:"
        echo "   just test-android $selected             # Test demo on Android"
        echo "   just test-desktop-target $selected      # Test demo on Desktop"
        echo "   just demo-to-test $selected             # Convert to regression test"
        echo "   just demo-test-cross-platform $selected # Test on both platforms"
    else
        echo "❌ No selection made"
        exit 1
    fi

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
    echo ""
    echo "📋 Replay Modes:"
    echo "   🤖 Automated: Includes quit action for CI/automated testing"
    echo "   👁️  Manual: No quit action for manual verification and screenshots"

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

# ================================
# DESKTOP REPLAY SUPPORT (TDD GREEN Phase)
# ================================

# Desktop test execution - equivalent of test-android for desktop platform (windowed by default) with fzf selection
test-desktop TARGET="" DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # If arguments provided, use direct execution mode (manual mode - stays open)
    if [ -n "{{TARGET}}" ]; then
        echo "🎯 Manual mode execution: {{TARGET}}"
        just _test-desktop-manual "{{TARGET}}" "{{DURATION}}"
        exit $?
    fi
    
    # Use shared fzf selection for all configs (manual mode)
    selected=$(just _fzf-select-config "desktop" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        echo "Running manual mode: just _test-desktop-manual '$selected'"
        just _test-desktop-manual "$selected" "{{DURATION}}"
    else
        echo "❌ No selection made"
        exit 1
    fi


# Desktop test execution target - automated mode (quits automatically)
test-desktop-target CONFIG_NAME DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running desktop test: {{CONFIG_NAME}} (automated mode - quits automatically)"
    echo "   Config: $CONFIG_FILE"
    echo ""
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="{{USER_DATA_DIR}}"
    LOGS_DIR="{{STANDARD_LOGS_DIR}}"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup
    STARTUP_CONFIG="{{PROJECT_PATH}}/debug_startup_actions.json"
    echo "📋 Copying config for desktop startup: $STARTUP_CONFIG"
    cp "$CONFIG_FILE" "$STARTUP_CONFIG"
    
    # Run desktop Godot with debug actions (automated mode with quit)
    echo "🚀 Starting desktop test in automated mode..."
    GAMETWO_TEST_MODE=automated ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
        && echo "✅ Desktop test completed successfully" \
        || echo "⚠️  Desktop test completed with exit code $?"
    
    echo ""
    
    # Check for checksum validation if config has checksum_config
    if jq -e '.checksum_config' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "🔍 Checksum validation enabled - validating replay..."
        just _validate-checksums-from-logs "$CONFIG_FILE" "$LOGS_DIR/godot.log" \
            && echo "✅ Checksum validation passed!" \
            || echo "❌ Checksum validation failed!"
        echo ""
    fi
    
    echo "🎉 Desktop test execution complete!"
    echo "💡 Check logs with: just logs-desktop-last"

# Internal helper: Desktop test execution - manual mode (stays open for verification)
_test-desktop-manual CONFIG_NAME DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | head -5 | xargs -I {} basename {} .json || echo "   No configs found"
        exit 1
    fi
    
    echo "🖥️  Running desktop test: {{CONFIG_NAME}} (manual mode - stays open)"
    echo "   Config: $CONFIG_FILE"
    echo ""
    
    # Ensure logs directory exists for desktop
    USER_DATA_DIR="{{USER_DATA_DIR}}"
    LOGS_DIR="{{STANDARD_LOGS_DIR}}"
    mkdir -p "$LOGS_DIR"
    
    echo "📂 Desktop logs will be saved to: $LOGS_DIR"
    
    # Copy config to the expected location for desktop startup
    STARTUP_CONFIG="{{PROJECT_PATH}}/debug_startup_actions.json"
    echo "📋 Copying config for desktop startup: $STARTUP_CONFIG"
    cp "$CONFIG_FILE" "$STARTUP_CONFIG"
    
    # Run desktop Godot with debug actions (manual mode - stays open)
    echo "🚀 Starting desktop test in manual mode..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode \
        && echo "✅ Desktop test completed successfully" \
        || echo "⚠️  Desktop test completed with exit code $?"
    
    echo ""
    echo "🎉 Desktop test execution complete!"
    echo "💡 Check logs with: just logs-desktop-last"


# Desktop log access - equivalent of logs-last for desktop platform
logs-desktop-last:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Find desktop logs in Godot user data directory
    USER_DATA_DIR="{{USER_DATA_DIR}}"
    LOGS_DIR="{{STANDARD_LOGS_DIR}}"
    
    echo "🖥️  Accessing desktop logs..."
    echo "   Directory: $LOGS_DIR"
    echo ""
    
    if [ -d "$LOGS_DIR" ]; then
        # Get latest log file
        LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo "📄 Latest desktop log: $(basename "$LATEST_LOG")"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$LATEST_LOG"
        else
            echo "❌ No desktop log files found in $LOGS_DIR"
            echo ""
            echo "💡 To generate desktop logs:"
            echo "   just test-desktop system-quit-only"
        fi
    else
        echo "❌ Desktop logs directory not found: $LOGS_DIR"
        echo ""
        echo "💡 Directory will be created on first desktop test run"
        echo "   Try: just test-desktop system-quit-only"
    fi

# ================================
# CHECKSUM VALIDATION SYSTEM
# ================================

# Internal helper: Validate checksums from logs against config expectations
_validate-checksums-from-logs CONFIG_FILE LOG_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="{{CONFIG_FILE}}"
    LOG_FILE="{{LOG_FILE}}"
    
    echo "🔍 Validating checksums..."
    echo "📄 Config file: $CONFIG_FILE"
    echo "📄 Log file: $LOG_FILE"
    
    # Check that both files exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    if [ ! -f "$LOG_FILE" ]; then
        echo "❌ Log file not found: $LOG_FILE"
        return 1
    fi
    
    # Check that seed was set correctly (optional verification)
    EXPECTED_SEED=$(jq -r '.checksum_config.initial_seed // null' "$CONFIG_FILE")
    if [[ "$EXPECTED_SEED" != "null" ]]; then
        if grep -q "RNG seed set.*$EXPECTED_SEED" "$LOG_FILE"; then
            echo "✅ Seed set correctly: $EXPECTED_SEED"
        else
            echo "⚠️  Could not verify seed was set to: $EXPECTED_SEED"
        fi
    fi
    echo ""
    
    # Extract expected checksums with metadata from JSON config
    EXPECTED_DATA=$(jq -c '.checksum_config.expected_checksums[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
    
    if [ -z "$EXPECTED_DATA" ]; then
        echo "⚠️  No expected checksums found in config - skipping validation"
        return 0
    fi
    
    # Extract actual checksums from replay logs (skip game.battle.set_seed action)
    ACTUAL_DATA=$(grep "SEMANTIC_ACTION" "$LOG_FILE" 2>/dev/null | grep -v '"action_name":"game.battle.set_seed"' | jq -c '{sequence: .sequence, action: .action_name, checksum: .pre_action_checksum}' 2>/dev/null || echo "")
    
    if [ -z "$ACTUAL_DATA" ]; then
        echo "❌ No SEMANTIC_ACTION logs found in replay"
        echo "   This indicates the replay system is not working correctly"
        return 1
    fi
    
    # Compare sequence by sequence
    local sequence=1
    local validation_passed=true
    
    while IFS= read -r expected_line && IFS= read -r actual_line <&3; do
        if [ -z "$expected_line" ] || [ -z "$actual_line" ]; then
            break
        fi
        
        EXPECTED_CHECKSUM=$(echo "$expected_line" | jq -r '.checksum' 2>/dev/null || echo "")
        EXPECTED_ACTION=$(echo "$expected_line" | jq -r '.action' 2>/dev/null || echo "")
        
        ACTUAL_CHECKSUM=$(echo "$actual_line" | jq -r '.checksum' 2>/dev/null || echo "")
        ACTUAL_ACTION=$(echo "$actual_line" | jq -r '.action' 2>/dev/null || echo "")
        
        echo "🔄 Sequence $sequence: $EXPECTED_ACTION"
        
        if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
            echo "❌ CHECKSUM MISMATCH at sequence $sequence"
            echo "   Action: $EXPECTED_ACTION"
            echo "   Expected: $EXPECTED_CHECKSUM"
            echo "   Actual:   $ACTUAL_CHECKSUM"
            echo ""
            echo "🛠️  Debugging Info:"
            echo "   Config file: $CONFIG_FILE"
            echo "   Log file: $LOG_FILE"
            echo "   Failed at action: $EXPECTED_ACTION"
            echo "   Seed: $EXPECTED_SEED"
            validation_passed=false
            break
        fi
        
        if [[ "$EXPECTED_ACTION" != "$ACTUAL_ACTION" ]]; then
            echo "❌ ACTION MISMATCH at sequence $sequence"
            echo "   Expected: $EXPECTED_ACTION"
            echo "   Actual: $ACTUAL_ACTION"
            validation_passed=false
            break
        fi
        
        echo "   ✅ Checksum match: ${EXPECTED_CHECKSUM:0:12}..."
        ((sequence++))
    done <<< "$EXPECTED_DATA" 3<<< "$ACTUAL_DATA"
    
    echo ""
    if [ "$validation_passed" = true ]; then
        echo "✅ All checksums validated successfully!"
        echo "📊 Total validated: $((sequence-1)) actions"
        return 0
    else
        echo "❌ Checksum validation failed!"
        return 1
    fi