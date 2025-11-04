# Native iOS Sentry SDK Build Commands for GameTwo
# Built-in to Godot executable via SCons compilation

# Native iOS Sentry SDK paths (shared variables defined in main Sentry justfile)

# Default native iOS Sentry build target
default-native-sentry:
    @echo "🎯 Native iOS Sentry SDK Build Commands for GameTwo"
    @echo ""
    @just help-native-sentry

# Show native iOS Sentry build help
help-native-sentry:
    @echo "🍎 Native iOS Sentry SDK Build Commands"
    @echo "======================================"
    @echo ""
    @echo "📱 NATIVE iOS INTEGRATION:"
    @echo "  just native-sentry-build              # Build native Sentry for iOS (editor + template)"
    @echo "  just native-sentry-editor             # Build native Sentry for iOS editor only"
    @echo "  just native-sentry-template          # Build native Sentry for iOS template only"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just native-sentry-clean             # Clean build artifacts"
    @echo "  just native-sentry-status            # Check build status"
    @echo "  just native-sentry-validate          # Validate Sentry integration"
    @echo ""
    @echo "⚡ QUICK COMMANDS:"
    @echo "  just native-sentry-quick             # Quick native build (editor only)"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just native-sentry-complete          # Complete native build + validation"
    @echo "  just native-sentry-dev               # Development workflow (build + validate)"

# Native iOS Sentry builds (compiled into Godot executable)
native-sentry-build: native-sentry-editor native-sentry-template
    @echo "✅ Native iOS Sentry builds completed"

native-sentry-editor:
    @echo "🏗️  Building Native Sentry for iOS editor..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=editor arch=arm64 ios_simulator=no
    @echo "✅ Native Sentry iOS editor build completed"

native-sentry-template:
    @echo "🏗️  Building Native Sentry for iOS template..."
    @cd {{SENTRY_PATH}} && scons platform=ios target=template_release arch=arm64 ios_simulator=no
    @echo "✅ Native Sentry iOS template build completed"
    @echo "📱 Copying Native Sentry SDK to iOS export project..."
    @if [ -d "{{SENTRY_ADDON_PATH}}/bin/ios/Sentry.xcframework" ]; then \
        cp -R {{SENTRY_ADDON_PATH}}/bin/ios/Sentry.xcframework {{IOS_EXPORT_PATH}}/; \
        echo "✅ Native Sentry SDK copied to iOS export project"; \
    else \
        echo "❌ Native Sentry SDK not found at {{SENTRY_ADDON_PATH}}/bin/ios/Sentry.xcframework"; \
        exit 1; \
    fi
    @echo "✅ Native iOS Sentry SDK integration complete"

# Verify Native Sentry SDK
native-sentry-verify:
    @echo "🔍 Verifying Native Sentry SDK..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "💡 Run: git submodule add https://github.com/Myran/sentry-godot.git {{SENTRY_PATH}}"; \
        exit 1; \
    fi
    @if [ ! -d "{{SENTRY_ADDON_PATH}}" ]; then \
        echo "❌ Sentry addon not found at {{SENTRY_ADDON_PATH}}"; \
        exit 1; \
    fi
    @echo "✅ Native Sentry SDK setup verified"

# Clean native build artifacts
native-sentry-clean:
    @echo "🧹 Cleaning native Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/project/addons/sentry/bin/
    @rm -rf {{IOS_EXPORT_PATH}}/Sentry.xcframework
    @echo "✅ Native Sentry build artifacts cleaned"

# Check native build status
native-sentry-status:
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
native-sentry-validate:
    @echo "🔧 Validating Native Sentry integration..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just native-sentry-build'"; \
        exit 1; \
    fi
    @if [ ! -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
        echo "❌ Native Sentry SDK binary missing"; \
        exit 1; \
    fi
    @echo "✅ Native Sentry SDK validation passed"

# Quick native build (editor only)
native-sentry-quick: native-sentry-verify native-sentry-editor
    @echo "⚡ Quick native Sentry build completed"

# Complete native build + validation workflow
native-sentry-complete:
    @just native-sentry-verify
    @just native-sentry-build
    @just native-sentry-validate
    @echo "🎉 Native iOS Sentry SDK complete build workflow finished"

# Development workflow (build + validation)
native-sentry-dev:
    @just native-sentry-complete