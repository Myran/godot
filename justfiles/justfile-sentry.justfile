# Unified Sentry SDK Build Commands for GameTwo
# Import split Sentry justfiles for modular access

# Sentry SDK paths (shared across both integration types)
SENTRY_PATH := "extras/sentry-godot"
SENTRY_ADDON_PATH := "extras/sentry-godot/project/addons/sentry"
SENTRY_PROJECT_PATH := "extras/sentry-godot/project"
IOS_EXPORT_PATH := "export/ios"

# Import specialized Sentry build modules
import "justfile-native-ios-sentry.justfile"
import "justfile-gdscript-sentry.justfile"

# Default Sentry build target
default-sentry:
    @echo "🎯 Unified Sentry SDK Build Commands for GameTwo"
    @echo ""
    @echo "🔥 Sentry Integration Options:"
    @echo "  🍎 Native iOS Sentry (built into Godot executable)"
    @echo "  🎮 GDScript Sentry (runtime GDExtension)"
    @echo ""
    @just help-sentry

# Show unified Sentry build help
help-sentry:
    @echo "🔥 Sentry SDK Build Commands"
    @echo "============================"
    @echo ""
    @echo "🍎 NATIVE iOS SENTRY (BUILT-IN):"
    @echo "  just sentry-native-ios-help              # Show native iOS commands"
    @echo "  just sentry-native-ios-build              # Build native Sentry for iOS"
    @echo "  just sentry-native-ios-complete          # Complete native build + validation"
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY (RUNTIME GDEXTENSION):"
    @echo "  just sentry-gdscript-help            # Show GDScript Sentry commands"
    @echo "  just sentry-gdscript-build            # Build GDScript Sentry for all platforms"
    @echo "  just sentry-gdscript-complete        # Complete GDScript build + validation"
    @echo ""
    @echo "🚀 UNIFIED WORKFLOWS:"
    @echo "  just sentry-build-all               # Build both native iOS and GDScript Sentry"
    @echo "  just sentry-validate-all             # Validate both Sentry integrations"
    @echo "  just sentry-complete                # Complete build + validation for both"
    @echo "  just sentry-dev                     # Development workflow (build + validate both)"
    @echo ""
    @echo "🧧 MAINTENANCE:"
    @echo "  just sentry-clean-all                # Clean all Sentry build artifacts"
    @echo "  just sentry-status-all               # Check status of both integrations"
    @echo ""
    @echo "ℹ️  NATIVE iOS = Built into Godot executable (crash reporting)"
    @echo "ℹ️  GDSCRIPT = Runtime GDExtension (script-level functionality)"

# Show native iOS Sentry help
sentry-native-ios-help:
    @just help-sentry-native-ios

# Show GDScript Sentry help
sentry-gdscript-help:
    @just help-sentry-gdscript

# Unified build workflows
sentry-build-all:
    @echo "🔥 Building both Sentry integrations..."
    @echo ""
    @echo "🍎 Building Native iOS Sentry..."
    @just native-sentry-build
    @echo ""
    @echo "🎮 Building GDScript Sentry for iOS..."
    @just sentry-gdscript-build-ios
    @echo ""
    @echo "✅ All Sentry integrations built successfully"

sentry-validate-all:
    @echo "🔧 Validating both Sentry integrations..."
    @echo ""
    @echo "🍎 Validating Native iOS Sentry..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just native-sentry-build'"; \
        echo "❌" > /tmp/native_status; \
    else \
        if [ ! -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
            echo "❌ Native Sentry SDK binary missing"; \
            echo "❌" > /tmp/native_status; \
        else \
            echo "✅ Native Sentry SDK validation passed"; \
            echo "✅" > /tmp/native_status; \
        fi; \
    fi
    @echo ""
    @echo "🎮 Validating GDScript Sentry..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        echo "❌" > /tmp/gdscript_status; \
    else \
        if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then \
            echo "❌ GDScript Sentry GDExtension not built - run 'just sentry-gdscript-build'"; \
            echo "❌" > /tmp/gdscript_status; \
        else \
            if [ ! -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
                echo "❌ GDScript Sentry GDExtension binary missing"; \
                echo "❌" > /tmp/gdscript_status; \
            else \
                echo "✅ GDScript Sentry SDK validation passed"; \
                echo "✅" > /tmp/gdscript_status; \
            fi; \
        fi; \
    fi
    @echo ""
    @echo "📊 Validation Summary:"
    @echo "   🍎 Native iOS Sentry: $(cat /tmp/native_status)"
    @echo "   🎮 GDScript Sentry: $(cat /tmp/gdscript_status)"
    @if [ "$(cat /tmp/native_status)" = "✅" ] && [ "$(cat /tmp/gdscript_status)" = "✅" ]; then \
        echo ""; \
        echo "✅ All Sentry integrations validated successfully"; \
        rm -f /tmp/native_status /tmp/gdscript_status; \
    else \
        echo ""; \
        echo "⚠️  Some Sentry integrations need attention - see details above"; \
        rm -f /tmp/native_status /tmp/gdscript_status; \
        exit 1; \
    fi

sentry-complete:
    @echo "🚀 Complete Sentry build and validation workflow..."
    @echo ""
    @just sentry-build-all
    @echo ""
    @just sentry-validate-all
    @echo ""
    @echo "🎉 Complete Sentry workflow finished successfully"

# Development workflow
sentry-dev:
    @echo "🔧 Sentry development workflow..."
    @echo ""
    @just sentry-complete

# Unified maintenance
sentry-clean-all:
    @echo "🧹 Cleaning all Sentry build artifacts..."
    @echo ""
    @echo "🍎 Cleaning Native iOS Sentry..."
    @just native-sentry-clean
    @echo ""
    @echo "🎮 Cleaning GDScript Sentry..."
    @just sentry-gdscript-clean
    @echo ""
    @echo "✅ All Sentry build artifacts cleaned"

sentry-status-all:
    @echo "📊 Sentry integration status report"
    @echo "================================"
    @echo ""
    @echo "🍎 NATIVE iOS SENTRY STATUS:"
    @just native-sentry-status
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY STATUS:"
    @just sentry-gdscript-status