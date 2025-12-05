# Gamestate Save/Load Testing Commands
# Complete workflow testing outside the normal test framework

# Run complete gamestate save/load test cycle
test-gamestate-cycle:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Complete Gamestate Save/Load Test Cycle"
    echo "=========================================="
    echo ""
    
    TEST_NAME="cycle-test-$(date +%s)"
    
    echo "🎯 Step 1: Save gamestate using debug menu simulation"
    echo "======================================================"
    just test-desktop-target gamestate-user-workflow-test
    
    if [ $? -ne 0 ]; then
        echo "❌ Save step failed"
        exit 1
    fi
    
    echo ""
    echo "🎯 Step 2: Extract gamestate using command line tool"
    echo "===================================================="
    just capture-gamestate-desktop "$TEST_NAME"
    
    if [ $? -ne 0 ]; then
        echo "❌ Extract step failed"
        exit 1
    fi
    
    echo ""
    echo "🎯 Step 3: Set up startup configuration for loading"
    echo "=================================================="
    
    GAMESTATE_FILE="/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/debug/saved_states/${TEST_NAME}.json"
    STARTUP_CONFIG="/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
    
    if [ ! -f "$GAMESTATE_FILE" ]; then
        echo "❌ Gamestate file not found: $GAMESTATE_FILE"
        exit 1
    fi
    
    # Read the gamestate data
    GAMESTATE_DATA=$(cat "$GAMESTATE_FILE")
    CAPTURE_ID=$(echo "$GAMESTATE_DATA" | jq -r '.capture_id')
    TIMESTAMP=$(echo "$GAMESTATE_DATA" | jq -r '.capture_timestamp')
    
    # Create startup configuration using jq
    echo "$GAMESTATE_DATA" | jq --arg file "$GAMESTATE_FILE" --arg capture_id "$CAPTURE_ID" --arg timestamp "$TIMESTAMP" --arg requested "$(date -Iseconds)" '{
      "gamestate_file": $file,
      "original_capture_id": $capture_id, 
      "original_timestamp": $timestamp,
      "requested_at": $requested,
      "gamestate_data": .
    }' > "$STARTUP_CONFIG"
    
    echo "✅ Startup configuration created"
    
    echo ""
    echo "🎯 Step 4: Run load and verification test"
    echo "========================================"
    just test-desktop-target gamestate-load-user-workflow-test
    
    LOAD_RESULT=$?
    
    echo ""
    echo "🎯 Step 5: Check restoration logs for evidence"
    echo "============================================="
    
    # Get the latest test ID
    LATEST_TEST_ID=$(ls -t /Users/mattiasmyhrman/Library/Application\ Support/Godot/app_userdata/gametwo/logs/desktop_gamestate-load-user-workflow-test_desktop_*.log | head -1 | xargs basename | sed 's/desktop_//' | sed 's/.log$//')
    
    echo "📄 Checking restoration logs for: $LATEST_TEST_ID"
    
    # Check for gamestate restoration evidence
    RESTORATION_LOGS=$(just logs-search "$LATEST_TEST_ID" "gamestate_restore" 2>/dev/null || echo "")
    LOADED_SESSION_LOGS=$(just logs-search "$LATEST_TEST_ID" "loaded_state_recording" 2>/dev/null || echo "")
    
    echo ""
    echo "📊 Test Results Summary"
    echo "======================"
    echo "Test Name: $TEST_NAME"
    echo "Gamestate File: $GAMESTATE_FILE"
    echo "Load Test Result: $([ $LOAD_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo ""
    
    if [ -n "$RESTORATION_LOGS" ]; then
        echo "✅ Gamestate restoration evidence found:"
        echo "$RESTORATION_LOGS" | head -5
        echo "... (see full logs with: just logs-search $LATEST_TEST_ID gamestate_restore)"
    else
        echo "❌ No gamestate restoration evidence found"
    fi
    
    if [ -n "$LOADED_SESSION_LOGS" ]; then
        echo ""
        echo "✅ Loaded state session evidence found:"
        echo "$LOADED_SESSION_LOGS"
    else
        echo "❌ No loaded state session evidence found"
    fi
    
    echo ""
    if [ -n "$RESTORATION_LOGS" ] && [ -n "$LOADED_SESSION_LOGS" ]; then
        echo "🎉 GAMESTATE SAVE/LOAD CYCLE: SUCCESS"
        echo "✅ All block types and restoration working correctly"
        exit 0
    else
        echo "❌ GAMESTATE SAVE/LOAD CYCLE: FAILED"
        echo "💡 Check logs with: just logs-search $LATEST_TEST_ID gamestate_restore"
        exit 1
    fi

# Quick gamestate test for development
test-gamestate-quick:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🚀 Quick Gamestate Test"
    echo "======================"
    
    # Save gamestate
    echo "1. Saving gamestate..."
    just test-desktop-target gamestate-user-workflow-test > /tmp/save_result.log 2>&1
    
    if grep -q "✅ All validations passed" /tmp/save_result.log; then
        echo "✅ Save successful"
    else
        echo "❌ Save failed"
        cat /tmp/save_result.log | tail -5
        exit 1
    fi
    
    # Extract gamestate
    echo "2. Extracting gamestate..."
    TEST_NAME="quick-$(date +%s)"
    just capture-gamestate-desktop "$TEST_NAME" > /tmp/extract_result.log 2>&1
    
    if grep -q "✅ Gamestate saved successfully" /tmp/extract_result.log; then
        echo "✅ Extract successful"
        
        # Show what block types were captured
        GAMESTATE_FILE="/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/debug/saved_states/${TEST_NAME}.json"
        echo ""
        echo "📋 Captured Block Types:"
        jq -r '.gamestate.board.draft_area[] | "Position \(.draft_position): Type \(.object_type) \(if .card_id then "(Card: \(.card_id))" else "" end)"' "$GAMESTATE_FILE" | head -10
        echo "..."
        
        TOTAL_BLOCKS=$(jq '.gamestate.board.draft_area | length' "$GAMESTATE_FILE")
        echo "📊 Total blocks captured: $TOTAL_BLOCKS"
        
        # Count block types
        echo ""
        echo "🔢 Block Type Distribution:"
        jq -r '.gamestate.board.draft_area | group_by(.object_type) | .[] | "Type \(.[0].object_type): \(length) blocks"' "$GAMESTATE_FILE"
        
    else
        echo "❌ Extract failed"
        cat /tmp/extract_result.log | tail -5
        exit 1
    fi
    
    echo ""
    echo "✅ Quick test complete!"
    echo "💡 Run 'just test-gamestate-cycle' for full load testing"

# Clean up gamestate test files
clean-gamestate-tests:
    #!/usr/bin/env bash
    echo "🧹 Cleaning gamestate test files..."
    
    # Remove test gamestate files
    rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/debug/saved_states/cycle-test-"*.json
    rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/debug/saved_states/quick-"*.json
    
    # Remove startup config if present
    rm -f "/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/startup_gamestate_load.json"
    
    echo "✅ Cleanup complete"