# Core Configuration & Shared Utilities
# Shared variables, paths, and utility functions used across all modules
# This module is imported by all other modules and provides foundational infrastructure

# Note: This file contains no functions, only variables and configuration
# Functions use these variables via inheritance from main justfile

# ================================
# CORE PROJECT CONFIGURATION
# ================================
GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
PROJECT_PATH := justfile_directory() + "/project"
GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
GODOT_VERSION := "4.0"
GODOT_BUILD_VERSION := "4.3.rc"

# ================================
# DEVICE CONFIGURATION
# ================================
# iOS Devices
IOS_IPHONE_DEVICE_ID := env_var_or_default("IOS_IPHONE_DEVICE_ID", "C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48")
IOS_IPAD_DEVICE_ID := env_var_or_default("IOS_IPAD_DEVICE_ID", "A4045434-B5F5-48B5-8654-C128A403149A")

# Android Devices  
ANDROID_DEVICE_ID := env_var_or_default("ANDROID_DEVICE_ID", "246d2c533a037ece")
ANDROID_DEVICE_IP := env_var_or_default("ANDROID_DEVICE_IP", "192.168.1.100")

# ================================
# PLATFORM IDENTIFIERS
# ================================
ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "com.primaryhive." + GAME_NAME)
IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.primaryhive." + GAME_NAME)

# ================================
# BUILD PATHS & TOOLS
# ================================
ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", "~/Library/Android/sdk")
ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
ANDROID_GRADLE_DIR := "build/gradle"
KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")

# ================================
# CREDENTIALS (Environment-based)
# ================================
# Only sensitive data remains as exports for security
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`

# ================================
# SHARED UTILITY FUNCTIONS
# ================================

# Clean up temporary config file if it was auto-generated
_cleanup-temp-config CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    CONFIG_FILE="project/debug_configs/{{CONFIG}}.json"
    
    # Check if this is a temporary config by looking for our specific description patterns
    if [ -f "$CONFIG_FILE" ] && (grep -q "Temporary config for single action:" "$CONFIG_FILE" 2>/dev/null || grep -q "Temporary.*config for.*pattern:" "$CONFIG_FILE" 2>/dev/null); then
        echo "🧹 Cleaning up temporary config: $CONFIG_FILE"
        rm "$CONFIG_FILE"
        echo "✅ Temporary config cleaned up"
    fi

# Handle JSON action with parameters by creating temporary config
_handle-json-action-params CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Extract action name from JSON (shell removes quotes)
    ACTION_NAME=$(echo '{{CONFIG}}' | grep -o 'action:[[:space:]]*[^,}]*' | sed 's/action:[[:space:]]*//')
    if [ -z "$ACTION_NAME" ]; then
        echo "❌ Could not extract action name from JSON: {{CONFIG}}"
        exit 1
    fi
    
    # Create safe filename based on action name
    SAFE_ACTION_NAME=$(echo "$ACTION_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
    if [[ "{{CONFIG}}" == *"params:"* ]]; then
        CONFIG_FILE="project/debug_configs/temp_${SAFE_ACTION_NAME}_with_params.json"
        CONFIG_DESC="Temporary config for action with parameters: $ACTION_NAME"
        echo "🔧 Creating temporary config for action with params: $ACTION_NAME"
    else
        CONFIG_FILE="project/debug_configs/temp_${SAFE_ACTION_NAME}_json_action.json"
        CONFIG_DESC="Temporary config for JSON action: $ACTION_NAME"
        echo "🔧 Creating temporary config for JSON action: $ACTION_NAME"
    fi
    
    # Create temporary config file with the JSON action structure
    # Convert shell-processed JSON back to proper JSON format
    PROPER_JSON=$(echo '{{CONFIG}}' | sed 's/\([a-zA-Z_][a-zA-Z0-9_]*\):/"\1":/g' | sed 's/: \([^",{}][^",{}]*\)/: "\1"/g')
    
    echo "{" > "$CONFIG_FILE"
    echo "  \"description\": \"$CONFIG_DESC\"," >> "$CONFIG_FILE"
    echo "  \"actions\": [" >> "$CONFIG_FILE"
    echo "    $PROPER_JSON" >> "$CONFIG_FILE"
    echo "  ]" >> "$CONFIG_FILE"
    echo "}" >> "$CONFIG_FILE"
    echo "✅ Temporary config created: $CONFIG_FILE"

# Validate config file exists or create temporary config for single action
_validate-config-exists CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if CONFIG is JSON with action field first (shell removes quotes)
    if [[ "{{CONFIG}}" == *"action:"* ]]; then
        if [[ "{{CONFIG}}" == *"params:"* ]]; then
            echo "🔍 Detected action with parameters JSON format"
        else
            echo "🔍 Detected action JSON format (no params)"
        fi
        just _handle-json-action-params "{{CONFIG}}"
        exit 0
    fi
    
    # Generate safe filename for config (replace unsafe characters)
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="project/debug_configs/${SAFE_CONFIG_NAME}.json"
    
    # Check if safe config file exists (including temporary ones)
    if [ -f "$CONFIG_FILE" ]; then
        exit 0
    fi
    
    # Also check if original unsafe filename exists (for backward compatibility)
    ORIGINAL_CONFIG_FILE="project/debug_configs/{{CONFIG}}.json"
    if [ -f "$ORIGINAL_CONFIG_FILE" ]; then
        exit 0
    fi
    
    # Config file doesn't exist - check if CONFIG is a config pattern or action name
    echo "🔍 Config file not found: $CONFIG_FILE"
    
    # Check if it's a wildcard pattern
    if [[ "{{CONFIG}}" == *'*'* ]]; then
        echo "🔍 Detected wildcard pattern: {{CONFIG}}"
        
        # First, try to match config file names
        echo "🔍 Checking for matching config files..."
        CONFIG_PATTERN="{{CONFIG}}"
        MATCHING_CONFIGS=$(ls project/debug_configs/*.json 2>/dev/null | sed 's|project/debug_configs/||g' | sed 's|\.json||g' | grep -E "^$(echo "$CONFIG_PATTERN" | sed 's/\*/.*/')\$" | head -20 || true)
        
        if [ -n "$MATCHING_CONFIGS" ]; then
            echo "✅ Found matching config files:"
            echo "$MATCHING_CONFIGS" | sed 's/^/  /'
            echo "🔧 Creating temporary test list for config pattern: {{CONFIG}}"
            
            # Create temporary test list file 
            TEMP_LIST_FILE="project/test-lists/temp_pattern_${SAFE_CONFIG_NAME}.json"
            CONFIG_LIST=$(echo "$MATCHING_CONFIGS" | sed 's/^/    "/' | sed 's/$/",/' | sed '$s/,$//')
            {
                echo '{'
                echo '  "name": "Config Pattern: '"$CONFIG_PATTERN"'",'
                echo '  "description": "Auto-generated test list for config pattern: '"$CONFIG_PATTERN"'",'
                echo '  "configs": ['
                echo "$CONFIG_LIST"
                echo '  ]'
                echo '}'
            } > "$TEMP_LIST_FILE"
            
            # Run the temporary test list 
            echo "✅ Temporary test list created: $TEMP_LIST_FILE"
            echo "🚀 Executing config pattern as test list..."
            
            # Execute via test list system and exit with its result
            exec just _test-list-android "temp_pattern_${SAFE_CONFIG_NAME}"
        fi
        
        echo "🔍 No matching config files, treating as action name pattern..."
        echo "🔧 Creating temporary config for wildcard pattern: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        PATTERN_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for wildcard pattern: '"$PATTERN_NAME"'","actions":["'"$PATTERN_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary wildcard config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Look for the action in existing config files to see if it's a valid action name
    if grep -r "\"{{CONFIG}}\"" project/debug_configs/*.json >/dev/null 2>&1; then
        echo "✅ Found '{{CONFIG}}' as an action name"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        ACTION_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Check if action would match any existing wildcard patterns
    ACTION_NAME="{{CONFIG}}"
    MATCHED_PATTERN=""
    while IFS= read -r pattern; do
        # Convert wildcard pattern to regex and test
        regex_pattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/[^.]*/g; s/\?/[^.]/g')
        if echo "$ACTION_NAME" | grep -qE "^${regex_pattern}$"; then
            MATCHED_PATTERN="$pattern"
            break
        fi
    done < <(grep -rh '"[^"]*\*[^"]*"' project/debug_configs/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | sort -u)
    
    if [ -n "$MATCHED_PATTERN" ]; then
        echo "✅ Action '{{CONFIG}}' matches wildcard pattern: $MATCHED_PATTERN"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Neither config file nor action name found
    echo "❌ Neither config file nor action name found for: {{CONFIG}}"
    echo ""
    echo "💡 Available config files:"
    ls -1 project/debug_configs/*.json 2>/dev/null | sed 's|project/debug_configs/||g' | sed 's|\.json||g' | sed 's/^/  /' || echo "  (no configs found)"
    echo ""
    echo "💡 Example action names (from existing configs):"
    grep -h "\"[A-Z].*Test\"" project/debug_configs/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/  \1/' | sort -u | head -10 || echo "  (no action examples found)"
    exit 1

# Gruvbox Material colors
_gruvbox-colors:
    # Base colors
    @export BG_H="#1d2021"
    @export BG="#282828"
    @export BG_S="#32302f"
    @export FG="#d4be98"
    
    # Regular colors
    @export RED="#ea6962"
    @export GREEN="#a9b665"
    @export YELLOW="#d8a657"
    @export BLUE="#7daea3"
    @export PURPLE="#d3869b"
    @export AQUA="#89b482"
    @export ORANGE="#e78a4e"
    @export GRAY="#928374"