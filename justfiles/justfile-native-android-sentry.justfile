# Native Android Sentry Build Commands for GameTwo
# Built-in to Godot executable via SCons compilation

# Native Android Sentry paths (shared variables defined in main Sentry justfile)

# Show Native Android Sentry build help
help-native-android-sentry:
    @echo "🤖 Native Android Sentry SDK Build Commands"
    @echo "=========================================="
    @echo ""
    @echo "📱 NATIVE ANDROID INTEGRATION:"
    @echo "  just build-sentry-native-android-debug   # Build native Sentry for Android debug builds"
    @echo "  just build-sentry-native-android-release # Build native Sentry for Android release builds (production)"
    @echo "  just build-sentry-native-android-all     # Build native Sentry for Android (debug + release)"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-native-android-clean        # Clean build artifacts"
    @echo "  just sentry-native-android-status       # Check build status"
    @echo "  just sentry-native-android-validate    # Validate Sentry integration"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just sentry-native-android-complete     # Complete native build + validation"

# Native Android Sentry builds (compiled into Godot executable)
build-sentry-native-android-all force="no":
    just build-sentry-native-android-debug {{force}}
    just build-sentry-native-android-release {{force}}
    @echo "✅ Native Android Sentry builds completed"

build-sentry-native-android-debug force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry Android debug already built
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_debug.arm64.a" ]; then
        echo "✅ Native Sentry Android debug already built"
        echo "   Use 'just build-sentry-native-android-debug force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for Android debug builds..."
    cd {{SENTRY_PATH}} && scons platform=android target=template_debug arch=arm64 build_android_lib=yes android_api_level=24
    echo "✅ Native Sentry Android debug build completed"

build-sentry-native-android-release force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry Android release already built
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_release.arm64.a" ]; then
        echo "✅ Native Sentry Android release already built"
        echo "   Use 'just build-sentry-native-android-release force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for Android release builds..."
    cd {{SENTRY_PATH}} && scons platform=android target=template_release arch=arm64 build_android_lib=yes android_api_level=24 optimize=size
    echo "✅ Native Sentry Android release build completed"

# Verify Native Android Sentry SDK
sentry-native-android-verify:
    @echo "🔍 Verifying Native Android Sentry SDK..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "🔄 Initializing Sentry submodule..."; \
        git submodule add https://github.com/Myran/sentry-godot.git {{SENTRY_PATH}}; \
    fi
    @if [ -d "{{SENTRY_PATH}}" ] && [ ! -d "{{SENTRY_PATH}}/modules/sentry-native" ]; then \
        echo "❌ Sentry submodules not initialized"; \
        echo "🔄 Initializing Sentry submodules recursively..."; \
        cd {{SENTRY_PATH}} && git submodule update --init --recursive; \
    fi
    @if [ ! -d "{{SENTRY_ADDON_PATH}}" ]; then \
        echo "❌ Sentry addon not found at {{SENTRY_ADDON_PATH}}"; \
        exit 1; \
    fi
    @if [ -z "${ANDROID_HOME:-}" ]; then \
        echo "❌ ANDROID_HOME environment variable not set"; \
        echo "💡 Please set ANDROID_HOME to your Android SDK path"; \
        exit 1; \
    fi
    @echo "✅ Native Android Sentry SDK setup verified"

# Clean native build artifacts
sentry-native-android-clean:
    @echo "🧹 Cleaning native Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.android.*.a
    @echo "✅ Native Android Sentry build artifacts cleaned"

# Check native build status
sentry-native-android-status:
    @echo "📊 Native Android Sentry SDK Build Status"
    @echo "======================================"
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Android SDK: ${ANDROID_HOME:-Not set}"
    @if [ -n "${ANDROID_HOME:-}" ]; then echo "✅ $ANDROID_HOME"; else echo "❌ Not set"; fi
    @echo "📱 Native Sentry Debug ARM32: {{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_debug.arm32.a"
    @if [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_debug.arm32.a" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "📱 Native Sentry Debug ARM64: {{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_debug.arm64.a"
    @if [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_debug.arm64.a" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "📱 Native Sentry Release ARM32: {{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_release.arm32.a"
    @if [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_release.arm32.a" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "📱 Native Sentry Release ARM64: {{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_release.arm64.a"
    @if [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libsentry.android.template_release.arm64.a" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Validate native Sentry integration
sentry-native-android-validate:
    @echo "🔧 Validating Native Android Sentry integration..."
    @if [ ! -f "{{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.debug.arm64.so" ]; then \
        echo "❌ Native Android Sentry debug not built - run 'just build-sentry-native-android-debug'"; \
        exit 1; \
    fi
    @if [ ! -f "{{SENTRY_PATH}}/project/addons/sentry/bin/android/libsentry.android.release.arm64.so" ]; then \
        echo "❌ Native Android Sentry release not built - run 'just build-sentry-native-android-release'"; \
        exit 1; \
    fi
    @echo "✅ Native Android Sentry SDK validation passed"

# Complete native build + validation workflow
sentry-native-android-complete force="no":
    @just sentry-native-android-verify
    @just build-sentry-native-android-all {{force}}
    @just sentry-native-android-validate
    @echo "🎉 Native Android Sentry SDK complete build workflow finished"