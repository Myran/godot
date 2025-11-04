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
    @echo "  just sentry-build-all               # Build both native iOS and GDScript Sentry (smart rebuild)"
    @echo "  just sentry-build-all yes           # Force rebuild both Sentry integrations"
    @echo "  just sentry-validate-all             # Validate both Sentry integrations"
    @echo "  just sentry-complete                # Complete build + validation for both"
    @echo ""
    @echo "🧧 MAINTENANCE:"
    @echo "  just sentry-clean-all                # Clean all Sentry build artifacts"
    @echo "  just sentry-status-quick             # Quick status check (2 lines)"
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

# Smart Sentry rebuild detection
_check-or-build-sentry-native-ios force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🍎 Checking Native iOS Sentry SDK..."

    if [ "{{force}}" = "yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding Native iOS Sentry..."
        just sentry-native-ios-build
    elif [ -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then
        echo "✅ Native iOS Sentry already built:"
        echo "   📱 {{IOS_EXPORT_PATH}}/Sentry.xcframework"
        echo "⏭️  Skipping Native iOS Sentry rebuild (saves 2-5 minutes)"
    else
        echo "🔧 Building Native iOS Sentry (this will take 2-5 minutes)..."
        just sentry-native-ios-build
    fi

_check-or-build-sentry-gdscript force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🎮 Checking GDScript Sentry SDK..."

    if [ "{{force}}" = "yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding GDScript Sentry..."
        just sentry-gdscript-build
    elif [ -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then
        echo "✅ GDScript Sentry already built:"
        echo "   📱 {{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework"
        echo "   📱 {{IOS_EXPORT_PATH}}/libsentry.ios.debug.xcframework"
        echo "⏭️  Skipping GDScript Sentry rebuild (saves 3-8 minutes)"
    else
        echo "🔧 Building GDScript Sentry (this will take 3-8 minutes)..."
        just sentry-gdscript-build
    fi

# Unified build workflows with smart rebuild detection
sentry-build-all force="no":
    @echo "🔥 Building all Sentry SDK components with smart rebuild detection..."
    @echo ""

    @just _check-or-build-sentry-native-ios {{force}}
    @echo ""
    @just _check-or-build-sentry-gdscript {{force}}
    @echo ""
    @just sentry-validate-all
    @echo ""
    @echo "🎉 All Sentry SDK components built and validated successfully!"

# Quick Sentry status check
sentry-status-quick:
    @echo "⚡ Quick Sentry status check..."
    @echo ""

    @echo "🍎 Native iOS Sentry:"
    @if [ -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
        echo "   ✅ Built (Sentry.xcframework)"; \
    else \
        echo "   ❌ Not built - run 'just sentry-build-all'"; \
    fi

    @echo "🎮 GDScript Sentry:"
    @if [ -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
        echo "   ✅ Built (libsentry.ios.release.xcframework)"; \
    else \
        echo "   ❌ Not built - run 'just sentry-build-all'"; \
    fi

sentry-validate-all:
    @echo "🔧 Validating both Sentry integrations..."
    @echo ""
    @echo "🍎 Validating Native iOS Sentry..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just sentry-native-ios-build'"; \
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


# Unified maintenance
sentry-clean-all:
    @echo "🧹 Cleaning all Sentry build artifacts..."
    @echo ""
    @echo "🍎 Cleaning Native iOS Sentry..."
    @just sentry-native-ios-clean
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
    @just sentry-native-ios-status
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY STATUS:"
    @just sentry-gdscript-status