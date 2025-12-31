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
    @echo "📤 DEBUG SYMBOL UPLOAD (Crash Symbolication):"
    @echo "  just sentry-upload-symbols-all           # Upload all debug symbols"
    @echo "  just sentry-upload-symbols-ios           # Upload iOS debug symbols"
    @echo "  just sentry-upload-symbols-macos         # Upload macOS debug symbols"
    @echo "  just sentry-upload-symbols-android       # Upload Android debug symbols"
    @echo "  just sentry-upload-symbols-windows       # Upload Windows debug symbols"
    @echo "  just sentry-symbols-status                # Check debug symbol configuration"
    @echo ""
    @echo "ℹ️  NATIVE Sentry = Compiled INTO Godot executable (C++ crash capture)"
    @echo "ℹ️  GDScript Sentry = Runtime GDExtension (script-level crash capture)"
    @echo "ℹ️  You need BOTH for complete crash reporting coverage"
    @echo "ℹ️  Upload dSYMs to enable symbolicated crash reports in Sentry"


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

# =============================================================================
# dSYM Upload to Sentry (Crash Symbolication)
# =============================================================================
# Requires: sentry-cli installed and configured
# Install: brew install getsentry/tools/sentry-cli
# Configure: Create .sentryclirc with auth token, org, and project
#            Or set SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT env vars

# Debug symbol paths (dSYM for Apple, .so.debug for Android, .pdb for Windows)
DSYM_IOS_PATH := "project/addons/sentry/bin/ios/dSYMs"
DSYM_MACOS_PATH := "project/addons/sentry/bin/macos/dSYMs"
DEBUG_ANDROID_PATH := "project/addons/sentry/bin/android"
DEBUG_WINDOWS_PATH := "project/addons/sentry/bin/windows/x86_64"

# Upload iOS debug symbols to Sentry for crash symbolication
sentry-upload-symbols-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Uploading iOS debug symbols to Sentry..."

    if ! command -v sentry-cli &> /dev/null; then
        echo "❌ sentry-cli not found. Install with: brew install getsentry/tools/sentry-cli"
        exit 1
    fi

    if [ ! -d "{{DSYM_IOS_PATH}}" ]; then
        echo "❌ iOS debug symbols not found at {{DSYM_IOS_PATH}}"
        echo "   Run 'just build-sentry-gdscript-ios' first"
        exit 1
    fi

    echo "📦 Debug symbol location: {{DSYM_IOS_PATH}}"
    ls -la "{{DSYM_IOS_PATH}}/"
    echo ""

    sentry-cli debug-files upload --include-sources "{{DSYM_IOS_PATH}}/"

    echo "✅ iOS debug symbols uploaded to Sentry"

# Upload macOS debug symbols to Sentry for crash symbolication
sentry-upload-symbols-macos:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🍎 Uploading macOS debug symbols to Sentry..."

    if ! command -v sentry-cli &> /dev/null; then
        echo "❌ sentry-cli not found. Install with: brew install getsentry/tools/sentry-cli"
        exit 1
    fi

    if [ ! -d "{{DSYM_MACOS_PATH}}" ]; then
        echo "❌ macOS debug symbols not found at {{DSYM_MACOS_PATH}}"
        echo "   Run 'just build-sentry-gdscript-macos' first"
        exit 1
    fi

    echo "📦 Debug symbol location: {{DSYM_MACOS_PATH}}"
    ls -la "{{DSYM_MACOS_PATH}}/"
    echo ""

    sentry-cli debug-files upload --include-sources "{{DSYM_MACOS_PATH}}/"

    echo "✅ macOS debug symbols uploaded to Sentry"

# Upload Android debug symbols to Sentry for crash symbolication
sentry-upload-symbols-android:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🤖 Uploading Android debug symbols to Sentry..."

    if ! command -v sentry-cli &> /dev/null; then
        echo "❌ sentry-cli not found. Install with: brew install getsentry/tools/sentry-cli"
        exit 1
    fi

    if [ ! -d "{{DEBUG_ANDROID_PATH}}" ]; then
        echo "❌ Android debug symbols not found at {{DEBUG_ANDROID_PATH}}"
        echo "   Run 'just build-sentry-gdscript-android' first"
        exit 1
    fi

    # Check for .so.debug files
    debug_files=$(find "{{DEBUG_ANDROID_PATH}}" -name "*.so.debug" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$debug_files" -eq 0 ]; then
        echo "❌ No .so.debug files found in {{DEBUG_ANDROID_PATH}}"
        exit 1
    fi

    echo "📦 Debug symbol location: {{DEBUG_ANDROID_PATH}}"
    ls -la "{{DEBUG_ANDROID_PATH}}/"*.so.debug 2>/dev/null || true
    echo ""

    sentry-cli debug-files upload --include-sources "{{DEBUG_ANDROID_PATH}}/"

    echo "✅ Android debug symbols uploaded to Sentry"

# Upload Windows debug symbols (PDB files) to Sentry for crash symbolication
# NOTE: PDB files must be copied from Windows VM during build process
sentry-upload-symbols-windows:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🪟 Uploading Windows debug symbols to Sentry..."

    if ! command -v sentry-cli &> /dev/null; then
        echo "❌ sentry-cli not found. Install with: brew install getsentry/tools/sentry-cli"
        exit 1
    fi

    if [ ! -d "{{DEBUG_WINDOWS_PATH}}" ]; then
        echo "❌ Windows debug symbols not found at {{DEBUG_WINDOWS_PATH}}"
        echo "   Run 'just build-sentry-gdscript-windows' first"
        exit 1
    fi

    # Check for .pdb files
    pdb_files=$(find "{{DEBUG_WINDOWS_PATH}}" -name "*.pdb" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pdb_files" -eq 0 ]; then
        echo "⚠️  No .pdb files found in {{DEBUG_WINDOWS_PATH}}"
        echo ""
        echo "   Windows PDB files are generated on the VM during build but"
        echo "   are not currently copied to the Mac. To enable Windows crash"
        echo "   symbolication, the VM build process needs to be updated to"
        echo "   copy PDB files alongside DLLs."
        echo ""
        echo "   For now, you can manually copy PDB files from the VM:"
        echo "   scp matt@192.168.50.92:C:/Users/matt/repos/gametwo/extras/sentry-godot/build/*.pdb {{DEBUG_WINDOWS_PATH}}/"
        exit 1
    fi

    echo "📦 Debug symbol location: {{DEBUG_WINDOWS_PATH}}"
    ls -la "{{DEBUG_WINDOWS_PATH}}/"*.pdb 2>/dev/null || true
    echo ""

    sentry-cli debug-files upload --include-sources "{{DEBUG_WINDOWS_PATH}}/"

    echo "✅ Windows debug symbols uploaded to Sentry"

# Upload all debug symbols (iOS + macOS + Android + Windows) to Sentry
sentry-upload-symbols-all:
    @echo "📤 Uploading all debug symbols to Sentry..."
    @echo ""
    @just sentry-upload-symbols-ios
    @echo ""
    @just sentry-upload-symbols-macos
    @echo ""
    @just sentry-upload-symbols-android
    @echo ""
    @just sentry-upload-symbols-windows
    @echo ""
    @echo "🎉 All debug symbols uploaded to Sentry successfully!"

# Check debug symbol upload status and configuration
sentry-symbols-status:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📊 Sentry Debug Symbol Status"
    echo "============================="
    echo ""

    # Check sentry-cli installation
    echo "🔧 sentry-cli:"
    if command -v sentry-cli &> /dev/null; then
        echo "   ✅ Installed ($(sentry-cli --version))"
    else
        echo "   ❌ Not installed"
        echo "   Install: brew install getsentry/tools/sentry-cli"
    fi
    echo ""

    # Check configuration
    echo "🔑 Configuration:"
    if [ -f ".sentryclirc" ]; then
        echo "   ✅ .sentryclirc found"
    elif [ -n "${SENTRY_AUTH_TOKEN:-}" ]; then
        echo "   ✅ SENTRY_AUTH_TOKEN env var set"
    else
        echo "   ❌ No configuration found"
        echo "   Create .sentryclirc or set SENTRY_AUTH_TOKEN env var"
    fi

    if [ -n "${SENTRY_ORG:-}" ]; then
        echo "   ✅ SENTRY_ORG: ${SENTRY_ORG}"
    elif [ -f ".sentryclirc" ] && grep -q "org=" ".sentryclirc" 2>/dev/null; then
        echo "   ✅ org configured in .sentryclirc"
    else
        echo "   ⚠️  SENTRY_ORG not set"
    fi

    if [ -n "${SENTRY_PROJECT:-}" ]; then
        echo "   ✅ SENTRY_PROJECT: ${SENTRY_PROJECT}"
    elif [ -f ".sentryclirc" ] && grep -q "project=" ".sentryclirc" 2>/dev/null; then
        echo "   ✅ project configured in .sentryclirc"
    else
        echo "   ⚠️  SENTRY_PROJECT not set"
    fi
    echo ""

    # Check dSYM files
    echo "📦 iOS dSYMs ({{DSYM_IOS_PATH}}):"
    if [ -d "{{DSYM_IOS_PATH}}" ]; then
        count=$(find "{{DSYM_IOS_PATH}}" -name "*.dSYM" -type d | wc -l | tr -d ' ')
        size=$(du -sh "{{DSYM_IOS_PATH}}" 2>/dev/null | cut -f1)
        echo "   ✅ Found ($count dSYM bundles, $size)"
    else
        echo "   ❌ Not found"
    fi
    echo ""

    echo "📦 macOS dSYMs ({{DSYM_MACOS_PATH}}):"
    if [ -d "{{DSYM_MACOS_PATH}}" ]; then
        count=$(find "{{DSYM_MACOS_PATH}}" -name "*.dSYM" -type d | wc -l | tr -d ' ')
        size=$(du -sh "{{DSYM_MACOS_PATH}}" 2>/dev/null | cut -f1)
        echo "   ✅ Found ($count dSYM bundles, $size)"
    else
        echo "   ❌ Not found"
    fi
    echo ""

    echo "📦 Android debug symbols ({{DEBUG_ANDROID_PATH}}):"
    if [ -d "{{DEBUG_ANDROID_PATH}}" ]; then
        count=$(find "{{DEBUG_ANDROID_PATH}}" -name "*.so.debug" 2>/dev/null | wc -l | tr -d ' ')
        size=$(du -sh "{{DEBUG_ANDROID_PATH}}" 2>/dev/null | cut -f1)
        if [ "$count" -gt 0 ]; then
            echo "   ✅ Found ($count .so.debug files, $size total)"
        else
            echo "   ⚠️  Directory exists but no .so.debug files found"
        fi
    else
        echo "   ❌ Not found"
    fi
    echo ""

    echo "📦 Windows debug symbols ({{DEBUG_WINDOWS_PATH}}):"
    if [ -d "{{DEBUG_WINDOWS_PATH}}" ]; then
        count=$(find "{{DEBUG_WINDOWS_PATH}}" -name "*.pdb" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            size=$(du -sh "{{DEBUG_WINDOWS_PATH}}"/*.pdb 2>/dev/null | cut -f1 | tail -1)
            echo "   ✅ Found ($count .pdb files)"
        else
            echo "   ⚠️  No .pdb files (PDBs generated on VM, not copied to Mac)"
            echo "      Run 'just sentry-upload-symbols-windows' for instructions"
        fi
    else
        echo "   ❌ Not found"
    fi