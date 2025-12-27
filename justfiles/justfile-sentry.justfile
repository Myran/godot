# Unified Sentry SDK Build Commands for GameTwo
# Import split Sentry justfiles for modular access

# Sentry SDK version (used for submodule and GDExtension downloads)
# Update this when upgrading sentry-godot
SENTRY_VERSION := "1.2.0"
SENTRY_GDEXT_COMMIT := "241f16b"  # Commit hash in GDExtension release filename

# Sentry SDK paths (shared across both integration types)
SENTRY_PATH := "extras/sentry-godot"
SENTRY_ADDON_PATH := "extras/sentry-godot/project/addons/sentry"
PROJECT_SENTRY_PATH := "project/addons/sentry"
SENTRY_PROJECT_PATH := "extras/sentry-godot/project"
IOS_EXPORT_PATH := "export/ios"
SENTRY_GDEXT_DIR := "extras/sentry-godot-gdextension-" + SENTRY_VERSION + "+" + SENTRY_GDEXT_COMMIT

# Import specialized Sentry build modules
import "justfile-native-ios-sentry.justfile"
import "justfile-native-android-sentry.justfile"
import "justfile-native-macos-sentry.justfile"
import "justfile-native-windows-template-sentry.justfile"
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
    @echo "🍎 NATIVE MACOS SENTRY (BUILT-IN):"
    @echo "  just help-sentry-native-macos            # Show native macOS commands"
    @echo "  just build-sentry-native-macos-all       # Build native Sentry for macOS (debug + release)"
    @echo "  just sentry-native-macos-complete        # Complete native build + validation"
    @echo ""
    @echo "🪟 NATIVE WINDOWS SENTRY (BUILT-IN):"
    @echo "  just help-sentry-native-windows          # Show native Windows commands"
    @echo "  just build-sentry-native-windows-all     # Build native Sentry for Windows (debug + release)"
    @echo "  just sentry-native-windows-complete      # Complete native build + validation"
    @echo ""
    @echo "🎮 GDSCRIPT SENTRY (RUNTIME GDEXTENSION):"
    @echo "  just help-sentry-gdscript                # Show GDScript Sentry commands"
    @echo "  just build-sentry-gdscript-all           # Build GDScript Sentry for all platforms"
    @echo "  just sentry-gdscript-complete            # Complete GDScript build + validation"
    @echo ""
    @echo "🪟 WINDOWS GDEXTENSION (VM BUILD):"
    @echo "  just build-sentry-gdscript-windows       # Build Windows GDExtension (via VM)"
    @echo "  just build-sentry-native-windows-vm-complete  # Build + package GDExtension"
    @echo ""
    @echo "🚀 UNIFIED WORKFLOWS:"
    @echo "  just build-sentry-all                   # Build all Sentry integrations (smart rebuild)"
    @echo "  just build-sentry-all force=yes          # Force rebuild all Sentry integrations"
    @echo "  just validate-sentry-all                 # Validate all Sentry integrations"
    @echo ""
    @echo "🧧 MAINTENANCE:"
    @echo "  just clean-sentry-all                    # Clean all Sentry build artifacts"
    @echo "  just status-sentry-quick                 # Quick status check (2 lines)"
    @echo "  just status-sentry-all                   # Check status of all integrations"
    @echo ""
    @echo "ℹ️  NATIVE Sentry = Compiled INTO Godot executable (C++ crash capture)"
    @echo "ℹ️  GDScript Sentry = Runtime GDExtension (script-level crash capture)"
    @echo "ℹ️  You need BOTH for complete crash reporting coverage"


# Smart Sentry rebuild detection



# Unified build workflows with smart rebuild detection
build-sentry-all force="no":
    @echo "🔥 Building all Sentry SDK components with smart rebuild detection..."
    @echo ""

    @just build-sentry-native-ios-all {{force}}
    @echo ""
    @just build-sentry-native-android-all {{force}}
    @echo ""
    @just build-sentry-native-macos-all {{force}}
    @echo ""
    @just build-sentry-native-windows-all {{force}}
    @echo ""
    @just build-sentry-gdscript-all
    @echo ""
    @just validate-sentry-all
    @echo ""
    @echo "🎉 All Sentry SDK components built and validated successfully!"

# Build Windows Sentry on VM with crashpad backend (MSVC native)
build-sentry-windows-vm force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Windows Sentry DLL already exists and crashpad_handler is present
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && \
       [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ] && \
       [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then
        echo "✅ Windows Sentry (crashpad) already built"
        echo "   Use 'just build-sentry-windows-vm force=yes' to rebuild"
        exit 0
    fi

    echo "🪟 Building Windows Sentry with crashpad backend on VM..."
    just build-sentry-native-windows-vm-complete

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
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ] && \
       [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then \
        echo "   ✅ Built (crashpad backend)"; \
    elif [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "   ⚠️  DLL built but crashpad_handler.exe missing - run 'just build-sentry-windows-vm force=yes'"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-windows-vm'"; \
    fi

validate-sentry-all:
    @echo "🔧 Validating all Sentry integrations..."
    @echo ""
    @echo "🍎 Validating Native iOS Sentry..."
    @if [ ! -d "{{IOS_EXPORT_PATH}}/Sentry.xcframework" ]; then \
        echo "❌ Native Sentry SDK not built - run 'just build-sentry-native-ios-all'"; \
        echo "❌" > /tmp/native_ios_status; \
    else \
        if [ ! -f "{{IOS_EXPORT_PATH}}/Sentry.xcframework/ios-arm64/Sentry.framework/Sentry" ]; then \
            echo "❌ Native Sentry SDK binary missing"; \
            echo "❌" > /tmp/native_ios_status; \
        else \
            echo "✅ Native Sentry SDK validation passed"; \
            echo "✅" > /tmp/native_ios_status; \
        fi; \
    fi
    @echo ""
    @echo "🤖 Validating Native Android Sentry..."
    @if [ ! -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.android.template_release.arm64.a" ]; then \
        echo "❌ Native Android Sentry not built - run 'just build-sentry-native-android-all'"; \
        echo "❌" > /tmp/native_android_status; \
    else \
        echo "✅ Native Android Sentry validation passed"; \
        echo "✅" > /tmp/native_android_status; \
    fi
    @echo ""
    @echo "🍎 Validating Native macOS Sentry..."
    @if [ ! -f "{{SENTRY_PATH}}/modules/godot-cpp/bin/libgodot-cpp.macos.template_release.universal.a" ]; then \
        echo "❌ Native macOS Sentry not built - run 'just build-sentry-native-macos-all'"; \
        echo "❌" > /tmp/native_macos_status; \
    else \
        echo "✅ Native macOS Sentry validation passed"; \
        echo "✅" > /tmp/native_macos_status; \
    fi
    @echo ""
    @echo "🪟 Validating Native Windows Sentry..."
    @if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_release.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then \
        echo "✅ Native Windows Sentry validation passed"; \
        echo "✅" > /tmp/native_windows_status; \
    else \
        echo "❌ Native Windows Sentry not built - run 'just build-sentry-native-windows-all'"; \
        echo "❌" > /tmp/native_windows_status; \
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
    @echo "📊 Validation Summary:"
    @echo "   🍎 Native iOS Sentry: $(cat /tmp/native_ios_status 2>/dev/null || echo '❌')"
    @echo "   🤖 Native Android Sentry: $(cat /tmp/native_android_status 2>/dev/null || echo '❌')"
    @echo "   🍎 Native macOS Sentry: $(cat /tmp/native_macos_status 2>/dev/null || echo '❌')"
    @echo "   🪟 Native Windows Sentry: $(cat /tmp/native_windows_status 2>/dev/null || echo '❌')"
    @echo "   🎮 GDScript Sentry: $(cat /tmp/gdscript_status 2>/dev/null || echo '❌')"
    @if [ "$(cat /tmp/native_ios_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/native_android_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/native_macos_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/native_windows_status 2>/dev/null || echo '❌')" = "✅" ] && [ "$(cat /tmp/gdscript_status 2>/dev/null || echo '❌')" = "✅" ]; then \
        echo ""; \
        echo "✅ All Sentry integrations validated successfully"; \
        rm -f /tmp/native_ios_status /tmp/native_android_status /tmp/native_macos_status /tmp/native_windows_status /tmp/gdscript_status; \
    else \
        echo ""; \
        echo "⚠️  Some Sentry integrations need attention - see details above"; \
        rm -f /tmp/native_ios_status /tmp/native_android_status /tmp/native_macos_status /tmp/native_windows_status /tmp/gdscript_status; \
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
    @echo "🍎 Cleaning Native macOS Sentry..."
    @just sentry-native-macos-clean
    @echo ""
    @echo "🪟 Cleaning Native Windows Sentry..."
    @just sentry-native-windows-clean
    @echo ""
    @echo "🎮 Cleaning GDScript Sentry (all platforms)..."
    @just sentry-gdscript-clean-all
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