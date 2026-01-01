# Build-Export-Test Recipes
#
# Full rebuild + export + deploy + test for each platform
# Reuses existing rebuild recipes (DRY principle)

# ================================
# ANDROID
# ================================

# Android: Rebuild templates → Export APK → Deploy → Test (full suite or specific config)
build-export-test-android CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"

    echo "🤖 ANDROID: Build + Export + Test"
    echo "===================================="
    echo ""

    # 1. Rebuild templates with Firebase C++ module
    echo "📦 Step 1: Rebuilding Android templates..."
    just rebuild-all-android
    echo ""

    # 2. Export APK
    echo "📤 Step 2: Exporting APK..."
    just export-android-apk
    echo ""

    # 3. Deploy to device
    echo "📲 Step 3: Deploying to Android device..."
    just deploy-android
    echo ""

    # 4. Run tests
    if [ -n "$CONFIG" ]; then
        echo "🧪 Step 4: Testing config: $CONFIG"
        just test-android-target "$CONFIG"
    else
        echo "🧪 Step 4: Running full test suite (fzf selection)..."
        just test-android
    fi

    echo ""
    echo "✅ Android build-export-test complete!"

# ================================
# iOS
# ================================

# iOS: Rebuild templates → Build app → Deploy → Test (full suite or specific config)
build-export-test-ios CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"

    echo "🍎 iOS: Build + Export + Test"
    echo "=============================="
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

    # 2. Build iOS app
    echo "📤 Step 2: Building iOS app..."
    just build-ios-app
    echo ""

    # 3. Deploy to device (install app)
    echo "📲 Step 3: Deploying to iOS device..."
    cd export/ios
    xcrun devicectl device install app --device "$IOS_DEVICE" Build/Products/Debug-iphoneos/gametwo.app
    echo "✅ iOS app deployed"
    cd - > /dev/null
    echo ""

    # 4. Run tests
    if [ -n "$CONFIG" ]; then
        echo "🧪 Step 4: Testing config: $CONFIG"
        just test-ios-target "$CONFIG"
    else
        echo "🧪 Step 4: Running full test suite (fzf selection)..."
        just test-ios
    fi

    echo ""
    echo "✅ iOS build-export-test complete!"

# ================================
# macOS
# ================================

# macOS: Rebuild templates → Export app → Test (full suite or specific config)
build-export-test-macos CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"

    echo "🍎 macOS: Build + Export + Test"
    echo "================================="
    echo ""

    # 1. Rebuild templates with Firebase C++ module
    echo "📦 Step 1: Rebuilding macOS templates..."
    just macos-build-template force=yes
    just package-macos-template force=yes
    echo ""

    # 2. Export macOS app
    echo "📤 Step 2: Exporting macOS app..."
    just export-macos-debug force=yes
    echo ""

    # 3. No deploy needed (local app)
    echo "📲 Step 3: (local app, no deploy needed)"
    echo ""

    # 4. Run tests
    if [ -n "$CONFIG" ]; then
        echo "🧪 Step 4: Testing config: $CONFIG"
        just test-macos-target "$CONFIG"
    else
        echo "🧪 Step 4: Running full test suite (fzf selection)..."
        just test-macos
    fi

    echo ""
    echo "✅ macOS build-export-test complete!"

# ================================
# WINDOWS
# ================================

# Windows: VM sync → Rebuild templates → Package → Export → Deploy → Test (full suite or specific config)
build-export-test-windows CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"

    echo "🪟 Windows: Build + Export + Test"
    echo "==================================="
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

    # 4. Export Windows app
    echo "📤 Step 4: Exporting Windows app..."
    rm -f export/windows/gametwo_debug.pck
    just export-windows-debug
    echo ""

    # 5. Deploy to physical machine
    echo "📲 Step 5: Deploying to Windows physical machine..."
    just win-physical-deploy
    echo ""

    # 6. Run tests
    if [ -n "$CONFIG" ]; then
        echo "🧪 Step 6: Testing config: $CONFIG"
        just test-windows-physical-target "$CONFIG"
    else
        echo "🧪 Step 6: Running full test suite (fzf selection)..."
        just test-windows-physical
    fi

    echo ""
    echo "✅ Windows build-export-test complete!"

# ================================
# ALL PLATFORMS
# ================================

# All platforms: Full rebuild + export + deploy + test (full suite or specific config)
build-export-test-all CONFIG="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG="{{CONFIG}}"
    MULTI_SESSION="$(date +%s)"
    export MULTI_PLATFORM_SESSION="$MULTI_SESSION"

    echo "🚀 BUILD-EXPORT-TEST: All Platforms"
    echo "====================================="
    echo "🔍 Multi-platform session: $MULTI_SESSION"
    echo ""

    if [ -n "$CONFIG" ]; then
        echo "🎯 Target configuration: $CONFIG"
    else
        echo "🎯 Running full test suite on all platforms"
    fi
    echo ""

    # Track results using temp files (for bash 3.2 compatibility)
    STATUS_DIR="/tmp/build-export-test-${MULTI_SESSION}"
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

        case "$PLATFORM" in
            macos)
                if just build-export-test-macos "$CONFIG" 2>&1 | tee "/tmp/build-export-test-${MULTI_SESSION}_${PLATFORM}.log"; then
                    echo "✅ PASSED" > "$STATUS_DIR/${PLATFORM}.status"
                else
                    echo "❌ FAILED" > "$STATUS_DIR/${PLATFORM}.status"
                fi
                ;;
            windows)
                if just build-export-test-windows "$CONFIG" 2>&1 | tee "/tmp/build-export-test-${MULTI_SESSION}_${PLATFORM}.log"; then
                    echo "✅ PASSED" > "$STATUS_DIR/${PLATFORM}.status"
                else
                    echo "❌ FAILED" > "$STATUS_DIR/${PLATFORM}.status"
                fi
                ;;
            android)
                if just build-export-test-android "$CONFIG" 2>&1 | tee "/tmp/build-export-test-${MULTI_SESSION}_${PLATFORM}.log"; then
                    echo "✅ PASSED" > "$STATUS_DIR/${PLATFORM}.status"
                else
                    echo "❌ FAILED" > "$STATUS_DIR/${PLATFORM}.status"
                fi
                ;;
            ios)
                if just build-export-test-ios "$CONFIG" 2>&1 | tee "/tmp/build-export-test-${MULTI_SESSION}_${PLATFORM}.log"; then
                    echo "✅ PASSED" > "$STATUS_DIR/${PLATFORM}.status"
                else
                    echo "❌ FAILED" > "$STATUS_DIR/${PLATFORM}.status"
                fi
                ;;
        esac
    done

    # Summary
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 BUILD-EXPORT-TEST SUMMARY"
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
