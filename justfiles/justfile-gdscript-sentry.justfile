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
    @echo "  just build-sentry-gdscript-desktop    # Build GDScript Sentry for desktop"
    @echo "  just build-sentry-gdscript-android    # Build GDScript Sentry for Android"
    @echo "  just build-sentry-gdscript-ios        # Build GDScript Sentry for iOS"
    @echo ""
    @echo "🖥️  DESKTOP BUILDS:"
    @echo "  just build-sentry-gdscript-editor-desktop   # Desktop editor build"
    @echo "  just build-sentry-gdscript-template-desktop # Desktop template build"
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
        just build-sentry-gdscript-desktop {{force}}
        just build-sentry-gdscript-android {{force}}
        just build-sentry-gdscript-ios {{force}}
    elif [ -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then
        echo "✅ GDScript Sentry already built:"
        echo "   📱 {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework"
        echo "⏭️  Skipping GDScript Sentry rebuild (saves 3-8 minutes)"
        echo "💡 Use 'just build-sentry-gdscript-all force=yes' to force rebuild"
    else
        echo "🔧 Building GDScript Sentry (this will take 3-8 minutes)..."
        just build-sentry-gdscript-desktop {{force}}
        just build-sentry-gdscript-android {{force}}
        just build-sentry-gdscript-ios {{force}}
    fi
    echo "✅ GDScript Sentry builds for all platforms completed"

# Desktop builds (current platform)
build-sentry-gdscript-desktop force="no":
    just build-sentry-gdscript-editor-desktop
    just build-sentry-gdscript-template-desktop
    @echo "✅ GDScript Sentry desktop builds completed"

build-sentry-gdscript-editor-desktop:
    @echo "🏗️  Building GDScript Sentry for desktop editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes
    @echo "✅ GDScript Sentry desktop editor build completed"

build-sentry-gdscript-template-desktop:
    @echo "🏗️  Building GDScript Sentry for desktop template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes
    @echo "✅ GDScript Sentry desktop template build completed"

# Android builds
build-sentry-gdscript-android force="no":
    just build-sentry-gdscript-android-lib
    just build-sentry-gdscript-editor-android
    just build-sentry-gdscript-template-android
    @echo "✅ GDScript Sentry Android builds completed"

build-sentry-gdscript-android-lib:
    @echo "🏗️  Building GDScript Sentry Android library..."
    @cd {{SENTRY_PATH}} && ./gradlew assemble
    @echo "📦 Copying Sentry AAR files to addons directory for automatic discovery..."
    @mkdir -p project/addons/sentry/
    @cp project/addons/sentry/bin/android/sentry_android_godot_plugin.debug.aar project/addons/sentry/ 2>/dev/null || echo "⚠️  Debug AAR file not found in build output"
    @cp project/addons/sentry/bin/android/sentry_android_godot_plugin.release.aar project/addons/sentry/ 2>/dev/null || echo "⚠️  Release AAR file not found in build output"
    @echo "✅ Sentry AAR files copied to addons directory"
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
    if [ -f "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.release.arm64.dylib" project/addons/sentry/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib
        echo "✅ Fixed release dylib embedded path"
    fi
    if [ -f "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib" ]; then
        install_name_tool -id "@rpath/libsentry.ios.debug.arm64.dylib" project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib
        echo "✅ Fixed debug dylib embedded path"
    fi
    echo "📱 Copying GDScript Sentry XCFrameworks to iOS export project..."
    if [ -d "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework" ]; then
        if [ ! -d "../../{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ] || [ "project/addons/sentry/bin/ios/libsentry.ios.release.xcframework" -nt "../../{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then
            echo "📦 Copying release XCFramework to export..."
            cp -R project/addons/sentry/bin/ios/libsentry.ios.release.xcframework ../../{{IOS_EXPORT_PATH}}/
            echo "✅ GDScript Sentry GDExtension XCFramework (release) copied to iOS export project"
        else
            echo "✅ Release XCFramework already exists in export and is up to date"
        fi
    else
        echo "⚠️  Release XCFramework not found in addon directory - skipping copy"
    fi
    if [ -d "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework" ]; then
        if [ ! -d "../../{{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework" ] || [ "project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework" -nt "../../{{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework" ]; then
            echo "📦 Copying debug XCFramework to export..."
            cp -R project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework ../../{{IOS_EXPORT_PATH}}/
            echo "✅ GDScript Sentry GDExtension XCFramework (debug) copied to iOS export project"
        else
            echo "✅ Debug XCFramework already exists in export and is up to date"
        fi
    else
        echo "⚠️  Debug XCFramework not found in addon directory - skipping copy"
    fi
    echo "🗑️  Removing libsentry XCFrameworks from addon directory (complete deduplication)..."
    # Remove duplicates since .gdextension already points to export/ios
    rm -rf project/addons/sentry/bin/ios/libsentry.ios.debug.xcframework
    rm -rf project/addons/sentry/bin/ios/libsentry.ios.release.xcframework
    echo "✅ Removed libsentry XCFrameworks from addon directory - no duplication"
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

# Clean build artifacts
sentry-gdscript-clean:
    @echo "🧹 Cleaning GDScript Sentry build artifacts..."
    # Remove built GDExtension libraries (NOT the pre-packaged native SDK frameworks)
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/macos/libsentry.macos.*.framework/libsentry.macos.*
    @rm -rf {{SENTRY_PATH}}/project/addons/sentry/bin/macos/dSYMs/libsentry.macos.*.framework.dSYM
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.*.so
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.*.so.debug
    @rm -f {{SENTRY_PATH}}/project/addons/sentry/bin/ios/libsentry.ios.*.dylib
    # Remove exported xcframeworks
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @echo "✅ GDScript Sentry build artifacts cleaned (native SDK frameworks preserved)"

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
    @echo "✅ GDScript Sentry SDK validation passed"

# Complete build + validation workflow
sentry-gdscript-complete:
    @just sentry-gdscript-verify
    @just sentry-gdscript-build
    @just sentry-gdscript-validate
    @echo "🎉 GDScript Sentry complete build workflow finished"