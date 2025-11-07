#!/bin/bash
# Load Android build environment from .env file

set -euo pipefail

echo "🔧 Loading Android build environment..."

# Check for .env file
if [[ ! -f ".env" ]]; then
    echo "❌ .env file not found!"
    echo "💡 Copy .env.template to .env and fill in your values:"
    echo "   cp .env.template .env"
    echo "   # Then edit .env with your keystore details"
    exit 1
fi

# Load environment variables safely
set -a
source .env
set +a

# Validate required variables
required_vars=(
    "GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"
    "GODOT_ANDROID_KEYSTORE_RELEASE_USER"
)

echo "🔍 Validating required environment variables..."

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ Missing required environment variables:"
    printf '  %s\n' "${missing_vars[@]}"
    echo ""
    echo "💡 Add these variables to your .env file:"
    for var in "${missing_vars[@]}"; do
        echo "   $var=your_value_here"
    done
    exit 1
fi

# Validate keystore files exist
echo "🔑 Validating keystore files..."

if [[ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
    echo "❌ Release keystore not found: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    echo "💡 Ensure the keystore file exists at the specified path"
    exit 1
fi

if [[ ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]]; then
    echo "⚠️  Debug keystore not found: $GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
    echo "💡 Debug keystore is optional - will generate if needed"
fi

# Show loaded configuration (without sensitive data)
echo "✅ Android environment loaded successfully"
echo "📱 Release keystore: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
echo "🔑 Release alias: $GODOT_ANDROID_KEYSTORE_RELEASE_USER"

if [[ -n "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
    echo "🐛 Debug keystore: $GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
fi

if [[ -n "${ANDROID_VERSION_CODE:-}" ]]; then
    echo "📦 Version code: $ANDROID_VERSION_CODE"
fi

if [[ -n "${ANDROID_VERSION_NAME:-}" ]]; then
    echo "📦 Version name: $ANDROID_VERSION_NAME"
fi

echo "🎉 Environment ready for secure Android builds!"