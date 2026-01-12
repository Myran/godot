# Config Validation Commands
# Validates test configurations for platform-agnostic semantic replay compatibility

# Validate that a config is platform-agnostic and suitable for semantic replay
validate-semantic-config CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="{{DEBUG_CONFIG_DIR}}/{{CONFIG}}.json"
    
    echo "🔍 Validating semantic config: {{CONFIG}}"
    echo "📄 Config file: $CONFIG_FILE"
    
    # Check config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls {{DEBUG_CONFIG_DIR}}/*.json 2>/dev/null | sed 's|{{DEBUG_CONFIG_DIR}}/||' | sed 's|\.json$||' | sed 's/^/   /' || echo "   (no configs found)"
        exit 1
    fi
    
    # Check config is valid JSON
    if ! jq -e . "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in config file: $CONFIG_FILE"
        echo "💡 JSON validation error:"
        jq . "$CONFIG_FILE" 2>&1 | head -5 | sed 's/^/   /'
        exit 1
    fi
    
    # Extract actions array
    if ! ACTIONS=$(jq -r '.actions[]' "$CONFIG_FILE" 2>/dev/null); then
        echo "❌ Config file missing 'actions' array: $CONFIG_FILE"
        echo "💡 Config structure:"
        jq 'keys' "$CONFIG_FILE" | sed 's/^/   /'
        exit 1
    fi
    
    # Validate each action
    echo "🎯 Validating actions..."
    INVALID_ACTIONS=0
    TOTAL_ACTIONS=0
    
    while IFS= read -r action; do
        [[ -n "$action" ]] || continue
        TOTAL_ACTIONS=$((TOTAL_ACTIONS + 1))
        
        case "$action" in
            # TDD test actions - NOT allowed in semantic replays
            "system.debug.test_"*)
                echo "❌ TDD test action found in semantic config: $action"
                echo "   💡 TDD test actions should only be in explicit TDD test configs"
                INVALID_ACTIONS=$((INVALID_ACTIONS + 1))
                ;;
            
            # Platform-specific actions - NOT allowed
            "system.debug."*"editor"*)
                echo "❌ Platform-specific action found: $action"
                echo "   💡 Desktop-specific actions cannot be used in cross-platform semantic replays"
                INVALID_ACTIONS=$((INVALID_ACTIONS + 1))
                ;;
            "system.debug."*"android"*)
                echo "❌ Platform-specific action found: $action"
                echo "   💡 Android-specific actions cannot be used in cross-platform semantic replays"
                INVALID_ACTIONS=$((INVALID_ACTIONS + 1))
                ;;
            
            # Platform-agnostic game actions - OK
            "game."*)
                echo "✅ Platform-agnostic gameplay action: $action"
                ;;
                
            # Platform-agnostic system actions - OK
            "system.debug.registry_stats"|"system.debug.quit_application"|"system.debug.hide_menu"|"system.debug.replay_complete")
                echo "✅ Platform-agnostic system action: $action"
                ;;
                
            # Network/RTDB actions - OK
            "system.network."*|"rtdb."*|"cpp.firebase."*|"backend.firebase."*)
                echo "✅ Platform-agnostic backend action: $action"
                ;;
                
            # Unknown actions - require manual review
            *)
                echo "⚠️  Unknown action (manual review needed): $action"
                echo "   💡 Verify this action works on both Android and editor"
                ;;
        esac
    done <<< "$ACTIONS"
    
    echo ""
    echo "📊 Validation Summary:"
    echo "   Total actions: $TOTAL_ACTIONS"
    echo "   Invalid actions: $INVALID_ACTIONS"
    
    if [[ $INVALID_ACTIONS -gt 0 ]]; then
        echo ""
        echo "❌ Config validation FAILED"
        echo "💡 This config contains platform-specific or TDD test actions"
        echo "💡 Semantic replay configs must be platform-agnostic"
        exit 1
    fi
    
    echo ""
    echo "✅ Config validated as platform-agnostic semantic replay"
    echo "💡 This config should work identically on Android and editor"

# Validate all configs in debug_configs directory
validate-all-semantic-configs:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Validating all semantic configs..."
    echo ""
    
    CONFIGS_DIR="{{DEBUG_CONFIG_DIR}}"
    if [[ ! -d "{{DEBUG_CONFIG_DIR}}" ]]; then
        echo "❌ Debug configs directory not found: {{DEBUG_CONFIG_DIR}}"
        exit 1
    fi
    
    TOTAL_CONFIGS=0
    VALID_CONFIGS=0
    INVALID_CONFIGS=0
    
    for config_file in "{{DEBUG_CONFIG_DIR}}"/*.json; do
        [[ -f "$config_file" ]] || continue
        
        config_name=$(basename "$config_file" .json)
        TOTAL_CONFIGS=$((TOTAL_CONFIGS + 1))
        
        echo "─────────────────────────────────────────"
        if just validate-semantic-config "$config_name" 2>/dev/null; then
            VALID_CONFIGS=$((VALID_CONFIGS + 1))
        else
            INVALID_CONFIGS=$((INVALID_CONFIGS + 1))
            echo "❌ $config_name: FAILED validation"
        fi
        echo ""
    done
    
    echo "═══════════════════════════════════════════"
    echo "📊 Overall Validation Summary:"
    echo "   Total configs: $TOTAL_CONFIGS"
    echo "   Valid (platform-agnostic): $VALID_CONFIGS"
    echo "   Invalid (platform-specific/TDD): $INVALID_CONFIGS"
    echo ""
    
    if [[ $INVALID_CONFIGS -gt 0 ]]; then
        echo "❌ Some configs failed validation"
        echo "💡 Fix platform-specific actions before using in semantic replays"
        exit 1
    fi
    
    echo "✅ All configs are platform-agnostic and semantic replay compatible"

# Check if a specific action is platform-agnostic
check-action-platform-agnostic ACTION:
    #!/usr/bin/env bash
    
    ACTION="{{ACTION}}"
    echo "🔍 Checking action platform compatibility: $ACTION"
    
    case "$ACTION" in
        # TDD test actions
        "system.debug.test_"*)
            echo "❌ TDD test action - NOT platform-agnostic"
            echo "💡 Should only be used in explicit TDD test configs"
            exit 1
            ;;
        
        # Platform-specific actions
        "system.debug."*"editor"*|"system.debug."*"android"*)
            echo "❌ Platform-specific action - NOT platform-agnostic"
            echo "💡 Cannot be used in cross-platform semantic replays"
            exit 1
            ;;
        
        # Platform-agnostic actions
        "game."*|"system.debug.registry_stats"|"system.debug.quit_application"|"system.debug.hide_menu"|"system.debug.replay_complete"|"system.network."*|"rtdb."*|"cpp.firebase."*|"backend.firebase."*)
            echo "✅ Platform-agnostic action"
            echo "💡 Safe for semantic replays on both Android and editor"
            ;;
        
        # Unknown actions
        *)
            echo "⚠️  Unknown action - manual review needed"
            echo "💡 Verify this action works on both Android and editor"
            exit 2
            ;;
    esac