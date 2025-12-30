# GDScript Sentry SDK Build Commands for GameTwo
# Runtime GDExtension loaded by Godot at runtime

# GDScript Sentry SDK paths (shared variables defined in main Sentry justfile)

# Show GDScript Sentry build help
help-sentry-gdscript:
    @echo "🎮 GDScript Sentry SDK Build Commands"
    @echo "===================================="
    @echo ""
    @echo "🎮 GDSCRIPT INTEGRATION:"
    @echo "  just build-sentry-gdscript-all         # Build GDScript Sentry for all platforms"
    @echo "  just build-sentry-gdscript-macos       # Build GDScript Sentry for macOS"
    @echo "  just build-sentry-gdscript-android     # Build GDScript Sentry for Android"
    @echo "  just build-sentry-gdscript-ios         # Build GDScript Sentry for iOS"
    @echo "  just build-sentry-gdscript-windows     # Build GDScript Sentry for Windows"
    @echo ""
    @echo "🍎 macOS BUILDS:"
    @echo "  just build-sentry-gdscript-editor-macos   # macOS editor build"
    @echo "  just build-sentry-gdscript-template-macos # macOS template build"
    @echo ""
    @echo "📱 ANDROID BUILDS:"
    @echo "  just build-sentry-gdscript-android-lib   # Android library build"
    @echo "  just build-sentry-gdscript-editor-android   # Android editor build"
    @echo "  just build-sentry-gdscript-template-android # Android template build"
    @echo ""
    @echo "🍎 iOS BUILDS:"
    @echo "  just build-sentry-gdscript-editor-ios       # iOS editor build"
    @echo "  just build-sentry-gdscript-template-ios     # iOS template build"
    @echo ""
    @echo "🪟 WINDOWS BUILDS:"
    @echo "  just build-sentry-gdscript-windows         # Windows GDExtension builds (via VM)"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-gdscript-clean            # Clean build artifacts"
    @echo "  just sentry-gdscript-status           # Check build status"
    @echo "  just sentry-gdscript-validate         # Validate Sentry integration"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just sentry-gdscript-complete        # Complete build + validation"

# All platform GDScript Sentry builds
build-sentry-gdscript-all force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🎮 Checking GDScript Sentry SDK..."

    # Force rebuild if explicitly requested OR if submodule changed
    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding GDScript Sentry..."
        just build-sentry-gdscript-macos {{force}}
        just build-sentry-gdscript-android {{force}}
        just build-sentry-gdscript-ios {{force}}
        just build-sentry-gdscript-windows {{force}}
    elif [ -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then
        echo "✅ GDScript Sentry already built:"
        echo "   📱 {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework"
        echo "⏭️  Skipping GDScript Sentry rebuild (saves 3-8 minutes)"
        echo "💡 Use 'just build-sentry-gdscript-all force=yes' to force rebuild"
    else
        echo "🔧 Building GDScript Sentry (this will take 3-8 minutes)..."
        just build-sentry-gdscript-macos {{force}}
        just build-sentry-gdscript-android {{force}}
        just build-sentry-gdscript-ios {{force}}
        just build-sentry-gdscript-windows {{force}}
    fi
    echo "✅ GDScript Sentry builds for all platforms completed"

# macOS builds
build-sentry-gdscript-macos force="no":
    just build-sentry-gdscript-editor-macos
    just build-sentry-gdscript-template-macos
    just sentry-sync-macos
    @echo "✅ GDScript Sentry macOS builds completed"

build-sentry-gdscript-editor-macos:
    @echo "🏗️  Building GDScript Sentry for macOS editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes
    @echo "✅ GDScript Sentry macOS editor build completed"

build-sentry-gdscript-template-macos:
    @echo "🏗️  Building GDScript Sentry for macOS template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes
    @echo "✅ GDScript Sentry macOS template build completed"

# Android builds
build-sentry-gdscript-android force="no":
    just build-sentry-gdscript-android-lib
    just build-sentry-gdscript-editor-android
    just build-sentry-gdscript-template-android
    just sentry-sync-android
    @echo "✅ GDScript Sentry Android builds completed"

build-sentry-gdscript-android-lib:
    @echo "🏗️  Building GDScript Sentry Android library..."
    @cd {{SENTRY_PATH}} && ./gradlew assemble
    @echo "✅ GDScript Sentry Android library build completed"

build-sentry-gdscript-editor-android:
    @echo "🏗️  Building GDScript Sentry for Android editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ GDScript Sentry Android editor build completed"

build-sentry-gdscript-template-android:
    @echo "🏗️  Building GDScript Sentry for Android template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ GDScript Sentry Android template build completed"

# iOS builds (device only - no simulator)
build-sentry-gdscript-ios force="no":
    just build-sentry-gdscript-editor-ios {{force}}
    just build-sentry-gdscript-template-ios {{force}}
    just sentry-sync-ios
    @echo "✅ GDScript Sentry iOS device builds completed"

build-sentry-gdscript-editor-ios force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry iOS editor already built
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.editor.arm64.dylib" ]; then
        echo "✅ GDScript Sentry iOS editor already built"
        echo "   Use 'just build-sentry-gdscript-editor-ios force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building GDScript Sentry for iOS device (editor)..."
    cd {{SENTRY_PATH}} && scons platform=ios target=editor arch=arm64 ios_simulator=no optimize=size
    echo "✅ GDScript Sentry iOS device editor build completed"

    # Fix install name to use @rpath instead of absolute temp path
    echo "🔧 Fixing editor dylib install name for xcframework packaging..."
    if [ -f "project/addons/sentry/bin/ios/temp/libsentry.ios.editor.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.editor.arm64.dylib" "project/addons/sentry/bin/ios/temp/libsentry.ios.editor.arm64.dylib"
        echo "✅ Fixed editor dylib install name"
    fi

build-sentry-gdscript-template-ios force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry iOS templates already built (both debug and release)
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && \
       [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib" ] && \
       [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib" ]; then
        echo "✅ GDScript Sentry iOS templates already built (debug + release)"
        echo "   Use 'just build-sentry-gdscript-template-ios force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building GDScript Sentry for iOS device templates (debug + release)..."
    cd {{SENTRY_PATH}} && \
        scons platform=ios target=template_debug arch=arm64 ios_simulator=no && \
        scons platform=ios target=template_release arch=arm64 ios_simulator=no optimize=size
    echo "✅ GDScript Sentry iOS device template builds completed"

    # Fix install name to use @rpath instead of absolute temp path
    echo "🔧 Fixing dylib install names for xcframework packaging..."
    if [ -f "project/addons/sentry/bin/ios/temp/libsentry.ios.release.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.release.arm64.dylib" "project/addons/sentry/bin/ios/temp/libsentry.ios.release.arm64.dylib"
        echo "✅ Fixed release dylib install name"
    fi
    if [ -f "project/addons/sentry/bin/ios/temp/libsentry.ios.debug.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.debug.arm64.dylib" "project/addons/sentry/bin/ios/temp/libsentry.ios.debug.arm64.dylib"
        echo "✅ Fixed debug dylib install name"
    fi

    echo "📱 Creating GDExtension XCFrameworks..."
    if [ -f "project/addons/sentry/bin/ios/temp/libsentry.ios.release.arm64.dylib" ]; then
        # Force recreation if force=yes OR if xcframework doesn't exist OR dylib is newer
        if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ] || [ ! -d "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework" ] || [ "project/addons/sentry/bin/ios/temp/libsentry.ios.release.arm64.dylib" -nt "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework" ]; then
            echo "📦 Creating release XCFramework..."
            # Remove existing xcframework first to ensure clean creation
            rm -rf project/addons/sentry/bin/ios/libsentry.ios.release.xcframework
            xcodebuild -create-xcframework \
                -library project/addons/sentry/bin/ios/temp/libsentry.ios.release.arm64.dylib \
                -output project/addons/sentry/bin/ios/libsentry.ios.release.xcframework
            echo "✅ GDScript Sentry GDExtension XCFramework (release) created"
        else
            echo "✅ Release XCFramework already exists and is up to date"
        fi
    else
        echo "⚠️  Release dylib not found - skipping release XCFramework"
    fi
    if [ -f "project/addons/sentry/bin/ios/temp/libsentry.ios.debug.arm64.dylib" ]; then
        # Force recreation if force=yes OR if xcframework doesn't exist OR dylib is newer
        if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ] || [ ! -d "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework" ] || [ "project/addons/sentry/bin/ios/temp/libsentry.ios.debug.arm64.dylib" -nt "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework" ]; then
            echo "📦 Creating debug XCFramework..."
            # Remove existing xcframework first to ensure clean creation
            rm -rf project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework
            xcodebuild -create-xcframework \
                -library project/addons/sentry/bin/ios/temp/libsentry.ios.debug.arm64.dylib \
                -output project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework
            echo "✅ GDScript Sentry GDExtension XCFramework (debug) created"
        else
            echo "✅ Debug XCFramework already exists and is up to date"
        fi
    else
        echo "⚠️  Debug dylib not found - skipping debug XCFramework"
    fi
    echo "🔧 Fixing embedded dylib paths in XCFrameworks..."
    # Note: We're currently in {{SENTRY_PATH}} (extras/sentry-godot), so use relative paths
    if [ -f "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.release.arm64.dylib" project/addons/sentry/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib
        echo "✅ Fixed embedded dylib paths in release XCFramework"
    fi
    if [ -f "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.debug.arm64.dylib" project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib
        echo "✅ Fixed embedded dylib paths in debug XCFramework"
    fi

    echo "📦 Syncing XCFrameworks to main project and export directory..."
    # Go back to justfile root directory for proper path resolution
    cd ../..

    # Sync from submodule to main project
    if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then
        echo "📦 Syncing release XCFramework to main project..."
        rm -rf {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.release.xcframework
        cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework {{PROJECT_SENTRY_PATH}}/bin/ios/
        echo "✅ Synced to {{PROJECT_SENTRY_PATH}}/bin/ios/"
    fi
    if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then
        echo "📦 Syncing debug XCFramework to main project..."
        rm -rf {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.debug.xcframework
        cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework {{PROJECT_SENTRY_PATH}}/bin/ios/
        echo "✅ Synced to {{PROJECT_SENTRY_PATH}}/bin/ios/"
    fi

    # Sync from main project to export directory
    if [ -d "{{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then
        echo "📦 Syncing release XCFramework to export..."
        rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework
        cp -R {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.release.xcframework {{IOS_EXPORT_PATH}}/
        echo "✅ Synced to {{IOS_EXPORT_PATH}}/"
    fi
    if [ -d "{{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then
        echo "📦 Syncing debug XCFramework to export..."
        rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework
        cp -R {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.debug.xcframework {{IOS_EXPORT_PATH}}/
        echo "✅ Synced to {{IOS_EXPORT_PATH}}/"
    fi

    echo "✅ GDScript Sentry iOS GDExtension integration complete"

# Verify GDScript Sentry SDK
sentry-gdscript-verify:
    @echo "🔍 Verifying GDScript Sentry SDK..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "🔄 Initializing Sentry submodule..."; \
        git submodule add https://github.com/Myran/sentry-godot.git {{SENTRY_PATH}}; \
    fi
    @if [ -d "{{SENTRY_PATH}}" ] && [ ! -d "{{SENTRY_PATH}}/modules/godot-cpp/SConstruct" ]; then \
        echo "❌ Sentry submodules not initialized"; \
        echo "🔄 Initializing Sentry submodules recursively..."; \
        cd {{SENTRY_PATH}} && git submodule update --init --recursive; \
    fi
    @if [ ! -d "{{SENTRY_ADDON_PATH}}" ]; then \
        echo "❌ Sentry addon not found at {{SENTRY_ADDON_PATH}}"; \
        exit 1; \
    fi
    @echo "✅ GDScript Sentry SDK setup verified"

# Platform-specific GDScript Sentry cleanup (aligned with native Sentry pattern)

sentry-gdscript-ios-clean:
    @echo "🧹 Cleaning GDScript Sentry iOS build artifacts..."
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/ios/libsentry.ios.*.dylib
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @echo "✅ GDScript Sentry iOS artifacts cleaned"

sentry-gdscript-android-clean:
    @echo "🧹 Cleaning GDScript Sentry Android build artifacts..."
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.*.so
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.*.so.debug
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/android/sentry_android_godot_plugin.*.aar
    @rm -f {{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.*.aar
    @rm -f project/android/build/libs/debug/sentry_android_godot_plugin.debug.aar
    @rm -f project/android/build/libs/release/sentry_android_godot_plugin.release.aar
    @echo "✅ GDScript Sentry Android artifacts cleaned"

sentry-gdscript-macos-clean:
    @echo "🧹 Cleaning GDScript Sentry macOS build artifacts..."
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/macos/libsentry.macos.*.framework/libsentry.macos.*
    @rm -rf {{SENTRY_PATH}}/project/addons/sentry/bin/macos/dSYMs/libsentry.macos.*.framework.dSYM
    @echo "✅ GDScript Sentry macOS artifacts cleaned"

sentry-gdscript-windows-clean:
    @echo "🧹 Cleaning GDScript Sentry Windows build artifacts..."
    @rm -f {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.*.x86_64.dll
    @echo "✅ GDScript Sentry Windows artifacts cleaned"

# Clean all GDScript Sentry build artifacts
sentry-gdscript-clean-all:
    @echo "🧹 Cleaning all GDScript Sentry build artifacts..."
    @just sentry-gdscript-ios-clean
    @just sentry-gdscript-android-clean
    @just sentry-gdscript-macos-clean
    @just sentry-gdscript-windows-clean
    @echo "✅ All GDScript Sentry build artifacts cleaned"

# Check build status
sentry-gdscript-status:
    @echo "📊 GDScript Sentry SDK Build Status"
    @echo "================================"
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 iOS export path: {{IOS_EXPORT_PATH}}"
    @if [ -d "{{IOS_EXPORT_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📱 GDScript Sentry GDExtension: {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework"
    @if [ -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Sync iOS xcframeworks from project addon to export directory
sentry-sync-ios:
    @echo "📱 Syncing iOS Sentry xcframeworks to export directory..."
    @if [ -d "{{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then \
        echo "📦 Copying release xcframework..."; \
        rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework; \
        cp -R {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.release.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Copied libsentry.ios.release.xcframework"; \
    else \
        echo "⚠️  Release xcframework not found in {{PROJECT_SENTRY_PATH}}/bin/ios/"; \
    fi
    @if [ -d "{{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then \
        echo "📦 Copying debug xcframework..."; \
        rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework; \
        cp -R {{PROJECT_SENTRY_PATH}}/bin/ios/libsentry.ios.debug.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Copied libsentry.ios.debug.xcframework"; \
    else \
        echo "⚠️  Debug xcframework not found in {{PROJECT_SENTRY_PATH}}/bin/ios/"; \
    fi
    @echo "✅ iOS Sentry sync complete"

# Sync macOS frameworks from submodule to project addon
sentry-sync-macos:
    @echo "🍎 Syncing macOS Sentry frameworks to project addon..."
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/macos/libsentry.macos.release.framework" ]; then \
        echo "📦 Copying release framework..."; \
        rm -rf {{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.release.framework; \
        cp -R {{SENTRY_ADDON_PATH}}/bin/macos/libsentry.macos.release.framework {{PROJECT_SENTRY_PATH}}/bin/macos/; \
        echo "✅ Copied libsentry.macos.release.framework"; \
    else \
        echo "⚠️  Release framework not found in {{SENTRY_ADDON_PATH}}/bin/macos/"; \
    fi
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/macos/libsentry.macos.debug.framework" ]; then \
        echo "📦 Copying debug framework..."; \
        rm -rf {{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.debug.framework; \
        cp -R {{SENTRY_ADDON_PATH}}/bin/macos/libsentry.macos.debug.framework {{PROJECT_SENTRY_PATH}}/bin/macos/; \
        echo "✅ Copied libsentry.macos.debug.framework"; \
    else \
        echo "⚠️  Debug framework not found in {{SENTRY_ADDON_PATH}}/bin/macos/"; \
    fi
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/macos/Sentry.framework" ]; then \
        echo "📦 Copying native Sentry.framework..."; \
        rm -rf {{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework; \
        cp -R {{SENTRY_ADDON_PATH}}/bin/macos/Sentry.framework {{PROJECT_SENTRY_PATH}}/bin/macos/; \
        echo "✅ Copied Sentry.framework"; \
    else \
        echo "⚠️  Sentry.framework not found in {{SENTRY_ADDON_PATH}}/bin/macos/"; \
    fi
    @echo "✅ macOS Sentry sync complete"

# Sync Android .so files from submodule to project addon
sentry-sync-android:
    @echo "🤖 Syncing Android Sentry binaries to project addon..."
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/android/libsentry.android.release.arm64.so" ]; then \
        echo "📦 Copying Android .so files..."; \
        cp -f {{SENTRY_ADDON_PATH}}/bin/android/libsentry.android.*.so {{PROJECT_SENTRY_PATH}}/bin/android/; \
        echo "✅ Copied .so files"; \
    else \
        echo "⚠️  Android .so files not found in {{SENTRY_ADDON_PATH}}/bin/android/"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/android/libsentry.android.release.arm64.so.debug" ]; then \
        echo "📦 Copying Android debug symbols..."; \
        cp -f {{SENTRY_ADDON_PATH}}/bin/android/libsentry.android.*.so.debug {{PROJECT_SENTRY_PATH}}/bin/android/; \
        echo "✅ Copied debug symbols"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/sentry_android_godot_plugin.release.aar" ]; then \
        echo "📦 Copying Android AAR files..."; \
        cp -f {{SENTRY_ADDON_PATH}}/sentry_android_godot_plugin.*.aar {{PROJECT_SENTRY_PATH}}/; \
        echo "✅ Copied AAR files to addon"; \
    fi
    # Also copy AAR files to project/android/build/libs for Gradle
    @if [ -f "{{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.debug.aar" ]; then \
        echo "📦 Copying AAR to android build libs..."; \
        mkdir -p project/android/build/libs/debug project/android/build/libs/release; \
        cp -f {{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.debug.aar project/android/build/libs/debug/; \
        echo "✅ Copied debug AAR to libs/debug"; \
    fi
    @if [ -f "{{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.release.aar" ]; then \
        mkdir -p project/android/build/libs/release; \
        cp -f {{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.release.aar project/android/build/libs/release/; \
        echo "✅ Copied release AAR to libs/release"; \
    fi
    @echo "✅ Android Sentry sync complete"

# Windows builds (via VM - cross-compilation from macOS)
build-sentry-gdscript-windows force="no":
    @echo "🏗️  Building GDScript Sentry for Windows (via VM)..."
    just build-sentry-native-windows-vm-build-all
    just build-sentry-native-windows-vm-package
    @echo "✅ GDScript Sentry Windows builds completed"

# Validate GDScript Sentry integration
sentry-gdscript-validate:
    @echo "🔧 Validating GDScript Sentry integration..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        exit 1; \
    fi
    @if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then \
        echo "❌ GDScript Sentry GDExtension not built - run 'just sentry-gdscript-build'"; \
        exit 1; \
    fi
    @if [ ! -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
        echo "❌ GDScript Sentry GDExtension binary missing"; \
        exit 1; \
    fi
    # Validate Android AAR files in build libs
    @echo "🤖 Validating Android AAR files..."
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.debug.aar" ]; then \
        echo "❌ Android debug AAR not found in {{PROJECT_SENTRY_PATH}}/"; \
        echo "   Run: just sentry-sync-android"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/sentry_android_godot_plugin.release.aar" ]; then \
        echo "❌ Android release AAR not found in {{PROJECT_SENTRY_PATH}}/"; \
        echo "   Run: just sentry-sync-android"; \
        exit 1; \
    fi
    @if [ ! -f "project/android/build/libs/debug/sentry_android_godot_plugin.debug.aar" ]; then \
        echo "❌ Android debug AAR not found in project/android/build/libs/debug/"; \
        echo "   Run: just sentry-sync-android"; \
        exit 1; \
    fi
    @if [ ! -f "project/android/build/libs/release/sentry_android_godot_plugin.release.aar" ]; then \
        echo "❌ Android release AAR not found in project/android/build/libs/release/"; \
        echo "   Run: just sentry-sync-android"; \
        exit 1; \
    fi
    @echo "✅ Android AAR files found in all locations"
    @echo "✅ GDScript Sentry SDK validation passed"

# Complete build + validation workflow
sentry-gdscript-complete force="no":
    @just sentry-gdscript-verify
    @just build-sentry-gdscript-all {{force}}
    @just sentry-gdscript-validate
    @echo "🎉 GDScript Sentry complete build workflow finished"