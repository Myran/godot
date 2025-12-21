# Windows Sentry GDExtension Build Commands for GameTwo
# =====================================================
# Builds sentry-godot GDExtension with crashpad backend using native MSVC on Windows VM.
# The crashpad backend provides out-of-process crash capture for reliable crash reporting.
#
# Architecture:
# - Build happens on Windows VM (192.168.50.92) via SSH
# - Uses SCons which internally calls CMake for sentry-native with crashpad
# - ARM64→x64 cross-compilation supported via SENTRY_WIN_X64_TOOLCHAIN
# - Results are copied back to macOS development machine
#
# Key files:
# - justfile-windows-native.justfile: Runs ON Windows (SCons build commands)
# - justfile-platform-windows.justfile: VM orchestration (SSH, file copy)
# - This file: Help and status commands for macOS

# Show Windows Sentry build help
help-sentry-windows:
    @echo "🪟 Windows Sentry GDExtension Build Commands"
    @echo "============================================="
    @echo ""
    @echo "🔧 VM BUILD COMMANDS (from macOS):"
    @echo "  just sentry-windows-vm-build-all      # Build release + debug on VM"
    @echo "  just sentry-windows-vm-package       # Copy built DLLs from VM to macOS"
    @echo "  just sentry-windows-vm-complete      # Full workflow: build + package"
    @echo ""
    @echo "🔧 DIRECT WINDOWS COMMANDS (run ON Windows VM):"
    @echo "  just windows-native-sentry-release  # Build release GDExtension"
    @echo "  just windows-native-sentry-debug    # Build debug GDExtension"
    @echo "  just windows-native-sentry-all      # Build both variants"
    @echo "  just windows-native-sentry-clean    # Clean build artifacts"
    @echo ""
    @echo "📊 STATUS & VALIDATION:"
    @echo "  just sentry-windows-status          # Check build status"
    @echo "  just sentry-windows-validate        # Validate DLL integration"
    @echo ""
    @echo "🧹 MAINTENANCE:"
    @echo "  just sentry-windows-clean           # Clean local build artifacts"
    @echo ""
    @echo "ℹ️  ARCHITECTURE:"
    @echo "   • Uses SCons + MSVC for proper GDExtension with gdextension_init"
    @echo "   • Crashpad backend for out-of-process crash capture"
    @echo "   • ARM64→x64 cross-compilation via toolchain file"

# Check build status
sentry-windows-status:
    @echo "📊 Windows Sentry GDExtension Build Status"
    @echo "==========================================="
    @echo ""
    @echo "📂 Release DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "   ✅ Built"; \
        ls -lh "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" | awk '{print "   Size:", $5, " Modified:", $6, $7, $8}'; \
    else \
        echo "   ❌ Not built"; \
    fi
    @echo ""
    @echo "📂 Debug DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll" ]; then \
        echo "   ✅ Built"; \
        ls -lh "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll" | awk '{print "   Size:", $5, " Modified:", $6, $7, $8}'; \
    else \
        echo "   ❌ Not built"; \
    fi
    @echo ""
    @echo "📂 Crashpad Handler: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then \
        echo "   ✅ Present (crashpad backend enabled)"; \
        ls -lh "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" | awk '{print "   Size:", $5, " Modified:", $6, $7, $8}'; \
    else \
        echo "   ❌ Missing (crashpad backend will not work)"; \
    fi
    @echo ""
    @echo "📂 WER DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_wer.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_wer.dll" ]; then \
        echo "   ✅ Present (Windows Error Reporting integration)"; \
    else \
        echo "   ⚠️  Missing (optional, WER integration disabled)"; \
    fi

# Validate Windows DLL integration
sentry-windows-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Validating Windows Sentry GDExtension integration..."
    echo ""

    ERRORS=0

    # Check GDExtension file
    if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then
        echo "❌ Sentry GDExtension config not found"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ Sentry GDExtension config found"
    fi

    # Check release DLL
    if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then
        echo "❌ Windows release DLL not built"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ Windows release DLL present"
        # Verify it has gdextension_init symbol
        if command -v nm &> /dev/null; then
            if nm "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" 2>/dev/null | grep -q "gdextension_init"; then
                echo "   ✅ Has gdextension_init entry point"
            else
                echo "   ⚠️  Cannot verify gdextension_init (nm may not work on Windows DLLs)"
            fi
        fi
    fi

    # Check debug DLL
    if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll" ]; then
        echo "❌ Windows debug DLL not built"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ Windows debug DLL present"
    fi

    # Check crashpad handler (required for crashpad backend)
    if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then
        echo "❌ crashpad_handler.exe missing (required for crash reporting)"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ crashpad_handler.exe present"
    fi

    echo ""
    if [ $ERRORS -eq 0 ]; then
        echo "✅ Windows Sentry GDExtension validation passed"
    else
        echo "❌ Validation failed with $ERRORS error(s)"
        echo "   Run 'just sentry-windows-vm-complete' to build"
        exit 1
    fi

# Clean local build artifacts
sentry-windows-clean:
    @echo "🧹 Cleaning Windows Sentry local artifacts..."
    @rm -rf {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/*.dll
    @rm -rf {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/*.exe
    @echo "✅ Windows Sentry local artifacts cleaned"
    @echo ""
    @echo "ℹ️  To clean VM build artifacts, run on Windows:"
    @echo "   just windows-native-sentry-clean"
