# Action Recording Commands for GameTwo Debug System
# Provides one-command workflows for recording and validation

# Main workflow: Record actions and create test (Phase 1 - before replay implementation)
record-and-create RECORDING_NAME: (_record-actions RECORDING_NAME) (_create-test-config RECORDING_NAME)
    @echo "🎉 Recording workflow completed for: {{RECORDING_NAME}}"
    @echo "📁 Recording saved: recordings/{{RECORDING_NAME}}_recording.json"
    @echo "🧪 Test config created: project/debug_configs/{{RECORDING_NAME}}-recording-test.json"
    @echo ""
    @echo "🚀 Run your new test with:"
    @echo "   just test-android-target {{RECORDING_NAME}}-recording-test"

# Future: Full record-replay-validate workflow (requires replay implementation)
record-and-validate RECORDING_NAME:
    @echo "🚧 Full record-replay-validate workflow requires replay system implementation"
    @echo "📋 Using record-and-create workflow instead..."
    just record-and-create {{RECORDING_NAME}}

# Record player actions with game setup
_record-actions RECORDING_NAME:
    @echo "🎬 Starting recording workflow for: {{RECORDING_NAME}}"
    just _setup-recording-session {{RECORDING_NAME}}
    just _wait-for-recording-completion {{RECORDING_NAME}}

# Create test configuration from recording
_create-test-config RECORDING_NAME:
    @echo "🧪 Creating test configuration: {{RECORDING_NAME}}-recording-test"
    just _generate-test-config {{RECORDING_NAME}}

# Setup recording session with game initialization
_setup-recording-session RECORDING_NAME:
    #!/usr/bin/env bash
    echo "🔧 Setting up recording session for: {{RECORDING_NAME}}"
    
    # Create recording setup config in project directory with safe name
    SAFE_NAME=$(echo "{{RECORDING_NAME}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="project/debug_configs/_temp_recording-setup-${SAFE_NAME}.json"
    
    cat > "$CONFIG_FILE" << 'EOF'
    {
      "description": "Recording Setup for {{RECORDING_NAME}} - Initialize game and start recording",
      "actions": [
        "system.recording.stats",
        "game.lineup.populate_enemy",
        "system.recording.start",
        "system.recording.stats"
      ]
    }
    EOF
    
    echo "✅ Temporary config created: $CONFIG_FILE"
    
    # Apply and run setup using config name (without .json extension)
    CONFIG_NAME="_temp_recording-setup-${SAFE_NAME}"
    just config-restart-android "$CONFIG_NAME"
    echo "✅ Recording session initialized - ready for player input"

# Wait for user to complete recording and stop
_wait-for-recording-completion RECORDING_NAME:
    #!/usr/bin/env bash
    echo "🎮 Recording is active. Interact with the game, then press ENTER to stop recording..."
    read -p "Press ENTER when finished recording: " dummy
    
    # Create recording stop and save config in project directory with safe name
    SAFE_NAME=$(echo "{{RECORDING_NAME}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="project/debug_configs/_temp_recording-stop-${SAFE_NAME}.json"
    
    cat > "$CONFIG_FILE" << 'EOF'
    {
      "description": "Recording Stop and Save for {{RECORDING_NAME}} - Stop recording and save to file",
      "actions": [
        "system.recording.stop",
        "system.recording.save",
        "system.recording.capture_state",
        "system.debug.quit_application"
      ],
      "recording_config": {
        "save_name": "{{RECORDING_NAME}}"
      }
    }
    EOF
    
    echo "✅ Temporary config created: $CONFIG_FILE"
    
    # Apply and run stop sequence using config name (without .json extension)
    CONFIG_NAME="_temp_recording-stop-${SAFE_NAME}"
    just config-restart-android "$CONFIG_NAME"
    echo "✅ Recording stopped and saved"


# Generate test configuration file from recording
_generate-test-config RECORDING_NAME:
    #!/usr/bin/env bash
    echo "🧪 Generating test configuration: {{RECORDING_NAME}}-recording-test"
    
    # Create test config for recording validation (Phase 1 - captures current state)
    cat > project/debug_configs/{{RECORDING_NAME}}-recording-test.json << 'EOF'
    {
      "description": "{{RECORDING_NAME}} Recording Test - Validate recording system state capture and checksum",
      "actions": [
        "system.recording.stats",
        "game.lineup.populate_enemy",
        "system.recording.capture_state",
        "system.checksum.validate",
        "system.debug.quit_application"
      ],
      "checksum_config": {
        "state_type": "recording_state",
        "expected_checksum": ""
      }
    }
    EOF
    
    echo "✅ Test configuration created: project/debug_configs/{{RECORDING_NAME}}-recording-test.json"

# Quick commands for individual operations
record RECORDING_NAME: (_record-actions RECORDING_NAME)
    @echo "🎬 Recording completed: {{RECORDING_NAME}}"

create-test RECORDING_NAME: (_create-test-config RECORDING_NAME)
    @echo "🧪 Test config created: {{RECORDING_NAME}}-recording-test"

# List available recordings
list-recordings:
    @echo "📁 Available recordings:"
    @ls -la recordings/*.json 2>/dev/null | grep "_recording.json" || echo "   No recordings found"

# Clean up temporary files
clean-recording-temp:
    @echo "🧹 Cleaning recording temporary files..."
    @rm -f /tmp/recording-*.json
    @rm -f project/debug_configs/_temp_recording-*.json
    @echo "✅ Temporary files cleaned"

# Show recording workflow help
help-recording:
    @echo "🎬 Recording System Commands"
    @echo "=========================="
    @echo ""
    @echo "📋 Main Workflows:"
    @echo "  just record-and-create NAME      Record actions and create test config"
    @echo "  just record-and-validate NAME    🚧 Future: Complete record→replay→validate workflow"
    @echo "  just record NAME                 Record player actions only"
    @echo "  just create-test NAME            Create test config only"
    @echo ""
    @echo "📁 Management:"
    @echo "  just list-recordings             Show available recordings"
    @echo "  just clean-recording-temp        Clean temporary files"
    @echo ""
    @echo "🧪 Testing:"
    @echo "  just test-android-target NAME-recording-test    Run generated test"
    @echo "  just test-android-update NAME-recording-test    Update test baseline"
    @echo ""
    @echo "📖 Example Usage:"
    @echo "  just record-and-create battle-scenario-1"
    @echo "  just test-android-target battle-scenario-1-recording-test"