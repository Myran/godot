# Build-Export-Test and Export-Test Recipes
#
# build-export-test-*: Full rebuild + export + deploy + test
# export-test-*: Export + deploy + test (skip rebuild, uses existing templates)
#
# Both variants share the export+deploy+test logic via internal helpers (DRY principle)

# ================================
# ANDROID
# ================================

# Internal: Android export + deploy + test (shared logic)
# STEP_OFFSET controls step numbering (0 for export-test, 2 for build-export-test)
_export-test-android-impl CONFIG STEP_OFFSET="0":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    OFFSET={{STEP_OFFSET}}

    # Export APK
    echo "📤 Step $((1 + OFFSET)): Exporting APK..."
    just export-android-apk
    echo ""

    # Deploy to device
    echo "📲 Step $((2 + OFFSET)): Deploying to Android device..."
    just deploy-android
    echo ""

    # Run tests
    echo "🧪 Step $((3 + OFFSET)): Testing config: $CONFIG"
    just test-android-target "$CONFIG"

# Android: Export APK → Deploy → Test (uses existing templates)
# Defaults to 'main' test list if no CONFIG provided
export-test-android CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🤖 ANDROID: Export + Test"
    echo "=========================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    just _export-test-android-impl "$CONFIG" 0

    echo ""
    echo "✅ Android export-test complete!"

# Android: Rebuild templates → Export APK → Deploy → Test (full suite or specific config)
# Defaults to 'main' test list if no CONFIG provided
build-export-test-android CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🤖 ANDROID: Build + Export + Test"
    echo "===================================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # 1. Rebuild templates with Firebase C++ module
    echo "📦 Step 1: Rebuilding Android templates..."
    just rebuild-all-android
    echo ""

    # 2. Install templates + inject SDKs (required after rebuild)
    echo "📥 Step 2: Installing templates + injecting Firebase/Sentry SDKs..."
    just setup-android-templates force=yes
    echo ""

    just _export-test-android-impl "$CONFIG" 2

    echo ""
    echo "✅ Android build-export-test complete!"

# ================================
# iOS
# ================================

# Internal: iOS build app + deploy + test (shared logic)
# STEP_OFFSET controls step numbering (0 for export-test, 1 for build-export-test)
# IOS_DEVICE must be set in environment before calling
_export-test-ios-impl CONFIG STEP_OFFSET="0":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    OFFSET={{STEP_OFFSET}}
    IOS_DEVICE="${IOS_TEST_DEVICE:-}"

    if [ -z "$IOS_DEVICE" ]; then
        echo "❌ IOS_TEST_DEVICE not set"
        exit 1
    fi

    # Build iOS app
    echo "📤 Step $((1 + OFFSET)): Building iOS app..."
    just build-ios-app
    echo ""

    # Deploy to device (install app)
    echo "📲 Step $((2 + OFFSET)): Deploying to iOS device..."
    cd export/ios
    xcrun devicectl device install app --device "$IOS_DEVICE" Build/Products/Debug-iphoneos/gametwo.app
    echo "✅ iOS app deployed"
    cd - > /dev/null
    echo ""

    # Run tests
    echo "🧪 Step $((3 + OFFSET)): Testing config: $CONFIG"
    just test-ios-target "$CONFIG"

# iOS: Build app → Deploy → Test (uses existing templates)
# Defaults to 'main' test list if no CONFIG provided
export-test-ios CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🍎 iOS: Export + Test"
    echo "======================"
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # Auto-select iOS device
    IOS_DEVICE=$(just _auto-select-ios-device 2>&1)
    if [ $? -ne 0 ] || [ -z "$IOS_DEVICE" ]; then
        echo "❌ No iOS device available"
        exit 1
    fi
    export IOS_TEST_DEVICE="$IOS_DEVICE"
    echo "📱 Using iOS device: $IOS_DEVICE"
    echo ""

    just _export-test-ios-impl "$CONFIG" 0

    echo ""
    echo "✅ iOS export-test complete!"

# iOS: Rebuild templates → Build app → Deploy → Test (full suite or specific config)
# Defaults to 'main' test list if no CONFIG provided
build-export-test-ios CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🍎 iOS: Build + Export + Test"
    echo "=============================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # Auto-select iOS device
    IOS_DEVICE=$(just _auto-select-ios-device 2>&1)
    if [ $? -ne 0 ] || [ -z "$IOS_DEVICE" ]; then
        echo "❌ No iOS device available"
        exit 1
    fi
    export IOS_TEST_DEVICE="$IOS_DEVICE"
    echo "📱 Using iOS device: $IOS_DEVICE"
    echo ""

    # 1. Rebuild templates with Firebase C++ module
    echo "📦 Step 1: Rebuilding iOS templates..."
    just rebuild-all-ios
    echo ""

    just _export-test-ios-impl "$CONFIG" 1

    echo ""
    echo "✅ iOS build-export-test complete!"

# ================================
# macOS
# ================================

# Internal: macOS export + test (shared logic)
# STEP_OFFSET controls step numbering (0 for export-test, 2 for build-export-test)
_export-test-macos-impl CONFIG STEP_OFFSET="0":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    OFFSET={{STEP_OFFSET}}

    # Export macOS app
    echo "📤 Step $((1 + OFFSET)): Exporting macOS app..."
    just export-macos-debug force=yes
    echo ""

    # No deploy needed (local app)
    echo "📲 Step $((2 + OFFSET)): (local app, no deploy needed)"
    echo ""

    # Run tests
    echo "🧪 Step $((3 + OFFSET)): Testing config: $CONFIG"
    just test-macos-target "$CONFIG"

# macOS: Export app → Test (uses existing templates)
# Defaults to 'main' test list if no CONFIG provided
export-test-macos CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🍎 macOS: Export + Test"
    echo "========================"
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    just _export-test-macos-impl "$CONFIG" 0

    echo ""
    echo "✅ macOS export-test complete!"

# macOS: Rebuild templates → Export app → Test (full suite or specific config)
# Defaults to 'main' test list if no CONFIG provided
build-export-test-macos CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🍎 macOS: Build + Export + Test"
    echo "================================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # 1. Rebuild templates with Firebase C++ module
    echo "📦 Step 1: Rebuilding macOS templates..."
    just macos-build-template force=yes
    just package-macos-template force=yes
    echo ""

    just _export-test-macos-impl "$CONFIG" 2

    echo ""
    echo "✅ macOS build-export-test complete!"

# ================================
# WINDOWS
# ================================

# Internal: Windows export + deploy + test (shared logic)
# STEP_OFFSET controls step numbering (0 for export-test, 3 for build-export-test)
_export-test-windows-impl CONFIG STEP_OFFSET="0":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    OFFSET={{STEP_OFFSET}}

    # Export Windows app
    echo "📤 Step $((1 + OFFSET)): Exporting Windows app..."
    rm -f export/windows/gametwo_debug.pck
    just export-windows-debug
    echo ""

    # Deploy to physical machine
    echo "📲 Step $((2 + OFFSET)): Deploying to Windows physical machine..."
    just win-physical-deploy
    echo ""

    # Run tests
    echo "🧪 Step $((3 + OFFSET)): Testing config: $CONFIG"
    just test-windows-physical-target "$CONFIG"

# Windows: Export → Deploy → Test (uses existing templates)
# Defaults to 'main' test list if no CONFIG provided
export-test-windows CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🪟 Windows: Export + Test"
    echo "=========================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    just _export-test-windows-impl "$CONFIG" 0

    echo ""
    echo "✅ Windows export-test complete!"

# Windows: VM sync → Rebuild templates → Package → Export → Deploy → Test (full suite or specific config)
# Defaults to 'main' test list if no CONFIG provided
build-export-test-windows CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    echo "🪟 Windows: Build + Export + Test"
    echo "==================================="
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # 1. Sync repo to VM
    echo "📦 Step 1: Syncing repo to VM..."
    just win-vm-sync
    echo ""

    # 2. Rebuild templates on VM
    echo "🔨 Step 2: Rebuilding Windows templates on VM..."
    just win-vm-template-debug
    echo ""

    # 3. Package templates from VM
    echo "📦 Step 3: Packaging templates from VM..."
    just win-vm-templates-package
    echo ""

    just _export-test-windows-impl "$CONFIG" 3

    echo ""
    echo "✅ Windows build-export-test complete!"

# ================================
# ALL PLATFORMS
# ================================

# Internal: Run export-test or build-export-test for all platforms
# MODE: "export-test" or "build-export-test"
_all-platforms-impl CONFIG MODE:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    MODE="{{MODE}}"
    MULTI_SESSION="$(date +%s)"
    export MULTI_PLATFORM_SESSION="$MULTI_SESSION"

    if [ "$MODE" = "export-test" ]; then
        echo "🚀 EXPORT-TEST: All Platforms"
        echo "==============================="
    else
        echo "🚀 BUILD-EXPORT-TEST: All Platforms"
        echo "====================================="
    fi
    echo "🔍 Multi-platform session: $MULTI_SESSION"
    echo "🎯 Target configuration: $CONFIG"
    echo ""

    # Track results using temp files (for bash 3.2 compatibility)
    STATUS_DIR="/tmp/${MODE}-${MULTI_SESSION}"
    rm -rf "$STATUS_DIR"
    mkdir -p "$STATUS_DIR"
    START_TIME=$(date +%s)

    # Test each platform
    for PLATFORM in macos windows android ios; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🚀 PLATFORM: $PLATFORM"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        RECIPE="${MODE}-${PLATFORM}"
        if just "$RECIPE" "$CONFIG" 2>&1 | tee "/tmp/${MODE}-${MULTI_SESSION}_${PLATFORM}.log"; then
            echo "✅ PASSED" > "$STATUS_DIR/${PLATFORM}.status"
        else
            echo "❌ FAILED" > "$STATUS_DIR/${PLATFORM}.status"
        fi
    done

    # Summary
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$MODE" = "export-test" ]; then
        echo "📊 EXPORT-TEST SUMMARY"
    else
        echo "📊 BUILD-EXPORT-TEST SUMMARY"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Session: $MULTI_SESSION"
    echo "Duration: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
    echo ""

    FAILED=0
    for PLATFORM in macos windows android ios; do
        if [ -f "$STATUS_DIR/${PLATFORM}.status" ]; then
            STATUS=$(cat "$STATUS_DIR/${PLATFORM}.status")
        else
            STATUS="❌ UNKNOWN"
        fi
        echo "  $PLATFORM: $STATUS"
        if [ "$STATUS" = "❌ FAILED" ]; then
            FAILED=$((FAILED + 1))
        fi
    done

    # Cleanup
    rm -rf "$STATUS_DIR"

    echo ""
    if [ $FAILED -eq 0 ]; then
        echo "✅ ALL PLATFORMS PASSED"
    else
        echo "❌ $FAILED platform(s) failed"
        exit 1
    fi

# All platforms: Export + deploy + test (uses existing templates)
# Defaults to 'main' test list if no CONFIG provided
# Auto-detects test list vs config (same logic as test-*-target)
export-test-all CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    # Resolve test input: auto-detects test list vs config (with or without @ prefix)
    RESOLVED=$(just _resolve-test-input "$CONFIG")

    # Check if resolved output contains multiple lines (test list expansion)
    LINE_COUNT=$(echo "$RESOLVED" | wc -l | tr -d ' ')
    if [[ $LINE_COUNT -gt 1 ]]; then
        # It's a test list - iterate through configs
        echo "🔄 Detected test list: $CONFIG"
        echo "📋 Found $LINE_COUNT config(s)"
        echo ""

        INDEX=0
        while IFS= read -r config; do
            if [[ -n "$config" ]]; then
                INDEX=$((INDEX + 1))
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📋 Config $INDEX/$LINE_COUNT: $config"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                just _all-platforms-impl "$config" "export-test"
            fi
        done <<< "$RESOLVED"
    else
        # Single config
        just _all-platforms-impl "$RESOLVED" "export-test"
    fi

# All platforms: Full rebuild + export + deploy + test (full suite or specific config)
# Defaults to 'main' test list if no CONFIG provided
# Auto-detects test list vs config (same logic as test-*-target)
build-export-test-all CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    if [ -z "$CONFIG" ]; then
        CONFIG="main"
    fi

    # Resolve test input: auto-detects test list vs config (with or without @ prefix)
    RESOLVED=$(just _resolve-test-input "$CONFIG")

    # Check if resolved output contains multiple lines (test list expansion)
    LINE_COUNT=$(echo "$RESOLVED" | wc -l | tr -d ' ')
    if [[ $LINE_COUNT -gt 1 ]]; then
        # It's a test list - iterate through configs
        echo "🔄 Detected test list: $CONFIG"
        echo "📋 Found $LINE_COUNT config(s)"
        echo ""
        echo "💡 First config will rebuild templates, remaining configs will use cached templates"
        echo ""

        INDEX=0
        while IFS= read -r config; do
            if [[ -n "$config" ]]; then
                INDEX=$((INDEX + 1))
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📋 Config $INDEX/$LINE_COUNT: $config"
                if [[ $INDEX -eq 1 ]]; then
                    echo "🔧 Full rebuild + test"
                else
                    echo "⚡ Using cached templates"
                fi
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                just _all-platforms-impl "$config" "build-export-test"
            fi
        done <<< "$RESOLVED"
    else
        # Single config
        just _all-platforms-impl "$RESOLVED" "build-export-test"
    fi
