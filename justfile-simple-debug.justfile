# Simple Debug Configuration Validation for GameTwo
# Focus: Simplicity, clarity, and CI/CD readiness

# Simple validation for a debug config
validate-config CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    
    echo "🔍 Validating: {{CONFIG_NAME}}"
    
    # Simple checks
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Not found: $CONFIG_FILE"
        exit 1
    fi
    
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "❌ Invalid JSON"
        exit 1
    fi
    
    if ! jq -e '.actions | type == "array"' "$CONFIG_FILE" >/dev/null; then
        echo "❌ Missing actions array"
        exit 1
    fi
    
    action_count=$(jq '.actions | length' "$CONFIG_FILE")
    echo "✅ Valid config with $action_count actions"

# Validate all configs (CI ready)
validate-all-configs:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Validating all debug configurations..."
    
    failed=0
    for config in project/debug_configs/*.json; do
        if [ -f "$config" ]; then
            name=$(basename "$config" .json)
            if ! just validate-config "$name" >/dev/null 2>&1; then
                echo "❌ $name"
                failed=1
            else
                echo "✅ $name"
            fi
        fi
    done
    
    if [ "$failed" -eq 0 ]; then
        echo "🎉 All configs valid"
        exit 0
    else
        echo "❌ Some configs failed"
        exit 1
    fi

# Simple config test with monitoring
test-config CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧪 Testing config: {{CONFIG_NAME}}"
    
    # Quick validation
    just validate-config {{CONFIG_NAME}} || exit 1
    
    # Apply and test
    just push-config-restart-android {{CONFIG_NAME}}
    
    echo "⏳ Monitoring for 15 seconds..."
    sleep 15
    
    echo "✅ Config test complete"

# Simple config status check
check-config-status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📊 Debug Config Status"
    echo "====================="
    
    # Check configs directory
    if [ -d "project/debug_configs" ]; then
        count=$(ls -1 project/debug_configs/*.json 2>/dev/null | wc -l)
        echo "✅ $count configurations available"
    else
        echo "❌ No configs directory"
        exit 1
    fi
    
    # Check device if adb available
    if command -v adb >/dev/null 2>&1; then
        if adb -s {{ANDROID_DEVICE_ID}} shell echo "test" >/dev/null 2>&1; then
            echo "✅ Device connected"
        else
            echo "⚠️  Device not connected"
        fi
    fi
    
    echo "💡 Use: just config-list to see available configs"
