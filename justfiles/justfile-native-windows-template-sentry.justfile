# Native Windows Sentry Build Commands for GameTwo
# Built-in to Godot executable via SCons compilation (runs on Windows VM)
#
# This is DIFFERENT from the GDExtension builds:
# - Native Sentry: Compiled INTO Godot template executable (captures C++ crashes)
# - GDExtension: Runtime-loaded DLL (captures script-level crashes)
#
# Both should be used for complete crash reporting coverage.

# Windows VM connection details (from core config)
# WIN_VM_HOST, WIN_VM_USER, WIN_VM_VCVARS, WIN_VM_REPO defined in justfile-core-config.justfile

# Show Native Windows Sentry build help
help-sentry-native-windows:
    @echo "🪟 Native Windows Sentry SDK Build Commands"
    @echo "=========================================="
    @echo ""
    @echo "📝 NATIVE VS GDEXTENSION:"
    @echo "   • Native: Compiled INTO Godot executable (C++ crash capture)"
    @echo "   • GDExtension: Runtime-loaded DLL (script-level crash capture)"
    @echo "   • You need BOTH for complete crash reporting"
    @echo ""
    @echo "🏗️  NATIVE WINDOWS TEMPLATE BUILDS (via VM):"
    @echo "   just build-sentry-native-windows-all        # Build native Sentry for Windows (debug + release)"
    @echo "   just build-sentry-native-windows-debug     # Build native Sentry for Windows debug template"
    @echo "   just build-sentry-native-windows-release   # Build native Sentry for Windows release template"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "   just sentry-native-windows-complete        # Complete native build + validation"
    @echo ""
    @echo "📊 STATUS & VALIDATION:"
    @echo "   just sentry-native-windows-status          # Check build status"
    @echo "   just sentry-native-windows-validate        # Validate integration"
    @echo ""
    @echo "ℹ️  These run on Windows VM ({{WIN_VM_HOST}}) via SSH"

# Native Windows Sentry builds (compiled into Godot executable)
build-sentry-native-windows-all force="no":
    just build-sentry-native-windows-debug {{force}}
    just build-sentry-native-windows-release {{force}}
    @echo "✅ Native Windows Sentry builds completed"

build-sentry-native-windows-debug force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if already built on VM (static library marker - .lib for Windows MSVC)
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ]; then
        if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_debug.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then
            echo "✅ Native Sentry Windows debug already built"
            echo "   Use 'just build-sentry-native-windows-debug force=yes' to rebuild"
            exit 0
        fi
    fi

    echo "🏗️  Building Native Sentry for Windows debug template (via VM)..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && cd extras/sentry-godot && scons platform=windows target=template_debug arch=x86_64'
    echo "✅ Native Sentry Windows debug build completed"

build-sentry-native-windows-release force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if already built on VM (static library marker - .lib for Windows MSVC)
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ]; then
        if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_release.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then
            echo "✅ Native Sentry Windows release already built"
            echo "   Use 'just build-sentry-native-windows-release force=yes' to rebuild"
            exit 0
        fi
    fi

    echo "🏗️  Building Native Sentry for Windows release template (via VM)..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && cd extras/sentry-godot && scons platform=windows target=template_release arch=x86_64'
    echo "✅ Native Sentry Windows release build completed"

# Complete native build + validation
sentry-native-windows-complete: build-sentry-native-windows-all sentry-native-windows-validate
    @echo "✅ Native Windows Sentry complete with validation"

# Check build status (queries VM for .lib files - MSVC format)
sentry-native-windows-status:
    @echo "📊 Native Windows Sentry Build Status"
    @echo "===================================="
    @echo ""
    @echo "Debug template:"
    @if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_debug.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then \
        echo "   ✅ Built (libgodot-cpp.windows.template_debug.x86_64.lib on VM)"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-native-windows-debug'"; \
    fi
    @echo ""
    @echo "Release template:"
    @if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_release.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then \
        echo "   ✅ Built (libgodot-cpp.windows.template_release.x86_64.lib on VM)"; \
    else \
        echo "   ❌ Not built - run 'just build-sentry-native-windows-release'"; \
    fi

# Validate integration (queries VM for .lib files - MSVC format)
sentry-native-windows-validate:
    @echo "🔍 Validating Native Windows Sentry integration..."
    @echo ""
    @VALIDATED=0; \
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_debug.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then \
        echo "✅ Debug native Sentry built"; \
        VALIDATED=1; \
    else \
        echo "❌ Debug native Sentry not built"; \
    fi; \
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist {{WIN_VM_REPO}}\\extras\\sentry-godot\\modules\\godot-cpp\\bin\\libgodot-cpp.windows.template_release.x86_64.lib echo exists" 2>/dev/null | grep -q exists; then \
        echo "✅ Release native Sentry built"; \
        VALIDATED=1; \
    else \
        echo "❌ Release native Sentry not built"; \
    fi; \
    if [ $VALIDATED -eq 1 ]; then \
        echo ""; \
        echo "✅ Native Windows Sentry validation passed"; \
        echo ""; \
        echo "💡 Next: Build Windows templates to include native Sentry:"; \
        echo "   just win-vm-template-debug"; \
        echo "   just win-vm-template-release"; \
    else \
        echo ""; \
        echo "❌ Validation failed - run 'just build-sentry-native-windows-all'"; \
        exit 1; \
    fi

# Clean native Sentry build artifacts
sentry-native-windows-clean:
    @echo "🧹 Cleaning Native Windows Sentry build artifacts..."
    @echo "💡 Cleaning on Windows VM..."
    @ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}}/extras/sentry-godot && scons platform=windows --clean' 2>/dev/null || echo "   (VM already clean or unreachable)"
    @echo "✅ Native Windows Sentry build artifacts cleaned"
