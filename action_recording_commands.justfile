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

# Full record-replay-validate workflow (now implemented!)
record-and-validate RECORDING_NAME: (_record-actions RECORDING_NAME) (_replay-and-validate RECORDING_NAME)
    @echo "🎉 Complete record-replay-validate workflow completed for: {{RECORDING_NAME}}"
    @echo "✅ Recording saved and replay validation passed"

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

# Replay and validate a recording
_replay-and-validate RECORDING_NAME:
    @echo "🔄 Starting replay validation for: {{RECORDING_NAME}}"
    just _create-replay-config {{RECORDING_NAME}}
    just _run-replay-validation {{RECORDING_NAME}}

# Create replay configuration with checksum validation
_create-replay-config RECORDING_NAME:
    #!/usr/bin/env bash
    echo "🔧 Creating replay configuration for: {{RECORDING_NAME}}"
    
    # Create replay config with checksum validation
    SAFE_NAME=$(echo "{{RECORDING_NAME}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="project/debug_configs/_temp_replay-${SAFE_NAME}.json"
    
    cat > "$CONFIG_FILE" << 'EOF'
    {
      "description": "Replay Validation for {{RECORDING_NAME}} - Load and replay recording with checksum validation",
      "actions": [
        "system.recording.list_recordings",
        "system.recording.reset_and_replay",
        "system.debug.quit_application"
      ],
      "checksum_config": {
        "state_type": "recording_state",
        "expected_checksum": ""
      }
    }
    EOF
    
    echo "✅ Replay config created: $CONFIG_FILE"

# Run replay validation
_run-replay-validation RECORDING_NAME:
    #!/usr/bin/env bash
    echo "🎮 Running replay validation for: {{RECORDING_NAME}}"
    
    SAFE_NAME=$(echo "{{RECORDING_NAME}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_NAME="_temp_replay-${SAFE_NAME}"
    just config-restart-android "$CONFIG_NAME"
    echo "✅ Replay validation completed"

# Replay a specific recording (standalone)
replay-recording RECORDING_NAME:
    @echo "🔄 Replaying recording: {{RECORDING_NAME}}"
    just _create-replay-config {{RECORDING_NAME}}
    just _run-replay-validation {{RECORDING_NAME}}

# List available recordings using debug action
list-recordings:
    @echo "📁 Available recordings:"
    just config-restart-android 'system.recording.list_recordings'

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
    @echo "  just record-and-validate NAME    ✅ Complete record→replay→validate workflow"
    @echo "  just record NAME                 Record player actions only"
    @echo "  just create-test NAME            Create test config only"
    @echo ""
    @echo "🔄 Replay Operations:"
    @echo "  just replay-recording NAME       Replay a specific recording with validation"
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
    @echo "  just record-and-create battle-scenario-1        # Record and create test"
    @echo "  just record-and-validate my-game-session        # Full record→replay→validate"
    @echo "  just replay-recording battle-scenario-1         # Replay existing recording"
    @echo "  just test-android-target battle-scenario-1-recording-test  # Run test"