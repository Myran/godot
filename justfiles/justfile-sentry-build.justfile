# Sentry SDK Build Commands for GameTwo
# Following GameTwo's modular justfile structure

# Sentry SDK paths
SENTRY_PATH := "extras/sentry-godot"
SENTRY_ADDON_PATH := "project/addons/sentry"
SENTRY_PROJECT_PATH := "extras/sentry-godot/project"
IOS_EXPORT_PATH := "export/ios"

# Default Sentry build target
default-sentry:
    @echo "🎯 Sentry SDK Build Commands for GameTwo"
    @echo ""
    @just help-sentry

# Show Sentry build help
help-sentry:
    @echo "🏗️  Sentry SDK Build Commands"
    @echo "=================================="
    @echo ""
    @echo "📦 Core Build Commands:"
    @echo "  just sentry-build-desktop         # Build Sentry for desktop (editor + template)"
    @echo "  just sentry-build-android         # Build Sentry for Android (editor + template)"
    @echo "  just sentry-build-ios             # Build Sentry for iOS (device + simulator)"
    @echo "  just sentry-build-all-platforms   # Build Sentry for all platforms"
    @echo ""
    @echo "🎯 Editor Builds:"
    @echo "  just sentry-editor-desktop       # Desktop editor build only"
    @echo "  just sentry-editor-android       # Android editor build only"
    @echo "  just sentry-editor-ios           # iOS editor build only"
    @echo ""
    @echo "📱 Template/Export Builds:"
    @echo "  just sentry-template-desktop     # Desktop template build"
    @echo "  just sentry-template-android     # Android template build"
    @echo "  just sentry-template-ios         # iOS template build"
    @echo ""
    @echo "🔧 Android Library:"
    @echo "  just sentry-android-lib          # Build Android bridge library"
    @echo ""
    @echo "🧪 Development:"
    @echo "  just sentry-clean                 # Clean build artifacts"
    @echo "  just sentry-status                # Check build status"
    @echo "  just sentry-validate              # Validate Sentry integration"
    @echo ""
    @echo "🚀 Full Build Pipeline:"
    @echo "  just sentry-build-complete       # Complete build for current platform"
    @echo ""
    @echo "🔧 Build Flags:"
    @echo "  SENTRY_ENABLED=1                 # Enables native iOS Sentry SDK initialization"
    @echo "                                   # Automatically passed to iOS SCons builds"

# Verify Sentry submodule exists
sentry-verify:
    @echo "🔍 Verifying Sentry SDK submodule..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "📦 Run: git submodule add https://github.com/Myran/sentry-godot.git extras/sentry-godot"; \
        exit 1; \
    fi
    @echo "✅ Sentry submodule verified at {{SENTRY_PATH}}"
    @cd {{SENTRY_PATH}} && git rev-parse HEAD

# Clean build artifacts
sentry-clean:
    @echo "🧹 Cleaning Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/project/addons/sentry/bin/
    @rm -rf {{SENTRY_ADDON_PATH}}/bin/
    @rm -rf {{SENTRY_PATH}}/.sconsign*
    @echo "✅ Sentry build artifacts cleaned"

# Check build status
sentry-status:
    @echo "📊 Sentry SDK Build Status"
    @echo "==========================="
    @echo "Submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then \
        cd {{SENTRY_PATH}} && echo "Git HEAD: $(git rev-parse --short HEAD)"; \
    else \
        echo "❌ Submodule not found"; \
    fi
    @echo ""
    @echo "Build Artifacts:"
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin" ]; then \
        echo "✅ Build artifacts exist"; \
        ls -la {{SENTRY_ADDON_PATH}}/bin/ || echo "Empty bin directory"; \
    else \
        echo "❌ No build artifacts found"; \
    fi

# Desktop builds (current platform)
sentry-build-desktop: sentry-editor-desktop sentry-template-desktop
    @echo "✅ Sentry desktop builds completed"

sentry-editor-desktop:
    @echo "🏗️  Building Sentry for desktop editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes
    @echo "✅ Sentry desktop editor build completed"

sentry-template-desktop:
    @echo "🏗️  Building Sentry for desktop template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes
    @echo "✅ Sentry desktop template build completed"

# Android builds
sentry-build-android: sentry-android-lib sentry-editor-android sentry-template-android
    @echo "✅ Sentry Android builds completed"

sentry-android-lib:
    @echo "🏗️  Building Sentry Android library..."
    @cd {{SENTRY_PATH}} && ./gradlew assemble
    @echo "✅ Sentry Android library build completed"

sentry-editor-android:
    @echo "🏗️  Building Sentry for Android editor..."
    @cd {{SENTRY_PATH}} && scons target=editor debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ Sentry Android editor build completed"

sentry-template-android:
    @echo "🏗️  Building Sentry for Android template..."
    @cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes platform=android build_android_lib=yes
    @echo "✅ Sentry Android template build completed"

# iOS builds (device only - no simulator)
# SENTRY_ENABLED=1 enables native iOS Sentry SDK initialization in Godot's AppDelegate
sentry-build-ios: sentry-editor-ios-device sentry-template-ios-device
    @echo "✅ Sentry iOS device builds completed"

sentry-editor-ios-device:
    @echo "🏗️  Building Sentry for iOS device (editor)..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=editor arch=arm64 ios_simulator=no SENTRY_ENABLED=1
    @echo "✅ Sentry iOS device editor build completed"

sentry-template-ios-device:
    @echo "🏗️  Building Sentry for iOS device template..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=template_release arch=arm64 ios_simulator=no SENTRY_ENABLED=1
    @echo "✅ Sentry iOS device template build completed"
    @echo "📱 Creating device-only GDExtension XCFrameworks..."
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib" ]; then \
        xcodebuild -create-xcframework \
            -library {{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.release.arm64.dylib \
            -output {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework; \
        echo "✅ Sentry GDExtension XCFramework (release) created"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib" ]; then \
        xcodebuild -create-xcframework \
            -library {{SENTRY_ADDON_PATH}}/bin/ios/temp/libsentry.ios.debug.arm64.dylib \
            -output {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework; \
        echo "✅ Sentry GDExtension XCFramework (debug) created"; \
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
    @echo "📱 Copying Sentry XCFrameworks to iOS export project..."
    @cp -R {{SENTRY_ADDON_PATH}}/bin/ios/Sentry.xcframework {{IOS_EXPORT_PATH}}/
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework" ]; then \
        cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Sentry GDExtension XCFramework (release) copied to iOS export project"; \
    fi
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework" ]; then \
        cp -R {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Sentry GDExtension XCFramework (debug) copied to iOS export project"; \
    fi
    @echo "📄 Copying Sentry GDExtension configuration to iOS app bundle..."
    @if [ -d "{{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app" ]; then \
        cp {{SENTRY_ADDON_PATH}}/sentry.gdextension {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/; \
        echo "✅ Sentry GDExtension configuration copied to Debug app bundle"; \
    fi
    @if [ -d "{{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app" ]; then \
        cp {{SENTRY_ADDON_PATH}}/sentry.gdextension {{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/; \
        echo "✅ Sentry GDExtension configuration copied to Release app bundle"; \
    fi
    @echo "📱 Copying Sentry dylib to iOS app Frameworks directory..."
    @if [ -d "{{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks" ]; then \
        if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
            cp {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks/; \
            echo "✅ Sentry release dylib copied to Debug app Frameworks"; \
        fi; \
        if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib" ]; then \
            cp {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.debug.xcframework/ios-arm64/libsentry.ios.debug.arm64.dylib {{IOS_EXPORT_PATH}}/Build/Products/Debug-iphoneos/gametwo.app/Frameworks/; \
            echo "✅ Sentry debug dylib copied to Debug app Frameworks"; \
        fi; \
    fi
    @if [ -d "{{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/Frameworks" ]; then \
        if [ -f "{{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
            cp {{SENTRY_ADDON_PATH}}/bin/ios/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib {{IOS_EXPORT_PATH}}/Build/Products/Release-iphoneos/gametwo.app/Frameworks/; \
            echo "✅ Sentry release dylib copied to Release app Frameworks"; \
        fi; \
    fi
    @echo "✅ Sentry files copied to iOS export project"

# Build for all platforms
sentry-build-all-platforms:
    @echo "🚀 Building Sentry SDK for all platforms..."
    @echo "This may take 20-30 minutes..."
    @just sentry-build-desktop
    @just sentry-build-android
    @just sentry-build-ios
    @echo "✅ Sentry SDK built for all platforms"

# Complete build for current platform
sentry-build-complete:
    @echo "🚀 Complete Sentry SDK build for current platform..."
    @just sentry-verify
    @if [[ "$OSTYPE" == "darwin"* ]]; then \
        echo "🍎 Detected macOS - building desktop + iOS"; \
        just sentry-build-desktop; \
        just sentry-build-ios; \
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then \
        echo "🐧 Detected Linux - building desktop"; \
        just sentry-build-desktop; \
    else \
        echo "🪟 Unknown platform - building desktop only"; \
        just sentry-build-desktop; \
    fi
    @echo "✅ Complete Sentry SDK build finished"

# Validate Sentry integration
sentry-validate:
    @echo "🔍 Validating Sentry integration..."
    @just test-desktop-target sentry-addon-validation || echo "❌ Sentry validation failed - integration incomplete"
    @echo "✅ Sentry validation completed"

# Development helper - build and validate
sentry-dev: sentry-build-complete sentry-validate
    @echo "🎯 Sentry SDK development cycle completed"

# Quick build for current platform only (development)
sentry-quick-build:
    @echo "⚡ Quick Sentry build for current platform..."
    @just sentry-editor-desktop
    @echo "✅ Quick Sentry build completed"