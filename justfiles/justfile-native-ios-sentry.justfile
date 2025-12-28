# Sentry Native iOS Build Commands for GameTwo
# Built-in to Godot executable via SCons compilation

# Sentry Native iOS paths (shared variables defined in main Sentry justfile)

# Show Sentry Native iOS build help
help-sentry-native-ios:
    @echo "🍎 Native iOS Sentry SDK Build Commands"
    @echo "======================================"
    @echo ""
    @echo "📱 NATIVE iOS INTEGRATION:"
    @echo "  just build-sentry-native-ios-all         # Build native Sentry for iOS (debug + release)"
    @echo "  just build-sentry-native-ios-debug      # Build native Sentry for iOS debug builds"
    @echo "  just build-sentry-native-ios-release    # Build native Sentry for iOS release builds (production)"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-native-ios-clean             # Clean build artifacts"
    @echo "  just sentry-native-ios-status            # Check build status"
    @echo "  just sentry-native-ios-validate          # Validate Sentry integration"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just sentry-native-ios-complete          # Complete native build + validation"

# Native iOS Sentry builds (compiled into Godot executable)
build-sentry-native-ios-all force="no":
    just build-sentry-native-ios-debug {{force}}
    just build-sentry-native-ios-release {{force}}
    @echo "✅ Native iOS Sentry builds completed"

build-sentry-native-ios-debug force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry iOS debug already built
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.ios.template_debug.arm64.a" ]; then
        echo "✅ Native Sentry iOS debug already built"
        echo "   Use 'just build-sentry-native-ios-debug force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for iOS debug builds..."
    cd {{SENTRY_PATH}} && scons platform=ios target=template_debug arch=arm64 ios_simulator=no optimize=size
    echo "✅ Native Sentry iOS debug build completed"

build-sentry-native-ios-release force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry iOS release already built and SDK copied
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.ios.template_release.arm64.a" ] && [ -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then
        echo "✅ Native Sentry iOS release already built and SDK integrated"
        echo "   Use 'just build-sentry-native-ios-release force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for iOS release builds..."
    cd {{SENTRY_PATH}} && scons platform=ios target=template_release arch=arm64 ios_simulator=no optimize=size
    echo "✅ Native Sentry iOS release build completed"
    echo "📱 Copying Native Sentry SDK to iOS export project..."
    cd {{justfile_directory()}} && if [ -d "project/addons/sentry/bin/ios/Sentry.xcframework" ]; then \
        cp -R project/addons/sentry/bin/ios/Sentry.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Native Sentry SDK copied to iOS export project"; \
    else \
        echo "❌ Native Sentry SDK not found at project/addons/sentry/bin/ios/Sentry.xcframework"; \
        exit 1; \
    fi
    echo "✅ Native iOS Sentry SDK integration complete"

# Verify Native Sentry SDK
sentry-native-ios-verify:
    @echo "🔍 Verifying Native Sentry SDK..."
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
    @echo "✅ Native Sentry SDK setup verified"

# Clean native build artifacts
sentry-native-ios-clean:
    @echo "🧹 Cleaning native Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.ios.*.a
    @rm -rf {{IOS_EXPORT_PATH}}/Sentry.xcframework
    @echo "✅ Native Sentry build artifacts cleaned"

# Check native build status
sentry-native-ios-status:
    @echo "📊 Native Sentry SDK Build Status"
    @echo "============================="
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 iOS export path: {{IOS_EXPORT_PATH}}"
    @if [ -d "{{IOS_EXPORT_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📱 Native Sentry SDK: {{IOS_EXPORT_PATH}}/Sentry.xcframework"
    @if [ -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Validate native Sentry integration
sentry-native-ios-validate:
    @echo "🔧 Validating Native Sentry integration..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just sentry-native-ios-build'"; \
        exit 1; \
    fi
    @if [ ! -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
        echo "❌ Native Sentry SDK binary missing"; \
        exit 1; \
    fi
    @echo "✅ Native Sentry SDK validation passed"

# Complete native build + validation workflow
sentry-native-ios-complete force="no":
    @just sentry-native-ios-verify
    @just build-sentry-native-ios-all {{force}}
    @just sentry-native-ios-validate
    @echo "🎉 Native iOS Sentry SDK complete build workflow finished"