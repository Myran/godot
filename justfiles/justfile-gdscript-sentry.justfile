# GDScript Sentry SDK Build Commands for GameTwo
# Runtime GDExtension loaded by Godot at runtime

# GDScript Sentry SDK paths (shared variables defined in main Sentry justfile)

# Default GDScript Sentry build target
default-gdscript-sentry:
    @echo "🎯 GDScript Sentry SDK Build Commands for GameTwo"
    @echo ""
    @just help-gdscript-sentry

# Show GDScript Sentry build help
help-gdscript-sentry:
    @echo "🎮 GDScript Sentry SDK Build Commands"
    @echo "===================================="
    @echo ""
    @echo "🎮 GDSCRIPT INTEGRATION:"
    @echo "  just gdscript-sentry-build            # Build GDScript Sentry for all platforms"
    @echo "  just gdscript-sentry-build-desktop    # Build GDScript Sentry for desktop"
    @echo "  just gdscript-sentry-build-android    # Build GDScript Sentry for Android"
    @echo "  just gdscript-sentry-build-ios        # Build GDScript Sentry for iOS"
    @echo ""
    @echo "🖥️  DESKTOP BUILDS:"
    @echo "  just gdscript-sentry-editor-desktop   # Desktop editor build"
    @echo "  just gdscript-sentry-template-desktop # Desktop template build"
    @echo ""
    @echo "📱 ANDROID BUILDS:"
    @echo "  just gdscript-sentry-android-lib      # Android library build"
    @echo "  just gdscript-sentry-editor-android   # Android editor build"
    @echo "  just gdscript-sentry-template-android # Android template build"
    @echo ""
    @echo "🍎 iOS BUILDS:"
    @echo "  just gdscript-sentry-editor-ios       # iOS editor build"
    @echo "  just gdscript-sentry-template-ios     # iOS template build"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just gdscript-sentry-clean            # Clean build artifacts"
    @echo "  just gdscript-sentry-status           # Check build status"
    @echo "  just gdscript-sentry-validate         # Validate Sentry integration"
    @echo ""
    @echo "⚡ QUICK COMMANDS:"
    @echo "  just gdscript-sentry-quick           # Quick build (desktop editor only)"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just gdscript-sentry-complete        # Complete build + validation"
    @echo "  just gdscript-sentry-dev             # Development workflow (build + validate)"

# All platform GDScript Sentry builds
gdscript-sentry-build: gdscript-sentry-build-desktop gdscript-sentry-build-android gdscript-sentry-build-ios
    @echo "✅ GDScript Sentry builds for all platforms completed"

# Desktop builds (current platform)
gdscript-sentry-build-desktop: gdscript-sentry-editor-desktop gdscript-sentry-template-desktop
    @echo "✅ GDScript Sentry desktop builds completed"

gdscript-sentry-editor-desktop:
    @echo "🏗️  Building GDScript Sentry for desktop editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes
    @echo "✅ GDScript Sentry desktop editor build completed"

gdscript-sentry-template-desktop:
    @echo "🏗️  Building GDScript Sentry for desktop template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes
    @echo "✅ GDScript Sentry desktop template build completed"

# Android builds
gdscript-sentry-build-android: gdscript-sentry-android-lib gdscript-sentry-editor-android gdscript-sentry-template-android
    @echo "✅ GDScript Sentry Android builds completed"

gdscript-sentry-android-lib:
    @echo "🏗️  Building GDScript Sentry Android library..."
    @cd {{SENTRY_PATH}} && ./gradlew assemble
    @echo "✅ GDScript Sentry Android library build completed"

gdscript-sentry-editor-android:
    @echo "🏗️  Building GDScript Sentry for Android editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ GDScript Sentry Android editor build completed"

gdscript-sentry-template-android:
    @echo "🏗️  Building GDScript Sentry for Android template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ GDScript Sentry Android template build completed"

# iOS builds (device only - no simulator)
gdscript-sentry-build-ios: gdscript-sentry-editor-ios gdscript-sentry-template-ios
    @echo "✅ GDScript Sentry iOS device builds completed"

gdscript-sentry-editor-ios:
    @echo "🏗️  Building GDScript Sentry for iOS device (editor)..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=editor arch=arm64 ios_simulator=no
    @echo "✅ GDScript Sentry iOS device editor build completed"

gdscript-sentry-template-ios:
    @echo "🏗️  Building GDScript Sentry for iOS device template..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=template_release arch=arm64 ios_simulator=no
    @echo "✅ GDScript Sentry iOS device template build completed"
    @echo "📱 Creating GDExtension XCFrameworks..."
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib" ]; then \
        if [ ! -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" ] || [ "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib" -nt "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then \
            echo "📦 Creating release XCFramework..."; \
            xcodebuild -create-xcframework \
                -library {{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib \
                -output {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework; \
            echo "✅ GDScript Sentry GDExtension XCFramework (release) created"; \
        else \
            echo "✅ Release XCFramework already exists and is up to date"; \
        fi; \
    else \
        echo "⚠️  Release dylib not found - skipping release XCFramework"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib" ]; then \
        if [ ! -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ] || [ "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib" -nt "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then \
            echo "📦 Creating debug XCFramework..."; \
            xcodebuild -create-xcframework \
                -library {{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib \
                -output {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework; \
            echo "✅ GDScript Sentry GDExtension XCFramework (debug) created"; \
        else \
            echo "✅ Debug XCFramework already exists and is up to date"; \
        fi; \
    else \
        echo "⚠️  Debug dylib not found - skipping debug XCFramework"; \
    fi
    @echo "🔧 Fixing embedded dylib paths in XCFrameworks..."
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
        install_name_tool -id "@rpath/libsentry.ios.release.arm64.dylib" {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib; \
        echo "✅ Fixed release dylib embedded path"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib" ]; then \
        install_name_tool -id "@rpath/libsentry.ios.debug.arm64.dylib" {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib; \
        echo "✅ Fixed debug dylib embedded path"; \
    fi
    @echo "📱 Copying GDScript Sentry XCFrameworks to iOS export project..."
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then \
        if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ] || [ "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" -nt "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then \
            echo "📦 Copying release XCFramework to export..."; \
            cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework {{IOS_EXPORT_PATH}}/; \
            echo "✅ GDScript Sentry GDExtension XCFramework (release) copied to iOS export project"; \
        else \
            echo "✅ Release XCFramework already exists in export and is up to date"; \
        fi; \
    else \
        echo "⚠️  Release XCFramework not found in addon directory - skipping copy"; \
    fi
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then \
        if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework" ] || [ "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" -nt "{{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework" ]; then \
            echo "📦 Copying debug XCFramework to export..."; \
            cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework {{IOS_EXPORT_PATH}}/; \
            echo "✅ GDScript Sentry GDExtension XCFramework (debug) copied to iOS export project"; \
        else \
            echo "✅ Debug XCFramework already exists in export and is up to date"; \
        fi; \
    else \
        echo "⚠️  Debug XCFramework not found in addon directory - skipping copy"; \
    fi
    @echo "🗑️  Removing libsentry XCFrameworks from addon directory (complete deduplication)..."
    # Remove duplicates since .gdextension already points to export/ios
    @rm -rf {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework
    @rm -rf {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework
    @echo "✅ Removed libsentry XCFrameworks from addon directory - no duplication"
    @echo "✅ GDScript Sentry iOS GDExtension integration complete"

# Verify GDScript Sentry SDK
gdscript-sentry-verify:
    @echo "🔍 Verifying GDScript Sentry SDK..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "💡 Run: git submodule add https://github.com/Myran/sentry-godot.git {{SENTRY_PATH}}"; \
        exit 1; \
    fi
    @if [ ! -d "{{SENTRY_ADDON_PATH}}" ]; then \
        echo "❌ Sentry addon not found at {{SENTRY_ADDON_PATH}}"; \
        exit 1; \
    fi
    @echo "✅ GDScript Sentry SDK setup verified"

# Clean build artifacts
gdscript-sentry-clean:
    @echo "🧹 Cleaning GDScript Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/project/addons/sentry/bin/
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @rm -rf {{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/Frameworks/libsentry.ios.*
    @echo "✅ GDScript Sentry build artifacts cleaned"

# Check build status
gdscript-sentry-status:
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
gdscript-sentry-validate:
    @echo "🔧 Validating GDScript Sentry integration..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        exit 1; \
    fi
    @if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then \
        echo "❌ GDScript Sentry GDExtension not built - run 'just gdscript-sentry-build'"; \
        exit 1; \
    fi
    @if [ ! -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
        echo "❌ GDScript Sentry GDExtension binary missing"; \
        exit 1; \
    fi
    @echo "✅ GDScript Sentry SDK validation passed"

# Quick build (desktop editor only)
gdscript-sentry-quick: gdscript-sentry-verify gdscript-sentry-editor-desktop
    @echo "⚡ Quick GDScript Sentry build completed"

# Complete build + validation workflow
gdscript-sentry-complete:
    @just gdscript-sentry-verify
    @just gdscript-sentry-build
    @just gdscript-sentry-validate
    @echo "🎉 GDScript Sentry complete build workflow finished"

# Development workflow (build + validation)
gdscript-sentry-dev:
    @just gdscript-sentry-complete