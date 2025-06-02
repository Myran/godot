#!/usr/bin/env bash
set -euo pipefail

# Test the enhanced debug system with test ID
TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"

echo "🧪 Testing Smart Debug System"
echo "🆔 Test ID: $TEST_ID"
echo ""

# Create enhanced config with test metadata
CONFIG_NAME="minimal-testing"
enhanced_config=$(mktemp)

echo "📄 Creating enhanced config with test metadata..."
jq --arg test_id "$TEST_ID" '. + {"test_metadata": {"test_id": $test_id, "config": "'$CONFIG_NAME'", "timestamp": "'$(date +%Y%m%d_%H%M%S)'"}}' \
    "project/debug_configs/$CONFIG_NAME.json" > "$enhanced_config"

echo "✅ Enhanced config created:"
cat "$enhanced_config" | jq .

# Save as test config for manual testing
cp "$enhanced_config" "project/debug_configs/test-with-id.json"
rm "$enhanced_config"

echo ""
echo "💡 Test config saved as: project/debug_configs/test-with-id.json"
echo "🔧 You can now push this config to test the smart system:"
echo "   just push-config-android test-with-id"
echo "   just restart-android-app"
echo ""
echo "📋 Expected log patterns to look for:"
echo "   DEBUG_TEST_START with test_id: $TEST_ID"
echo "   DEBUG_TEST_SUCCESS with test_id: $TEST_ID"
echo "   DEBUG_TEST_COMPLETE with test_id: $TEST_ID"
