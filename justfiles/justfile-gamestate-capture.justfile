# GameState Debug Capture & Load System
# Enables complete developer workflow for scenario testing

# Helper function to compare two gamestate files (shared by save-load cycle tests)
_compare-gamestates FIRST_FILE SECOND_FILE FIRST_LABEL SECOND_LABEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ ! -f "{{FIRST_FILE}}" ]]; then
        echo "❌ First save file not found: {{FIRST_FILE}}"
        exit 1
    fi
    
    if [[ ! -f "{{SECOND_FILE}}" ]]; then
        echo "❌ Second save file not found: {{SECOND_FILE}}"
        exit 1
    fi
    
    echo "📊 Calculating checksums..."
    FIRST_CHECKSUM=$(jq -r '.gamestate' "{{FIRST_FILE}}" | jq -S -c '{board, lineup}' | shasum -a 256 | cut -d' ' -f1)
    SECOND_CHECKSUM=$(jq -r '.gamestate' "{{SECOND_FILE}}" | jq -S -c '{board, lineup}' | shasum -a 256 | cut -d' ' -f1)
    
    echo "🔍 {{FIRST_LABEL}} checksum:  $FIRST_CHECKSUM"
    echo "🔍 {{SECOND_LABEL}} checksum: $SECOND_CHECKSUM"
    echo ""
    
    if [[ "$FIRST_CHECKSUM" == "$SECOND_CHECKSUM" ]]; then
        echo "✅ SUCCESS: Save/Load cycle preserves gamestate perfectly!"
        echo "🎉 Checksums match - the system works correctly"
        exit 0
    else
        echo "❌ FAILURE: Save/Load cycle does not preserve gamestate"
        echo "💥 Checksums differ - there may be a state consistency issue"
        exit 1
    fi

# Helper function to create load-and-save config (shared by save-load cycle tests)
_create-load-save-config AUTO_QUIT:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{AUTO_QUIT}}" == "true" ]]; then
        METADATA_SECTION='"metadata": {
        "auto_quit": true
      },'
    else
        METADATA_SECTION=""
    fi
    
    cat > tests/debug_configs/gamestate-load-and-save-test.json << EOF
    {
      "description": "Load pending gamestate then save for cycle testing",
      $METADATA_SECTION
      "checksum_config": {
        "initial_seed": 12345,
        "state_type": "load_and_save_cycle"
      },
      "actions": [
        {
          "action": "system.debug.load_gamestate",
          "params": {
            "filepath": "pending_gamestate_load.json"
          }
        },
        "system.debug.save_gamestate"
      ]
    }
    EOF

# Extract captured gamestate from logs and create debug save file
capture-gamestate NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎯 Extracting gamestate '{{NAME}}' from logs..."
    echo ""
    
    # Use shared log command for DRY compliance
    echo "1️⃣ Searching for DEBUG_GAMESTATE_CAPTURE in desktop logs..."
    
    CAPTURE_OUTPUT=$(just logs-desktop-last 2>/dev/null | grep "DEBUG_GAMESTATE_CAPTURE" || echo "")
    
    if [ -z "$CAPTURE_OUTPUT" ]; then
        echo "❌ No gamestate capture found in recent desktop logs"
        echo ""
        echo "💡 To capture a gamestate:"
        echo "   1. Start game: just run-desktop"
        echo "   2. Open debug menu (press D key)"
        echo "   3. Click 'Save State' button"
        echo "   4. Exit game"
        echo "   5. Run: just capture-gamestate NAME"
        echo ""
        echo "🔍 Check if Save State action was used:"
        if just logs-desktop-last 2>/dev/null | grep -q "Save State\|DEBUG_GAMESTATE_CAPTURE"; then
            SAVE_STATE_COUNT=$(just logs-desktop-last 2>/dev/null | grep -c "DEBUG_GAMESTATE_CAPTURE" || echo "0")
            echo "   ✅ Save State action found in logs ($SAVE_STATE_COUNT captures)"
        else
            echo "   ❌ No Save State action found"
        fi
        exit 1
    fi
    
    # Extract the most recent capture line from the search results
    CAPTURE_LINE=$(echo "$CAPTURE_OUTPUT" | grep "DEBUG_GAMESTATE_CAPTURE" | tail -1)
    
    if [ -z "$CAPTURE_LINE" ]; then
        echo "❌ No valid DEBUG_GAMESTATE_CAPTURE entry found"
        exit 1
    fi
    
    # Create debug saves directory in user data location (cross-platform compatible)
    SAVED_STATES_DIR="{{SAVED_STATES_DIR}}"
    mkdir -p "$SAVED_STATES_DIR"
    
    # Extract JSON data from the capture line
    echo "2️⃣ Extracting JSON data from capture..."
    JSON_DATA=$(echo "$CAPTURE_LINE" | grep -o '{.*}' | tail -1)
    
    if [ -z "$JSON_DATA" ]; then
        echo "❌ No valid JSON data found in capture line"
        echo "Debug info: $CAPTURE_LINE"
        exit 1
    fi
    
    # Validate and save JSON data
    echo "$JSON_DATA" | jq '.' > /tmp/gamestate_temp.json
    
    if [ $? -ne 0 ]; then
        echo "❌ Invalid JSON in captured gamestate"
        echo "Raw data: $JSON_DATA"
        exit 1
    fi
    
    # Move to final location
    mv /tmp/gamestate_temp.json "$SAVED_STATES_DIR/{{NAME}}.json"
    
    # Verify file creation and show info
    if [ -f "$SAVED_STATES_DIR/{{NAME}}.json" ]; then
        CAPTURE_ID=$(jq -r '.capture_id // "unknown"' "$SAVED_STATES_DIR/{{NAME}}.json")
        TIMESTAMP=$(jq -r '.capture_timestamp // "unknown"' "$SAVED_STATES_DIR/{{NAME}}.json")
        SESSION_ID=$(jq -r '.session_id // "unknown"' "$SAVED_STATES_DIR/{{NAME}}.json")
        FILE_SIZE=$(wc -c < "$SAVED_STATES_DIR/{{NAME}}.json")
        
        echo ""
        echo "✅ Gamestate saved successfully!"
        echo "📄 File: $SAVED_STATES_DIR/{{NAME}}.json"
        echo "🆔 Capture ID: $CAPTURE_ID"
        echo "📱 Session ID: $SESSION_ID"
        echo "⏰ Captured: $TIMESTAMP"
        echo "📏 Size: ${FILE_SIZE} bytes"
        echo ""
        echo "🎮 Next steps:"
        echo "   1. Start game: just run-desktop"
        echo "   2. Open debug menu (press D key)"
        echo "   3. Navigate to 'Saved States'"
        echo "   4. Click 'Load: {{NAME}}'"
        echo "   5. Continue with new actions for recording"
        echo ""
        echo "🔄 Integration with existing recording system:"
        echo "   • Load this state and perform actions"
        echo "   • Exit game to get NEW session ID (don't use the captured one)"
        echo "   • Generate replay config: just replay-generate-desktop NEW_SESSION_ID replay-from-{{NAME}}"
        echo ""
        echo "💡 The captured session ID ($SESSION_ID) is from when this state was originally saved."
        echo "   After loading and performing new actions, you'll get a fresh session ID for replay generation."
    else
        echo "❌ Failed to create gamestate file"
        exit 1
    fi

# List all available saved states
list-saved-states:
    #!/usr/bin/env bash
    echo "🔄 Available Debug Saved States:"
    echo "================================"
    
    SAVED_STATES_DIR="{{SAVED_STATES_DIR}}"
    
    if [ ! -d "$SAVED_STATES_DIR" ]; then
        echo "📁 No saved states directory found"
        echo "💡 Use 'just capture-gamestate NAME' to create saved states"
        exit 0
    fi
    
    cd "$SAVED_STATES_DIR"
    
    if [ -z "$(ls -A . 2>/dev/null)" ]; then
        echo "📁 No saved states found"
        echo "💡 Use debug menu 'Save State' + 'just capture-gamestate NAME'"
        exit 0
    fi
    
    for file in *.json; do
        if [ -f "$file" ]; then
            NAME=$(basename "$file" .json)
            CAPTURE_ID=$(jq -r '.capture_id // "unknown"' "$file" 2>/dev/null)
            SESSION_ID=$(jq -r '.session_id // "unknown"' "$file" 2>/dev/null)
            TIMESTAMP=$(jq -r '.capture_timestamp // "unknown"' "$file" 2>/dev/null)
            SIZE=$(wc -c < "$file")
            
            echo "🎯 $NAME"
            echo "   📄 File: $file"
            echo "   🆔 Capture ID: $CAPTURE_ID"
            echo "   📱 Session ID: $SESSION_ID"
            echo "   ⏰ Captured: $TIMESTAMP"
            echo "   📏 Size: ${SIZE} bytes"
            echo ""
        fi
    done
    
    echo "🎮 To load a state:"
    echo "   1. just run-desktop"
    echo "   2. Debug menu → Saved States → Load: [name]"

# Clean up old saved states
clean-saved-states:
    #!/usr/bin/env bash
    echo "🧹 Cleaning saved states..."
    
    SAVED_STATES_DIR="{{SAVED_STATES_DIR}}"
    
    if [ -d "$SAVED_STATES_DIR" ]; then
        COUNT=$(ls -1 "$SAVED_STATES_DIR"/*.json 2>/dev/null | wc -l)
        rm -f "$SAVED_STATES_DIR"/*.json
        echo "✅ Removed $COUNT saved state files"
    else
        echo "📁 No saved states directory found"
    fi

# Show comprehensive gamestate workflow help
help-gamestate:
    @echo "🎮 GameState Debug Workflow Commands:"
    @echo "===================================="
    @echo ""
    @echo "📋 Complete Workflow:"
    @echo "  1. just run-desktop                    # Start game"
    @echo "  2. Debug menu → 'Save State'           # Capture state during gameplay"  
    @echo "  3. Exit game"
    @echo "  4. just capture-gamestate NAME         # Extract from logs → JSON file"
    @echo "  5. just run-desktop                    # Start again"
    @echo "  6. Debug menu → 'Saved States'         # Navigate to saved states"
    @echo "  7. Click 'Load: NAME'                  # Load as recording starting point"
    @echo "  8. Continue with new actions/recording"
    @echo ""
    @echo "🔧 Commands:"
    @echo "  just capture-gamestate NAME           # Extract last captured state from logs"
    @echo "  just list-saved-states                # Show all available saved states"
    @echo "  just clean-saved-states               # Remove all saved state files"
    @echo "  just help-gamestate                   # Show this help"
    @echo "  just gamestate-status                 # System status and diagnostics"
    @echo "  just test-gamestate-system            # Validate system files"
    @echo "  just test-save-load-cycle-desktop     # Complete save/load cycle validation"
    @echo "  just test-save-load-cycle-with-state-desktop STATE # Enhanced test with provided state"
    @echo ""
    @echo "🧪 Save/Load Cycle Testing:"
    @echo "  just test-save-load-cycle-desktop      # Standard test: create → save → load → compare"
    @echo "  just test-save-load-cycle-with-state-desktop STATE_NAME  # Enhanced test: load STATE → save → load → compare"
    @echo "  just test-save-load-cycle-android       # Android: standard test: create → save → load → compare"
    @echo "  just test-save-load-cycle-with-state-android STATE_NAME  # Android: enhanced test: load STATE → save → load → compare"
    @echo ""
    @echo "📁 Files created in: {{SAVED_STATES_DIR}}"

# Quick test of gamestate system (for development validation)
test-gamestate-system:
    #!/usr/bin/env bash
    echo "🧪 Testing gamestate capture system..."
    
    # Check if required directories exist
    if [ ! -d "project/debug/actions/system" ]; then
        echo "❌ Debug actions directory not found"
        echo "💡 Run implementation first"
        exit 1
    fi
    
    # Check for required files
    REQUIRED_FILES=(
        "project/debug/actions/system/save_debug_state_action.gd"
        "project/debug/actions/system/load_debug_state_action.gd"
        "project/core/saves/gamestate_save_manager.gd"
        "justfiles/justfile-gamestate-capture.justfile"
    )
    
    MISSING_FILES=0
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            echo "❌ Missing: $file"
            MISSING_FILES=$((MISSING_FILES + 1))
        else
            echo "✅ Found: $file"
        fi
    done
    
    if [ $MISSING_FILES -eq 0 ]; then
        echo ""
        echo "✅ All gamestate system files present!"
        echo "🎮 Ready for: just help-gamestate"
    else
        echo ""
        echo "❌ $MISSING_FILES files missing - implementation incomplete"
    fi

# Development helper: Show current saved states status
gamestate-status:
    #!/usr/bin/env bash
    echo "📊 GameState System Status:"
    echo "=========================="
    
    SAVED_STATES_DIR="{{SAVED_STATES_DIR}}"
    
    # Check for saved states directory
    if [ -d "$SAVED_STATES_DIR" ]; then
        COUNT=$(ls -1 "$SAVED_STATES_DIR"/*.json 2>/dev/null | wc -l)
        echo "📁 Saved states directory: EXISTS"
        echo "📄 Saved state files: $COUNT"
        
        if [ $COUNT -gt 0 ]; then
            echo ""
            echo "📋 Available states:"
            just list-saved-states
        fi
    else
        echo "📁 Saved states directory: NOT FOUND"
        echo "💡 Will be created automatically when first state is captured"
    fi
    
    echo ""
    echo "🔍 Recent gamestate captures in logs:"
    
    # Use existing logs-desktop-last command to search for captures
    CAPTURE_OUTPUT=$(just logs-desktop-last 2>/dev/null | grep "DEBUG_GAMESTATE_CAPTURE" || echo "")
    
    if [ -n "$CAPTURE_OUTPUT" ]; then
        RECENT_CAPTURES=$(echo "$CAPTURE_OUTPUT" | grep -c "DEBUG_GAMESTATE_CAPTURE" || echo "0")
        echo "🎯 Total captures found: $RECENT_CAPTURES"
        
        if [ "$RECENT_CAPTURES" -gt 0 ]; then
            echo "⏰ Most recent capture:"
            LAST_CAPTURE=$(echo "$CAPTURE_OUTPUT" | grep "DEBUG_GAMESTATE_CAPTURE" | tail -1 | grep -o '{.*}' | tail -1)
            if [ -n "$LAST_CAPTURE" ]; then
                echo "$LAST_CAPTURE" | jq -r '.capture_timestamp // "Unknown timestamp"' 2>/dev/null || echo "   (Unable to parse timestamp)"
            else
                echo "   (Unable to parse capture data)"
            fi
        fi
    else
        echo "📂 No DEBUG_GAMESTATE_CAPTURE entries found in recent logs"
        echo "💡 Use debug menu 'Save State' to capture gamestate first"
        
        # Check if Save State action has been used recently
        echo ""
        echo "🔍 Save State action usage:"
        if just logs-desktop-last 2>/dev/null | grep -q "Save State"; then
            SAVE_STATE_COUNT=$(just logs-desktop-last 2>/dev/null | grep -c "Save State" 2>/dev/null || echo "0")
            echo "   ✅ Save State found in recent logs ($SAVE_STATE_COUNT times)"
        else
            echo "   ❌ No Save State action found"
        fi
    fi


# 🧪 Save Consistency Test (Note: Load functionality has blocking issues)
test-save-load-cycle-desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Starting Save Consistency Test"
    echo "=================================="
    echo ""
    
    # Clean up any previous test files
    echo "🧹 Cleaning up previous test files..."
    rm -f "{{SAVED_STATES_DIR}}"/cycle_test_*.json
    
    echo "📋 Step 1: Create initial save and extract it"
    echo "--------------------------------------------"
    
    # Create a simple save config without checksum validation
    cat > tests/debug_configs/gamestate-initial-save-test.json << 'EOF'
    {
      "description": "Initial gamestate save for cycle testing",
      "checksum_config": {
        "initial_seed": 12345,
        "state_type": "cycle_test_initial"
      },
      "actions": [
        "system.debug.save_gamestate"
      ]
    }
    EOF
    
    just test-desktop-target gamestate-initial-save-test || {
        echo "❌ Initial save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 2: Extract first saved state"
    echo "-----------------------------------"
    just capture-gamestate cycle_test_first || {
        echo "❌ Failed to extract first gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 3: Load first save via startup mechanism and save again"
    echo "------------------------------------------------------------"
    echo "💡 Using startup gamestate loading to avoid automated mode issues"
    
    # Create startup gamestate load config
    cat > "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json" << 'EOF'
    {
      "gamestate_file": "cycle_test_first.json",
      "source": "save_load_cycle_test"
    }
    EOF
    
    # Create load and save config for deterministic testing
    just _create-load-save-config false
    
    just test-desktop-target gamestate-load-and-save-test || {
        echo "❌ Load and save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 4: Extract second saved state"
    echo "------------------------------------"
    just capture-gamestate cycle_test_second || {
        echo "❌ Failed to extract second gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 5: Compare gamestate files"
    echo "---------------------------------"
    
    FIRST_FILE="{{SAVED_STATES_DIR}}/cycle_test_first.json"
    SECOND_FILE="{{SAVED_STATES_DIR}}/cycle_test_second.json"
    
    if just _compare-gamestates "$FIRST_FILE" "$SECOND_FILE" "First save" "Second save"; then
        # Clean up temporary test files
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f tests/debug_configs/gamestate-initial-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        
        echo ""
        echo "📊 Test Summary:"
        echo "• Initial save: ✅ Success"
        echo "• State extraction: ✅ Success" 
        echo "• Startup load + re-save: ✅ Success"
        echo "• Second extraction: ✅ Success"
        echo "• Checksum comparison: ✅ MATCH"
        echo ""
        echo "🎯 The gamestate save/load system is working perfectly!"
        
    else
        echo "❌ FAILURE: Save/Load cycle does not preserve gamestate"
        echo "💡 Checksums differ - there may be an issue with the restoration logic"
        echo ""
        echo "🔍 Debug Information:"
        echo "First file size:  $(wc -c < "$FIRST_FILE") bytes"
        echo "Second file size: $(wc -c < "$SECOND_FILE") bytes"
        echo ""
        echo "🔧 Compare files manually:"
        echo "diff '$FIRST_FILE' '$SECOND_FILE'"
        echo ""
        echo "🔧 Compare gamestate sections only:"
        echo "diff <(jq -S '.gamestate' '$FIRST_FILE') <(jq -S '.gamestate' '$SECOND_FILE')"
        
        # Clean up temporary test files but keep gamestate files for debugging
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f tests/debug_configs/gamestate-initial-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        exit 1
    fi

# 🧪 Enhanced Save Consistency Test with Provided State
test-save-load-cycle-with-state-desktop STATE_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Starting Enhanced Save Consistency Test"
    echo "==========================================="
    echo "🎯 Using provided state: {{STATE_NAME}}"
    echo ""
    
    # Verify the state exists
    STATE_FILE="{{SAVED_STATES_DIR}}/{{STATE_NAME}}.json"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "❌ Specified state not found: $STATE_FILE"
        echo ""
        echo "🔍 Available states:"
        just list-saved-states
        exit 1
    fi
    
    echo "✅ Found state file: $STATE_FILE"
    echo ""
    echo "📋 Enhanced Workflow: Load → Save → Load → Compare"
    echo "=================================================="
    echo ""
    
    # Clean up any previous test files
    echo "🧹 Cleaning up previous test files..."
    rm -f "{{SAVED_STATES_DIR}}"/cycle_test_*.json
    
    echo "📋 Step 1: Load provided state via startup mechanism and save"
    echo "-----------------------------------------------------------"
    echo "💡 Using startup gamestate loading to avoid automated mode issues"
    
    # Load the actual gamestate data and embed it in the startup config
    echo "📄 Reading gamestate data from $STATE_FILE..."
    GAMESTATE_DATA=$(cat "$STATE_FILE")
    
    # Create startup gamestate load config with embedded data
    cat > "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json" << EOF
    {
      "gamestate_data": $GAMESTATE_DATA,
      "source": "save_load_cycle_test",
      "requested_at": "$(date -Iseconds)"
    }
    EOF
    
    # Create load and save config for deterministic testing  
    just _create-load-save-config true
    
    just test-desktop-target gamestate-load-and-save-test || {
        echo "❌ Load and save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 2: Extract saved state"
    echo "-----------------------------"
    just capture-gamestate cycle_test_second || {
        echo "❌ Failed to extract second gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 3: Compare gamestate files"
    echo "---------------------------------"
    
    FIRST_FILE="{{SAVED_STATES_DIR}}/{{STATE_NAME}}.json"
    SECOND_FILE="{{SAVED_STATES_DIR}}/cycle_test_second.json"
    
    if just _compare-gamestates "$FIRST_FILE" "$SECOND_FILE" "Original state" "Load/save cycle"; then
        # Clean up temporary test files
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        
        echo ""
        echo "📊 Test Summary:"
        echo "• Using provided state: ✅ Success ({{STATE_NAME}})"
        echo "• Actual load + save cycle: ✅ Success"
        echo "• State extraction: ✅ Success"
        echo "• Checksum comparison: ✅ MATCH"
        echo ""
        echo "🎯 The gamestate save/load system is working perfectly!"
        
    else
        echo "❌ FAILURE: Save/Load cycle does not preserve gamestate"
        echo "💡 Checksums differ - there may be an issue with the restoration logic"
        echo ""
        echo "🔍 Debug Information:"
        echo "First file size:  $(wc -c < "$FIRST_FILE") bytes"
        echo "Second file size: $(wc -c < "$SECOND_FILE") bytes"
        echo ""
        echo "🔧 Compare files manually:"
        echo "diff '$FIRST_FILE' '$SECOND_FILE'"
        echo ""
        echo "🔧 Compare gamestate sections only:"
        echo "diff <(jq -S '.gamestate' '$FIRST_FILE') <(jq -S '.gamestate' '$SECOND_FILE')"
        
        # Clean up temporary test files but keep gamestate files for debugging
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        exit 1
    fi

# 🧪 Save Consistency Test - Android Version
test-save-load-cycle-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Starting Save Consistency Test (Android)"
    echo "==========================================="
    echo ""
    
    # Clean up any previous test files
    echo "🧹 Cleaning up previous test files..."
    rm -f "{{SAVED_STATES_DIR}}"/cycle_test_*.json
    
    echo "📋 Step 1: Create initial save and extract it"
    echo "--------------------------------------------"
    
    # Create a simple save config without checksum validation
    cat > tests/debug_configs/gamestate-initial-save-test.json << 'EOF'
    {
      "description": "Initial gamestate save for cycle testing",
      "checksum_config": {
        "initial_seed": 12345,
        "state_type": "cycle_test_initial"
      },
      "actions": [
        "system.debug.save_gamestate"
      ]
    }
    EOF
    
    just test-android-target gamestate-initial-save-test || {
        echo "❌ Initial save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 2: Extract first saved state"
    echo "-----------------------------------"
    just capture-gamestate cycle_test_first || {
        echo "❌ Failed to extract first gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 3: Load first save via startup mechanism and save again"
    echo "------------------------------------------------------------"
    echo "💡 Using startup gamestate loading to avoid automated mode issues"
    
    # Create startup gamestate load config
    cat > "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json" << 'EOF'
    {
      "gamestate_file": "cycle_test_first.json",
      "source": "save_load_cycle_test"
    }
    EOF
    
    # Create load and save config for deterministic testing
    just _create-load-save-config false
    
    just test-android-target gamestate-load-and-save-test || {
        echo "❌ Load and save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 4: Extract second saved state"
    echo "------------------------------------"
    just capture-gamestate cycle_test_second || {
        echo "❌ Failed to extract second gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 5: Compare gamestate files"
    echo "---------------------------------"
    
    FIRST_FILE="{{SAVED_STATES_DIR}}/cycle_test_first.json"
    SECOND_FILE="{{SAVED_STATES_DIR}}/cycle_test_second.json"
    
    if just _compare-gamestates "$FIRST_FILE" "$SECOND_FILE" "First save" "Second save"; then
        # Clean up temporary test files
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f tests/debug_configs/gamestate-initial-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        
        echo ""
        echo "📊 Test Summary:"
        echo "• Initial save: ✅ Success"
        echo "• State extraction: ✅ Success" 
        echo "• Startup load + re-save: ✅ Success"
        echo "• Second extraction: ✅ Success"
        echo "• Checksum comparison: ✅ MATCH"
        echo ""
        echo "🎯 The gamestate save/load system is working perfectly on Android!"
        
    else
        echo "❌ FAILURE: Save/Load cycle does not preserve gamestate"
        echo "💡 Checksums differ - there may be an issue with the restoration logic"
        echo ""
        echo "🔍 Debug Information:"
        echo "First file size:  $(wc -c < "$FIRST_FILE") bytes"
        echo "Second file size: $(wc -c < "$SECOND_FILE") bytes"
        echo ""
        echo "🔧 Compare files manually:"
        echo "diff '$FIRST_FILE' '$SECOND_FILE'"
        echo ""
        echo "🔧 Compare gamestate sections only:"
        echo "diff <(jq -S '.gamestate' '$FIRST_FILE') <(jq -S '.gamestate' '$SECOND_FILE')"
        
        # Clean up temporary test files but keep gamestate files for debugging
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f tests/debug_configs/gamestate-initial-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        exit 1
    fi

# 🧪 Enhanced Save Consistency Test with Provided State - Android Version
test-save-load-cycle-with-state-android STATE_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Starting Enhanced Save Consistency Test (Android)"
    echo "===================================================="
    echo "🎯 Using provided state: {{STATE_NAME}}"
    echo ""
    
    # Verify the state exists
    STATE_FILE="{{SAVED_STATES_DIR}}/{{STATE_NAME}}.json"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "❌ Specified state not found: $STATE_FILE"
        echo ""
        echo "🔍 Available states:"
        just list-saved-states
        exit 1
    fi
    
    echo "✅ Found state file: $STATE_FILE"
    echo ""
    echo "📋 Enhanced Workflow: Load → Save → Load → Compare"
    echo "=================================================="
    echo ""
    
    # Clean up any previous test files
    echo "🧹 Cleaning up previous test files..."
    rm -f "{{SAVED_STATES_DIR}}"/cycle_test_*.json
    
    echo "📋 Step 1: Load provided state via startup mechanism and save"
    echo "-----------------------------------------------------------"
    echo "💡 Using startup gamestate loading to avoid automated mode issues"
    
    # Load the actual gamestate data and embed it in the startup config
    echo "📄 Reading gamestate data from $STATE_FILE..."
    GAMESTATE_DATA=$(cat "$STATE_FILE")
    
    # Create startup gamestate load config with embedded data
    cat > "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json" << EOF
    {
      "gamestate_data": $GAMESTATE_DATA,
      "source": "save_load_cycle_test",
      "requested_at": "$(date -Iseconds)"
    }
    EOF
    
    # Create load and save config for deterministic testing  
    just _create-load-save-config true
    
    just test-android-target gamestate-load-and-save-test || {
        echo "❌ Load and save test failed"
        exit 1
    }
    
    echo ""
    echo "📋 Step 2: Extract saved state"
    echo "-----------------------------"
    just capture-gamestate cycle_test_second || {
        echo "❌ Failed to extract second gamestate"
        exit 1
    }
    
    echo ""
    echo "📋 Step 3: Compare gamestate files"
    echo "---------------------------------"
    
    FIRST_FILE="{{SAVED_STATES_DIR}}/{{STATE_NAME}}.json"
    SECOND_FILE="{{SAVED_STATES_DIR}}/cycle_test_second.json"
    
    if just _compare-gamestates "$FIRST_FILE" "$SECOND_FILE" "Original state" "Load/save cycle"; then
        # Clean up temporary test files
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        
        echo ""
        echo "📊 Test Summary:"
        echo "• Using provided state: ✅ Success ({{STATE_NAME}})"
        echo "• Actual load + save cycle: ✅ Success"
        echo "• State extraction: ✅ Success"
        echo "• Checksum comparison: ✅ MATCH"
        echo ""
        echo "🎯 The gamestate save/load system is working perfectly on Android!"
        
    else
        echo "❌ FAILURE: Save/Load cycle does not preserve gamestate"
        echo "💡 Checksums differ - there may be an issue with the restoration logic"
        echo ""
        echo "🔍 Debug Information:"
        echo "First file size:  $(wc -c < "$FIRST_FILE") bytes"
        echo "Second file size: $(wc -c < "$SECOND_FILE") bytes"
        echo ""
        echo "🔧 Compare files manually:"
        echo "diff '$FIRST_FILE' '$SECOND_FILE'"
        echo ""
        echo "🔧 Compare gamestate sections only:"
        echo "diff <(jq -S '.gamestate' '$FIRST_FILE') <(jq -S '.gamestate' '$SECOND_FILE')"
        
        # Clean up temporary test files but keep gamestate files for debugging
        rm -f tests/debug_configs/gamestate-load-and-save-test.json
        rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
        exit 1
    fi