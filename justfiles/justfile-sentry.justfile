# Unified Sentry SDK Build Commands for GameTwo
# Import split Sentry justfiles for modular access

# Sentry SDK paths (shared across both integration types)
SENTRY_PATH := "extras/sentry-godot"
SENTRY_ADDON_PATH := "extras/sentry-godot/project/addons/sentry"
PROJECT_SENTRY_PATH := "project/addons/sentry"
SENTRY_PROJECT_PATH := "extras/sentry-godot/project"
IOS_EXPORT_PATH := "export/ios"

# Import specialized Sentry build modules
import "justfile-native-ios-sentry.justfile"
import "justfile-native-android-sentry.justfile"
import "justfile-gdscript-sentry.justfile"
import "justfile-native-windows-sentry.justfile"

# Default Sentry build target
# Show unified Sentry build help
help-sentry:
    @echo "🔥 Sentry SDK Build Commands"
    @echo "============================"
    @echo ""
    @echo "🍎 NATIVE IOS SENTRY (BUILT-IN):"
    @echo "  just help-sentry-native-ios             # Show native iOS commands"
    @echo "  just build-sentry-native-ios-all         # Build native Sentry for iOS (debug + release)"
    @echo "  just sentry-native-ios-complete          # Complete native build + validation"
    @echo ""
    @echo "🤖 NATIVE ANDROID SENTRY (BUILT-IN):"
    @echo "  just help-native-android-sentry         # Show native Android commands"
    @echo "  just build-sentry-native-android-all     # Build native Sentry for Android (debug + release)"
    @echo "  just sentry-native-android-complete     # Complete native build + validation"
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY (RUNTIME GDEXTENSION):"
    @echo "  just help-sentry-gdscript             # Show GDScript Sentry commands"
    @echo "  just build-sentry-gdscript-all         # Build GDScript Sentry for all platforms"
    @echo "  just sentry-gdscript-complete        # Complete GDScript build + validation"
    @echo ""
    @echo "🪟 WINDOWS SENTRY DLLS (GDEXTENSION SUPPORT):"
    @echo "  just help-sentry-windows              # Show Windows DLL commands"
    @echo "  just sentry-windows-build            # Build Windows Sentry DLLs (all archs)"
    @echo "  just sentry-windows-complete         # Complete Windows build + validation"
    @echo ""
    @echo "🚀 UNIFIED WORKFLOWS:"
    @echo "  just build-sentry-all               # Build all Sentry integrations (smart rebuild)"
    @echo "  just build-sentry-all force=yes      # Force rebuild all Sentry integrations"
    @echo "  just validate-sentry-all             # Validate all Sentry integrations"
    @echo ""
    @echo "🧧 MAINTENANCE:"
    @echo "  just clean-sentry-all                # Clean all Sentry build artifacts"
    @echo "  just status-sentry-quick             # Quick status check (2 lines)"
    @echo "  just status-sentry-all               # Check status of all integrations"
    @echo ""
    @echo "ℹ️  NATIVE iOS = Built into Godot executable (crash reporting)"
    @echo "ℹ️  NATIVE ANDROID = Built into Godot executable (crash reporting)"
    @echo "ℹ️  GDSCRIPT = Runtime GDExtension (script-level functionality)"
    @echo "ℹ️  WINDOWS = Cross-compiled DLLs for Windows export support"


# Smart Sentry rebuild detection



# Unified build workflows with smart rebuild detection
build-sentry-all force="no":
    @echo "🔥 Building all Sentry SDK components with smart rebuild detection..."
    @echo ""

    @just build-sentry-native-ios-all {{force}}
    @echo ""
    @just build-sentry-native-android-all {{force}}
    @echo ""
    @just build-sentry-gdscript-all {{force}}
    @echo ""
    @just build-sentry-native-windows-release {{force}}
    @echo ""
    @just validate-sentry-all
    @echo ""
    @echo "🎉 All Sentry SDK components built and validated successfully!"

# Quick Sentry status check
status-sentry-quick:
    @echo "⚡ Quick Sentry status check..."
    @echo ""

    @echo "🍎 Native iOS Sentry:"
    @if [ -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
        echo "   ✅ Built (Sentry.xcframework)"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-all'"; \
    fi

    @echo "🎮 GDScript Sentry:"
    @if [ -f "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework/ios-arm64/libsentry.ios.release.arm64.dylib" ]; then \
        echo "   ✅ Built (libsentry.ios.release.xcframework)"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-all'"; \
    fi

    @echo "🪟 Windows Sentry:"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "   ✅ Built (Windows DLLs)"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-all'"; \
    fi

validate-sentry-all:
    @echo "🔧 Validating all Sentry integrations..."
    @echo ""
    @echo "🍎 Validating Native iOS Sentry..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just build-sentry-native-ios-all'"; \
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
            echo "❌ GDScript Sentry GDExtension not built - run 'just build-sentry-gdscript-all'"; \
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
    @echo "🪟 Validating Windows Sentry..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        echo "❌" > /tmp/windows_status; \
    else \
        if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
            echo "❌ Windows Sentry DLL not built - run 'just build-sentry-native-windows-release'"; \
            echo "❌" > /tmp/windows_status; \
        else \
            if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then \
                echo "⚠️  Windows crashpad_handler.exe missing (non-critical)"; \
                echo "✅" > /tmp/windows_status; \
            else \
                echo "✅ Windows Sentry DLL validation passed"; \
                echo "✅" > /tmp/windows_status; \
            fi; \
        fi; \
    fi
    @echo ""
    @echo "📊 Validation Summary:"
    @echo "   🍎 Native iOS Sentry: $(cat /tmp/native_status 2>/dev/null || echo '❌')"
    @echo "   🎮 GDScript Sentry: $(cat /tmp/gdscript_status 2>/dev/null || echo '❌')"
    @echo "   🪟 Windows Sentry: $(cat /tmp/windows_status 2>/dev/null || echo '❌')"
    @if [ "$(cat /tmp/native_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/gdscript_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/windows_status 2>/dev/null || echo '❌')" = "✅" ]; then \
        echo ""; \
        echo "✅ All Sentry integrations validated successfully"; \
        rm -f /tmp/native_status /tmp/gdscript_status /tmp/windows_status; \
    else \
        echo ""; \
        echo "⚠️  Some Sentry integrations need attention - see details above"; \
        rm -f /tmp/native_status /tmp/gdscript_status /tmp/windows_status; \
        exit 1; \
    fi


# Unified maintenance
clean-sentry-all:
    @echo "🧹 Cleaning all Sentry build artifacts..."
    @echo ""
    @echo "🍎 Cleaning Native iOS Sentry..."
    @just sentry-native-ios-clean
    @echo ""
    @echo "🤖 Cleaning Native Android Sentry..."
    @just sentry-native-android-clean
    @echo ""
    @echo "🎮 Cleaning GDScript Sentry..."
    @just sentry-gdscript-clean
    @echo ""
    @echo "🪟 Cleaning Windows Sentry..."
    @just sentry-windows-clean
    @echo ""
    @echo "✅ All Sentry build artifacts cleaned"

status-sentry-all:
    @echo "📊 Sentry integration status report"
    @echo "================================"
    @echo ""
    @echo "🍎 NATIVE iOS SENTRY STATUS:"
    @just sentry-native-ios-status
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY STATUS:"
    @just sentry-gdscript-status
    @echo ""
    @echo "🪟 WINDOWS SENTRY STATUS:"
    @just sentry-windows-status