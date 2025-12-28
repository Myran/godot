# Sentry Native macOS Build Commands for GameTwo
# Built-in to Godot executable via SCons compilation

# Sentry Native macOS paths (shared variables defined in main Sentry justfile)

# Show Sentry Native macOS build help
help-sentry-native-macos:
    @echo "🍎 Native macOS Sentry SDK Build Commands"
    @echo "========================================"
    @echo ""
    @echo "🖥️  NATIVE macOS INTEGRATION:"
    @echo "  just build-sentry-native-macos-all       # Build native Sentry for macOS (debug + release)"
    @echo "  just build-sentry-native-macos-debug     # Build native Sentry for macOS debug builds"
    @echo "  just build-sentry-native-macos-release   # Build native Sentry for macOS release builds (production)"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-native-macos-clean           # Clean build artifacts"
    @echo "  just sentry-native-macos-status          # Check build status"
    @echo "  just sentry-native-macos-validate        # Validate Sentry integration"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just sentry-native-macos-complete        # Complete native build + validation"

# Native macOS Sentry builds (compiled into Godot executable)
build-sentry-native-macos-all force="no":
    just build-sentry-native-macos-debug {{force}}
    just build-sentry-native-macos-release {{force}}
    @echo "✅ Native macOS Sentry builds completed"

build-sentry-native-macos-debug force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry macOS debug already built
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.macos.template_debug.universal.a" ]; then
        echo "✅ Native Sentry macOS debug already built"
        echo "   Use 'just build-sentry-native-macos-debug force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for macOS debug builds..."
    cd {{SENTRY_PATH}} && scons target=template_debug debug_symbols=yes
    echo "✅ Native Sentry macOS debug build completed"

build-sentry-native-macos-release force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Sentry macOS release already built and SDK copied
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.macos.template_release.universal.a" ] && [ -d "{{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework" ]; then
        echo "✅ Native Sentry macOS release already built and SDK integrated"
        echo "   Use 'just build-sentry-native-macos-release force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Native Sentry for macOS release builds..."
    cd {{SENTRY_PATH}} && scons target=template_release debug_symbols=yes
    echo "✅ Native Sentry macOS release build completed"

    # Sync frameworks to project
    just sentry-sync-macos
    echo "✅ Native macOS Sentry SDK integration complete"

# Verify Native Sentry SDK
sentry-native-macos-verify:
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
sentry-native-macos-clean:
    @echo "🧹 Cleaning native macOS Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.macos.*.a
    @rm -rf {{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework
    @echo "✅ Native macOS Sentry build artifacts cleaned"

# Check native build status
sentry-native-macos-status:
    @echo "📊 Native macOS Sentry SDK Build Status"
    @echo "======================================="
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "🍎 Native Sentry SDK: {{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework"
    @if [ -d "{{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "🍎 GDExtension debug: {{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.debug.framework"
    @if [ -d "{{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.debug.framework" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "🍎 GDExtension release: {{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.release.framework"
    @if [ -d "{{PROJECT_SENTRY_PATH}}/bin/macos/libsentry.macos.release.framework" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Validate native Sentry integration
sentry-native-macos-validate:
    @echo "🔧 Validating Native macOS Sentry integration..."
    @if [ ! -d "{{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just build-sentry-native-macos-all'"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/macos/Sentry.framework/Sentry" ]; then \
        echo "❌ Native Sentry SDK binary missing"; \
        exit 1; \
    fi
    @echo "✅ Native macOS Sentry SDK validation passed"

# Complete native build + validation workflow
sentry-native-macos-complete force="no":
    @just sentry-native-macos-verify
    @just build-sentry-native-macos-all {{force}}
    @just sentry-native-macos-validate
    @echo "🎉 Native macOS Sentry SDK complete build workflow finished"
